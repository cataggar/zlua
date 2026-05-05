const std = @import("std");
const compile = @import("compile.zig");
const frontend = @import("frontend.zig");
const process = @import("testing/process.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

pub const RuntimeError = error{
    RuntimeError,
    StackOverflow,
    UnsupportedOpcode,
};

const max_stack_values: usize = 8192;
const max_call_frames: usize = 256;

pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: *Table,
    closure: *Closure,
    native_print,
    native_tostring,
    native_rawget,
    native_rawset,
    native_next,
    native_pairs,
    native_ipairs,
    native_ipairs_iter,
    native_table_create,
    native_select,
};

const Closure = struct {
    proto: *const proto_mod.Proto,
    upvalues: []const *Upvalue,
};

const Upvalue = struct {
    stack_index: usize,
    closed: Value = .nil,
    is_open: bool = true,
    next: ?*Upvalue = null,
};

const TableEntry = struct {
    key: Value,
    value: Value,
};

const Table = struct {
    array: std.ArrayList(Value) = .empty,
    entries: std.ArrayList(TableEntry) = .empty,
    metatable: ?*Table = null,

    fn init(allocator: std.mem.Allocator, array_hint: u32, hash_hint: u32) !Table {
        var table = Table{};
        errdefer table.deinit(allocator);
        try table.array.ensureTotalCapacity(allocator, array_hint);
        try table.entries.ensureTotalCapacity(allocator, hash_hint);
        return table;
    }

    fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.array.deinit(allocator);
        self.* = undefined;
    }

    fn get(self: Table, key: Value) Value {
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.array.items[index - 1];
        }
        for (self.entries.items) |entry| {
            if (valuesEqual(entry.key, key)) return entry.value;
        }
        return .nil;
    }

    fn set(self: *Table, allocator: std.mem.Allocator, key: Value, value: Value) !void {
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) {
                self.array.items[index - 1] = value;
                return;
            }
            if (value != .nil and (index == self.array.items.len + 1 or index <= self.array.capacity)) {
                const old_len = self.array.items.len;
                try self.array.resize(allocator, index);
                @memset(self.array.items[old_len..], .nil);
                self.array.items[index - 1] = value;
                self.removeHashKey(key);
                return;
            }
        }
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                if (value == .nil) {
                    _ = self.entries.swapRemove(index);
                } else {
                    self.entries.items[index].value = value;
                }
                return;
            }
        }
        if (value != .nil) try self.entries.append(allocator, .{ .key = key, .value = value });
    }

    fn len(self: Table) i64 {
        var result = self.array.items.len;
        while (result > 0 and self.array.items[result - 1] == .nil) result -= 1;
        while (result < std.math.maxInt(i64)) {
            const next_index = result + 1;
            if (self.get(.{ .integer = @intCast(next_index) }) == .nil) break;
            result = next_index;
        }
        return @intCast(result);
    }

    fn next(self: Table, key: Value) ![2]Value {
        if (key == .nil) return self.firstEntryAfterArray(0);
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.firstEntryAfterArray(index);
        }
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                if (index + 1 < self.entries.items.len) {
                    const next_entry = self.entries.items[index + 1];
                    return .{ next_entry.key, next_entry.value };
                }
                return .{ .nil, .nil };
            }
        }
        return error.RuntimeError;
    }

    fn firstEntryAfterArray(self: Table, index: usize) [2]Value {
        var next_index = index;
        while (next_index < self.array.items.len) {
            next_index += 1;
            const value = self.array.items[next_index - 1];
            if (value != .nil) return .{ .{ .integer = @intCast(next_index) }, value };
        }
        if (self.entries.items.len == 0) return .{ .nil, .nil };
        const entry = self.entries.items[0];
        return .{ entry.key, entry.value };
    }

    fn removeHashKey(self: *Table, key: Value) void {
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                _ = self.entries.swapRemove(index);
                return;
            }
        }
    }
};

pub const Thread = struct {
    stack: std.ArrayList(Value) = .empty,
    frames: std.ArrayList(CallFrame) = .empty,
    open_upvalues: ?*Upvalue = null,
    last_result_base: usize = 0,
    last_result_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, closure: *Closure) !Thread {
        var thread = Thread{};
        errdefer thread.deinit(allocator);
        const proto = closure.proto;
        try thread.ensureStack(allocator, @max(proto.max_registers, 1));
        try thread.frames.append(allocator, .{ .closure = closure, .proto = proto, .base = 0, .pc = 0, .return_start = 0, .return_count = 0, .varargs = &.{} });
        return thread;
    }

    pub fn deinit(self: *Thread, allocator: std.mem.Allocator) void {
        self.frames.deinit(allocator);
        self.stack.deinit(allocator);
        self.* = undefined;
    }

    fn ensureStack(self: *Thread, allocator: std.mem.Allocator, size: usize) !void {
        if (size > max_stack_values) return error.StackOverflow;
        const old_len = self.stack.items.len;
        if (size <= old_len) return;
        try self.stack.resize(allocator, size);
        @memset(self.stack.items[old_len..], .nil);
    }
};

const CallFrame = struct {
    closure: *Closure,
    proto: *const proto_mod.Proto,
    base: usize,
    pc: usize,
    return_start: usize,
    return_count: u16,
    varargs: []const Value,
};

