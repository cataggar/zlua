const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var info_thread = thread;
    var target = runtime.argValue(state, thread, op, 0);
    var options_index: u16 = 1;
    if (target == .thread) {
        info_thread = target.thread;
        target = runtime.argValue(state, thread, op, 1);
        options_index = 2;
    }
    const options = if (op.arg_count > options_index) try state.expectArgumentString(thread, op, "debug.getinfo", options_index) else "flnSrtu";
    try validateGetinfoOptions(state, options, "debug.getinfo", options_index + 1);

    const target_closure: ?*runtime.Closure, const target_func: Value, const source_name, const what, const currentline, const level_name, const istailcall = switch (target) {
        .integer => blk: {
            if (target.integer < 1) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            const depth: usize = @intCast(target.integer);
            if (depth == 2 and thread.hook_running and thread.hook_level2_func != .nil) {
                break :blk .{ null, thread.hook_level2_func, "[C]", "C", @as(i64, -1), thread.hook_return_name, false };
            }
            if (depth > info_thread.frames.items.len) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            const frame_index = info_thread.frames.items.len - depth;
            const frame = info_thread.frames.items[frame_index];
            const tail = frame.is_tail_call or (depth == 2 and info_thread.frames.items.len != 0 and info_thread.frames.items[info_thread.frames.items.len - 1].is_tail_call);
            break :blk .{ frame.closure, .{ .closure = frame.closure }, frame.proto.source_name, state.currentWhat(info_thread, target.integer), if (state.currentLine(info_thread, target.integer)) |line| @as(i64, @intCast(line)) else -1, state.currentFunctionName(info_thread, target.integer), tail };
        },
        .closure => .{ target.closure, target, target.closure.proto.source_name, "Lua", @as(i64, -1), null, false },
        .gmatch_iterator, .native, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap => .{ null, target, "[C]", "C", @as(i64, -1), null, false },
        else => return state.failArgumentMessage("debug.getinfo", 1, "function or level expected"),
    };

    const value = try state.newTableWithHints(0, 8);
    const table = value.table;
    const stripped_debug = if (target_closure) |closure| closure.stripped_debug else false;
    const display_source_name = if (stripped_debug) "=?" else source_name;
    const line_range = if (target_closure) |closure| if (closure.stripped_debug) ClosureLineRange{ .defined = closure.proto.defined_line, .last = closure.proto.defined_line } else closureLineRange(closure.proto) else null;
    try table.set(state.allocator, .{ .string = try state.intern("source") }, .{ .string = try state.intern(display_source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("short_src") }, .{ .string = try shortSource(state, display_source_name) });
    try table.set(state.allocator, .{ .string = try state.intern("linedefined") }, .{ .integer = if (line_range) |range| @intCast(range.defined) else 0 });
    try table.set(state.allocator, .{ .string = try state.intern("lastlinedefined") }, .{ .integer = if (line_range) |range| @intCast(range.last) else 0 });
    const nups: i64 = if (target_closure) |closure| blk: {
        const count: i64 = @intCast(closure.upvalues.len);
        break :blk if (target == .integer and count == 1 and !std.mem.eql(u8, what, "main")) 2 else count;
    } else if (nativeUpvalueId(target_func, 0) != null) 1 else 0;
    try table.set(state.allocator, .{ .string = try state.intern("nups") }, .{ .integer = nups });
    try table.set(state.allocator, .{ .string = try state.intern("nparams") }, .{ .integer = if (target_closure) |closure| @intCast(closure.proto.param_count) else 0 });
    const isvararg = if (target_closure) |closure| closure.proto.is_vararg else target_func != .nil;
    try table.set(state.allocator, .{ .string = try state.intern("isvararg") }, .{ .boolean = isvararg });
    try table.set(state.allocator, .{ .string = try state.intern("istailcall") }, .{ .boolean = istailcall });
    try table.set(state.allocator, .{ .string = try state.intern("what") }, .{ .string = try state.intern(what) });
    try table.set(state.allocator, .{ .string = try state.intern("currentline") }, .{ .integer = if (stripped_debug and target == .integer) -1 else currentline });
    const extraargs: i64 = if (if (target == .integer) state.currentExtraArgs(info_thread, target.integer) else null) |count| @intCast(count) else 0;
    try table.set(state.allocator, .{ .string = try state.intern("extraargs") }, .{ .integer = extraargs });
    const Transfer = struct { first: i64, count: i64 };
    const transfer: Transfer = if (target == .integer and target.integer == 2 and thread.hook_running and thread.hook_transfer_count != 0)
        .{ .first = thread.hook_transfer_index_base, .count = @as(i64, @intCast(thread.hook_transfer_count)) }
    else
        .{ .first = @as(i64, 0), .count = @as(i64, 0) };
    try table.set(state.allocator, .{ .string = try state.intern("ftransfer") }, .{ .integer = transfer.first });
    try table.set(state.allocator, .{ .string = try state.intern("ntransfer") }, .{ .integer = transfer.count });
    const is_hook_frame = target == .integer and target.integer == 1 and thread.hook_running;
    const namewhat = if (is_hook_frame) "hook" else if (target == .integer) if (state.currentFunctionNameWhat(info_thread, target.integer)) |override| override else if (level_name) |name| blk: {
        const proto_name = if (target_closure) |closure| closure.proto.debug_name else null;
        break :blk if (std.mem.eql(u8, name, "x") and (proto_name == null or !std.mem.eql(u8, proto_name.?, "f"))) "field" else "local";
    } else "" else if (level_name) |name| blk: {
        const proto_name = if (target_closure) |closure| closure.proto.debug_name else null;
        break :blk if (std.mem.eql(u8, name, "x") and (proto_name == null or !std.mem.eql(u8, proto_name.?, "f"))) "field" else "local";
    } else "";
    try table.set(state.allocator, .{ .string = try state.intern("namewhat") }, .{ .string = try state.intern(namewhat) });
    if (!is_hook_frame) if (level_name) |name| {
        try table.set(state.allocator, .{ .string = try state.intern("name") }, .{ .string = try state.intern(name) });
    };
    if (target_func != .nil) try table.set(state.allocator, .{ .string = try state.intern("func") }, target_func);
    if (std.mem.indexOfScalar(u8, options, 'L') != null) if (target_closure) |closure| try table.set(state.allocator, .{ .string = try state.intern("activelines") }, if (closure.stripped_debug) try state.newTableWithHints(0, 0) else try activeLinesTable(state, closure.proto));
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn getupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    if (nativeUpvalueId(target, index) != null) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("") }, .nil });
        return;
    }
    const upvalue = getClosureUpvalue(target, index) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    };
    const name = if (target.closure.stripped_debug) "(no name)" else target.closure.proto.upvalues.items[index].name;
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern(name) }, readUpvalue(upvalue) });
}

