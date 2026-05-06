const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn concat(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(table_value);
    const sep = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil) try state.expectString(runtime.argValue(state, thread, op, 1)) else "";
    const start = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1;
    const len = runtime.toInteger(try state.lengthOf(thread, table_value)) orelse return state.fail("object length is not an integer");
    const stop = if (op.arg_count >= 4) runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse len else len;
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var index = start;
    while (index <= stop) : (index += 1) {
        if (index != start) try out.appendSlice(state.allocator, sep);
        const value = try state.getTableFromThread(thread, table_value, .{ .integer = index });
        switch (value) {
            .integer, .number, .string => try runtime.appendLuaString(state.allocator, &out, value),
            else => return state.fail(try concatIndexError(state, index)),
        }
        if (index == std.math.maxInt(i64)) break;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn concatIndexError(state: *State, index: i64) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &out, "invalid value at index {d}", .{index});
    return state.intern(out.items);
}

pub fn insert(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count < 2 or op.arg_count > 3) return state.fail("wrong number of arguments to 'insert'");
    const table_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(table_value);
    const len = runtime.toInteger(try state.lengthOf(thread, table_value)) orelse return state.fail("object length is not an integer");
    const pos = if (op.arg_count == 2) len +% 1 else runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("position out of bounds");
    const value = if (op.arg_count == 2) runtime.argValue(state, thread, op, 1) else runtime.argValue(state, thread, op, 2);
    if (op.arg_count == 3 and (pos < 1 or pos > len + 1)) return state.fail("position out of bounds");
    var index = len +% 1;
    while (index > pos) : (index -= 1) {
        const shifted = try state.getTableFromThread(thread, table_value, .{ .integer = index - 1 });
        try state.setTableFromThread(thread, table_value, .{ .integer = index }, shifted);
    }
    try state.setTableFromThread(thread, table_value, .{ .integer = pos }, value);
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

pub fn move(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const src_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(src_value);
    const first = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const last = runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse return state.fail("number expected");
    const dest_start = runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse return state.fail("number expected");
    const dest_value = if (op.arg_count >= 5 and runtime.argValue(state, thread, op, 4) != .nil) runtime.argValue(state, thread, op, 4) else runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(dest_value);
    if (last >= first) {
        const count_i = @as(i128, last) - @as(i128, first) + 1;
        if (count_i > std.math.maxInt(i64)) return state.fail("too many elements to move");
        const dest_end = @as(i128, dest_start) + count_i - 1;
        if (dest_end < std.math.minInt(i64) or dest_end > std.math.maxInt(i64)) return state.fail("destination wrap around");
        const count: i64 = @intCast(count_i);
        if (runtime.valuesEqual(src_value, dest_value) and dest_start > first and dest_start <= last) {
            var offset = count - 1;
            while (true) {
                const value = try state.getTableFromThread(thread, src_value, .{ .integer = first + offset });
                try state.setTableFromThread(thread, dest_value, .{ .integer = dest_start + offset }, value);
                if (offset == 0) break;
                offset -= 1;
            }
        } else {
            var offset: i64 = 0;
            while (offset < count) : (offset += 1) {
                const value = try state.getTableFromThread(thread, src_value, .{ .integer = first + offset });
                try state.setTableFromThread(thread, dest_value, .{ .integer = dest_start + offset }, value);
            }
        }
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
    const table_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(table_value);
    const len = runtime.toInteger(try state.lengthOf(thread, table_value)) orelse return state.fail("object length is not an integer");
    const pos = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("position out of bounds") else len;
    if (op.arg_count >= 2 and (pos < 0 or (pos == 0 and len != 0) or (pos > len and (len == std.math.maxInt(i64) or pos != len + 1)))) return state.fail("position out of bounds");
    if (pos > len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const removed = try state.getTableFromThread(thread, table_value, .{ .integer = pos });
    var index = pos;
    while (index < len) : (index += 1) {
        const shifted = try state.getTableFromThread(thread, table_value, .{ .integer = index + 1 });
        try state.setTableFromThread(thread, table_value, .{ .integer = index }, shifted);
    }
    try state.setTableFromThread(thread, table_value, .{ .integer = len }, .nil);
    try state.returnValues(thread, op.base, op.return_count, &.{removed});
}

pub fn sort(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(table_value);
    const comparator = if (op.arg_count >= 2) runtime.argValue(state, thread, op, 1) else Value.nil;
    const len = runtime.toInteger(try state.lengthOf(thread, table_value)) orelse return state.fail("object length is not an integer");
    if (len > 1_000_000) return state.fail("array too big");
    if (len > 1) {
        const count: usize = @intCast(len);
        const values = try state.allocator.alloc(Value, count);
        defer state.allocator.free(values);
        for (values, 0..) |*slot, index| slot.* = try state.getTableFromThread(thread, table_value, .{ .integer = @intCast(index + 1) });
        try sortValues(state, thread, comparator, values);
        for (values, 0..) |value, index| try state.setTableFromThread(thread, table_value, .{ .integer = @intCast(index + 1) }, value);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn sortValues(state: *State, thread: *Thread, comparator: Value, values: []Value) !void {
    if (values.len < 2) return;
    var left: usize = 0;
    var right: usize = values.len - 1;
    const pivot = values[values.len / 2];
    while (left <= right) {
        while (try sortLess(state, thread, comparator, values[left], pivot)) left += 1;
        while (try sortLess(state, thread, comparator, pivot, values[right])) {
            if (right == 0) break;
            right -= 1;
        }
        if (left > right) break;
        std.mem.swap(Value, &values[left], &values[right]);
        left += 1;
        if (right == 0) break;
        right -= 1;
    }
    if (right > 0) try sortValues(state, thread, comparator, values[0 .. right + 1]);
    if (left < values.len) try sortValues(state, thread, comparator, values[left..]);
}

fn sortLess(state: *State, thread: *Thread, comparator: Value, lhs: Value, rhs: Value) !bool {
    if (comparator != .nil) {
        const result = runtime.truthy(try state.callOneResult(thread, comparator, &.{ lhs, rhs }));
        if (result and runtime.truthy(try state.callOneResult(thread, comparator, &.{ rhs, lhs }))) return state.fail("invalid order function for sorting");
        return result;
    }
    return state.compareValues(thread, lhs, rhs, .lt);
}

pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table_value = runtime.argValue(state, thread, op, 0);
    _ = try state.expectTable(table_value);
    const start = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1;
    const len = runtime.toInteger(try state.lengthOf(thread, table_value)) orelse return state.fail("object length is not an integer");
    const stop = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse len else len;
    if (@as(i128, stop) - @as(i128, start) + 1 > 1_000_000) return state.fail("too many results to unpack");
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index = start;
    while (index <= stop) {
        try values.append(state.allocator, try state.getTableFromThread(thread, table_value, .{ .integer = index }));
        if (index == stop) break;
        index += 1;
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}
