const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn byte(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, source.len);
    const stop = normalizeIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse @as(i64, @intCast(start)) else @as(i64, @intCast(start)), source.len);
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    if (start <= stop and start >= 1) {
        var index = start;
        while (index <= stop and index <= source.len) : (index += 1) try values.append(state.allocator, .{ .integer = source[index - 1] });
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

pub fn char(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    for (0..op.arg_count) |index| {
        const value = runtime.toInteger(runtime.argValue(state, thread, op, @intCast(index))) orelse return state.fail("number expected");
        if (value < 0 or value > 255) return state.fail("value out of range");
        try out.append(state.allocator, @intCast(value));
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn dump(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    if (target != .closure) return state.fail("unable to dump given function");

    var debug_payload = std.ArrayList(u8).empty;
    defer debug_payload.deinit(state.allocator);
    try appendProtoDebugStrings(state.allocator, &debug_payload, target.closure.proto);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try runtime.appendBinaryChunkHeader(state.allocator, &out);
    try out.appendSlice(state.allocator, runtime.binary_chunk_payload_magic);
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], @intFromPtr(target.closure.proto), .little);
    try out.appendSlice(state.allocator, bytes[0..8]);
    std.mem.writeInt(u32, bytes[0..4], @intCast(debug_payload.items.len), .little);
    try out.appendSlice(state.allocator, bytes[0..4]);
    try out.appendSlice(state.allocator, debug_payload.items);

    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn appendProtoDebugStrings(allocator: std.mem.Allocator, out: *std.ArrayList(u8), proto: *const compile.proto.Proto) !void {
    for (proto.constants.items) |constant| {
        if (constant == .string) {
            try out.appendSlice(allocator, constant.string);
            try out.appendSlice(allocator, constant.string);
        }
    }
    for (proto.children.items) |child| try appendProtoDebugStrings(allocator, out, child);
}

pub fn find(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try findImpl(state, thread, op, true);
}

pub fn format(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const fmt = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var arg: u16 = 1;
    var index: usize = 0;
    while (index < fmt.len) : (index += 1) {
        if (fmt[index] != '%') {
            try out.append(state.allocator, fmt[index]);
            continue;
        }
        index += 1;
        if (index >= fmt.len) return state.fail("invalid format");
        if (fmt[index] == '%') {
            try out.append(state.allocator, '%');
            continue;
        }
        while (index < fmt.len and std.mem.indexOfScalar(u8, "-+ #0.123456789", fmt[index]) != null) index += 1;
        if (index >= fmt.len) return state.fail("invalid format");
        const value = runtime.argValue(state, thread, op, arg);
        arg += 1;
        switch (fmt[index]) {
            's' => try runtime.appendValue(state.allocator, &out, value),
            'q' => try appendQuoted(state.allocator, &out, try state.expectString(value)),
            'd', 'i' => try runtime.appendFmt(state.allocator, &out, "{d}", .{runtime.toInteger(value) orelse return state.fail("number expected")}),
            'u' => try runtime.appendFmt(state.allocator, &out, "{d}", .{@as(u64, @bitCast(runtime.toInteger(value) orelse return state.fail("number expected")))}),
            'x' => try runtime.appendFmt(state.allocator, &out, "{x}", .{runtime.toInteger(value) orelse return state.fail("number expected")}),
            'X' => try runtime.appendFmt(state.allocator, &out, "{X}", .{runtime.toInteger(value) orelse return state.fail("number expected")}),
            'o' => try runtime.appendFmt(state.allocator, &out, "{o}", .{runtime.toInteger(value) orelse return state.fail("number expected")}),
            'p' => try appendPointer(state.allocator, &out, value),
            'f', 'e', 'E', 'g', 'G' => try runtime.appendNumber(state.allocator, &out, try runtime.toNumber(value)),
            else => return state.fail("invalid format"),
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn gmatch(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const state_value = try state.newTableWithHints(0, 3);
    const state_table = state_value.table;
    try state_table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = try state.expectString(runtime.argValue(state, thread, op, 0)) });
    try state_table.set(state.allocator, .{ .string = try state.intern("p") }, .{ .string = try state.expectString(runtime.argValue(state, thread, op, 1)) });
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = 0 });
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .string_gmatch_iter }, state_value, .nil });
}

