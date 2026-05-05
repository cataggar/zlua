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
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @rem(left, right) }});
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = @rem(try runtime.toNumber(lhs), try runtime.toNumber(rhs)) }});
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
    const integral = if (number >= 0) @floor(number) else @ceil(number);
    const int_value: Value = if (runtime.floatToInteger(integral)) |integer| .{ .integer = integer } else .{ .number = integral };
    try state.returnValues(thread, op.base, op.return_count, &.{ int_value, .{ .number = number - integral } });
}

pub fn rad(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try unaryScale(state, thread, op, std.math.pi / 180.0);
}

pub fn random(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const raw = nextRandomUnit(state);
    if (op.arg_count == 0) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = raw }});
        return;
    }
    const low: i64 = if (op.arg_count == 1) 1 else runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected");
    const high: i64 = if (op.arg_count == 1) runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected") else runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    if (low > high) return state.fail("interval is empty");
    const span: u64 = @intCast(high - low + 1);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = low + @as(i64, @intCast(state.random_state % span)) }});
}

pub fn randomseed(state: *State, thread: *Thread, op: bytecode.Call) !void {
    state.random_state = @bitCast(runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse 0);
    _ = nextRandomUnit(state);
    try state.returnValues(thread, op.base, op.return_count, &.{});
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
    const result: Value = if (runtime.toInteger(value)) |integer| .{ .integer = integer } else if (value == .number) if (runtime.floatToInteger(value.number)) |integer| .{ .integer = integer } else .nil else .nil;
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
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
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

fn nextRandomUnit(state: *State) f64 {
    state.random_state = state.random_state *% 6364136223846793005 +% 1442695040888963407;
    return @as(f64, @floatFromInt(state.random_state >> 11)) / @as(f64, @floatFromInt(@as(u64, 1) << 53));
}