pub const State = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    globals: std.StringHashMap(Value),
    strings: std.StringHashMap([]const u8),
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    last_error: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) !State {
        var state = State{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
            .strings = std.StringHashMap([]const u8).init(allocator),
        };
        errdefer state.deinit();
        try state.globals.put(try state.intern("print"), .native_print);
        try state.globals.put(try state.intern("tostring"), .native_tostring);
        try state.globals.put(try state.intern("rawget"), .native_rawget);
        try state.globals.put(try state.intern("rawset"), .native_rawset);
        try state.globals.put(try state.intern("next"), .native_next);
        try state.globals.put(try state.intern("pairs"), .native_pairs);
        try state.globals.put(try state.intern("ipairs"), .native_ipairs);
        try state.globals.put(try state.intern("select"), .native_select);

        const table_lib = try state.newTableWithHints(0, 1);
        try state.setTable(table_lib, .{ .string = try state.intern("create") }, .native_table_create);
        try state.globals.put(try state.intern("table"), table_lib);
        return state;
    }

    pub fn deinit(self: *State) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
        self.strings.deinit();
        self.globals.deinit();
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn execute(self: *State, proto: *const proto_mod.Proto) !void {
        const root = try self.newRootClosure(proto);
        var thread = try Thread.init(self.allocator, root);
        defer thread.deinit(self.allocator);
        try self.runThread(&thread);
    }

    fn runThread(self: *State, thread: *Thread) !void {
        while (thread.frames.items.len > 0) {
            var frame = &thread.frames.items[thread.frames.items.len - 1];
            const proto = frame.proto;
            if (frame.pc >= proto.instructions.items.len) {
                try self.returnFromFrame(thread, 0, 0);
                continue;
            }
            const instruction = proto.instructions.items[frame.pc];
            frame.pc += 1;

            switch (instruction) {
                .load_nil => |dest| self.set(thread, dest, .nil),
                .load_bool => |op| self.set(thread, op.dest, .{ .boolean = op.value }),
                .load_const => |op| self.set(thread, op.dest, try self.loadConstant(proto.constants.items[op.constant])),
                .move => |op| self.set(thread, op.dest, self.get(thread, op.source)),
                .get_global => |op| self.set(thread, op.register, self.globals.get(constantString(proto, op.name)) orelse .nil),
                .set_global => |op| try self.setGlobal(constantString(proto, op.name), self.get(thread, op.register)),
                .add => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .add)),
                .sub => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .sub)),
                .mul => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .mul)),
                .div => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .div)),
                .idiv => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .idiv)),
                .mod => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .mod)),
                .pow => |op| self.set(thread, op.dest, try numericBinary(self.get(thread, op.left), self.get(thread, op.right), .pow)),
                .unm => |op| self.set(thread, op.dest, try numericUnary(self.get(thread, op.source), .negate)),
                .concat => |op| self.set(thread, op.dest, try self.concatValues(self.get(thread, op.left), self.get(thread, op.right))),
                .eq => |op| self.set(thread, op.dest, .{ .boolean = valuesEqual(self.get(thread, op.left), self.get(thread, op.right)) }),
                .lt => |op| self.set(thread, op.dest, .{ .boolean = try lessThan(self.get(thread, op.left), self.get(thread, op.right)) }),
                .le => |op| self.set(thread, op.dest, .{ .boolean = try lessEqual(self.get(thread, op.left), self.get(thread, op.right)) }),
                .not => |op| self.set(thread, op.dest, .{ .boolean = !truthy(self.get(thread, op.source)) }),
                .len => |op| self.set(thread, op.dest, try self.lengthOf(self.get(thread, op.source))),
                .new_table => |op| self.set(thread, op.dest, try self.newTableWithHints(op.array_hint, op.hash_hint)),
                .set_list => |op| try self.setList(thread, op),
                .get_table => |op| self.set(thread, op.dest, try self.getTable(self.get(thread, op.table), self.get(thread, op.key))),
                .set_table => |op| try self.setTable(self.get(thread, op.table), self.get(thread, op.key), self.get(thread, op.value)),
                .get_field => |op| self.set(thread, op.dest, try self.getTable(self.get(thread, op.table), .{ .string = constantString(proto, op.name) })),
                .set_field => |op| try self.setTable(self.get(thread, op.table), .{ .string = constantString(proto, op.name) }, self.get(thread, op.value)),
                .jmp => |offset| jump(frame, offset),
                .test_op => |op| if (truthy(self.get(thread, op.register)) == op.jump_if_truthy) jump(frame, op.offset),
                .test_set => |op| {
                    const value = self.get(thread, op.source);
                    self.set(thread, op.dest, value);
                    if (truthy(value) == op.jump_if_truthy) jump(frame, op.offset);
                },
                .call => |op| try self.callValue(thread, op),
                .tail_call => |op| try self.tailCallValue(thread, op),
                .ret => |op| try self.returnFromFrame(thread, op.first, op.count),
                .vararg => |op| try self.loadVarargs(thread, op),
                .tfor_prep => |op| if (!(try self.advanceGenericFor(thread, op))) jump(frame, op.offset),
                .tfor_call => |op| _ = try self.advanceGenericFor(thread, op),
                .tfor_loop => |op| jump(frame, op.offset),
                .closure => |op| self.set(thread, op.dest, try self.newClosure(thread, proto.children.items[op.proto])),
                .get_upvalue => |op| self.set(thread, op.register, self.readUpvalue(thread, op.upvalue)),
                .set_upvalue => |op| self.writeUpvalue(thread, op.upvalue, self.get(thread, op.register)),
                .close => |register| self.closeUpvalues(thread, thread.frames.items[thread.frames.items.len - 1].base + register),
                .band, .bor, .bxor, .bnot, .shl, .shr, .for_prep, .for_loop => return self.fail("unsupported runtime opcode"),
            }
        }
    }

    fn get(_: *State, thread: *Thread, register: bytecode.Register) Value {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        return thread.stack.items[frame.base + register];
    }

    fn set(_: *State, thread: *Thread, register: bytecode.Register, value: Value) void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        thread.stack.items[frame.base + register] = value;
    }

    fn setGlobal(self: *State, name: []const u8, value: Value) !void {
        const key = if (self.globals.contains(name)) name else try self.intern(name);
        try self.globals.put(key, value);
    }

    fn loadConstant(self: *State, constant: bytecode.Constant) !Value {
        return switch (constant) {
            .nil => .nil,
            .boolean => |value| .{ .boolean = value },
            .integer => |lexeme| try parseIntegerLiteral(lexeme),
            .number => |lexeme| .{ .number = try parseLuaNumber(lexeme) },
            .string => |lexeme| .{ .string = try self.decodeStringLiteral(lexeme) },
        };
    }

    fn intern(self: *State, bytes: []const u8) ![]const u8 {
        if (self.strings.get(bytes)) |interned| return interned;
        const interned = try self.arena.allocator().dupe(u8, bytes);
        try self.strings.put(interned, interned);
        return interned;
    }

    fn decodeStringLiteral(self: *State, lexeme: []const u8) ![]const u8 {
        if (lexeme.len < 2) return lexeme;
        if (lexeme[0] == '\'' or lexeme[0] == '"') return self.decodeShortString(lexeme);
        if (lexeme[0] == '[') return self.decodeLongString(lexeme);
        return lexeme;
    }

    fn decodeShortString(self: *State, lexeme: []const u8) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);

        var index: usize = 1;
        while (index + 1 < lexeme.len) {
            const byte = lexeme[index];
            index += 1;
            if (byte != '\\') {
                try out.append(self.allocator, byte);
                continue;
            }
            if (index >= lexeme.len - 1) return self.fail("unfinished string escape");
            const escaped = lexeme[index];
            index += 1;
            switch (escaped) {
                'a' => try out.append(self.allocator, 0x07),
                'b' => try out.append(self.allocator, 0x08),
                'f' => try out.append(self.allocator, 0x0c),
                'n' => try out.append(self.allocator, '\n'),
                'r' => try out.append(self.allocator, '\r'),
                't' => try out.append(self.allocator, '\t'),
                'v' => try out.append(self.allocator, 0x0b),
                '\\', '"', '\'' => try out.append(self.allocator, escaped),
                'x' => {
                    if (index + 1 >= lexeme.len) return self.fail("invalid hexadecimal escape");
                    const value = hexValue(lexeme[index]) * 16 + hexValue(lexeme[index + 1]);
                    index += 2;
                    try out.append(self.allocator, @intCast(value));
                },
                '0'...'9' => {
                    var value: u32 = escaped - '0';
                    var count: usize = 1;
                    while (count < 3 and index < lexeme.len - 1 and std.ascii.isDigit(lexeme[index])) : (count += 1) {
                        value = value * 10 + lexeme[index] - '0';
                        index += 1;
                    }
                    try out.append(self.allocator, @intCast(value));
                },
                'z' => while (index < lexeme.len - 1 and std.ascii.isWhitespace(lexeme[index])) : (index += 1) {},
                'u' => {
                    if (index >= lexeme.len - 1 or lexeme[index] != '{') return self.fail("invalid unicode escape");
                    index += 1;
                    var value: u32 = 0;
                    var count: usize = 0;
                    while (index < lexeme.len - 1 and lexeme[index] != '}') : (index += 1) {
                        value = value * 16 + hexValue(lexeme[index]);
                        count += 1;
                    }
                    if (count == 0 or index >= lexeme.len - 1 or lexeme[index] != '}' or value > 0x10ffff) return self.fail("invalid unicode escape");
                    index += 1;
                    var encoded: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(@intCast(value), &encoded) catch return self.fail("invalid unicode escape");
                    try out.appendSlice(self.allocator, encoded[0..len]);
                },
                '\n' => {},
                '\r' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\n') index += 1;
                },
                else => return self.fail("invalid string escape"),
            }
        }

        const bytes = try self.intern(out.items);
        out.deinit(self.allocator);
        return bytes;
    }

    fn decodeLongString(self: *State, lexeme: []const u8) ![]const u8 {
        var level: usize = 0;
        while (1 + level < lexeme.len and lexeme[1 + level] == '=') level += 1;
        const content_start = level + 2;
        const content_end = lexeme.len - level - 2;
        var content = lexeme[content_start..content_end];
        if (std.mem.startsWith(u8, content, "\r\n")) {
            content = content[2..];
        } else if (std.mem.startsWith(u8, content, "\n") or std.mem.startsWith(u8, content, "\r")) {
            content = content[1..];
        }
        return self.intern(content);
    }

    fn newTableWithHints(self: *State, array_hint: u32, hash_hint: u32) !Value {
        const table = try self.arena.allocator().create(Table);
        table.* = try Table.init(self.arena.allocator(), array_hint, hash_hint);
        return .{ .table = table };
    }

    fn newRootClosure(self: *State, proto: *const proto_mod.Proto) !*Closure {
        const closure = try self.arena.allocator().create(Closure);
        closure.* = .{ .proto = proto, .upvalues = &.{} };
        return closure;
    }

    fn newClosure(self: *State, thread: *Thread, proto: *const proto_mod.Proto) !Value {
        const parent = thread.frames.items[thread.frames.items.len - 1];
        const upvalues = try self.arena.allocator().alloc(*Upvalue, proto.upvalues.items.len);
        for (proto.upvalues.items, 0..) |desc, index| {
            upvalues[index] = if (desc.in_stack)
                try self.captureUpvalue(thread, parent.base + desc.index)
            else
                parent.closure.upvalues[desc.index];
        }

        const closure = try self.arena.allocator().create(Closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues };
        return .{ .closure = closure };
    }

    fn captureUpvalue(self: *State, thread: *Thread, stack_index: usize) !*Upvalue {
        var current = thread.open_upvalues;
        while (current) |upvalue| : (current = upvalue.next) {
            if (upvalue.is_open and upvalue.stack_index == stack_index) return upvalue;
        }

        const upvalue = try self.arena.allocator().create(Upvalue);
        upvalue.* = .{ .stack_index = stack_index, .next = thread.open_upvalues };
        thread.open_upvalues = upvalue;
        return upvalue;
    }

    fn readUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex) Value {
        _ = self;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        return if (upvalue.is_open) thread.stack.items[upvalue.stack_index] else upvalue.closed;
    }

    fn writeUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex, value: Value) void {
        _ = self;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        if (upvalue.is_open) {
            thread.stack.items[upvalue.stack_index] = value;
        } else {
            upvalue.closed = value;
        }
    }

    fn closeUpvalues(self: *State, thread: *Thread, first_stack_index: usize) void {
        _ = self;
        var previous: ?*Upvalue = null;
        var current = thread.open_upvalues;
        while (current) |upvalue| {
            const next = upvalue.next;
            if (upvalue.is_open and upvalue.stack_index >= first_stack_index) {
                upvalue.closed = thread.stack.items[upvalue.stack_index];
                upvalue.is_open = false;
                upvalue.next = null;
                if (previous) |prev| {
                    prev.next = next;
                } else {
                    thread.open_upvalues = next;
                }
            } else {
                previous = upvalue;
            }
            current = next;
        }
    }

    fn getTable(self: *State, table_value: Value, key_value: Value) !Value {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail("attempt to index a non-table value"),
        };
        const key = try self.readableTableKey(key_value) orelse return .nil;
        return table.get(key);
    }

    fn setTable(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail("attempt to index a non-table value"),
        };
        try table.set(self.arena.allocator(), try self.writableTableKey(key_value), value);
    }

    fn readableTableKey(self: *State, value: Value) !?Value {
        _ = self;
        return switch (value) {
            .nil => null,
            .number => |number| if (std.math.isNan(number)) null else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    fn writableTableKey(self: *State, value: Value) !Value {
        return switch (value) {
            .nil => self.fail("table index is nil"),
            .number => |number| if (std.math.isNan(number)) self.fail("table index is NaN") else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    fn lengthOf(self: *State, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
            .table => |table| .{ .integer = table.len() },
            else => self.fail("attempt to get length of a non-string value"),
        };
    }

    fn concatValues(self: *State, lhs: Value, rhs: Value) !Value {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try appendLuaString(self.allocator, &out, lhs);
        try appendLuaString(self.allocator, &out, rhs);
        return .{ .string = try self.intern(out.items) };
    }

    fn callValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const callee = self.get(thread, op.base);
        const resolved = try self.resolveCall(thread, op);
        switch (callee) {
            .closure => |closure| try self.callClosure(thread, resolved, closure),
            .native_print => {
                for (0..resolved.arg_count) |index| {
                    if (index != 0) try self.stdout.append(self.allocator, '\t');
                    try appendValue(self.allocator, &self.stdout, self.get(thread, resolved.base + 1 + @as(bytecode.Register, @intCast(index))));
                }
                try self.stdout.append(self.allocator, '\n');
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{});
            },
            .native_tostring => {
                var out = std.ArrayList(u8).empty;
                defer out.deinit(self.allocator);
                const value = if (resolved.arg_count == 0) Value.nil else self.get(thread, resolved.base + 1);
                try appendValue(self.allocator, &out, value);
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{.{ .string = try self.intern(out.items) }});
            },
            .native_rawget => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.rawGet(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1))}),
            .native_rawset => {
                const table = argValue(self, thread, resolved, 0);
                try self.rawSet(table, argValue(self, thread, resolved, 1), argValue(self, thread, resolved, 2));
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{table});
            },
            .native_next => {
                const values = try self.nextValues(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_pairs => {
                const table = try self.expectTable(argValue(self, thread, resolved, 0));
                _ = table;
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_next, argValue(self, thread, resolved, 0), .nil });
            },
            .native_ipairs => {
                const table = try self.expectTable(argValue(self, thread, resolved, 0));
                _ = table;
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_ipairs_iter, argValue(self, thread, resolved, 0), .{ .integer = 0 } });
            },
            .native_ipairs_iter => {
                const values = try self.ipairsIterValues(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_table_create => {
                const array_hint = try self.tableCreateHint(argValue(self, thread, resolved, 0));
                const hash_hint = if (resolved.arg_count >= 2) try self.tableCreateHint(argValue(self, thread, resolved, 1)) else 0;
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.newTableWithHints(array_hint, hash_hint)});
            },
            .native_select => try self.selectValues(thread, resolved),
            else => return self.fail("attempt to call a non-function value"),
        }
    }

    fn callClosure(self: *State, thread: *Thread, op: bytecode.Call, closure: *Closure) !void {
        if (thread.frames.items.len >= max_call_frames) return self.fail("stack overflow");

        const caller = thread.frames.items[thread.frames.items.len - 1];
        const base = caller.base + op.base;
        const frame = try self.prepareClosureFrame(thread, closure, base, base, @intCast(op.arg_count), base, op.return_count);

        try thread.frames.append(self.allocator, .{
            .closure = frame.closure,
            .proto = frame.proto,
            .base = frame.base,
            .pc = frame.pc,
            .return_start = frame.return_start,
            .return_count = frame.return_count,
            .varargs = frame.varargs,
        });
    }

    fn tailCallValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const callee = self.get(thread, op.base);
        const resolved = try self.resolveCall(thread, op);
        switch (callee) {
            .closure => |closure| {
                self.closeUpvalues(thread, frame.base);
                const new_frame = try self.prepareClosureFrame(thread, closure, frame.base + resolved.base, frame.base, @intCast(resolved.arg_count), frame.return_start, frame.return_count);
                thread.frames.items[thread.frames.items.len - 1] = new_frame;
            },
            else => {
                try self.callValue(thread, .{ .base = resolved.base, .arg_count = resolved.arg_count, .return_count = frame.return_count });
                try self.returnFromFrame(thread, resolved.base, frame.return_count);
            },
        }
    }

    fn returnFromFrame(self: *State, thread: *Thread, first: bytecode.Register, count: u16) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const source_start = frame.base + first;
        const source_count = try self.resolveResultCount(thread, source_start, count);
        self.closeUpvalues(thread, frame.base);
        if (thread.frames.items.len == 1) {
            thread.frames.items.len = 0;
            return;
        }

        const return_start = frame.return_start;
        const return_count = try self.resolveReturnCount(frame.return_count, source_count);
        thread.frames.items.len -= 1;

        try thread.ensureStack(self.allocator, return_start + return_count);
        const copied = @min(return_count, source_count);
        copyStackValues(thread, return_start, source_start, copied);
        for (copied..return_count) |index| thread.stack.items[return_start + index] = .nil;
        thread.last_result_base = return_start;
        thread.last_result_count = return_count;
    }

    fn returnValues(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, values: []const Value) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const actual_count = try self.resolveReturnCount(return_count, values.len);
        const absolute_base = frame.base + base;
        try thread.ensureStack(self.allocator, absolute_base + actual_count);
        for (0..actual_count) |index| {
            thread.stack.items[absolute_base + index] = if (index < values.len) values[index] else .nil;
        }
        thread.last_result_base = absolute_base;
        thread.last_result_count = actual_count;
    }

    fn prepareClosureFrame(self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame {
        const register_count = @max(closure.proto.max_registers, 1);
        const param_count = @as(usize, closure.proto.param_count);
        const copied = @min(arg_count, param_count);
        const varargs = try self.captureVarargs(thread, source_base + 1 + param_count, if (closure.proto.is_vararg and arg_count > param_count) arg_count - param_count else 0);
        try thread.ensureStack(self.allocator, frame_base + register_count);

        for (0..copied) |index| thread.stack.items[frame_base + index] = thread.stack.items[source_base + 1 + index];
        for (copied..register_count) |index| thread.stack.items[frame_base + index] = .nil;

        if (closure.proto.is_vararg and closure.proto.max_registers > closure.proto.param_count) {
            thread.stack.items[frame_base + param_count] = try self.namedVarargTable(varargs);
        }

        return .{
            .closure = closure,
            .proto = closure.proto,
            .base = frame_base,
            .pc = 0,
            .return_start = return_start,
            .return_count = return_count,
            .varargs = varargs,
        };
    }

    fn captureVarargs(self: *State, thread: *Thread, source_start: usize, count: usize) ![]const Value {
        if (count == 0) return &.{};
        const values = try self.arena.allocator().alloc(Value, count);
        for (0..count) |index| values[index] = thread.stack.items[source_start + index];
        return values;
    }

    fn namedVarargTable(self: *State, varargs: []const Value) !Value {
        const table_value = try self.newTableWithHints(@intCast(varargs.len), 1);
        try self.setTable(table_value, .{ .string = try self.intern("n") }, .{ .integer = @intCast(varargs.len) });
        for (varargs, 0..) |value, index| {
            try self.setTable(table_value, .{ .integer = @intCast(index + 1) }, value);
        }
        return table_value;
    }

    fn resolveCall(self: *State, thread: *Thread, op: bytecode.Call) !bytecode.Call {
        if (op.arg_count != bytecode.multret_count) return op;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const expected_base = frame.base + op.base + 1;
        if (thread.last_result_base < expected_base) return self.fail("invalid multiple-return call state");
        const end = thread.last_result_base + thread.last_result_count;
        const count = if (end <= expected_base) 0 else end - expected_base;
        return .{ .base = op.base, .arg_count = @intCast(count), .return_count = op.return_count };
    }

    fn resolveResultCount(self: *State, thread: *Thread, source_start: usize, count: u16) !usize {
        if (count != bytecode.multret_count) return count;
        if (thread.last_result_base < source_start) return self.fail("invalid multiple-return result state");
        const end = thread.last_result_base + thread.last_result_count;
        return if (end <= source_start) 0 else end - source_start;
    }

    fn resolveReturnCount(self: *State, count: u16, available: usize) !usize {
        _ = self;
        return if (count == bytecode.multret_count) available else count;
    }

    fn loadVarargs(self: *State, thread: *Thread, op: bytecode.Vararg) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const actual_count = try self.resolveReturnCount(op.count, frame.varargs.len);
        const dest = frame.base + op.dest;
        try thread.ensureStack(self.allocator, dest + actual_count);
        const copied = @min(actual_count, frame.varargs.len);
        for (0..copied) |index| thread.stack.items[dest + index] = frame.varargs[index];
        for (copied..actual_count) |index| thread.stack.items[dest + index] = .nil;
        thread.last_result_base = dest;
        thread.last_result_count = actual_count;
    }

    fn setList(self: *State, thread: *Thread, op: bytecode.SetList) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const source_start = frame.base + op.first;
        const count = if (op.count == bytecode.multret_count) try self.resolveResultCount(thread, source_start, bytecode.multret_count) else op.count;
        const table_value = self.get(thread, op.table);
        for (0..count) |index| {
            try self.setTable(table_value, .{ .integer = @intCast(op.start_index + index) }, thread.stack.items[source_start + index]);
        }
    }

    fn selectValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.fail("bad argument #1 to 'select'");
        const first = argValue(self, thread, op, 0);
        if (first == .string and std.mem.eql(u8, first.string, "#")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(op.arg_count - 1) }});
            return;
        }

        var index = toInteger(first) orelse return self.fail("bad argument #1 to 'select'");
        const count: i64 = @intCast(op.arg_count - 1);
        if (index < 0) index = count + index + 1;
        if (index < 1 or index > count + 1) return self.fail("bad argument #1 to 'select'");

        var values = std.ArrayList(Value).empty;
        defer values.deinit(self.allocator);
        var arg_index: usize = @intCast(index);
        const last_arg: usize = @intCast(count);
        while (arg_index <= last_arg) : (arg_index += 1) {
            try values.append(self.allocator, argValue(self, thread, op, @intCast(arg_index)));
        }
        try self.returnValues(thread, op.base, op.return_count, values.items);
    }

    fn rawGet(self: *State, table_value: Value, key_value: Value) !Value {
        const table = try self.expectTable(table_value);
        const key = try self.readableTableKey(key_value) orelse return .nil;
        return table.get(key);
    }

    fn rawSet(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        const table = try self.expectTable(table_value);
        try table.set(self.arena.allocator(), try self.writableTableKey(key_value), value);
    }

    fn nextValues(self: *State, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        const key = try self.readableTableKey(key_value) orelse Value.nil;
        return table.next(key) catch return self.fail("invalid key to 'next'");
    }

    fn ipairsIterValues(self: *State, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        const current = toInteger(key_value) orelse return self.fail("invalid index to 'ipairs'");
        if (current == std.math.maxInt(i64)) return .{ .nil, .nil };
        const next_index = current + 1;
        const value = table.get(.{ .integer = next_index });
        if (value == .nil) return .{ .nil, .nil };
        return .{ .{ .integer = next_index }, value };
    }

    fn advanceGenericFor(self: *State, thread: *Thread, op: bytecode.GenericFor) !bool {
        const iterator = self.get(thread, op.base);
        const state = self.get(thread, op.base + 1);
        const control = self.get(thread, op.base + 2);
        const values = switch (iterator) {
            .native_next => try self.nextValues(state, control),
            .native_ipairs_iter => try self.ipairsIterValues(state, control),
            else => return self.fail("attempt to call a non-function value"),
        };
        self.set(thread, op.base + 2, values[0]);
        for (0..op.variable_count) |index| {
            const value = if (index < values.len) values[index] else Value.nil;
            self.set(thread, op.base + 3 + @as(bytecode.Register, @intCast(index)), value);
        }
        return values[0] != .nil;
    }

    fn expectTable(self: *State, value: Value) !*Table {
        return switch (value) {
            .table => |table| table,
            else => self.fail("table expected"),
        };
    }

    fn tableCreateHint(self: *State, value: Value) !u32 {
        const integer = toInteger(value) orelse return self.fail("number expected");
        if (integer < 0) return self.fail("negative size");
        return std.math.cast(u32, integer) orelse self.fail("size too large");
    }

    fn fail(self: *State, message: []const u8) RuntimeError {
        self.last_error = message;
        return error.RuntimeError;
    }
};

pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    var tree = frontend.parse(allocator, source) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua parser rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };
    defer tree.deinit();

    compile.resolver.resolve(allocator, &tree) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua resolver rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };

    var proto = compile.compile(allocator, &tree) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua compiler rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };
    defer proto.deinit();

    var state = try State.init(allocator);
    defer state.deinit();
    state.execute(&proto) catch |err| {
        const detail = state.last_error orelse @errorName(err);
        const message = try std.fmt.allocPrint(allocator, "zlua runtime error: {s}\n", .{detail});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };

    return .{
        .stdout = try allocator.dupe(u8, state.stdout.items),
        .stderr = try allocator.dupe(u8, state.stderr.items),
        .exit_code = 0,
        .signal = null,
        .timed_out = false,
    };
}

const NumericOp = enum { add, sub, mul, div, idiv, mod, pow };
const UnaryOp = enum { negate };

fn numericBinary(lhs: Value, rhs: Value, op: NumericOp) !Value {
    if (op != .div and op != .pow) {
        if (toInteger(lhs)) |left| {
            if (toInteger(rhs)) |right| {
                return switch (op) {
                    .add => .{ .integer = left +% right },
                    .sub => .{ .integer = left -% right },
                    .mul => .{ .integer = left *% right },
                    .idiv => if (right == 0) error.RuntimeError else .{ .integer = floorDiv(left, right) },
                    .mod => if (right == 0) error.RuntimeError else .{ .integer = floorMod(left, right) },
                    else => unreachable,
                };
            }
        }
    }

    const left = try toNumber(lhs);
    const right = try toNumber(rhs);
    return switch (op) {
        .add => .{ .number = left + right },
        .sub => .{ .number = left - right },
        .mul => .{ .number = left * right },
        .div => .{ .number = left / right },
        .idiv => .{ .number = @floor(left / right) },
        .mod => .{ .number = left - @floor(left / right) * right },
        .pow => .{ .number = std.math.pow(f64, left, right) },
    };
}