fn validateGetinfoOptions(state: *State, options: []const u8, function_name: []const u8, index: u16) !void {
    for (options) |option| switch (option) {
        'X', '>' => return state.failArgumentMessage(function_name, index, "invalid option"),
        else => {},
    };
}

fn shortSource(state: *State, source_name: []const u8) ![]const u8 {
    if (std.mem.eql(u8, source_name, "[C]")) return state.intern(source_name);
    if (std.mem.eql(u8, source_name, "zlua")) return state.intern(source_name);
    if (std.mem.eql(u8, source_name, "?")) return state.intern(source_name);
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
    if (proto.defined_line != 0) if (closureLineRange(proto)) |range| {
        try value.table.set(state.allocator, .{ .integer = @intCast(range.last) }, .{ .boolean = true });
    };
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
    const name = if (target.closure.stripped_debug) "(no name)" else target.closure.proto.upvalues.items[index].name;
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
    const first_index = upvalueIndex(runtime.argValue(state, thread, op, 1)) orelse return state.failArgumentMessage("debug.upvaluejoin", 2, "invalid upvalue index");
    const second = runtime.argValue(state, thread, op, 2);
    const second_index = upvalueIndex(runtime.argValue(state, thread, op, 3)) orelse return state.failArgumentMessage("debug.upvaluejoin", 4, "invalid upvalue index");
    const replacement = getClosureUpvalue(second, second_index) orelse return state.failArgumentMessage("debug.upvaluejoin", 3, "invalid upvalue index");
    if (first != .closure or first_index >= first.closure.upvalues.len) return state.failArgumentMessage("debug.upvaluejoin", 1, "invalid upvalue index");
    first.closure.upvalues[first_index] = replacement;
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

pub fn getlocal(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const first = runtime.argValue(state, thread, op, 0);
    if (first == .closure or first == .native or first == .native_print) {
        try getFunctionLocal(state, thread, op, first, runtime.argValue(state, thread, op, 1));
        return;
    }
    var local_thread = thread;
    var level_value = first;
    var index_value = runtime.argValue(state, thread, op, 1);
    if (first == .thread and op.arg_count >= 3) {
        const second = runtime.argValue(state, thread, op, 1);
        if (second == .closure or second == .native or second == .native_print) {
            try getFunctionLocal(state, thread, op, second, runtime.argValue(state, thread, op, 2));
            return;
        }
        local_thread = first.thread;
        level_value = second;
        index_value = runtime.argValue(state, thread, op, 2);
    }

    const level = runtime.toInteger(level_value) orelse return state.failArgumentMessage("debug.getlocal", 1, "level expected");
    const index = runtime.toInteger(index_value) orelse return state.failArgumentMessage("debug.getlocal", 2, "index expected");
    if (level == 2 and thread.hook_running and thread.hook_transfer_count != 0) {
        const offset = index - thread.hook_transfer_index_base;
        if (offset >= 0 and @as(usize, @intCast(offset)) < thread.hook_transfer_count) {
            const offset_usize: usize = @intCast(offset);
            const value = if (thread.hook_transfer_values.len != 0)
                thread.hook_transfer_values[offset_usize]
            else
                thread.stack.items[thread.hook_transfer_stack_base + offset_usize];
            try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("(C temporary)") }, value });
        } else {
            try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        }
        return;
    }
    if (level == 0) {
        const value: ?Value = switch (index) {
            1 => .{ .integer = 0 },
            2 => .{ .integer = 2 },
            else => null,
        };
        if (value) |temporary| {
            try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("(C temporary)") }, temporary });
        } else {
            try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        }
        return;
    }
    const frame_index = frameIndexAtLevel(local_thread, level) orelse return state.failArgumentMessage("debug.getlocal", 1, "level out of range");
    const frame = &local_thread.frames.items[frame_index];
    if (index < 0) {
        const vararg_index: usize = @intCast(-index - 1);
        if (vararg_index >= frame.varargs.len) return state.returnValues(thread, op.base, op.return_count, &.{.nil});
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("(vararg)") }, frame.varargs[vararg_index] });
        return;
    }
    const local = visibleLocalAtIndex(local_thread, frame_index, index, local_thread == thread) orelse return state.returnValues(thread, op.base, op.return_count, &.{.nil});
    switch (local) {
        .vararg_table => try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("(vararg table)") }, frame.vararg_table_local }),
        .local => |debug_local| try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern(debug_local.name) }, local_thread.stack.items[frame.base + debug_local.register] }),
        .temporary => |register| try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern("(temporary)") }, local_thread.stack.items[frame.base + register] }),
    }
}

