const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const options = if (op.arg_count >= 2) try state.expectString(runtime.argValue(state, thread, op, 1)) else "flnSrtu";
    try validateGetinfoOptions(state, options);

    const target_closure: ?*runtime.Closure, const source_name, const what, const currentline, const level_name = switch (target) {
        .integer => blk: {
            if (target.integer < 1) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            const depth: usize = @intCast(target.integer);
            if (depth > thread.frames.items.len) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            const frame = thread.frames.items[thread.frames.items.len - depth];
            break :blk .{ frame.closure, frame.proto.source_name, state.currentWhat(thread, target.integer), if (state.currentLine(thread, target.integer)) |line| @as(i64, @intCast(line)) else -1, state.currentFunctionName(thread, target.integer) };
        },
        .closure => .{ target.closure, target.closure.proto.source_name, "Lua", @as(i64, -1), null },
        .gmatch_iterator, .native, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap => .{ null, "[C]", "C", @as(i64, -1), null },
        else => return state.fail("function or level expected"),
    };

    const value = try state.newTableWithHints(0, 8);
    const table = value.table;
    const line_range = if (target_closure) |closure| if (closure.stripped_debug) null else closureLineRange(closure.proto) else null;
    try table.set(state.allocator, .{ .string = try state.intern("source") }, .{ .string = try state.intern(source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("short_src") }, .{ .string = try shortSource(state, source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("linedefined") }, .{ .integer = if (line_range) |range| @intCast(range.defined) else 0 });
    try table.set(state.allocator, .{ .string = try state.intern("lastlinedefined") }, .{ .integer = if (line_range) |range| @intCast(range.last) else 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nups") }, .{ .integer = if (target_closure) |closure| @intCast(closure.upvalues.len) else 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nparams") }, .{ .integer = if (target_closure) |closure| @intCast(closure.proto.param_count) else 0 });
    try table.set(state.allocator, .{ .string = try state.intern("isvararg") }, .{ .boolean = if (target_closure) |closure| closure.proto.is_vararg else false });
    try table.set(state.allocator, .{ .string = try state.intern("what") }, .{ .string = try state.intern(what) });
    try table.set(state.allocator, .{ .string = try state.intern("currentline") }, .{ .integer = currentline });
    const extraargs: i64 = if (if (target == .integer) state.currentExtraArgs(thread, target.integer) else null) |count| @intCast(count) else 0;
    try table.set(state.allocator, .{ .string = try state.intern("extraargs") }, .{ .integer = extraargs });
    const namewhat = if (level_name) |name| blk: {
        const proto_name = if (target_closure) |closure| closure.proto.debug_name else null;
        break :blk if (std.mem.eql(u8, name, "x") and (proto_name == null or !std.mem.eql(u8, proto_name.?, "f"))) "field" else "local";
    } else "";
    try table.set(state.allocator, .{ .string = try state.intern("namewhat") }, .{ .string = try state.intern(namewhat) });
    if (level_name) |name| {
        try table.set(state.allocator, .{ .string = try state.intern("name") }, .{ .string = try state.intern(name) });
    }
    if (target_closure != null) try table.set(state.allocator, .{ .string = try state.intern("func") }, .{ .closure = target_closure.? });
    if (std.mem.indexOfScalar(u8, options, 'L') != null) if (target_closure) |closure| try table.set(state.allocator, .{ .string = try state.intern("activelines") }, if (closure.stripped_debug) try state.newTableWithHints(0, 0) else try activeLinesTable(state, closure.proto));
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

fn validateGetinfoOptions(state: *State, options: []const u8) !void {
    for (options) |option| switch (option) {
        'S', 'l', 'n', 'u', 'f', 't', 'L', 'r' => {},
        else => return state.fail("invalid option"),
    };
}

fn shortSource(state: *State, source_name: []const u8) ![]const u8 {
    if (std.mem.eql(u8, source_name, "[C]")) return state.intern(source_name);
    if (std.mem.eql(u8, source_name, "zlua")) return state.intern(source_name);
    if (source_name.len > 0 and source_name[0] == '=') return state.intern(source_name[1..]);
    if (source_name.len > 0 and source_name[0] == '@') {
        const path = source_name[1..];
        if (path.len <= 60) return state.intern(path);
        var out = std.ArrayList(u8).empty;
        defer out.deinit(state.allocator);
        try out.appendSlice(state.allocator, "...");
        try out.appendSlice(state.allocator, path[path.len - 57 ..]);
        return state.intern(out.items);
    }

    const preview = stringPreview(source_name, 50);
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try out.appendSlice(state.allocator, "[string \"");
    try out.appendSlice(state.allocator, preview.text);
    if (preview.truncated) try out.appendSlice(state.allocator, "...");
    try out.appendSlice(state.allocator, "\"]");
    return state.intern(out.items);
}

const StringPreview = struct {
    text: []const u8,
    truncated: bool,
};

fn stringPreview(source_name: []const u8, limit: usize) StringPreview {
    const newline = std.mem.indexOfScalar(u8, source_name, '\n');
    const end = @min(newline orelse source_name.len, limit);
    return .{ .text = source_name[0..end], .truncated = newline != null or source_name.len > limit };
}

fn activeLinesTable(state: *State, proto: *const compile.proto.Proto) !Value {
    const value = try state.newTableWithHints(0, @intCast(proto.line_info.items.len));
    for (proto.line_info.items) |info| {
        if (info.line == 0) continue;
        try value.table.set(state.allocator, .{ .integer = @intCast(info.line) }, .{ .boolean = true });
    }
    if (closureLineRange(proto)) |range| {
        try value.table.set(state.allocator, .{ .integer = @intCast(range.last) }, .{ .boolean = true });
    }
    return value;
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

pub fn sethook(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.fail("bad argument #1 to 'sethook'");

    const first = runtime.argValue(state, thread, op, 0);
    const target, const hook_index: u16 = if (first == .thread) .{ first.thread, 1 } else .{ thread, 0 };
    const hook = runtime.argValue(state, thread, op, hook_index);
    const mask_value = runtime.argValue(state, thread, op, hook_index + 1);
    const mask = if (hook == .nil) "" else try state.expectString(mask_value);
    const count = if (op.arg_count > hook_index + 2) runtime.toInteger(runtime.argValue(state, thread, op, hook_index + 2)) orelse 0 else 0;

    state.setThreadHook(target, hook, mask, if (count > 0) @intCast(count) else 0);
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

pub fn gethook(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = if (op.arg_count > 0 and runtime.argValue(state, thread, op, 0) == .thread) runtime.argValue(state, thread, op, 0).thread else thread;
    try state.returnValues(thread, op.base, op.return_count, &.{
        target.hook,
        .{ .string = try state.threadHookMask(target) },
        .{ .integer = @intCast(target.hook_count) },
    });
}

fn upvalueIndex(value: Value) ?usize {
    const integer = runtime.toInteger(value) orelse return null;
    if (integer <= 0) return null;
    return @intCast(integer - 1);
}

const ClosureLineRange = struct {
    defined: usize,
    last: usize,
};

fn closureLineRange(proto: *const compile.proto.Proto) ?ClosureLineRange {
    if (proto.line_info.items.len == 0) return null;
    var min_line = proto.line_info.items[0].line;
    var max_line = min_line;
    for (proto.line_info.items[1..]) |info| {
        min_line = @min(min_line, info.line);
        max_line = @max(max_line, info.line);
    }
    return .{
        .defined = if (min_line == max_line or min_line == 0) min_line else min_line - 1,
        .last = if (min_line == max_line) max_line else max_line + 1,
    };
}

fn nativeUpvalueId(value: Value, index: usize) ?[]const u8 {
    if (index != 0) return null;
    if (value == .gmatch_iterator) return "native:string.gmatch:1";
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