fn numericUnary(value: Value, op: UnaryOp) !Value {
    return switch (op) {
        .negate => switch (value) {
            .integer => |integer| .{ .integer = -%integer },
            .number => |number| .{ .number = -number },
            else => .{ .number = -(try toNumber(value)) },
        },
    };
}

fn valuesEqual(lhs: Value, rhs: Value) bool {
    return switch (lhs) {
        .nil => rhs == .nil,
        .boolean => |value| rhs == .boolean and rhs.boolean == value,
        .integer => |value| switch (rhs) {
            .integer => |other| value == other,
            .number => |other| @as(f64, @floatFromInt(value)) == other,
            else => false,
        },
        .number => |value| switch (rhs) {
            .integer => |other| value == @as(f64, @floatFromInt(other)),
            .number => |other| value == other,
            else => false,
        },
        .string => |value| rhs == .string and std.mem.eql(u8, value, rhs.string),
        .table => |value| rhs == .table and value == rhs.table,
        .closure => |value| rhs == .closure and value == rhs.closure,
        .native_print => rhs == .native_print,
        .native_tostring => rhs == .native_tostring,
        .native_rawget => rhs == .native_rawget,
        .native_rawset => rhs == .native_rawset,
        .native_next => rhs == .native_next,
        .native_pairs => rhs == .native_pairs,
        .native_ipairs => rhs == .native_ipairs,
        .native_ipairs_iter => rhs == .native_ipairs_iter,
        .native_table_create => rhs == .native_table_create,
        .native_select => rhs == .native_select,
    };
}