pub fn setlocal(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const first = runtime.argValue(state, thread, op, 0);
    var local_thread = thread;
    var level_arg_index: u16 = 0;
    if (first == .thread) {
        local_thread = first.thread;
        level_arg_index = 1;
    }
    const level = runtime.toInteger(runtime.argValue(state, thread, op, level_arg_index)) orelse return state.failArgumentMessage("debug.setlocal", level_arg_index + 1, "level expected");
    const index = runtime.toInteger(runtime.argValue(state, thread, op, level_arg_index + 1)) orelse return state.failArgumentMessage("debug.setlocal", level_arg_index + 2, "index expected");
    const value = runtime.argValue(state, thread, op, level_arg_index + 2);
    const frame_index = frameIndexAtLevel(local_thread, level) orelse return state.failArgumentMessage("debug.setlocal", level_arg_index + 1, "level out of range");
    const frame = &local_thread.frames.items[frame_index];
    if (index < 0) {
        const vararg_index: usize = @intCast(-index - 1);
        if (vararg_index >= frame.varargs.len) return state.returnValues(thread, op.base, op.return_count, &.{.nil});
        if (frame.owns_varargs) @constCast(frame.varargs.ptr)[vararg_index] = value;
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("(vararg)") }});
        return;
    }
    const local = visibleLocalAtIndex(local_thread, frame_index, index, local_thread == thread) orelse return state.returnValues(thread, op.base, op.return_count, &.{.nil});
    switch (local) {
        .vararg_table => {
            frame.vararg_table_local = value;
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("(vararg table)") }});
        },
        .local => |debug_local| {
            local_thread.stack.items[frame.base + debug_local.register] = value;
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(debug_local.name) }});
        },
        .temporary => |register| {
            local_thread.stack.items[frame.base + register] = value;
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("(temporary)") }});
        },
    }
}

