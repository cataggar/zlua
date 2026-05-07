const std = @import("std");
const compile = @import("../compile.zig");
const errors = @import("../errors.zig");
const types = @import("types.zig");
const value_mod = @import("value.zig");

const proto_mod = compile.proto;
const Value = types.Value;
const Thread = types.Thread;
const CallFrame = types.CallFrame;

const appendFmt = value_mod.appendFmt;
const appendValue = value_mod.appendValue;
const localActiveAt = value_mod.localActiveAt;

const DebugStackSlot = struct {
    frame_index: usize,
    register: usize,
};

fn lineForFrame(frame: CallFrame) ?usize {
    if (frame.proto.line_info.items.len == 0) return null;
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    if (pc >= frame.proto.line_info.items.len) return null;
    const line = frame.proto.line_info.items[pc].line;
    return if (line == 0) null else line;
}

fn debugStackRegister(thread: *Thread, stack_index: usize) ?DebugStackSlot {
    var frame_index = thread.frames.items.len;
    while (frame_index > 0) {
        frame_index -= 1;
        const frame = thread.frames.items[frame_index];
        const register_count: usize = @intCast(frame.proto.max_registers);
        if (stack_index >= frame.base and stack_index < frame.base + register_count) {
            return .{ .frame_index = frame_index, .register = stack_index - frame.base };
        }
    }
    return null;
}

fn debugValueTypeName(value: Value) []const u8 {
    return value_mod.debugValueTypeName(value);
}

pub fn appendUnhandledErrorDebugDump(comptime State: type, self: *State, thread: *Thread, err: anyerror) !void {
    const out = &self.stderr;
    const stats = self.allocationStats();
    try out.appendSlice(self.allocator, "\n[zlua debug] unhandled runtime exception\n");
    try appendFmt(self.allocator, out, "error={s}\n", .{@errorName(err)});
    try out.appendSlice(self.allocator, "error_value=");
    try appendDebugValue(State, self, out, self.currentErrorValue());
    try out.append(self.allocator, '\n');
    if (self.last_error) |payload| switch (payload) {
        .diagnostic => |message| try appendFmt(self.allocator, out, "last_error={s}\n", .{message}),
        .argument => |argument| {
            const rendered = try errors.renderArgumentError(self.allocator, argument);
            defer self.allocator.free(rendered);
            try appendFmt(self.allocator, out, "last_error={s}\n", .{rendered});
        },
        .lua_value => {},
    };
    try appendFmt(self.allocator, out, "allocations strings={d} tables={d} closures={d} upvalues={d} threads={d} bytes={d}\n", .{ stats.strings, stats.tables, stats.closures, stats.upvalues, stats.threads, stats.bytes });
    try appendFmt(self.allocator, out, "thread status={s} frames={d} stack={d} results={d}@{d} native_depth={d} protected_close_depth={d}\n", .{ @tagName(thread.status), thread.frames.items.len, thread.stack.items.len, thread.last_result_count, thread.last_result_base, thread.native_call_depth, thread.protected_close_depth });
    try appendFmt(self.allocator, out, "continuations protected={d} call_one={d} tail={d} generic_for={d}\n", .{ thread.protected_continuations.items.len, thread.call_one_continuations.items.len, thread.tail_call_continuations.items.len, thread.generic_for_continuations.items.len });
    try appendDebugFrames(State, self, out, thread);
    try appendDebugStack(State, self, out, thread);
    try out.appendSlice(self.allocator, "[/zlua debug]\n");
}