fn lessThan(lhs: Value, rhs: Value) !bool {
    return switch (lhs) {
        .integer, .number => (try toNumber(lhs)) < (try toNumber(rhs)),
        .string => |left| switch (rhs) {
            .string => |right| std.mem.lessThan(u8, left, right),
            else => error.RuntimeError,
        },
        else => error.RuntimeError,
    };
}

fn lessEqual(lhs: Value, rhs: Value) !bool {
    return valuesEqual(lhs, rhs) or try lessThan(lhs, rhs);
}

fn truthy(value: Value) bool {
    return switch (value) {
        .nil => false,
        .boolean => |boolean| boolean,
        else => true,
    };
}

fn toInteger(value: Value) ?i64 {
    return switch (value) {
        .integer => |integer| integer,
        .string => |string| parseIntegerStrict(string),
        else => null,
    };
}

fn toNumber(value: Value) !f64 {
    return switch (value) {
        .integer => |integer| @floatFromInt(integer),
        .number => |number| number,
        .string => |string| parseLuaNumber(string),
        else => error.RuntimeError,
    };
}

fn appendLuaString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .integer, .number, .string => try appendValue(allocator, out, value),
        else => return error.RuntimeError,
    }
}

fn floorDiv(left: i64, right: i64) i64 {
    return @divFloor(left, right);
}

