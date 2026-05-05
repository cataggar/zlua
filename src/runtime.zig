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

pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: *Table,
    native_print,
    native_tostring,
};

const TableEntry = struct {
    key: Value,
    value: Value,
};

const Table = struct {
    entries: std.ArrayList(TableEntry) = .empty,

    fn get(self: Table, key: Value) Value {
        for (self.entries.items) |entry| {
            if (valuesEqual(entry.key, key)) return entry.value;
        }
        return .nil;
    }

    fn set(self: *Table, allocator: std.mem.Allocator, key: Value, value: Value) !void {
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
};

pub const Thread = struct {
    stack: []Value,
    frames: []CallFrame,

    pub fn init(allocator: std.mem.Allocator, register_count: usize) !Thread {
        const count = @max(register_count, 1);
        const stack = try allocator.alloc(Value, count);
        @memset(stack, .nil);
        const frames = try allocator.alloc(CallFrame, 1);
        frames[0] = .{ .base = 0, .pc = 0 };
        return .{ .stack = stack, .frames = frames };
    }

    pub fn deinit(self: *Thread, allocator: std.mem.Allocator) void {
        allocator.free(self.frames);
        allocator.free(self.stack);
        self.* = undefined;
    }
};

const CallFrame = struct {
    base: usize,
    pc: usize,
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
        var thread = try Thread.init(self.allocator, proto.max_registers);
        defer thread.deinit(self.allocator);
        try self.runProto(proto, &thread);
    }

    fn runProto(self: *State, proto: *const proto_mod.Proto, thread: *Thread) !void {
        var frame = &thread.frames[0];
        while (frame.pc < proto.instructions.items.len) {
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
                .new_table => |op| self.set(thread, op.dest, try self.newTable()),
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
                .call => |op| try self.callNative(thread, op),
                .ret => return,
                .band, .bor, .bxor, .bnot, .shl, .shr, .get_upvalue, .set_upvalue, .set_list, .tail_call, .vararg, .closure, .close, .for_prep, .for_loop, .tfor_prep, .tfor_call, .tfor_loop => return self.fail("unsupported runtime opcode"),
            }
        }
    }

    fn get(_: *State, thread: *Thread, register: bytecode.Register) Value {
        return thread.stack[register];
    }

    fn set(_: *State, thread: *Thread, register: bytecode.Register, value: Value) void {
        thread.stack[register] = value;
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

    fn newTable(self: *State) !Value {
        const table = try self.arena.allocator().create(Table);
        table.* = .{};
        return .{ .table = table };
    }

    fn getTable(self: *State, table_value: Value, key_value: Value) !Value {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail("attempt to index a non-table value"),
        };
        return table.get(try self.tableKey(key_value));
    }

    fn setTable(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail("attempt to index a non-table value"),
        };
        try table.set(self.arena.allocator(), try self.tableKey(key_value), value);
    }

    fn tableKey(self: *State, value: Value) !Value {
        return switch (value) {
            .nil => self.fail("table index is nil"),
            .number => |number| if (std.math.isNan(number)) self.fail("table index is NaN") else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    fn lengthOf(self: *State, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
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

    fn callNative(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const callee = self.get(thread, op.base);
        switch (callee) {
            .native_print => {
                for (0..op.arg_count) |index| {
                    if (index != 0) try self.stdout.append(self.allocator, '\t');
                    try appendValue(self.allocator, &self.stdout, self.get(thread, op.base + 1 + @as(bytecode.Register, @intCast(index))));
                }
                try self.stdout.append(self.allocator, '\n');
                for (0..op.return_count) |index| self.set(thread, op.base + @as(bytecode.Register, @intCast(index)), .nil);
            },
            .native_tostring => {
                var out = std.ArrayList(u8).empty;
                defer out.deinit(self.allocator);
                const value = if (op.arg_count == 0) Value.nil else self.get(thread, op.base + 1);
                try appendValue(self.allocator, &out, value);
                if (op.return_count > 0) self.set(thread, op.base, .{ .string = try self.intern(out.items) });
                for (1..op.return_count) |index| self.set(thread, op.base + @as(bytecode.Register, @intCast(index)), .nil);
            },
            else => return self.fail("attempt to call a non-function value"),
        }
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
        .native_print => rhs == .native_print,
        .native_tostring => rhs == .native_tostring,
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

fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |boolean| try out.appendSlice(allocator, if (boolean) "true" else "false"),
        .integer => |integer| try appendFmt(allocator, out, "{d}", .{integer}),
        .number => |number| try appendNumber(allocator, out, number),
        .string => |string| try out.appendSlice(allocator, string),
        .table => try out.appendSlice(allocator, "table"),
        .native_print => try out.appendSlice(allocator, "function: print"),
        .native_tostring => try out.appendSlice(allocator, "function: tostring"),
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
