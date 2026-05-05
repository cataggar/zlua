const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

const UnaryFn = enum { acos, asin, cos, exp, sin, sqrt, tan };
const IntegerUnaryFn = enum { ceil, floor };

pub fn abs(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    const result: Value = switch (value) {
        .integer => |integer| .{ .integer = if (integer == std.math.minInt(i64)) integer else @intCast(@abs(integer)) },
        else => .{ .number = @abs(try runtime.toNumber(value)) },
    };
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

pub fn acos(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .acos);
}

pub fn asin(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .asin);
}

pub fn atan(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const y = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const x = if (op.arg_count >= 2) try runtime.toNumber(runtime.argValue(state, thread, op, 1)) else 1.0;
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = std.math.atan2(y, x) }});
}

pub fn ceil(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try integerUnary(state, thread, op, .ceil);
}

pub fn cos(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .cos);
}

pub fn deg(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unaryScale(state, thread, op, 180.0 / std.math.pi);
}

pub fn exp(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .exp);
}

pub fn floor(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try integerUnary(state, thread, op, .floor);
}

pub fn fmod(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const lhs = runtime.argValue(state, thread, op, 0);
    const rhs = runtime.argValue(state, thread, op, 1);
    if (runtime.toInteger(lhs)) |left| if (runtime.toInteger(rhs)) |right| {
        if (right == 0) return state.fail("bad argument #2 to 'math.fmod' (zero)");
        if (left == std.math.minInt(i64) and right == -1) {
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @rem(left, right) }});
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = @rem(try runtime.toNumber(lhs), try runtime.toNumber(rhs)) }});
}

pub fn frexp(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    if (!std.math.isFinite(value)) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .number = value }, .{ .integer = 0 } });
        return;
    }
    const result = std.math.frexp(value);
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .number = result.significand }, .{ .integer = result.exponent } });
}

pub fn ldexp(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const exponent = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const clamped = std.math.clamp(exponent, std.math.minInt(i32), std.math.maxInt(i32));
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = std.math.ldexp(value, @intCast(clamped)) }});
}

pub fn log(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const result = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        std.math.log(f64, try runtime.toNumber(runtime.argValue(state, thread, op, 1)), value)
    else
        @log(value);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = result }});
}

pub fn max(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try minMax(state, thread, op, false);
}

pub fn min(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try minMax(state, thread, op, true);
}

pub fn modf(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const number = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    if (!std.math.isFinite(number)) {
        const frac = if (std.math.isNan(number)) number else 0.0;
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .number = number }, .{ .number = frac } });
        return;
    }
    const integral = if (number >= 0) @floor(number) else @ceil(number);
    const int_value: Value = if (runtime.floatToInteger(integral)) |integer| .{ .integer = integer } else .{ .number = integral };
    try state.returnValues(thread, op.base, op.return_count, &.{ int_value, .{ .number = number - integral } });
}

pub fn rad(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unaryScale(state, thread, op, std.math.pi / 180.0);
}

pub fn random(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count > 2) return state.fail("wrong number of arguments");
    const bits = nextRandom(state);
    if (op.arg_count == 0) {
        const value = @as(f64, @floatFromInt(bits >> 11)) / @as(f64, @floatFromInt(@as(u64, 1) << 53));
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = value }});
        return;
    }
    const low: i64 = if (op.arg_count == 1) 1 else runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected");
    const high: i64 = if (op.arg_count == 1) runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected") else runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    if (op.arg_count == 1 and high == 0) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @bitCast(bits) }});
        return;
    }
    if (low > high) return state.fail("interval is empty");
    const span = @as(u64, @bitCast(high -% low)) +% 1;
    const offset = projectRandom(state, bits, span -% 1);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = low +% @as(i64, @bitCast(offset)) }});
}

pub fn randomseed(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count > 2) return state.fail("wrong number of arguments");
    const seed1 = if (op.arg_count >= 1) runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected") else @as(i64, @bitCast(nextRandom(state)));
    const seed2 = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected") else if (op.arg_count == 0) @as(i64, @bitCast(nextRandom(state))) else 0;
    seedRandom(state, @bitCast(seed1), @bitCast(seed2));
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = seed1 }, .{ .integer = seed2 } });
}