pub fn gmatchIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try gmatchNext(state, runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn gmatchNext(state: *State, state_value: Value) ![2]Value {
    const state_table = try state.expectTable(state_value);
    const source = try state.expectString(state_table.get(.{ .string = "s" }));
    const pattern = try state.expectString(state_table.get(.{ .string = "p" }));
    const pos = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const found = simplePatternFind(source, pattern, @intCast(@max(pos, 0))) orelse return .{ .nil, .nil };
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(if (found.end > found.start) found.end else found.end + 1) });
    return .{ .{ .string = try state.intern(source[found.start..found.end]) }, .nil };
}

pub fn gsub(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const pattern = try state.expectString(runtime.argValue(state, thread, op, 1));
    const replacement = runtime.argValue(state, thread, op, 2);
    const max_count = if (op.arg_count >= 4) runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse std.math.maxInt(i64) else std.math.maxInt(i64);
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var pos: usize = 0;
    var count: i64 = 0;
    while (pos <= source.len and count < max_count) {
        const found = simplePatternFind(source, pattern, pos) orelse break;
        try out.appendSlice(state.allocator, source[pos..found.start]);
        try out.appendSlice(state.allocator, try gsubReplacement(state, replacement, source[found.start..found.end]));
        pos = if (found.end > found.start) found.end else found.end + 1;
        count += 1;
    }
    try out.appendSlice(state.allocator, source[@min(pos, source.len)..]);
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern(out.items) }, .{ .integer = count } });
}

fn gsubReplacement(state: *State, replacement: Value, matched: []const u8) ![]const u8 {
    return switch (replacement) {
        .string => |bytes| bytes,
        .table => |table| switch (table.get(.{ .string = matched })) {
            .nil => matched,
            .boolean => |value| if (value) "true" else matched,
            .string => |bytes| bytes,
            else => |value| blk: {
                var out = std.ArrayList(u8).empty;
                defer out.deinit(state.allocator);
                try runtime.appendValue(state.allocator, &out, value);
                break :blk try state.intern(out.items);
            },
        },
        else => return state.fail("string or table expected"),
    };
}

pub fn len(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(source.len) }});
}

pub fn lower(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try asciiMap(state, thread, op, true);
}

pub fn match(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try findImpl(state, thread, op, false);
}

pub fn pack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const pack_format = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var arg: u16 = 1;
    var endian: Endian = nativeEndian();
    var index: usize = 0;
    while (index < pack_format.len) : (index += 1) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code)) continue;
        if (code == '<') {
            endian = .little;
            continue;
        }
        if (code == '>' or code == '!') {
            endian = .big;
            continue;
        }
        if (code == '=') {
            endian = nativeEndian();
            continue;
        }
        const size = packCodeSize(code, pack_format, &index) orelse return state.fail("invalid format option");
        if (code == 'c') {
            const value = try state.expectString(runtime.argValue(state, thread, op, arg));
            arg += 1;
            if (value.len > size) return state.fail("string longer than given size");
            try out.appendSlice(state.allocator, value);
            try out.appendNTimes(state.allocator, 0, size - value.len);
            continue;
        }
        const value = runtime.argValue(state, thread, op, arg);
        arg += 1;
        try appendPackedValue(state.allocator, &out, value, code, size, endian);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn packsize(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const pack_format = try state.expectString(runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(try packFormatSize(state, pack_format)) }});
}

pub fn rep(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const count = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const sep = if (op.arg_count >= 3) try state.expectString(runtime.argValue(state, thread, op, 2)) else "";
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    if (count > 0) {
        var index: i64 = 0;
        while (index < count) : (index += 1) {
            if (index != 0) try out.appendSlice(state.allocator, sep);
            try out.appendSlice(state.allocator, source);
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn reverse(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = try state.allocator.alloc(u8, source.len);
    defer state.allocator.free(out);
    for (source, 0..) |source_byte, index| out[source.len - 1 - index] = source_byte;
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out) }});
}

pub fn sub(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeIndex(runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1, source.len);
    const stop = normalizeIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse -1 else -1, source.len);
    if (start > stop or start > source.len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("") }});
        return;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(source[@max(start, 1) - 1 .. @min(stop, source.len)]) }});
}

pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const pack_format = try state.expectString(runtime.argValue(state, thread, op, 0));
    const data = try state.expectString(runtime.argValue(state, thread, op, 1));
    var pos: usize = @intCast(@max(1, if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1) - 1);
    var endian: Endian = nativeEndian();
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index: usize = 0;
    while (index < pack_format.len) : (index += 1) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code)) continue;
        if (code == '<') {
            endian = .little;
            continue;
        }
        if (code == '>' or code == '!') {
            endian = .big;
            continue;
        }
        if (code == '=') {
            endian = nativeEndian();
            continue;
        }
        const size = packCodeSize(code, pack_format, &index) orelse return state.fail("invalid format option");
        if (pos + size > data.len) return state.fail("data string too short");
        if (code == 'c') {
            try values.append(state.allocator, .{ .string = try state.intern(data[pos .. pos + size]) });
        } else {
            try values.append(state.allocator, unpackValue(data[pos .. pos + size], code, endian));
        }
        pos += size;
    }
    try values.append(state.allocator, .{ .integer = @intCast(pos + 1) });
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

pub fn upper(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try asciiMap(state, thread, op, false);
}

fn asciiMap(state: *State, thread: *Thread, op: bytecode.Call, to_lower: bool) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = try state.allocator.alloc(u8, source.len);
    defer state.allocator.free(out);
    for (source, 0..) |source_byte, index| out[index] = if (to_lower) std.ascii.toLower(source_byte) else std.ascii.toUpper(source_byte);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out) }});
}

fn findImpl(state: *State, thread: *Thread, op: bytecode.Call, positions: bool) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const pattern = try state.expectString(runtime.argValue(state, thread, op, 1));
    const initial = normalizeIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1, source.len);
    const plain = op.arg_count >= 4 and runtime.truthy(runtime.argValue(state, thread, op, 3));
    const start = if (initial <= 1) 0 else @min(initial - 1, source.len);
    const found = if (plain) plainFind(source, pattern, start) else simplePatternFind(source, pattern, start);
    if (found) |range| {
        if (positions) {
            try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = @intCast(range.start + 1) }, .{ .integer = @intCast(range.end) } });
        } else {
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(source[range.start..range.end]) }});
        }
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
    }
}

fn normalizeIndex(index: i64, source_len: usize) usize {
    const length: i64 = @intCast(source_len);
    const normalized = if (index < 0) length + index + 1 else index;
    if (normalized <= 0) return 0;
    return @intCast(normalized);
}

const MatchRange = struct { start: usize, end: usize };

fn plainFind(source: []const u8, pattern: []const u8, start: usize) ?MatchRange {
    if (pattern.len == 0) return .{ .start = @min(start, source.len), .end = @min(start, source.len) };
    if (start > source.len) return null;
    const relative = std.mem.indexOf(u8, source[start..], pattern) orelse return null;
    return .{ .start = start + relative, .end = start + relative + pattern.len };
}

fn simplePatternFind(source: []const u8, pattern: []const u8, start: usize) ?MatchRange {
    if (pattern.len == 0) return .{ .start = @min(start, source.len), .end = @min(start, source.len) };
    if (pattern[0] == '^') {
        const anchored_start = @min(start, source.len);
        const end = matchSimplePatternAt(source, pattern[1..], anchored_start) orelse return null;
        return .{ .start = anchored_start, .end = end };
    }
    var candidate = start;
    while (candidate <= source.len) : (candidate += 1) {
        if (matchSimplePatternAt(source, pattern, candidate)) |end| return .{ .start = candidate, .end = end };
    }
    return null;
}

fn matchSimplePatternAt(source: []const u8, pattern: []const u8, start: usize) ?usize {
    return matchPatternFrom(source, pattern, start, 0);
}