pub fn appendDebugFrames(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread) !void {
    try appendFmt(self.allocator, out, "frames newest-first ({d}):\n", .{thread.frames.items.len});
    var index = thread.frames.items.len;
    while (index > 0) {
        index -= 1;
        const frame = thread.frames.items[index];
        const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
        const line = lineForFrame(frame) orelse 0;
        const name = frame.proto.debug_name orelse "(anonymous)";
        const instruction = if (pc < frame.proto.instructions.items.len)
            @tagName(std.meta.activeTag(frame.proto.instructions.items[pc]))
        else
            "<end>";
        try appendFmt(self.allocator, out, "  frame {d}: {s}:{d} pc={d} op={s} func={s} base={d} return={d}@{d} registers={d}\n", .{ index, frame.proto.source_name, line, pc, instruction, name, frame.base, frame.return_count, frame.return_start, frame.proto.max_registers });
        try appendDebugLocals(State, self, out, thread, frame);
        try appendDebugVarargs(State, self, out, frame);
        try appendDebugUpvalues(State, self, out, frame);
    }
}

pub fn appendDebugLocals(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread, frame: CallFrame) !void {
    const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
    var found = false;
    for (frame.proto.locals.items) |local| {
        if (!localActiveAt(local, pc)) continue;
        found = true;
        try appendFmt(self.allocator, out, "    local {s} r{d}", .{ local.name, local.register });
        if (local.to_close) try out.appendSlice(self.allocator, " <close>");
        try out.appendSlice(self.allocator, " = ");
        const absolute_register = frame.base + local.register;
        if (absolute_register < thread.stack.items.len) {
            try appendDebugValue(State, self, out, thread.stack.items[absolute_register]);
        } else {
            try out.appendSlice(self.allocator, "<out-of-stack>");
        }
        try out.append(self.allocator, '\n');
    }
    if (!found) try out.appendSlice(self.allocator, "    locals: <none>\n");
}

pub fn appendDebugVarargs(comptime State: type, self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void {
    if (frame.varargs.len == 0) {
        try out.appendSlice(self.allocator, "    varargs: <none>\n");
        return;
    }
    for (frame.varargs, 0..) |value, index| {
        try appendFmt(self.allocator, out, "    vararg {d} = ", .{index});
        try appendDebugValue(State, self, out, value);
        try out.append(self.allocator, '\n');
    }
}

pub fn appendDebugUpvalues(comptime State: type, self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void {
    if (frame.closure.upvalues.len == 0) {
        try out.appendSlice(self.allocator, "    upvalues: <none>\n");
        return;
    }
    for (frame.closure.upvalues, 0..) |upvalue, index| {
        const name = if (index < frame.proto.upvalues.items.len) frame.proto.upvalues.items[index].name else "?";
        const value = if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
        try appendFmt(self.allocator, out, "    upvalue U{d} {s} {s}", .{ index, name, if (upvalue.is_open) "open" else "closed" });
        if (upvalue.is_open) try appendFmt(self.allocator, out, " stack={d}", .{upvalue.stack_index});
        try out.appendSlice(self.allocator, " = ");
        try appendDebugValue(State, self, out, value);
        try out.append(self.allocator, '\n');
    }
}

pub fn appendDebugStack(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread) !void {
    try appendFmt(self.allocator, out, "stack ({d} slots):\n", .{thread.stack.items.len});
    for (thread.stack.items, 0..) |value, stack_index| {
        try appendFmt(self.allocator, out, "  [{d}]", .{stack_index});
        if (debugStackRegister(thread, stack_index)) |slot| {
            try appendFmt(self.allocator, out, " frame={d} r{d}", .{ slot.frame_index, slot.register });
        }
        try out.appendSlice(self.allocator, " = ");
        try appendDebugValue(State, self, out, value);
        try out.append(self.allocator, '\n');
    }
}

pub fn appendDebugValue(comptime State: type, self: *State, out: *std.ArrayList(u8), value: Value) !void {
    try appendFmt(self.allocator, out, "({s}) ", .{debugValueTypeName(value)});
    if (value == .table and !self.isTrackedTable(value.table)) {
        try appendFmt(self.allocator, out, "table: 0x{x}", .{@intFromPtr(value.table)});
        return;
    }
    try appendValue(self.allocator, out, value);
}
