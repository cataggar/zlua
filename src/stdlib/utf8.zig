const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn char(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    for (0..op.arg_count) |index| {
        const code = runtime.toInteger(runtime.argValue(state, thread, op, @intCast(index))) orelse return state.fail("integer expected");
        var bytes: [6]u8 = undefined;
        const encoded_len = encode(code, &bytes) orelse return state.fail("value out of range");
        try out.appendSlice(state.allocator, bytes[0..encoded_len]);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn codepoint(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, source.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse @as(i64, @intCast(start)) else @as(i64, @intCast(start)), source.len);
    const strict = !(op.arg_count >= 4 and runtime.truthy(runtime.argValue(state, thread, op, 3)));
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    if (start > stop) {
        try state.returnValues(thread, op.base, op.return_count, values.items);
        return;
    }
    if (start < 1) return state.fail("out of bounds");
    if (stop > source.len) return state.fail("out of bounds");
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, source.len);
    while (pos < end) {
        const decoded = decodeAt(source, pos, strict) orelse return state.fail("invalid UTF-8 code");
        try values.append(state.allocator, .{ .integer = decoded.codepoint });
        pos += decoded.len;
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

pub fn codes(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const strict = !(op.arg_count >= 2 and runtime.truthy(runtime.argValue(state, thread, op, 1)));
    if (strict) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .utf8_codes_iter }, .{ .string = source }, .{ .integer = 0 } });
        return;
    }
    const state_value = try state.newTableWithHints(0, 2);
    try state_value.table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = source });
    try state_value.table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = 0 });
    try state_value.table.set(state.allocator, .{ .string = try state.intern("strict") }, .{ .boolean = strict });
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .utf8_codes_iter }, state_value, .nil });
}

pub fn codesIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try codesNext(state, runtime.argValue(state, thread, op, 0), runtime.argValue(state, thread, op, 1));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn codesNext(state: *State, state_value: Value, index_value: Value) ![2]Value {
    if (state_value == .string) {
        const current = runtime.toInteger(index_value) orelse return .{ .nil, .nil };
        if (current < 0) return .{ .nil, .nil };
        const pos: usize = if (current == 0) 0 else blk: {
            const previous_pos: usize = @intCast(current - 1);
            if (previous_pos >= state_value.string.len) return .{ .nil, .nil };
            break :blk previous_pos + (sequenceLenAt(state_value.string, previous_pos) orelse return state.fail("invalid UTF-8 code"));
        };
        if (pos >= state_value.string.len) return .{ .nil, .nil };
        const decoded = decodeAt(state_value.string, pos, true) orelse return state.fail("invalid UTF-8 code");
        return .{ .{ .integer = @intCast(pos + 1) }, .{ .integer = decoded.codepoint } };
    }

    const state_table = try state.expectTable(state_value);
    const source = try state.expectString(state_table.get(.{ .string = "s" }));
    const current = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const strict = runtime.truthy(state_table.get(.{ .string = "strict" }));
    const pos: usize = @intCast(@max(current, 0));
    if (pos >= source.len) return .{ .nil, .nil };
    const decoded = decodeAt(source, pos, strict) orelse return state.fail("invalid UTF-8 code");
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(pos + decoded.len) });
    return .{ .{ .integer = @intCast(pos + 1) }, .{ .integer = decoded.codepoint } };
}

pub fn len(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, source.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse -1 else -1, source.len);
    const strict = !(op.arg_count >= 4 and runtime.truthy(runtime.argValue(state, thread, op, 3)));
    var count: i64 = 0;
    if (start < 1 or start > source.len + 1) return state.fail("out of bounds");
    if (stop > source.len) return state.fail("out of bounds");
    if (start > stop) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
        return;
    }
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, source.len);
    while (pos < end) {
        const decoded = decodeAt(source, pos, strict) orelse {
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .integer = @intCast(pos + 1) } });
            return;
        };
        count += 1;
        pos += decoded.len;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = count }});
}