fn matchPatternFrom(source: []const u8, pattern: []const u8, source_index: usize, pattern_index: usize) ?usize {
    if (pattern_index >= pattern.len) return source_index;
    if (pattern[pattern_index] == '$' and pattern_index + 1 == pattern.len) return if (source_index == source.len) source_index else null;

    const atom_start = pattern_index;
    const atom_end = nextPatternAtom(pattern, atom_start);
    const quantifier = if (atom_end < pattern.len and std.mem.indexOfScalar(u8, "*+-?", pattern[atom_end]) != null) pattern[atom_end] else 0;
    const next_index = atom_end + @as(usize, if (quantifier != 0) 1 else 0);
    const atom = pattern[atom_start..atom_end];

    switch (quantifier) {
        0 => {
            if (source_index >= source.len or !patternAtomMatches(atom, source[source_index])) return null;
            return matchPatternFrom(source, pattern, source_index + 1, next_index);
        },
        '?' => {
            if (source_index < source.len and patternAtomMatches(atom, source[source_index])) {
                if (matchPatternFrom(source, pattern, source_index + 1, next_index)) |end| return end;
            }
            return matchPatternFrom(source, pattern, source_index, next_index);
        },
        '*', '+' => {
            var end = source_index;
            while (end < source.len and patternAtomMatches(atom, source[end])) end += 1;
            if (quantifier == '+' and end == source_index) return null;
            var candidate = end;
            while (candidate >= source_index) : (candidate -= 1) {
                if (matchPatternFrom(source, pattern, candidate, next_index)) |matched_end| return matched_end;
                if (candidate == source_index) break;
            }
            return null;
        },
        '-' => {
            var candidate = source_index;
            while (true) {
                if (matchPatternFrom(source, pattern, candidate, next_index)) |matched_end| return matched_end;
                if (candidate >= source.len or !patternAtomMatches(atom, source[candidate])) return null;
                candidate += 1;
            }
        },
        else => unreachable,
    }
}

fn nextPatternAtom(pattern: []const u8, index: usize) usize {
    if (pattern[index] == '%' and index + 1 < pattern.len) return index + 2;
    if (pattern[index] == '[') {
        var end = index + 1;
        while (end < pattern.len and pattern[end] != ']') : (end += 1) {}
        if (end < pattern.len) return end + 1;
    }
    return index + 1;
}

fn patternAtomMatches(atom: []const u8, source_byte: u8) bool {
    if (atom.len == 1) return atom[0] == '.' or atom[0] == source_byte;
    if (atom[0] == '%') return switch (atom[1]) {
        'a' => std.ascii.isAlphabetic(source_byte),
        'A' => !std.ascii.isAlphabetic(source_byte),
        'c' => isControl(source_byte),
        'C' => !isControl(source_byte),
        'd' => std.ascii.isDigit(source_byte),
        'D' => !std.ascii.isDigit(source_byte),
        'g' => source_byte > ' ' and source_byte < 0x7f,
        'G' => !(source_byte > ' ' and source_byte < 0x7f),
        'l' => std.ascii.isLower(source_byte),
        'L' => !std.ascii.isLower(source_byte),
        'p' => isPunctuation(source_byte),
        'P' => !isPunctuation(source_byte),
        's' => std.ascii.isWhitespace(source_byte),
        'S' => !std.ascii.isWhitespace(source_byte),
        'u' => std.ascii.isUpper(source_byte),
        'U' => !std.ascii.isUpper(source_byte),
        'w' => std.ascii.isAlphanumeric(source_byte),
        'W' => !std.ascii.isAlphanumeric(source_byte),
        'x' => std.ascii.isHex(source_byte),
        'X' => !std.ascii.isHex(source_byte),
        'z' => source_byte == 0,
        'Z' => source_byte != 0,
        else => atom[1] == source_byte,
    };
    if (atom[0] == '[' and atom[atom.len - 1] == ']') {
        const negated = atom.len > 2 and atom[1] == '^';
        const body = atom[if (negated) 2 else 1 .. atom.len - 1];
        var matched = false;
        var index: usize = 0;
        while (index < body.len) : (index += 1) {
            if (index + 2 < body.len and body[index + 1] == '-') {
                matched = matched or (body[index] <= source_byte and source_byte <= body[index + 2]);
                index += 2;
            } else {
                matched = matched or body[index] == source_byte;
            }
        }
        return if (negated) !matched else matched;
    }
    return false;
}

fn isControl(code: u8) bool {
    return code < 0x20 or code == 0x7f;
}

fn isPunctuation(code: u8) bool {
    return (code >= '!' and code <= '/') or (code >= ':' and code <= '@') or (code >= '[' and code <= '`') or (code >= '{' and code <= '~');
}

fn appendQuoted(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) !void {
    try out.append(allocator, '"');
    for (source) |source_byte| switch (source_byte) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => try out.append(allocator, source_byte),
    };
    try out.append(allocator, '"');
}

fn appendPointer(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    const address: usize = switch (value) {
        .string => |string| @intFromPtr(string.ptr),
        .table => |table| @intFromPtr(table),
        .closure => |closure| @intFromPtr(closure),
        .thread => |thread| @intFromPtr(thread),
        else => 0,
    };
    try runtime.appendFmt(allocator, out, "0x{x}", .{address});
}