fn floorMod(left: i64, right: i64) i64 {
    return @mod(left, right);
}

fn jump(frame: *CallFrame, offset: bytecode.JumpOffset) void {
    if (offset >= 0) {
        frame.pc += @intCast(offset);
    } else {
        frame.pc -= @intCast(-offset);
    }
}

fn copyStackValues(thread: *Thread, dest: usize, source: usize, count: usize) void {
    if (count == 0 or dest == source) return;
    if (dest > source and dest < source + count) {
        var index = count;
        while (index > 0) {
            index -= 1;
            thread.stack.items[dest + index] = thread.stack.items[source + index];
        }
    } else {
        for (0..count) |index| thread.stack.items[dest + index] = thread.stack.items[source + index];
    }
}

fn constantString(proto: *const proto_mod.Proto, index: bytecode.ConstantIndex) []const u8 {
    return proto.constants.items[index].string;
}

fn parseIntegerLiteral(lexeme: []const u8) !Value {
    if (isHex(lexeme)) {
        const unsigned = try std.fmt.parseInt(u64, lexeme[2..], 16);
        return .{ .integer = @as(i64, @bitCast(unsigned)) };
    }
    if (std.fmt.parseInt(i64, lexeme, 10)) |integer| {
        return .{ .integer = integer };
    } else |_| {
        return .{ .number = try std.fmt.parseFloat(f64, lexeme) };
    }
}