pub fn offset(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const n = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const explicit_pos = op.arg_count >= 3;
    const pos = normalizeStringIndex(if (explicit_pos) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else if (n >= 0) 1 else @as(i64, @intCast(source.len + 1)), source.len);
    if (pos < 1 or pos > source.len + 1) {
        if (explicit_pos) return state.fail("position out of bounds");
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    if (n != 0 and pos <= source.len and isContinuation(source[pos - 1])) return state.fail("initial position is a continuation byte");

    if (n == 0) {
        const byte_pos = if (pos == source.len + 1) source.len else charStartAtOrBefore(source, pos - 1);
        try returnOffsetRange(state, thread, op, source, byte_pos);
        return;
    }

    var byte_pos: usize = if (n > 0) pos - 1 else blk: {
        if (pos <= 1) {
            try state.returnValues(thread, op.base, op.return_count, &.{.nil});
            return;
        }
        break :blk charStartAtOrBefore(source, pos - 2);
    };
    if (n < 0 and byte_pos < source.len and isContinuation(source[byte_pos])) return state.fail("initial position is a continuation byte");

    var remaining = if (n > 0) n - 1 else -n - 1;
    while (remaining > 0) : (remaining -= 1) {
        if (n > 0) {
            if (byte_pos >= source.len) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            byte_pos += sequenceLenAt(source, byte_pos) orelse return state.fail("invalid UTF-8 code");
        } else {
            if (byte_pos == 0) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            byte_pos -= 1;
            while (byte_pos > 0 and isContinuation(source[byte_pos])) byte_pos -= 1;
        }
    }
    try returnOffsetRange(state, thread, op, source, byte_pos);
}

fn normalizeStringIndex(index: i64, source_len: usize) usize {
    const length: i64 = @intCast(source_len);
    const normalized = if (index < 0) length + index + 1 else index;
    if (normalized <= 0) return 0;
    return @intCast(normalized);
}

const Decoded = struct { codepoint: i64, len: usize };

fn decodeAt(bytes: []const u8, pos: usize, strict: bool) ?Decoded {
    if (pos >= bytes.len) return null;
    const first = bytes[pos];
    if (first < 0x80) return .{ .codepoint = first, .len = 1 };
    const decoded_len = expectedSequenceLenAt(bytes, pos) orelse return null;
    if (pos + decoded_len > bytes.len) return null;
    var code: i64 = first & (@as(u8, 0x7f) >> @intCast(decoded_len));
    for (bytes[pos + 1 .. pos + decoded_len]) |byte| {
        if (!isContinuation(byte)) return null;
        code = (code << 6) | (byte & 0x3f);
    }
    if (strict and !isStrictCodepoint(code, decoded_len)) return null;
    return .{ .codepoint = code, .len = decoded_len };
}

fn sequenceLenAt(bytes: []const u8, pos: usize) ?usize {
    const expected_len = expectedSequenceLenAt(bytes, pos) orelse return null;
    return @min(expected_len, bytes.len - pos);
}

fn expectedSequenceLenAt(bytes: []const u8, pos: usize) ?usize {
    if (pos >= bytes.len) return null;
    const first = bytes[pos];
    return if (first < 0x80) 1 else if ((first & 0xe0) == 0xc0) 2 else if ((first & 0xf0) == 0xe0) 3 else if ((first & 0xf8) == 0xf0) 4 else if ((first & 0xfc) == 0xf8) 5 else if ((first & 0xfe) == 0xfc) 6 else null;
}

fn isStrictCodepoint(code: i64, byte_len: usize) bool {
    const min: i64 = switch (byte_len) {
        1 => 0,
        2 => 0x80,
        3 => 0x800,
        4 => 0x10000,
        else => return false,
    };
    return code >= min and code <= 0x10ffff and !(code >= 0xd800 and code <= 0xdfff);
}

fn charStartAtOrBefore(bytes: []const u8, byte_pos: usize) usize {
    var start = @min(byte_pos, bytes.len);
    while (start > 0 and isContinuation(bytes[start])) start -= 1;
    return start;
}

fn returnOffsetRange(state: *State, thread: *Thread, op: bytecode.Call, source: []const u8, byte_pos: usize) !void {
    if (byte_pos > source.len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    if (byte_pos == source.len) {
        const sentinel: i64 = @intCast(source.len + 1);
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = sentinel }, .{ .integer = sentinel } });
        return;
    }
    const len_at = sequenceLenAt(source, byte_pos) orelse return state.fail("invalid UTF-8 code");
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = @intCast(byte_pos + 1) }, .{ .integer = @intCast(byte_pos + len_at) } });
}

fn encode(code: i64, out: *[6]u8) ?usize {
    if (code < 0 or code > @as(i64, max_lua_utf8_codepoint)) return null;
    return encodeUnsigned(@intCast(code), out);
}

fn encodeUnsigned(code: u32, out: *[6]u8) ?usize {
    if (code <= 0x7f) {
        out[0] = @intCast(code);
        return 1;
    }
    if (code <= 0x7ff) {
        out[0] = 0xc0 | @as(u8, @intCast(code >> 6));
        out[1] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 2;
    }
    if (code <= 0xffff) {
        out[0] = 0xe0 | @as(u8, @intCast(code >> 12));
        out[1] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 3;
    }
    if (code <= 0x1fffff) {
        out[0] = 0xf0 | @as(u8, @intCast(code >> 18));
        out[1] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 4;
    }
    if (code <= 0x3ffffff) {
        out[0] = 0xf8 | @as(u8, @intCast(code >> 24));
        out[1] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 5;
    }
    if (code <= max_lua_utf8_codepoint) {
        out[0] = 0xfc | @as(u8, @intCast(code >> 30));
        out[1] = 0x80 | @as(u8, @intCast((code >> 24) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[5] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 6;
    }
    return null;
}

fn isContinuation(byte: u8) bool {
    return (byte & 0xc0) == 0x80;
}

const max_lua_utf8_codepoint: u32 = 0x7fffffff;
