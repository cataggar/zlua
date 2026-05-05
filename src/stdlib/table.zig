const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn concat(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const sep = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil) try state.expectString(runtime.argValue(state, thread, op, 1)) else "";
    const start = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1;
    const stop = if (op.arg_count >= 4) runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse table.len() else table.len();
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var index = start;
    while (index <= stop) : (index += 1) {
        if (index != start) try out.appendSlice(state.allocator, sep);
        try runtime.appendLuaString(state.allocator, &out, table.get(.{ .integer = index }));
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn insert(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const len = table.len();
    const pos = if (op.arg_count == 2) len + 1 else runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("position out of bounds");
    const value = if (op.arg_count == 2) runtime.argValue(state, thread, op, 1) else runtime.argValue(state, thread, op, 2);
    if (pos < 1 or pos > len + 1) return state.fail("position out of bounds");
    var index = len + 1;
    while (index > pos) : (index -= 1) try table.set(state.allocator, .{ .integer = index }, table.get(.{ .integer = index - 1 }));
    try table.set(state.allocator, .{ .integer = pos }, value);
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

pub fn move(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const src = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const first = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const last = runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse return state.fail("number expected");
    const dest_start = runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse return state.fail("number expected");
    const dest_value = if (op.arg_count >= 5 and runtime.argValue(state, thread, op, 4) != .nil) runtime.argValue(state, thread, op, 4) else runtime.argValue(state, thread, op, 0);
    const dest = try state.expectTable(dest_value);
    if (last >= first) {
        const count: usize = @intCast(last - first + 1);
        const temp = try state.allocator.alloc(Value, count);
        defer state.allocator.free(temp);
        for (temp, 0..) |*slot, index| slot.* = src.get(.{ .integer = first + @as(i64, @intCast(index)) });
        for (temp, 0..) |value, index| try dest.set(state.allocator, .{ .integer = dest_start + @as(i64, @intCast(index)) }, value);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{dest_value});
}

pub fn pack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table_value = try state.newTableWithHints(op.arg_count, 1);
    const table = table_value.table;
    for (0..op.arg_count) |index| try table.set(state.allocator, .{ .integer = @intCast(index + 1) }, runtime.argValue(state, thread, op, @intCast(index)));
    try table.set(state.allocator, .{ .string = try state.intern("n") }, .{ .integer = op.arg_count });
    try state.returnValues(thread, op.base, op.return_count, &.{table_value});
}

pub fn remove(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const len = table.len();
    const pos = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("position out of bounds") else len;
    if (pos < 1 or pos > len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const removed = table.get(.{ .integer = pos });
    var index = pos;
    while (index < len) : (index += 1) try table.set(state.allocator, .{ .integer = index }, table.get(.{ .integer = index + 1 }));
    try table.set(state.allocator, .{ .integer = len }, .nil);
    try state.returnValues(thread, op.base, op.return_count, &.{removed});
}

pub fn sort(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const comparator = if (op.arg_count >= 2) runtime.argValue(state, thread, op, 1) else Value.nil;
    const len = table.len();
    var i: i64 = 2;
    while (i <= len) : (i += 1) {
        var j = i;
        while (j > 1 and try sortLess(state, thread, comparator, table.get(.{ .integer = j }), table.get(.{ .integer = j - 1 }))) : (j -= 1) {
            const a = table.get(.{ .integer = j });
            const b = table.get(.{ .integer = j - 1 });
            try table.set(state.allocator, .{ .integer = j - 1 }, a);
            try table.set(state.allocator, .{ .integer = j }, b);
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn sortLess(state: *State, thread: *Thread, comparator: Value, lhs: Value, rhs: Value) !bool {
    if (comparator != .nil) return runtime.truthy(try state.callOneResult(thread, comparator, &.{ lhs, rhs }));
    return state.compareValues(thread, lhs, rhs, .lt);
}

pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const start = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1;
    const stop = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse table.len() else table.len();
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index = start;
    while (index <= stop) : (index += 1) try values.append(state.allocator, table.get(.{ .integer = index }));
    try state.returnValues(thread, op.base, op.return_count, values.items);
}