const Endian = enum { little, big };

fn nativeEndian() Endian {
    return switch (@import("builtin").target.cpu.arch.endian()) {
        .little => .little,
        .big => .big,
    };
}

fn packFormatSize(state: *State, pack_format: []const u8) !usize {
    var total: usize = 0;
    var index: usize = 0;
    while (index < pack_format.len) : (index += 1) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code) or code == '<' or code == '>' or code == '=' or code == '!') continue;
        total += packCodeSize(code, pack_format, &index) orelse return state.fail("invalid format option");
    }
    return total;
}

fn packCodeSize(code: u8, pack_format: []const u8, index: *usize) ?usize {
    return switch (code) {
        'b', 'B' => 1,
        'h', 'H' => 2,
        'l', 'L', 'j', 'J', 'T', 'n', 'd' => 8,
        'f' => 4,
        'i', 'I' => parsePackSize(pack_format, index),
        'c' => parseFixedStringSize(pack_format, index),
        else => null,
    };
}

fn parsePackSize(pack_format: []const u8, index: *usize) ?usize {
    var size: usize = 0;
    while (index.* + 1 < pack_format.len and std.ascii.isDigit(pack_format[index.* + 1])) {
        index.* += 1;
        size = size * 10 + pack_format[index.*] - '0';
    }
    if (size == 0) size = @sizeOf(isize);
    if (size != 1 and size != 2 and size != 4 and size != 8) return null;
    return size;
}

fn parseFixedStringSize(pack_format: []const u8, index: *usize) ?usize {
    var size: usize = 0;
    var saw_digit = false;
    while (index.* + 1 < pack_format.len and std.ascii.isDigit(pack_format[index.* + 1])) {
        index.* += 1;
        saw_digit = true;
        size = size * 10 + pack_format[index.*] - '0';
    }
    return if (saw_digit) size else null;
}

fn appendPackedValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value, code: u8, size: usize, endian: Endian) !void {
    var bytes: [8]u8 = undefined;
    switch (code) {
        'f' => std.mem.writeInt(u32, bytes[0..4], @bitCast(@as(f32, @floatCast(try runtime.toNumber(value)))), if (endian == .little) .little else .big),
        'd', 'n' => std.mem.writeInt(u64, bytes[0..8], @bitCast(try runtime.toNumber(value)), if (endian == .little) .little else .big),
        else => {
            const integer = runtime.toInteger(value) orelse return error.RuntimeError;
            const unsigned: u64 = @bitCast(integer);
            switch (size) {
                1 => bytes[0] = @truncate(unsigned),
                2 => std.mem.writeInt(u16, bytes[0..2], @truncate(unsigned), if (endian == .little) .little else .big),
                4 => std.mem.writeInt(u32, bytes[0..4], @truncate(unsigned), if (endian == .little) .little else .big),
                8 => std.mem.writeInt(u64, bytes[0..8], unsigned, if (endian == .little) .little else .big),
                else => unreachable,
            }
        },
    }
    try out.appendSlice(allocator, bytes[0..size]);
}

fn unpackValue(bytes: []const u8, code: u8, endian: Endian) Value {
    return switch (code) {
        'f' => .{ .number = @floatCast(@as(f32, @bitCast(std.mem.readInt(u32, bytes[0..4], if (endian == .little) .little else .big)))) },
        'd', 'n' => .{ .number = @bitCast(std.mem.readInt(u64, bytes[0..8], if (endian == .little) .little else .big)) },
        else => blk: {
            const unsigned: u64 = switch (bytes.len) {
                1 => bytes[0],
                2 => std.mem.readInt(u16, bytes[0..2], if (endian == .little) .little else .big),
                4 => std.mem.readInt(u32, bytes[0..4], if (endian == .little) .little else .big),
                8 => std.mem.readInt(u64, bytes[0..8], if (endian == .little) .little else .big),
                else => 0,
            };
            const signed = switch (code) {
                'b', 'h', 'l', 'j', 'i' => signExtend(unsigned, bytes.len),
                else => @as(i64, @intCast(unsigned)),
            };
            break :blk .{ .integer = signed };
        },
    };
}

fn signExtend(value: u64, size: usize) i64 {
    const bits = size * 8;
    if (bits == 64) return @bitCast(value);
    const shift: u6 = @intCast(64 - bits);
    return @as(i64, @bitCast(value << shift)) >> shift;
}