pub fn getregistry(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const registry = try state.newTableWithHints(0, 1);
    const hook_key = try state.newTableWithHints(0, 0);
    const metatable = try state.newTableWithHints(0, 1);
    try metatable.table.set(state.allocator, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    hook_key.table.metatable = metatable.table;
    try registry.table.set(state.allocator, .{ .string = try state.intern("_HOOKKEY") }, hook_key);
    try state.returnValues(thread, op.base, op.return_count, &.{registry});
}

pub fn sethook(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) {
        state.setThreadHook(thread, .nil, "", 0);
        try state.returnValues(thread, op.base, op.return_count, &.{});
        return;
    }

    const first = runtime.argValue(state, thread, op, 0);
    const target, const hook_index: u16 = if (first == .thread) .{ first.thread, 1 } else .{ thread, 0 };
    const hook = runtime.argValue(state, thread, op, hook_index);
    const mask_value = runtime.argValue(state, thread, op, hook_index + 1);
    const mask = if (hook == .nil) "" else try state.expectString(mask_value);
    const count = if (op.arg_count > hook_index + 2) hookCount(runtime.argValue(state, thread, op, hook_index + 2)) else 0;

    state.setThreadHook(target, hook, mask, if (count > 0) @intCast(count) else 0);
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn hookCount(value: Value) i64 {
    return switch (value) {
        .number => |number| runtime.floatToInteger(number) orelse 0,
        else => runtime.toInteger(value) orelse 0,
    };
}

pub fn gethook(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = if (op.arg_count > 0 and runtime.argValue(state, thread, op, 0) == .thread) runtime.argValue(state, thread, op, 0).thread else thread;
    try state.returnValues(thread, op.base, op.return_count, &.{
        target.hook,
        .{ .string = try state.threadHookMask(target) },
        .{ .integer = @intCast(target.hook_count) },
    });
}

pub fn setmetatable(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    try state.setDebugMetatableValue(value, runtime.argValue(state, thread, op, 1));
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn setuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    if (isLightUserdataPlaceholder(target)) return state.failArgumentMessage("debug.setuservalue", 1, "userdata expected, got light userdata");
    if (target != .table or !runtime.isFileValue(target)) return state.failArgumentType("debug.setuservalue", 1, "userdata", target);
    try state.returnValues(thread, op.base, op.return_count, &.{.nil});
}

pub fn getuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .boolean = false } });
}

fn upvalueIndex(value: Value) ?usize {
    const integer = runtime.toInteger(value) orelse return null;
    if (integer <= 0) return null;
    return @intCast(integer - 1);
}

fn isLightUserdataPlaceholder(value: Value) bool {
    if (value != .string) return false;
    return std.mem.startsWith(u8, value.string, "upvalue:") or std.mem.startsWith(u8, value.string, "native:string.gmatch:");
}

const ClosureLineRange = struct {
    defined: usize,
    last: usize,
};

fn closureLineRange(proto: *const compile.proto.Proto) ?ClosureLineRange {
    if (proto.defined_line == 0) return .{ .defined = 0, .last = 0 };
    if (proto.line_info.items.len == 0) return null;
    var min_line = proto.line_info.items[0].line;
    var max_line = min_line;
    for (proto.line_info.items[1..]) |info| {
        min_line = @min(min_line, info.line);
        max_line = @max(max_line, info.line);
    }
    return .{
        .defined = if (proto.defined_line != 0) proto.defined_line else if (min_line == max_line or min_line == 0) min_line else min_line - 1,
        .last = if (proto.last_defined_line != 0) proto.last_defined_line else if (min_line == max_line) max_line else max_line + 1,
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

fn getFunctionLocal(state: *State, thread: *Thread, op: bytecode.Call, target: Value, index_value: Value) !void {
    if (target != .closure) return state.returnValues(thread, op.base, op.return_count, &.{.nil});
    const index = runtime.toInteger(index_value) orelse return state.returnValues(thread, op.base, op.return_count, &.{.nil});
    if (index <= 0) return state.returnValues(thread, op.base, op.return_count, &.{.nil});
    var seen: i64 = 0;
    for (target.closure.proto.locals.items) |local| {
        if (local.register >= target.closure.proto.param_count) continue;
        seen += 1;
        if (seen == index) {
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(local.name) }});
            return;
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.nil});
}