pub fn sin(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .sin);
}

pub fn sqrt(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .sqrt);
}

pub fn tan(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unary(state, thread, op, .tan);
}

pub fn tointeger(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    const result: Value = switch (value) {
        .integer => |integer| .{ .integer = integer },
        .number => |number| if (runtime.floatToInteger(number)) |integer| .{ .integer = integer } else .nil,
        .string => |string| blk: {
            if (runtime.parseIntegerStrict(string)) |integer| break :blk .{ .integer = integer };
            const number = runtime.parseLuaNumber(string) catch break :blk .nil;
            break :blk if (runtime.floatToInteger(number)) |integer| .{ .integer = integer } else .nil;
        },
        else => .nil,
    };
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const result: Value = switch (runtime.argValue(state, thread, op, 0)) {
        .integer => .{ .string = try state.intern("integer") },
        .number => .{ .string = try state.intern("float") },
        else => .nil,
    };
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

pub fn ult(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const lhs = runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected");
    const rhs = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = @as(u64, @bitCast(lhs)) < @as(u64, @bitCast(rhs)) }});
}

fn unary(state: *State, thread: *Thread, op: bytecode.Call, func: UnaryFn) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const result = switch (func) {
        .acos => std.math.acos(value),
        .asin => std.math.asin(value),
        .cos => @cos(value),
        .exp => @exp(value),
        .sin => @sin(value),
        .sqrt => @sqrt(value),
        .tan => @tan(value),
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = result }});
}

fn unaryScale(state: *State, thread: *Thread, op: bytecode.Call, scale: f64) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = (try runtime.toNumber(runtime.argValue(state, thread, op, 0))) * scale }});
}

fn integerUnary(state: *State, thread: *Thread, op: bytecode.Call, func: IntegerUnaryFn) !void {
    const arg = runtime.argValue(state, thread, op, 0);
    if (arg == .integer) {
        try state.returnValues(thread, op.base, op.return_count, &.{arg});
        return;
    }
    const value = runtime.toNumber(arg) catch return state.fail("number expected");
    const number = switch (func) {
        .ceil => @ceil(value),
        .floor => @floor(value),
    };
    if (runtime.floatToInteger(number)) |integer| {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = integer }});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = number }});
    }
}

fn minMax(state: *State, thread: *Thread, op: bytecode.Call, choose_min: bool) !void {
    if (op.arg_count == 0) return state.fail("value expected");
    var best = runtime.argValue(state, thread, op, 0);
    var index: u16 = 1;
    while (index < op.arg_count) : (index += 1) {
        const value = runtime.argValue(state, thread, op, index);
        const choose = if (choose_min) try state.compareValues(thread, value, best, .lt) else try state.compareValues(thread, best, value, .lt);
        if (choose) best = value;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{best});
}

fn nextRandom(state: *State) u64 {
    const state0 = state.random_state[0];
    const state1 = state.random_state[1];
    const state2 = state.random_state[2] ^ state0;
    const state3 = state.random_state[3] ^ state1;
    const result = std.math.rotl(u64, state1 *% 5, 7) *% 9;
    state.random_state[0] = state0 ^ state3;
    state.random_state[1] = state1 ^ state2;
    state.random_state[2] = state2 ^ (state1 << 17);
    state.random_state[3] = std.math.rotl(u64, state3, 45);
    return result;
}

fn projectRandom(state: *State, initial: u64, range: u64) u64 {
    var limit = range;
    var shift: u8 = 1;
    while ((limit & (limit +% 1)) != 0) : (shift *= 2) {
        limit |= limit >> @intCast(shift);
    }
    var result = initial;
    while (true) {
        result &= limit;
        if (result <= range) return result;
        result = nextRandom(state);
    }
}

fn seedRandom(state: *State, seed1: u64, seed2: u64) void {
    state.random_state = .{ seed1, 0xff, seed2, 0 };
    for (0..16) |_| _ = nextRandom(state);
}
