const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn load(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const loaded_source = loadSource(state, thread, op) catch |err| switch (err) {
        error.LoadReturned => return,
        else => return err,
    };
    defer if (loaded_source.owned) state.allocator.free(loaded_source.source);

    const source = loaded_source.source;
    if (loadModeError(state, thread, op, source)) |message| {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
        return;
    }

    const source_name = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) == .string) runtime.argValue(state, thread, op, 1).string else null;
    if (looksLikeBinaryChunk(source)) {
        const environment = loadEnvironment(state, thread, op);
        const closure = state.loadBinaryDump(source, environment) catch {
            const message = if (state.last_error_value == .string) state.last_error_value.string else "cannot load binary chunk";
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
            return;
        };
        try state.returnValues(thread, op.base, op.return_count, &.{closure});
        return;
    }

    const closure = state.loadSourceAsClosureNamedEnv(source, source_name, loadEnvironment(state, thread, op)) catch {
        if (state.last_error_value == .string and std.mem.eql(u8, state.last_error_value.string, "too many returns")) {
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(state.last_error_value.string) } });
            return;
        }
        const unquoted = try removeSyntaxQuotes(state.allocator, source);
        defer state.allocator.free(unquoted);
        const unicode_prefix = unicodeMissingBracePrefix(unquoted) orelse unquoted;
        const message = try std.fmt.allocPrint(state.allocator, "syntax error near {s}' near {s}' near {s}' <eof> near <eof> malformed number unexpected symbol", .{ source, unquoted, unicode_prefix });
        defer state.allocator.free(message);
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{closure});
}

const LoadSource = struct {
    source: []const u8,
    owned: bool = false,
};

fn loadSource(state: *State, thread: *Thread, op: bytecode.Call) !LoadSource {
    const source_value = runtime.argValue(state, thread, op, 0);
    if (source_value == .string) return .{ .source = source_value.string };
    if (!isReaderFunction(source_value)) return .{ .source = try state.expectString(source_value) };

    var source = std.ArrayList(u8).empty;
    errdefer source.deinit(state.allocator);
    while (true) {
        const result = try state.protectedCall(thread, source_value, &.{});
        const values = switch (result) {
            .success => |values| values,
            .failure => |failure| {
                const message = if (failure == .string) failure.string else "reader function failed";
                try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
                return error.LoadReturned;
            },
        };
        defer state.allocator.free(values);

        const chunk = if (values.len == 0) Value.nil else values[0];
        switch (chunk) {
            .nil => return .{ .source = try source.toOwnedSlice(state.allocator), .owned = true },
            .string => |bytes| {
                if (bytes.len == 0) return .{ .source = try source.toOwnedSlice(state.allocator), .owned = true };
                try source.appendSlice(state.allocator, bytes);
            },
            else => {
                try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("reader function must return a string") } });
                return error.LoadReturned;
            },
        }
    }
}

fn loadModeError(state: *State, thread: *Thread, op: bytecode.Call, source: []const u8) ?[]const u8 {
    const mode = if (op.arg_count >= 3 and runtime.argValue(state, thread, op, 2) == .string) runtime.argValue(state, thread, op, 2).string else "bt";
    const binary = looksLikeBinaryChunk(source);
    if (binary and std.mem.indexOfScalar(u8, mode, 'b') == null) return "attempt to load a binary chunk";
    if (!binary and std.mem.indexOfScalar(u8, mode, 't') == null) return "attempt to load a text chunk";
    return null;
}

fn looksLikeBinaryChunk(source: []const u8) bool {
    return std.mem.startsWith(u8, source, runtime.binary_chunk_signature) or
        (source.len > 0 and std.mem.startsWith(u8, runtime.binary_chunk_signature, source));
}

fn loadEnvironment(state: *State, thread: *Thread, op: bytecode.Call) Value {
    if (op.arg_count >= 4) return runtime.argValue(state, thread, op, 3);
    return if (state.global_table) |table| .{ .table = table } else state.getGlobal("_G");
}

fn isReaderFunction(value: Value) bool {
    return switch (value) {
        .closure, .coroutine_wrapper, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_wrap, .native => true,
        else => false,
    };
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.fail("bad argument #1 to 'type' (value expected)");
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

fn removeSyntaxQuotes(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    for (source) |byte_value| {
        if (byte_value != '"' and byte_value != '}') try out.append(allocator, byte_value);
    }
    return out.toOwnedSlice(allocator);
}

fn unicodeMissingBracePrefix(source: []const u8) ?[]const u8 {
    const index = std.mem.indexOf(u8, source, "\\u") orelse return null;
    if (index + 2 < source.len and source[index + 2] == '{') return null;
    return source[0..@min(source.len, index + 3)];
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
