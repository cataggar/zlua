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
        var bytes: [4]u8 = undefined;
        const encoded_len = encode(@intCast(code), &bytes) orelse return state.fail("value out of range");
        try out.appendSlice(state.allocator, bytes[0..encoded_len]);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn codepoint(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, source.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse @as(i64, @intCast(start)) else @as(i64, @intCast(start)), source.len);
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, source.len);
    while (pos < end) {
        const decoded = decodeAt(source, pos) orelse return state.fail("invalid UTF-8 code");
        try values.append(state.allocator, .{ .integer = decoded.codepoint });
        pos += decoded.len;
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

pub fn codes(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const state_value = try state.newTableWithHints(0, 2);
    try state_value.table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = source });
    try state_value.table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = 0 });
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .utf8_codes_iter }, state_value, .nil });
}

pub fn codesIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try codesNext(state, runtime.argValue(state, thread, op, 0), runtime.argValue(state, thread, op, 1));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn codesNext(state: *State, state_value: Value, index_value: Value) ![2]Value {
    _ = index_value;
    const state_table = try state.expectTable(state_value);
    const source = try state.expectString(state_table.get(.{ .string = "s" }));
    const current = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const pos: usize = @intCast(@max(current, 0));
    if (pos >= source.len) return .{ .nil, .nil };
    const decoded = decodeAt(source, pos) orelse return state.fail("invalid UTF-8 code");
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(pos + decoded.len) });
    return .{ .{ .integer = @intCast(pos + 1) }, .{ .integer = decoded.codepoint } };
}

pub fn len(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, source.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse -1 else -1, source.len);
    var count: i64 = 0;
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, source.len);
    while (pos < end) {
        const decoded = decodeAt(source, pos) orelse {
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
    const pos = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else if (n >= 0) 1 else -1, source.len);
    if (pos < 1 or pos > source.len + 1) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    var byte_pos = pos - 1;
    while (byte_pos > 0 and isContinuation(source[byte_pos])) byte_pos -= 1;
    if (n == 0) {
        const decoded = decodeAt(source, byte_pos) orelse return state.fail("invalid UTF-8 code");
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = @intCast(byte_pos + 1) }, .{ .integer = @intCast(byte_pos + decoded.len) } });
        return;
    }
    var remaining = if (n > 0) n - 1 else -n;
    while (remaining > 0) : (remaining -= 1) {
        if (n > 0) {
            const decoded = decodeAt(source, byte_pos) orelse return state.fail("invalid UTF-8 code");
            byte_pos += decoded.len;
            if (byte_pos >= source.len and remaining > 1) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
        } else {
            if (byte_pos == 0) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            byte_pos -= 1;
            while (byte_pos > 0 and isContinuation(source[byte_pos])) byte_pos -= 1;
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(byte_pos + 1) }});
}

fn normalizeStringIndex(index: i64, source_len: usize) usize {
    const length: i64 = @intCast(source_len);
    const normalized = if (index < 0) length + index + 1 else index;
    if (normalized <= 0) return 0;
    return @intCast(normalized);
}

const Decoded = struct { codepoint: i64, len: usize };

fn decodeAt(bytes: []const u8, pos: usize) ?Decoded {
    if (pos >= bytes.len) return null;
    const first = bytes[pos];
    if (first < 0x80) return .{ .codepoint = first, .len = 1 };
    const decoded_len: usize = if ((first & 0xe0) == 0xc0) 2 else if ((first & 0xf0) == 0xe0) 3 else if ((first & 0xf8) == 0xf0) 4 else return null;
    if (pos + decoded_len > bytes.len) return null;
    var code: i64 = first & (@as(u8, 0x7f) >> @intCast(decoded_len));
    for (bytes[pos + 1 .. pos + decoded_len]) |byte| {
        if (!isContinuation(byte)) return null;
        code = (code << 6) | (byte & 0x3f);
    }
    return .{ .codepoint = code, .len = decoded_len };
}

fn encode(code: u21, out: *[4]u8) ?usize {
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
    if (code <= 0x10ffff) {
        out[0] = 0xf0 | @as(u8, @intCast(code >> 18));
        out[1] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 4;
    }
    return null;
}

fn isContinuation(byte: u8) bool {
    return (byte & 0xc0) == 0x80;
}
