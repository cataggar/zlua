const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn load(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const closure = state.loadSourceAsClosure(source) catch {
        const message = state.last_error orelse "cannot load source";
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{closure});
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(typeName(runtime.argValue(state, thread, op, 0))) }});
}

pub fn tonumber(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil) {
        const base = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("base out of range");
        if (base < 2 or base > 36) return state.fail("base out of range");
        const string = try state.expectString(value);
        const parsed = parseIntegerBase(runtime.trimAscii(string), @intCast(base)) orelse Value.nil;
        try state.returnValues(thread, op.base, op.return_count, &.{parsed});
        return;
    }
    if (value == .integer or value == .number) {
        try state.returnValues(thread, op.base, op.return_count, &.{value});
    } else if (value == .string) {
        const parsed = if (runtime.parseIntegerStrict(value.string)) |integer| Value{ .integer = integer } else if (runtime.parseLuaNumber(value.string)) |number| Value{ .number = number } else |_| Value.nil;
        try state.returnValues(thread, op.base, op.return_count, &.{parsed});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
    }
}

pub fn warn(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn typeName(value: Value) []const u8 {
    return switch (value) {
        .nil => "nil",
        .boolean => "boolean",
        .integer, .number => "number",
        .string => "string",
        .table => "table",
        .closure, .coroutine_wrapper, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_wrap, .native => "function",
        .thread => "thread",
    };
}

fn parseIntegerBase(text: []const u8, base: u8) ?Value {
    if (text.len == 0) return null;
    var index: usize = 0;
    var sign: i64 = 1;
    if (text[0] == '+' or text[0] == '-') {
        sign = if (text[0] == '-') -1 else 1;
        index = 1;
    }
    if (index == text.len) return null;
    var value: i64 = 0;
    while (index < text.len) : (index += 1) {
        const digit = digitValue(text[index]) orelse return null;
        if (digit >= base) return null;
        value = value * base + digit;
    }
    return .{ .integer = value * sign };
}

fn digitValue(byte: u8) ?i64 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'z' => byte - 'a' + 10,
        'A'...'Z' => byte - 'A' + 10,
        else => null,
    };
}

test {
    _ = std;
}
