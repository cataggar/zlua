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
    native_print,
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
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    last_error: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator) !State {
        var state = State{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
        };
        errdefer state.deinit();
        try state.globals.put(try state.arena.allocator().dupe(u8, "print"), .native_print);
        return state;
    }

    pub fn deinit(self: *State) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
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
                .eq => |op| self.set(thread, op.dest, .{ .boolean = valuesEqual(self.get(thread, op.left), self.get(thread, op.right)) }),
                .lt => |op| self.set(thread, op.dest, .{ .boolean = try lessThan(self.get(thread, op.left), self.get(thread, op.right)) }),
                .le => |op| self.set(thread, op.dest, .{ .boolean = try lessEqual(self.get(thread, op.left), self.get(thread, op.right)) }),
                .not => |op| self.set(thread, op.dest, .{ .boolean = !truthy(self.get(thread, op.source)) }),
                .jmp => |offset| jump(frame, offset),
                .test_op => |op| if (truthy(self.get(thread, op.register)) == op.jump_if_truthy) jump(frame, op.offset),
                .test_set => |op| {
                    const value = self.get(thread, op.source);
                    self.set(thread, op.dest, value);
                    if (truthy(value) == op.jump_if_truthy) jump(frame, op.offset);
                },
                .call => |op| try self.callNative(thread, op),
                .ret => return,
                .band, .bor, .bxor, .bnot, .shl, .shr, .len, .concat, .get_upvalue, .set_upvalue, .get_table, .set_table, .get_field, .set_field, .new_table, .set_list, .tail_call, .vararg, .closure, .close, .for_prep, .for_loop, .tfor_prep, .tfor_call, .tfor_loop => return self.fail("unsupported runtime opcode"),
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
        const key = if (self.globals.contains(name)) name else try self.arena.allocator().dupe(u8, name);
        try self.globals.put(key, value);
    }

    fn loadConstant(self: *State, constant: bytecode.Constant) !Value {
        return switch (constant) {
            .nil => .nil,
            .boolean => |value| .{ .boolean = value },
            .integer => |lexeme| .{ .integer = try parseInteger(lexeme) },
            .number => |lexeme| .{ .number = try std.fmt.parseFloat(f64, lexeme) },
            .string => |lexeme| .{ .string = try self.decodeStringLiteral(lexeme) },
        };
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
                '\n' => {},
                '\r' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\n') index += 1;
                },
                else => return self.fail("invalid string escape"),
            }
        }

        const bytes = try self.arena.allocator().dupe(u8, out.items);
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
        return self.arena.allocator().dupe(u8, content);
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
        .native_print => rhs == .native_print,
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
        else => null,
    };
}

fn toNumber(value: Value) !f64 {
    return switch (value) {
        .integer => |integer| @floatFromInt(integer),
        .number => |number| number,
        else => error.RuntimeError,
    };
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

fn parseInteger(lexeme: []const u8) !i64 {
    if (std.mem.startsWith(u8, lexeme, "0x") or std.mem.startsWith(u8, lexeme, "0X")) {
        return std.fmt.parseInt(i64, lexeme[2..], 16);
    }
    return std.fmt.parseInt(i64, lexeme, 10);
}

fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |boolean| try out.appendSlice(allocator, if (boolean) "true" else "false"),
        .integer => |integer| try appendFmt(allocator, out, "{d}", .{integer}),
        .number => |number| try appendNumber(allocator, out, number),
        .string => |string| try out.appendSlice(allocator, string),
        .native_print => try out.appendSlice(allocator, "function: print"),
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
