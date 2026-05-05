const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const value = try state.newTableWithHints(0, 8);
    const table = value.table;
    const source_name = if (target == .closure) target.closure.proto.source_name else "zlua";
    try table.set(state.allocator, .{ .string = try state.intern("source") }, .{ .string = try state.intern(source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("short_src") }, .{ .string = try state.intern(source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("linedefined") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("lastlinedefined") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nups") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nparams") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("isvararg") }, .{ .boolean = false });
    const what = switch (target) {
        .integer => "Lua",
        .closure => "Lua",
        .native, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_wrap => "C",
        else => return state.fail("function or level expected"),
    };
    try table.set(state.allocator, .{ .string = try state.intern("what") }, .{ .string = try state.intern(what) });
    const currentline: i64 = if (if (target == .integer) state.currentLine(thread, target.integer) else null) |line| @intCast(line) else -1;
    try table.set(state.allocator, .{ .string = try state.intern("currentline") }, .{ .integer = currentline });
    const extraargs: i64 = if (if (target == .integer) state.currentExtraArgs(thread, target.integer) else null) |count| @intCast(count) else 0;
    try table.set(state.allocator, .{ .string = try state.intern("extraargs") }, .{ .integer = extraargs });
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn getupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    const upvalue = getClosureUpvalue(target, index) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    const name = target.closure.proto.upvalues.items[index].name;
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern(name) }, readUpvalue(upvalue) });
}

pub fn setupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    const upvalue = getClosureUpvalue(target, index) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    writeUpvalue(upvalue, runtime.argValue(state, thread, op, 2));
    const name = target.closure.proto.upvalues.items[index].name;
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(name) }});
}

pub fn upvalueid(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    if (nativeUpvalueId(target, index)) |id| {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(id) }});
        return;
    }
    const upvalue = getClosureUpvalue(target, index) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    const id = try std.fmt.allocPrint(state.allocator, "upvalue:{x}", .{@intFromPtr(upvalue)});
    defer state.allocator.free(id);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(id) }});
}

pub fn upvaluejoin(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const first = runtime.argValue(state, thread, op, 0);
    const first_index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse return state.fail("invalid upvalue index");
    const second = runtime.argValue(state, thread, op, 2);
    const second_index = upvalueIndex(runtime.argValue(state, thread, op, 3)) orelse return state.fail("invalid upvalue index");
    const replacement = getClosureUpvalue(second, second_index) orelse return state.fail("invalid upvalue index");
    if (first != .closure or first_index >= first.closure.upvalues.len) return state.fail("invalid upvalue index");
    first.closure.upvalues[first_index] = replacement;
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn upvalueIndex(value: Value) ?usize {
    const integer = runtime.toInteger(value) orelse return null;
    if (integer <= 0) return null;
    return @intCast(integer - 1);
}

fn nativeUpvalueId(value: Value, index: usize) ?[]const u8 {
    if (index != 0) return null;
    if (value != .native) return null;
    return switch (value.native) {
        .string_gmatch_iter => "native:string.gmatch:1",
        else => null,
    };
}

fn getClosureUpvalue(value: Value, index: usize) ?*runtime.Upvalue {
    if (value != .closure) return null;
    if (index >= value.closure.upvalues.len) return null;
    return value.closure.upvalues[index];
}

fn readUpvalue(upvalue: *runtime.Upvalue) Value {
    return if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
}

fn writeUpvalue(upvalue: *runtime.Upvalue, value: Value) void {
    if (upvalue.is_open) {
        upvalue.owner.stack.items[upvalue.stack_index] = value;
    } else {
        upvalue.closed = value;
    }
}