fn parseIntegerStrict(text: []const u8) ?i64 {
    const trimmed = trimAscii(text);
    if (trimmed.len == 0) return null;
    if (isHex(trimmed)) {
        for (trimmed[2..]) |byte| if (!std.ascii.isHex(byte)) return null;
        const unsigned = std.fmt.parseInt(u64, trimmed[2..], 16) catch return null;
        return @as(i64, @bitCast(unsigned));
    }
    for (trimmed, 0..) |byte, index| {
        if (index == 0 and (byte == '+' or byte == '-')) continue;
        if (!std.ascii.isDigit(byte)) return null;
    }
    return std.fmt.parseInt(i64, trimmed, 10) catch null;
}

fn parseLuaNumber(text: []const u8) !f64 {
    const trimmed = trimAscii(text);
    if (trimmed.len == 0) return error.RuntimeError;
    if (isHex(trimmed)) return parseHexNumber(trimmed);
    return std.fmt.parseFloat(f64, trimmed);
}

fn parseHexNumber(text: []const u8) !f64 {
    var index: usize = 2;
    var value: f64 = 0;
    var digits: usize = 0;
    while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
        value = value * 16 + @as(f64, @floatFromInt(hexValue(text[index])));
        digits += 1;
    }
    if (index < text.len and text[index] == '.') {
        index += 1;
        var place: f64 = 1.0 / 16.0;
        while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
            value += @as(f64, @floatFromInt(hexValue(text[index]))) * place;
            place /= 16.0;
            digits += 1;
        }
    }
    if (digits == 0) return error.RuntimeError;

    var exponent: i32 = 0;
    if (index < text.len and (text[index] == 'p' or text[index] == 'P')) {
        index += 1;
        var sign: i32 = 1;
        if (index < text.len and (text[index] == '+' or text[index] == '-')) {
            sign = if (text[index] == '-') -1 else 1;
            index += 1;
        }
        const exponent_start = index;
        while (index < text.len and std.ascii.isDigit(text[index])) : (index += 1) {
            exponent = exponent * 10 + @as(i32, @intCast(text[index] - '0'));
        }
        if (index == exponent_start) return error.RuntimeError;
        exponent *= sign;
    }
    if (index != text.len) return error.RuntimeError;
    return value * std.math.pow(f64, 2.0, @floatFromInt(exponent));
}