fn frameAtLevel(thread: *Thread, level: i64) ?*@TypeOf(thread.frames.items[0]) {
    const index = frameIndexAtLevel(thread, level) orelse return null;
    return &thread.frames.items[index];
}

fn frameIndexAtLevel(thread: *Thread, level: i64) ?usize {
    if (level < 1) return null;
    const depth: usize = @intCast(level);
    if (depth > thread.frames.items.len) return null;
    return thread.frames.items.len - depth;
}

const VisibleLocal = union(enum) {
    vararg_table,
    local: compile.proto.LocalDebug,
    temporary: bytecode.Register,
};

fn visibleLocalAtIndex(thread: *Thread, frame_index: usize, index: i64, include_temporaries: bool) ?VisibleLocal {
    if (index <= 0) return null;
    const frame = &thread.frames.items[frame_index];
    if (hasSyntheticVarargTableLocal(frame)) {
        if (index == 1) return .vararg_table;
        return localOrTemporaryAtIndex(thread, frame_index, index - 1, include_temporaries);
    }
    return localOrTemporaryAtIndex(thread, frame_index, index, include_temporaries);
}

fn hasSyntheticVarargTableLocal(frame: anytype) bool {
    return frame.proto.is_vararg and !frame.proto.named_vararg and frame.proto.defined_line != 0;
}

fn localOrTemporaryAtIndex(thread: *Thread, frame_index: usize, index: i64, include_temporaries: bool) ?VisibleLocal {
    const frame = &thread.frames.items[frame_index];
    var seen: i64 = 0;
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    const expose_named_locals = !frame.closure.stripped_debug;
    if (expose_named_locals) {
        for (frame.proto.locals.items) |local| {
            if (std.mem.eql(u8, local.name, "_ENV")) continue;
            if (!runtime.localActiveAt(local, pc)) continue;
            seen += 1;
            if (seen == index) return .{ .local = local };
        }
    }

    if (!include_temporaries) return null;

    const register_limit = if (frame_index + 1 < thread.frames.items.len)
        @min(frame.proto.max_registers, thread.frames.items[frame_index + 1].base - frame.base)
    else
        frame.proto.max_registers;
    for (0..register_limit) |register_usize| {
        const register: bytecode.Register = @intCast(register_usize);
        if (envLocalUsesRegister(frame, register)) continue;
        if (expose_named_locals and activeLocalUsesRegister(frame, pc, register)) continue;
        if (thread.stack.items[frame.base + register] == .nil and (frame.closure.stripped_debug or !inactiveLocalUsesRegister(frame, pc, register))) continue;
        seen += 1;
        if (seen == index) return .{ .temporary = register };
    }
    return null;
}

fn envLocalUsesRegister(frame: anytype, register: bytecode.Register) bool {
    for (frame.proto.locals.items) |local| {
        if (local.register == register and std.mem.eql(u8, local.name, "_ENV")) return true;
    }
    return false;
}

fn activeLocalUsesRegister(frame: anytype, pc: usize, register: bytecode.Register) bool {
    for (frame.proto.locals.items) |local| {
        if (std.mem.eql(u8, local.name, "_ENV")) continue;
        if (local.register == register and runtime.localActiveAt(local, pc)) return true;
    }
    return false;
}

fn inactiveLocalUsesRegister(frame: anytype, pc: usize, register: bytecode.Register) bool {
    for (frame.proto.locals.items) |local| {
        if (std.mem.eql(u8, local.name, "_ENV")) continue;
        if (local.register == register and !runtime.localActiveAt(local, pc)) return true;
    }
    return false;
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