fn floatToInteger(number: f64) ?i64 {
    if (!std.math.isFinite(number) or @floor(number) != number) return null;
    const min = @as(f64, @floatFromInt(std.math.minInt(i64)));
    const max = @as(f64, @floatFromInt(std.math.maxInt(i64)));
    if (number < min or number > max) return null;
    return @intFromFloat(number);
}

fn isHex(text: []const u8) bool {
    return text.len >= 3 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X');
}

fn trimAscii(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\n\r\x0b\x0c");
}

fn arrayIndex(value: Value) ?usize {
    const integer = switch (value) {
        .integer => |integer| integer,
        else => return null,
    };
    if (integer <= 0) return null;
    return std.math.cast(usize, integer);
}

fn argValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value {
    if (index >= op.arg_count) return .nil;
    return state.get(thread, op.base + 1 + index);
}

fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |boolean| try out.appendSlice(allocator, if (boolean) "true" else "false"),
        .integer => |integer| try appendFmt(allocator, out, "{d}", .{integer}),
        .number => |number| try appendNumber(allocator, out, number),
        .string => |string| try out.appendSlice(allocator, string),
        .table => try out.appendSlice(allocator, "table"),
        .closure => try out.appendSlice(allocator, "function"),
        .native_print => try out.appendSlice(allocator, "function: print"),
        .native_tostring => try out.appendSlice(allocator, "function: tostring"),
        .native_rawget => try out.appendSlice(allocator, "function: rawget"),
        .native_rawset => try out.appendSlice(allocator, "function: rawset"),
        .native_next => try out.appendSlice(allocator, "function: next"),
        .native_pairs => try out.appendSlice(allocator, "function: pairs"),
        .native_ipairs => try out.appendSlice(allocator, "function: ipairs"),
        .native_ipairs_iter => try out.appendSlice(allocator, "function: ipairs iterator"),
        .native_table_create => try out.appendSlice(allocator, "function: table.create"),
        .native_select => try out.appendSlice(allocator, "function: select"),
    }
}

fn appendNumber(allocator: std.mem.Allocator, out: *std.ArrayList(u8), number: f64) !void {
    try appendFmt(allocator, out, "{d}", .{number});
    if (@floor(number) == number and std.math.isFinite(number)) {
        try out.appendSlice(allocator, ".0");
    }
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn hexValue(byte: u8) u32 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => 0,
    };
}

test "executes basic print and arithmetic" {
    var result = try executeSource(std.testing.allocator,
        \\print(1 + 2)
        \\print(9 // 4)
        \\print(2 ^ 8)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "3\n2\n256.0\n"));
}

test "executes if while and repeat jumps" {
    var result = try executeSource(std.testing.allocator,
        \\local x = 0
        \\while x < 3 do
        \\  x = x + 1
        \\end
        \\if x == 3 then print("while") else print("bad") end
        \\repeat
        \\  x = x - 1
        \\until x == 0
        \\print(x)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "while\n0\n"));
}

test "reports stack overflow for unbounded Lua recursion" {
    var result = try executeSource(std.testing.allocator,
        \\function f()
        \\  return 1 + f()
        \\end
        \\f()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack overflow") != null);
}

test "reports calls to non-functions" {
    var result = try executeSource(std.testing.allocator,
        \\local value = 1
        \\value()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "attempt to call a non-function value") != null);
}
