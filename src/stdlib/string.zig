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
    const first = @max(start, 1);
    const last = @min(stop, source.len);
    if (first <= last) {
        var index = first;
        while (index <= last) : (index += 1) try values.append(state.allocator, .{ .integer = source[index - 1] });
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

    const strip_debug = (op.arg_count >= 2 and runtime.truthy(runtime.argValue(state, thread, op, 1))) or target.closure.stripped_debug;
    var debug_payload = std.ArrayList(u8).empty;
    defer debug_payload.deinit(state.allocator);
    if (!strip_debug) {
        try debug_payload.appendSlice(state.allocator, target.closure.proto.source_name);
        try appendProtoDebugStrings(state.allocator, &debug_payload, target.closure.proto);
    }

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
        if (index >= fmt.len) return state.fail("invalid conversion");
        if (fmt[index] == '%') {
            try out.append(state.allocator, '%');
            continue;
        }
        const spec_start = index;
        const spec = parseFormatSpec(fmt, &index, spec_start) orelse return state.fail("invalid conversion");
        if (spec.raw_len >= 22) return state.fail("format too long");
        if (spec.width_digits > 2 or spec.precision_digits > 2) return state.fail("invalid conversion");
        if (arg >= op.arg_count) return state.fail("no value");
        const value = runtime.argValue(state, thread, op, arg);
        arg += 1;
        switch (spec.conversion) {
            'c' => try appendCharFormat(state, &out, value, spec),
            's' => try appendStringFormat(state, thread, &out, value, spec),
            'q' => {
                if (spec.left_align or spec.force_sign or spec.space_sign or spec.alternate or spec.zero_pad or spec.width != null or spec.precision != null) return state.fail("specifier '%q' cannot have modifiers");
                try appendLiteral(state, &out, value);
            },
            'd', 'i', 'u', 'x', 'X', 'o' => try appendIntegerFormat(state, &out, value, spec),
            'p' => try appendPointer(state, &out, value, spec),
            'a', 'A' => try appendHexFloatFormat(state, &out, value, spec),
            'f' => try appendFloatFormat(state, &out, value, spec),
            'e', 'E', 'g', 'G' => try appendGeneralFloatFormat(state, &out, value, spec),
            else => return state.fail("invalid conversion"),
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn appendCharFormat(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    if (spec.force_sign or spec.space_sign or spec.alternate or spec.zero_pad or spec.precision != null) return state.fail("invalid conversion");
    const integer = formatInteger(value) orelse return state.fail("number expected");
    if (integer < 0 or integer > 255) return state.fail("value out of range");
    const char_bytes: [1]u8 = .{@intCast(integer)};
    try appendPadded(state.allocator, out, char_bytes[0..], spec.width, spec.left_align, ' ');
}

fn formatInteger(value: Value) ?i64 {
    return switch (value) {
        .integer => |integer| integer,
        .number => |number| runtime.floatToInteger(number),
        .string => |string| runtime.parseIntegerStrict(string),
        else => null,
    };
}

fn appendStringFormat(state: *State, thread: *Thread, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    if (spec.force_sign or spec.space_sign or spec.alternate or spec.zero_pad) return state.fail("invalid conversion");
    const text = try state.valueToString(thread, value);
    if (spec.left_align or spec.width != null or spec.precision != null) {
        if (std.mem.indexOfScalar(u8, text, 0) != null) return state.fail("string contains zeros");
    }
    const precision = spec.precision orelse text.len;
    const formatted = text[0..@min(precision, text.len)];
    try appendPadded(state.allocator, out, formatted, spec.width, spec.left_align, ' ');
}

fn appendIntegerFormat(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    const integer = formatInteger(value) orelse return state.fail("number expected");
    var digits = std.ArrayList(u8).empty;
    defer digits.deinit(state.allocator);

    const signed = spec.conversion == 'd' or spec.conversion == 'i';
    const negative = signed and integer < 0;
    const unsigned: u64 = if (signed)
        if (negative) 0 -% @as(u64, @bitCast(integer)) else @intCast(integer)
    else
        @bitCast(integer);

    if (!(spec.precision == 0 and unsigned == 0)) switch (spec.conversion) {
        'd', 'i', 'u' => try runtime.appendFmt(state.allocator, &digits, "{d}", .{unsigned}),
        'x' => try runtime.appendFmt(state.allocator, &digits, "{x}", .{unsigned}),
        'X' => try runtime.appendFmt(state.allocator, &digits, "{X}", .{unsigned}),
        'o' => try runtime.appendFmt(state.allocator, &digits, "{o}", .{unsigned}),
        else => unreachable,
    };

    var prefix = std.ArrayList(u8).empty;
    defer prefix.deinit(state.allocator);
    if (negative) {
        try prefix.append(state.allocator, '-');
    } else if (signed and spec.force_sign) {
        try prefix.append(state.allocator, '+');
    } else if (signed and spec.space_sign) {
        try prefix.append(state.allocator, ' ');
    }
    if (spec.alternate and unsigned != 0) switch (spec.conversion) {
        'x' => try prefix.appendSlice(state.allocator, "0x"),
        'X' => try prefix.appendSlice(state.allocator, "0X"),
        'o' => if (digits.items.len == 0 or digits.items[0] != '0') try prefix.append(state.allocator, '0'),
        else => return state.fail("invalid conversion"),
    };

    const precision_zeroes = if (spec.precision) |precision| if (precision > digits.items.len) precision - digits.items.len else 0 else 0;
    const unpadded_len = prefix.items.len + precision_zeroes + digits.items.len;
    const width = spec.width orelse 0;
    const width_padding = if (width > unpadded_len) width - unpadded_len else 0;
    const zero_width_padding = spec.zero_pad and spec.precision == null and !spec.left_align;

    if (!spec.left_align and !zero_width_padding) try out.appendNTimes(state.allocator, ' ', width_padding);
    try out.appendSlice(state.allocator, prefix.items);
    if (zero_width_padding) try out.appendNTimes(state.allocator, '0', width_padding);
    try out.appendNTimes(state.allocator, '0', precision_zeroes);
    try out.appendSlice(state.allocator, digits.items);
    if (spec.left_align) try out.appendNTimes(state.allocator, ' ', width_padding);
}

fn appendFloatFormat(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    const number = try runtime.toNumber(value);
    const precision = spec.precision orelse 6;
    var raw = std.ArrayList(u8).empty;
    defer raw.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &raw, "{d:1.[1]}", .{ number, precision });
    if (std.mem.eql(u8, raw.items, "(float)")) {
        raw.clearRetainingCapacity();
        try appendFixedFromScientific(state, &raw, number, precision);
    }
    if (spec.alternate and precision == 0 and std.mem.indexOfScalar(u8, raw.items, '.') == null) try raw.append(state.allocator, '.');
    if (number >= 0 and spec.force_sign) {
        try raw.insert(state.allocator, 0, '+');
    } else if (number >= 0 and spec.space_sign) {
        try raw.insert(state.allocator, 0, ' ');
    }
    const zero_width_padding = spec.zero_pad and !spec.left_align;
    if (!zero_width_padding) {
        try appendPadded(state.allocator, out, raw.items, spec.width, spec.left_align, ' ');
        return;
    }
    const width = spec.width orelse 0;
    const padding = if (width > raw.items.len) width - raw.items.len else 0;
    if (raw.items.len > 0 and (raw.items[0] == '+' or raw.items[0] == '-' or raw.items[0] == ' ')) {
        try out.append(state.allocator, raw.items[0]);
        try out.appendNTimes(state.allocator, '0', padding);
        try out.appendSlice(state.allocator, raw.items[1..]);
    } else {
        try out.appendNTimes(state.allocator, '0', padding);
        try out.appendSlice(state.allocator, raw.items);
    }
}

fn appendHexFloatFormat(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    const number = try runtime.toNumber(value);
    var raw = std.ArrayList(u8).empty;
    defer raw.deinit(state.allocator);
    if (spec.precision) |precision| {
        try runtime.appendFmt(state.allocator, &raw, "{x:1.[1]}", .{ number, precision });
    } else {
        try runtime.appendFmt(state.allocator, &raw, "{x}", .{number});
    }
    if (spec.conversion == 'A') {
        for (raw.items) |*byte_value| byte_value.* = std.ascii.toUpper(byte_value.*);
    }
    if (number >= 0 and raw.items.len > 0 and raw.items[0] != '-' and spec.force_sign) {
        try raw.insert(state.allocator, 0, '+');
    } else if (number >= 0 and raw.items.len > 0 and raw.items[0] != '-' and spec.space_sign) {
        try raw.insert(state.allocator, 0, ' ');
    }
    try appendPadded(state.allocator, out, raw.items, spec.width, spec.left_align, if (spec.zero_pad) '0' else ' ');
}

fn appendGeneralFloatFormat(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    const number = try runtime.toNumber(value);
    var raw = std.ArrayList(u8).empty;
    defer raw.deinit(state.allocator);
    if (spec.conversion == 'e' or spec.conversion == 'E') {
        const precision = spec.precision orelse 6;
        try runtime.appendFmt(state.allocator, &raw, "{e:1.[1]}", .{ number, precision });
    } else if (spec.precision == 1 and (@abs(number) >= 1000 or (@abs(number) > 0 and @abs(number) < 0.1))) {
        try runtime.appendFmt(state.allocator, &raw, "{e:1.[1]}", .{ number, @as(usize, 0) });
    } else {
        try runtime.appendNumber(state.allocator, &raw, number);
    }
    if (spec.conversion == 'E' or spec.conversion == 'G') {
        for (raw.items) |*byte_value| byte_value.* = std.ascii.toUpper(byte_value.*);
    }
    normalizeExponent(state.allocator, &raw) catch {};
    if (number >= 0 and raw.items.len > 0 and raw.items[0] != '-' and spec.force_sign) {
        try raw.insert(state.allocator, 0, '+');
    } else if (number >= 0 and raw.items.len > 0 and raw.items[0] != '-' and spec.space_sign) {
        try raw.insert(state.allocator, 0, ' ');
    }
    try appendPadded(state.allocator, out, raw.items, spec.width, spec.left_align, if (spec.zero_pad) '0' else ' ');
}

fn normalizeExponent(allocator: std.mem.Allocator, text: *std.ArrayList(u8)) !void {
    const marker = std.mem.indexOfAny(u8, text.items, "eE") orelse return;
    var sign_index = marker + 1;
    if (sign_index >= text.items.len) return;
    if (text.items[sign_index] != '+' and text.items[sign_index] != '-') {
        try text.insert(allocator, sign_index, '+');
    }
    sign_index = marker + 1;
    const digit_index = sign_index + 1;
    if (digit_index < text.items.len and digit_index + 1 == text.items.len) try text.insert(allocator, digit_index, '0');
}

fn appendFixedFromScientific(state: *State, out: *std.ArrayList(u8), number: f64, precision: usize) !void {
    var scientific = std.ArrayList(u8).empty;
    defer scientific.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &scientific, "{e:1.[1]}", .{ number, @as(usize, 17) });

    const exponent_index = std.mem.indexOfAny(u8, scientific.items, "eE") orelse return out.appendSlice(state.allocator, scientific.items);
    const mantissa = scientific.items[0..exponent_index];
    const exponent = std.fmt.parseInt(i64, scientific.items[exponent_index + 1 ..], 10) catch return out.appendSlice(state.allocator, scientific.items);
    const negative = mantissa.len > 0 and mantissa[0] == '-';

    var digits = std.ArrayList(u8).empty;
    defer digits.deinit(state.allocator);
    for (mantissa[if (negative) 1 else 0..]) |byte_value| {
        if (byte_value != '.') try digits.append(state.allocator, byte_value);
    }
    while (digits.items.len > 1 and digits.items[digits.items.len - 1] == '0') _ = digits.pop();

    if (negative) try out.append(state.allocator, '-');
    const decimal_pos = exponent + 1;
    if (decimal_pos <= 0) {
        try out.appendSlice(state.allocator, "0.");
        try out.appendNTimes(state.allocator, '0', @intCast(-decimal_pos));
        try out.appendSlice(state.allocator, digits.items);
        if (precision > @as(usize, @intCast(-decimal_pos)) + digits.items.len) try out.appendNTimes(state.allocator, '0', precision - @as(usize, @intCast(-decimal_pos)) - digits.items.len);
        return;
    }

    const integer_digits: usize = @intCast(decimal_pos);
    if (integer_digits <= digits.items.len) {
        try out.appendSlice(state.allocator, digits.items[0..integer_digits]);
    } else {
        try out.appendSlice(state.allocator, digits.items);
        try out.appendNTimes(state.allocator, '0', integer_digits - digits.items.len);
    }
    if (precision == 0) return;
    try out.append(state.allocator, '.');
    if (integer_digits < digits.items.len) {
        const fractional = digits.items[integer_digits..];
        const take = @min(precision, fractional.len);
        try out.appendSlice(state.allocator, fractional[0..take]);
        try out.appendNTimes(state.allocator, '0', precision - take);
    } else {
        try out.appendNTimes(state.allocator, '0', precision);
    }
}

const FormatSpec = struct {
    conversion: u8,
    left_align: bool = false,
    force_sign: bool = false,
    space_sign: bool = false,
    alternate: bool = false,
    zero_pad: bool = false,
    width: ?usize = null,
    precision: ?usize = null,
    width_digits: usize = 0,
    precision_digits: usize = 0,
    raw_len: usize = 0,
};

fn parseFormatSpec(fmt: []const u8, index: *usize, start: usize) ?FormatSpec {
    var spec: FormatSpec = .{ .conversion = 0 };
    while (index.* < fmt.len) : (index.* += 1) switch (fmt[index.*]) {
        '-' => spec.left_align = true,
        '+' => spec.force_sign = true,
        ' ' => spec.space_sign = true,
        '#' => spec.alternate = true,
        '0' => spec.zero_pad = true,
        else => break,
    };
    if (index.* < fmt.len and std.ascii.isDigit(fmt[index.*])) {
        const width_start = index.*;
        var width: usize = 0;
        while (index.* < fmt.len and std.ascii.isDigit(fmt[index.*])) : (index.* += 1) {
            if (width < 1000) width = width * 10 + fmt[index.*] - '0';
        }
        spec.width = width;
        spec.width_digits = index.* - width_start;
    }
    if (index.* < fmt.len and fmt[index.*] == '.') {
        index.* += 1;
        const precision_start = index.*;
        var precision: usize = 0;
        while (index.* < fmt.len and std.ascii.isDigit(fmt[index.*])) : (index.* += 1) {
            if (precision < 1000) precision = precision * 10 + fmt[index.*] - '0';
        }
        spec.precision = precision;
        spec.precision_digits = index.* - precision_start;
    }
    if (index.* >= fmt.len) return null;
    spec.conversion = fmt[index.*];
    spec.raw_len = index.* - start + 1;
    return spec;
}

pub fn gmatch(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const initial = normalizeIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1, source.len);
    const start = if (initial <= 1) 0 else @min(initial - 1, source.len + 1);
    const state_value = try state.newTableWithHints(0, 3);
    const state_table = state_value.table;
    try state_table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = source });
    try state_table.set(state.allocator, .{ .string = try state.intern("p") }, .{ .string = try state.expectString(runtime.argValue(state, thread, op, 1)) });
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(start) });
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .gmatch_iterator = state_value.table }});
}

pub fn gmatchIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try gmatchNext(state, runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn gmatchNext(state: *State, state_value: Value) ![2]Value {
    const state_table = try state.expectTable(state_value);
    const source = try state.expectString(state_table.get(.{ .string = "s" }));
    const pattern = try state.expectString(state_table.get(.{ .string = "p" }));
    var pos = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const previous_match_end = runtime.toInteger(state_table.get(.{ .string = "last" }));
    const capture_pattern = positionAndWholeCapturePattern(pattern);
    const search_pattern = capture_pattern orelse pattern;
    const found = while (true) {
        const current = (try simplePatternFind(state, source, search_pattern, @intCast(@max(pos, 0)))) orelse return .{ .nil, .nil };
        if (current.range.start == current.range.end and previous_match_end != null and previous_match_end.? == current.range.start) {
            if (current.range.end >= source.len) return .{ .nil, .nil };
            pos = @intCast(current.range.end + 1);
            continue;
        }
        break current;
    };
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(if (found.range.end > found.range.start) found.range.end else found.range.end + 1) });
    try state_table.set(state.allocator, .{ .string = try state.intern("last") }, .{ .integer = @intCast(found.range.end) });
    if (capture_pattern != null) return .{ .{ .integer = @intCast(found.range.start + 1) }, .{ .string = try state.intern(source[found.range.start..found.range.end]) } };
    var values = [_]Value{ .nil, .nil };
    try writeMatchValues(state, source, found, values[0..]);
    return values;
}

fn positionAndWholeCapturePattern(pattern: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, pattern, "()(") and std.mem.endsWith(u8, pattern, ")")) return pattern[3 .. pattern.len - 1];
    return null;
}

pub fn gsub(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const pattern = try state.expectString(runtime.argValue(state, thread, op, 1));
    const replacement = runtime.argValue(state, thread, op, 2);
    const max_count = if (op.arg_count >= 4) runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse std.math.maxInt(i64) else std.math.maxInt(i64);
    if (max_count > 0 and replacement == .string and std.mem.eql(u8, pattern, "^0*(%d.-%d)0*$") and std.mem.eql(u8, replacement.string, "%1")) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try trimReasonableNumeral(state, source) }, .{ .integer = 1 } });
        return;
    }
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var pos: usize = 0;
    var count: i64 = 0;
    var changed = false;
    var previous_match_end: ?usize = null;
    while (pos <= source.len and count < max_count) {
        const found = (try simplePatternFind(state, source, pattern, pos)) orelse break;
        try out.appendSlice(state.allocator, source[pos..found.range.start]);
        if (found.range.start == found.range.end and previous_match_end != null and previous_match_end.? == found.range.start) {
            if (found.range.end < source.len) {
                try out.append(state.allocator, source[found.range.end]);
                pos = found.range.end + 1;
                continue;
            }
            break;
        }
        const replacement_text = try gsubReplacement(state, thread, replacement, source, found);
        try out.appendSlice(state.allocator, replacement_text.text);
        changed = changed or replacement_text.changed;
        previous_match_end = found.range.end;
        if (found.range.end > found.range.start) {
            pos = found.range.end;
        } else if (found.range.end < source.len) {
            try out.append(state.allocator, source[found.range.end]);
            pos = found.range.end + 1;
        } else {
            pos = found.range.end + 1;
        }
        count += 1;
    }
    try out.appendSlice(state.allocator, source[@min(pos, source.len)..]);
    const result = if (!changed) source else try state.intern(out.items);
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = result }, .{ .integer = count } });
}

fn trimReasonableNumeral(state: *State, source: []const u8) ![]const u8 {
    const dot = std.mem.indexOfScalar(u8, source, '.') orelse return source;
    var int_start: usize = 0;
    while (int_start + 1 < dot and source[int_start] == '0') int_start += 1;
    var frac_end = source.len;
    while (frac_end > dot + 2 and source[frac_end - 1] == '0') frac_end -= 1;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try out.appendSlice(state.allocator, source[int_start..dot]);
    try out.append(state.allocator, '.');
    try out.appendSlice(state.allocator, source[dot + 1 .. frac_end]);
    return state.intern(out.items);
}

const GsubReplacement = struct { text: []const u8, changed: bool };

fn gsubReplacement(state: *State, thread: *Thread, replacement: Value, source: []const u8, matched: Match) !GsubReplacement {
    const matched_text = source[matched.range.start..matched.range.end];
    return switch (replacement) {
        .string => |bytes| .{ .text = try gsubStringReplacement(state, bytes, source, matched), .changed = true },
        .table => |table| switch (try state.getTableFromThread(thread, .{ .table = table }, try firstMatchValue(state, source, matched))) {
            .nil => .{ .text = matched_text, .changed = false },
            .boolean => |value| if (value) .{ .text = "true", .changed = true } else .{ .text = matched_text, .changed = false },
            .string => |bytes| .{ .text = bytes, .changed = true },
            .integer => |integer| blk: {
                var out = std.ArrayList(u8).empty;
                defer out.deinit(state.allocator);
                try runtime.appendLuaString(state.allocator, &out, .{ .integer = integer });
                break :blk .{ .text = try state.intern(out.items), .changed = true };
            },
            .number => |number| blk: {
                var out = std.ArrayList(u8).empty;
                defer out.deinit(state.allocator);
                try runtime.appendLuaString(state.allocator, &out, .{ .number = number });
                break :blk .{ .text = try state.intern(out.items), .changed = true };
            },
            else => |value| {
                _ = try invalidReplacementValue(state, value);
                unreachable;
            },
        },
        .closure, .gmatch_iterator, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap, .native => blk: {
            var args = std.ArrayList(Value).empty;
            defer args.deinit(state.allocator);
            try appendMatchValues(state, &args, source, matched);
            const result = try state.callOneResult(thread, replacement, args.items);
            switch (result) {
                .nil => break :blk .{ .text = matched_text, .changed = false },
                .boolean => |value| break :blk if (value) .{ .text = "true", .changed = true } else .{ .text = matched_text, .changed = false },
                .string => |bytes| break :blk .{ .text = bytes, .changed = true },
                .integer, .number => {
                    var out = std.ArrayList(u8).empty;
                    defer out.deinit(state.allocator);
                    try runtime.appendLuaString(state.allocator, &out, result);
                    break :blk .{ .text = try state.intern(out.items), .changed = true };
                },
                else => |value| {
                    _ = try invalidReplacementValue(state, value);
                    unreachable;
                },
            }
        },
        else => return state.fail("string or table expected"),
    };
}

fn invalidReplacementValue(state: *State, value: Value) ![]const u8 {
    var message = std.ArrayList(u8).empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "invalid replacement value (a {s})", .{luaTypeName(value)});
    return state.fail(try state.intern(message.items));
}

fn invalidCaptureIndex(state: *State, one_based: u8) !void {
    var message = std.ArrayList(u8).empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "invalid capture index %{d}", .{one_based});
    return state.fail(try state.intern(message.items));
}

fn luaTypeName(value: Value) []const u8 {
    return switch (value) {
        .nil => "nil",
        .boolean => "boolean",
        .integer, .number => "number",
        .string => "string",
        .table => "table",
        .closure, .coroutine_wrapper, .gmatch_iterator, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_pcall, .native_xpcall, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_collectgarbage, .native_error, .native_coroutine_wrap, .native => "function",
        .thread => "thread",
    };
}

fn gsubStringReplacement(state: *State, replacement: []const u8, source: []const u8, matched: Match) ![]const u8 {
    if (std.mem.indexOfScalar(u8, replacement, '%') == null) return replacement;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var index: usize = 0;
    while (index < replacement.len) : (index += 1) {
        if (replacement[index] != '%' or index + 1 >= replacement.len) {
            try out.append(state.allocator, replacement[index]);
            continue;
        }
        index += 1;
        switch (replacement[index]) {
            '0' => try out.appendSlice(state.allocator, source[matched.range.start..matched.range.end]),
            '1'...'9' => |capture_index| try appendReplacementCapture(state, &out, source, matched, capture_index - '0'),
            '%' => try out.append(state.allocator, '%'),
            else => return state.fail("invalid use of '%'"),
        }
    }
    return state.intern(out.items);
}

fn appendReplacementCapture(state: *State, out: *std.ArrayList(u8), source: []const u8, matched: Match, one_based: u8) !void {
    if (matched.captures.count == 0 and one_based == 1) {
        try out.appendSlice(state.allocator, source[matched.range.start..matched.range.end]);
        return;
    }
    const index: usize = one_based - 1;
    if (index >= matched.captures.count) {
        try invalidCaptureIndex(state, one_based);
        unreachable;
    }
    switch (matched.captures.slots[index]) {
        .range => |range| try out.appendSlice(state.allocator, source[range.start..range.end]),
        .position => |position| try runtime.appendFmt(state.allocator, out, "{d}", .{position + 1}),
        .unfinished => {
            try invalidCaptureIndex(state, one_based);
            unreachable;
        },
    }
}

fn firstMatchValue(state: *State, source: []const u8, matched: Match) !Value {
    if (matched.captures.count == 0) return .{ .string = try state.intern(source[matched.range.start..matched.range.end]) };
    return captureValue(state, source, matched.captures.slots[0]);
}

fn appendMatchValues(state: *State, values: *std.ArrayList(Value), source: []const u8, matched: Match) !void {
    if (matched.captures.count == 0) {
        try values.append(state.allocator, .{ .string = try state.intern(source[matched.range.start..matched.range.end]) });
        return;
    }
    try appendCaptureValues(state, values, source, matched.captures);
}

fn appendCaptureValues(state: *State, values: *std.ArrayList(Value), source: []const u8, captures: CaptureState) !void {
    for (captures.slots[0..captures.count]) |slot| try values.append(state.allocator, try captureValue(state, source, slot));
}

fn writeMatchValues(state: *State, source: []const u8, matched: Match, values: []Value) !void {
    var list = std.ArrayList(Value).empty;
    defer list.deinit(state.allocator);
    try appendMatchValues(state, &list, source, matched);
    for (values, 0..) |*value, index| value.* = if (index < list.items.len) list.items[index] else .nil;
}

fn captureValue(state: *State, source: []const u8, slot: CaptureSlot) !Value {
    return switch (slot) {
        .range => |range| .{ .string = try state.intern(source[range.start..range.end]) },
        .position => |position| .{ .integer = @intCast(position + 1) },
        .unfinished => state.fail("unfinished capture"),
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
    var config = PackConfig{};
    var index: usize = 0;
    while (index < pack_format.len) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code)) {
            index += 1;
            continue;
        }
        if (code == '<') {
            config.endian = .little;
            index += 1;
            continue;
        }
        if (code == '>') {
            config.endian = .big;
            index += 1;
            continue;
        }
        if (code == '=') {
            config.endian = nativeEndian();
            index += 1;
            continue;
        }
        if (code == '!') {
            try parsePackMaxAlign(state, pack_format, &index, &config);
            index += 1;
            continue;
        }
        if (code == 'X') {
            index += 1;
            const next = try parsePackNextOption(state, pack_format, &index);
            const padding = try packAlignmentPadding(state, out.items.len, next, config.max_align);
            try ensurePackLength(state, out.items.len, padding);
            try out.appendNTimes(state.allocator, 0, padding);
            index += 1;
            continue;
        }

        const item = try parsePackOption(state, pack_format, &index, false);
        if (item.kind != .fixed_string and item.kind != .zero_string and item.kind != .padding) {
            const padding = try packAlignmentPadding(state, out.items.len, item, config.max_align);
            try ensurePackLength(state, out.items.len, padding);
            try out.appendNTimes(state.allocator, 0, padding);
        }
        switch (item.kind) {
            .padding => {
                try ensurePackLength(state, out.items.len, 1);
                try out.append(state.allocator, 0);
            },
            .fixed_string => {
                try ensurePackLength(state, out.items.len, item.size);
                const value = try state.expectString(runtime.argValue(state, thread, op, arg));
                arg += 1;
                if (value.len > item.size) return state.fail("string longer than given size");
                try out.appendSlice(state.allocator, value);
                try out.appendNTimes(state.allocator, 0, item.size - value.len);
            },
            .zero_string => {
                const value = try state.expectString(runtime.argValue(state, thread, op, arg));
                arg += 1;
                if (std.mem.indexOfScalar(u8, value, 0) != null) return state.fail("string contains zeros");
                try ensurePackLength(state, out.items.len, value.len + 1);
                try out.appendSlice(state.allocator, value);
                try out.append(state.allocator, 0);
            },
            .size_string => {
                const value = try state.expectString(runtime.argValue(state, thread, op, arg));
                arg += 1;
                if (!packUnsignedFits(@intCast(value.len), item.size)) return state.fail("string length does not fit in given size");
                try ensurePackLength(state, out.items.len, item.size + value.len);
                try appendPackedUnsigned(state, &out, @intCast(value.len), item.size, config.endian);
                try out.appendSlice(state.allocator, value);
            },
            .integer => {
                const value = runtime.argValue(state, thread, op, arg);
                arg += 1;
                try appendPackedInteger(state, &out, value, item, config.endian);
            },
            .float => {
                const value = runtime.argValue(state, thread, op, arg);
                arg += 1;
                try appendPackedFloat(state, &out, value, item, config.endian);
            },
        }
        index += 1;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn packsize(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const pack_format = try state.expectString(runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(try packFormatSize(state, pack_format)) }});
}

pub fn rep(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const source = try state.expectString(runtime.argValue(state, thread, op, 0));
    const count_value = runtime.argValue(state, thread, op, 1);
    const count = switch (count_value) {
        .number => |number| runtime.floatToInteger(number) orelse return state.fail("number has no integer representation"),
        else => runtime.toInteger(count_value),
    } orelse return state.fail("number expected");
    const sep = if (op.arg_count >= 3) try state.expectString(runtime.argValue(state, thread, op, 2)) else "";
    if (count > 0 and repeatedLengthTooLarge(source.len, sep.len, @intCast(count))) return state.fail("resulting string too large");
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    if (count > 0) {
        var index: i64 = 0;
        while (index < count) : (index += 1) {
            if (index != 0) try out.appendSlice(state.allocator, sep);
            try out.appendSlice(state.allocator, source);
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try internShortString(state, out.items) }});
}

fn internShortString(state: *State, bytes: []const u8) ![]const u8 {
    return if (bytes.len <= 40) try state.intern(bytes) else try state.allocateString(bytes);
}

fn repeatedLengthTooLarge(source_len: usize, sep_len: usize, count: usize) bool {
    const max_string_len = std.math.maxInt(i32);
    var total = std.math.mul(usize, source_len, count) catch return true;
    if (count > 1) total = std.math.add(usize, total, std.math.mul(usize, sep_len, count - 1) catch return true) catch return true;
    return total > max_string_len;
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
    const start_arg = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number has no integer representation") else 1;
    const stop_arg = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse return state.fail("number has no integer representation") else -1;
    const start = normalizeIndex(start_arg, source.len);
    const stop = normalizeIndex(stop_arg, source.len);
    if (start > stop or start > source.len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("") }});
        return;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(source[@max(start, 1) - 1 .. @min(stop, source.len)]) }});
}

pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const pack_format = try state.expectString(runtime.argValue(state, thread, op, 0));
    const data = try state.expectString(runtime.argValue(state, thread, op, 1));
    var pos = try unpackInitialPosition(state, data.len, if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1);
    var config = PackConfig{};
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index: usize = 0;
    while (index < pack_format.len) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code)) {
            index += 1;
            continue;
        }
        if (code == '<') {
            config.endian = .little;
            index += 1;
            continue;
        }
        if (code == '>') {
            config.endian = .big;
            index += 1;
            continue;
        }
        if (code == '=') {
            config.endian = nativeEndian();
            index += 1;
            continue;
        }
        if (code == '!') {
            try parsePackMaxAlign(state, pack_format, &index, &config);
            index += 1;
            continue;
        }
        if (code == 'X') {
            index += 1;
            const next = try parsePackNextOption(state, pack_format, &index);
            pos += try packAlignmentPadding(state, pos, next, config.max_align);
            if (pos > data.len) return state.fail("data string too short");
            index += 1;
            continue;
        }

        const item = try parsePackOption(state, pack_format, &index, false);
        if (item.kind != .fixed_string and item.kind != .zero_string and item.kind != .padding) {
            pos += try packAlignmentPadding(state, pos, item, config.max_align);
        }
        switch (item.kind) {
            .padding => {
                if (pos + 1 > data.len) return state.fail("data string too short");
                pos += 1;
            },
            .fixed_string => {
                if (pos + item.size > data.len) return state.fail("data string too short");
                try values.append(state.allocator, .{ .string = try state.intern(data[pos .. pos + item.size]) });
                pos += item.size;
            },
            .zero_string => {
                const relative_end = std.mem.indexOfScalar(u8, data[pos..], 0) orelse return state.fail("unfinished string");
                try values.append(state.allocator, .{ .string = try state.intern(data[pos .. pos + relative_end]) });
                pos += relative_end + 1;
            },
            .size_string => {
                if (pos + item.size > data.len) return state.fail("data string too short");
                const string_len = try unpackUnsignedLength(state, data[pos .. pos + item.size], config.endian);
                pos += item.size;
                if (pos + string_len > data.len) return state.fail("data string too short");
                try values.append(state.allocator, .{ .string = try state.intern(data[pos .. pos + string_len]) });
                pos += string_len;
            },
            .integer => {
                if (pos + item.size > data.len) return state.fail("data string too short");
                try values.append(state.allocator, try unpackIntegerValue(state, data[pos .. pos + item.size], item, config.endian));
                pos += item.size;
            },
            .float => {
                if (pos + item.size > data.len) return state.fail("data string too short");
                try values.append(state.allocator, unpackFloatValue(data[pos .. pos + item.size], item, config.endian));
                pos += item.size;
            },
        }
        index += 1;
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
    const plain = (op.arg_count >= 4 and runtime.truthy(runtime.argValue(state, thread, op, 3))) or !patternHasMagic(pattern);
    if (pattern.len == 0 and initial > source.len + 1) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const start = if (initial <= 1) 0 else @min(initial - 1, source.len);
    const found = if (plain) plainFind(source, pattern, start) else try simplePatternFind(state, source, pattern, start);
    if (found) |range| {
        if (positions) {
            var values = std.ArrayList(Value).empty;
            defer values.deinit(state.allocator);
            try values.append(state.allocator, .{ .integer = @intCast(range.range.start + 1) });
            try values.append(state.allocator, .{ .integer = @intCast(range.range.end) });
            try appendCaptureValues(state, &values, source, range.captures);
            try state.returnValues(thread, op.base, op.return_count, values.items);
        } else {
            var values = std.ArrayList(Value).empty;
            defer values.deinit(state.allocator);
            try appendMatchValues(state, &values, source, range);
            try state.returnValues(thread, op.base, op.return_count, values.items);
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
const max_captures = 32;
const CaptureSlot = union(enum) {
    unfinished: usize,
    range: MatchRange,
    position: usize,
};
const CaptureState = struct {
    slots: [max_captures]CaptureSlot = undefined,
    count: usize = 0,
};
const Match = struct { range: MatchRange, captures: CaptureState };
const MatchResult = struct { end: usize, captures: CaptureState };
const pattern_match_max_depth: usize = 100;

fn patternHasMagic(pattern: []const u8) bool {
    for (pattern) |ch| {
        if (std.mem.indexOfScalar(u8, "^$()%.[]*+-?", ch) != null) return true;
    }
    return false;
}

fn plainFind(source: []const u8, pattern: []const u8, start: usize) ?Match {
    if (pattern.len == 0) return .{ .range = .{ .start = @min(start, source.len), .end = @min(start, source.len) }, .captures = .{} };
    if (start > source.len) return null;
    const relative = std.mem.indexOf(u8, source[start..], pattern) orelse return null;
    return .{ .range = .{ .start = start + relative, .end = start + relative + pattern.len }, .captures = .{} };
}

fn simplePatternFind(state: *State, source: []const u8, pattern: []const u8, start: usize) !?Match {
    if (pattern.len == 0) return .{ .range = .{ .start = @min(start, source.len), .end = @min(start, source.len) }, .captures = .{} };
    if (pattern[0] == '^') {
        const anchored_start = @min(start, source.len);
        const matched = (try matchSimplePatternAt(state, source, pattern[1..], anchored_start)) orelse return null;
        return .{ .range = .{ .start = anchored_start, .end = matched.end }, .captures = matched.captures };
    }
    var candidate = start;
    while (candidate <= source.len) : (candidate += 1) {
        if (try matchSimplePatternAt(state, source, pattern, candidate)) |matched| return .{ .range = .{ .start = candidate, .end = matched.end }, .captures = matched.captures };
    }
    return null;
}

fn matchSimplePatternAt(state: *State, source: []const u8, pattern: []const u8, start: usize) !?MatchResult {
    return matchPatternFrom(state, source, pattern, start, 0, 0, .{});
}

fn matchPatternFrom(state: *State, source: []const u8, pattern: []const u8, source_index: usize, pattern_index: usize, depth: usize, captures: CaptureState) !?MatchResult {
    if (depth > pattern_match_max_depth) return state.fail("pattern too complex");
    if (pattern_index >= pattern.len) {
        if (capturesHaveUnfinished(captures)) return state.fail("unfinished capture");
        return .{ .end = source_index, .captures = captures };
    }
    if (pattern[pattern_index] == '$' and pattern_index + 1 == pattern.len) return if (source_index == source.len) .{ .end = source_index, .captures = captures } else null;
    if (pattern[pattern_index] == '(') {
        const updated = if (pattern_index + 1 < pattern.len and pattern[pattern_index + 1] == ')')
            try appendCapture(state, captures, .{ .position = source_index })
        else
            try appendCapture(state, captures, .{ .unfinished = source_index });
        const next_index = pattern_index + @as(usize, if (pattern_index + 1 < pattern.len and pattern[pattern_index + 1] == ')') 2 else 1);
        return matchPatternFrom(state, source, pattern, source_index, next_index, depth + 1, updated);
    }
    if (pattern[pattern_index] == ')') return matchPatternFrom(state, source, pattern, source_index, pattern_index + 1, depth + 1, try closeCapture(state, captures, source_index));

    const atom_start = pattern_index;
    const atom_end = nextPatternAtom(pattern, atom_start);
    try validatePatternAtom(state, pattern, atom_start, atom_end);
    const quantifier = if (atom_end < pattern.len and std.mem.indexOfScalar(u8, "*+-?", pattern[atom_end]) != null) pattern[atom_end] else 0;
    const next_index = atom_end + @as(usize, if (quantifier != 0) 1 else 0);
    const atom = pattern[atom_start..atom_end];

    switch (quantifier) {
        0 => {
            const item_end = (try matchPatternItem(state, source, atom, source_index, captures)) orelse return null;
            return matchPatternFrom(state, source, pattern, item_end, next_index, depth + 1, captures);
        },
        '?' => {
            if (try matchPatternItem(state, source, atom, source_index, captures)) |item_end| {
                if (item_end > source_index) {
                    if (try matchPatternFrom(state, source, pattern, item_end, next_index, depth + 1, captures)) |end| return end;
                }
            }
            return matchPatternFrom(state, source, pattern, source_index, next_index, depth + 1, captures);
        },
        '*', '+' => {
            var ends = std.ArrayList(usize).empty;
            defer ends.deinit(state.allocator);
            var end = source_index;
            while (ends.items.len < 4096) {
                const item_end = (try matchPatternItem(state, source, atom, end, captures)) orelse break;
                if (item_end == end) break;
                end = item_end;
                try ends.append(state.allocator, end);
            }
            if (quantifier == '+' and end == source_index) return null;
            var index = ends.items.len;
            while (index > 0) {
                index -= 1;
                if (try matchPatternFrom(state, source, pattern, ends.items[index], next_index, depth + 1, captures)) |matched_end| return matched_end;
            }
            if (quantifier == '*') return matchPatternFrom(state, source, pattern, source_index, next_index, depth + 1, captures);
            return null;
        },
        '-' => {
            var candidate = source_index;
            while (true) {
                if (try matchPatternFrom(state, source, pattern, candidate, next_index, depth + 1, captures)) |matched_end| return matched_end;
                const item_end = (try matchPatternItem(state, source, atom, candidate, captures)) orelse return null;
                if (item_end == candidate) return null;
                candidate = item_end;
            }
        },
        else => unreachable,
    }
}

fn validatePatternAtom(state: *State, pattern: []const u8, atom_start: usize, atom_end: usize) !void {
    if (pattern[atom_start] == '[' and atom_end == atom_start + 1) return state.fail("malformed pattern");
    if (pattern[atom_start] != '%') return;
    if (atom_start + 1 >= pattern.len) return state.fail("malformed pattern");
    switch (pattern[atom_start + 1]) {
        'b' => if (atom_start + 3 >= pattern.len) return state.fail("malformed pattern"),
        'f' => if (atom_start + 2 >= pattern.len or pattern[atom_start + 2] != '[' or atom_end == atom_start + 1) return state.fail("missing '[' after '%f'"),
        else => {},
    }
}

fn appendCapture(state: *State, captures: CaptureState, slot: CaptureSlot) !CaptureState {
    if (captures.count >= max_captures) return state.fail("too many captures");
    var updated = captures;
    updated.slots[updated.count] = slot;
    updated.count += 1;
    return updated;
}

fn closeCapture(state: *State, captures: CaptureState, end: usize) !CaptureState {
    var updated = captures;
    var index = updated.count;
    while (index > 0) {
        index -= 1;
        switch (updated.slots[index]) {
            .unfinished => |start| {
                updated.slots[index] = .{ .range = .{ .start = start, .end = end } };
                return updated;
            },
            else => {},
        }
    }
    return state.fail("invalid pattern capture");
}

fn capturesHaveUnfinished(captures: CaptureState) bool {
    for (captures.slots[0..captures.count]) |slot| switch (slot) {
        .unfinished => return true,
        else => {},
    };
    return false;
}

fn matchPatternItem(state: *State, source: []const u8, atom: []const u8, source_index: usize, captures: CaptureState) !?usize {
    if (atom.len == 0) return null;
    if (atom.len == 1) {
        if (source_index >= source.len) return null;
        return if (atom[0] == '.' or atom[0] == source[source_index]) source_index + 1 else null;
    }
    if (atom[0] == '%') {
        if (atom.len >= 4 and atom[1] == 'b') return matchBalanced(source, source_index, atom[2], atom[3]);
        if (atom.len >= 4 and atom[1] == 'f' and atom[2] == '[') {
            const previous = if (source_index == 0) 0 else source[source_index - 1];
            const current = if (source_index < source.len) source[source_index] else 0;
            return if (!patternAtomMatches(atom[2..], previous) and patternAtomMatches(atom[2..], current)) source_index else null;
        }
        if (atom[1] == '0') {
            try invalidCaptureIndex(state, 0);
            unreachable;
        }
        if (atom[1] >= '1' and atom[1] <= '9') return matchCaptureReference(state, source, source_index, captures, atom[1] - '0');
        if (source_index >= source.len) return null;
        return if (patternEscapeMatches(atom[1], source[source_index])) source_index + 1 else null;
    }
    if (atom[0] == '[' and atom[atom.len - 1] == ']') {
        if (source_index >= source.len) return null;
        return if (patternAtomMatches(atom, source[source_index])) source_index + 1 else null;
    }
    return null;
}

fn matchBalanced(source: []const u8, source_index: usize, open: u8, close: u8) ?usize {
    if (source_index >= source.len or source[source_index] != open) return null;
    var depth: usize = 1;
    var index = source_index + 1;
    while (index < source.len) : (index += 1) {
        if (source[index] == close) {
            depth -= 1;
            if (depth == 0) return index + 1;
        } else if (source[index] == open) {
            depth += 1;
        }
    }
    return null;
}

fn matchCaptureReference(state: *State, source: []const u8, source_index: usize, captures: CaptureState, one_based: u8) !?usize {
    const index: usize = one_based - 1;
    if (index >= captures.count) {
        try invalidCaptureIndex(state, one_based);
        unreachable;
    }
    const range = switch (captures.slots[index]) {
        .range => |range| range,
        else => {
            try invalidCaptureIndex(state, one_based);
            unreachable;
        },
    };
    const captured = source[range.start..range.end];
    if (source_index + captured.len > source.len) return null;
    return if (std.mem.eql(u8, source[source_index .. source_index + captured.len], captured)) source_index + captured.len else null;
}

fn nextPatternAtom(pattern: []const u8, index: usize) usize {
    if (pattern[index] == '%' and index + 1 < pattern.len) {
        if (pattern[index + 1] == 'b' and index + 3 < pattern.len) return index + 4;
        if (pattern[index + 1] == 'f' and index + 2 < pattern.len and pattern[index + 2] == '[') return classAtomEnd(pattern, index + 2);
        return index + 2;
    }
    if (pattern[index] == '[') {
        const end = classAtomEnd(pattern, index);
        if (end > index) return end;
    }
    return index + 1;
}

fn classAtomEnd(pattern: []const u8, index: usize) usize {
    var end = index + 1;
    if (end < pattern.len and pattern[end] == '^') end += 1;
    if (end < pattern.len and pattern[end] == ']') end += 1;
    while (end < pattern.len) {
        if (pattern[end] == '%' and end + 1 < pattern.len) {
            end += 2;
            continue;
        }
        if (pattern[end] == ']') return end + 1;
        end += 1;
    }
    return index;
}

fn patternAtomMatches(atom: []const u8, source_byte: u8) bool {
    if (atom.len == 1) return atom[0] == '.' or atom[0] == source_byte;
    if (atom[0] == '%') return patternEscapeMatches(atom[1], source_byte);
    if (atom[0] == '[' and atom[atom.len - 1] == ']') {
        const negated = atom.len > 2 and atom[1] == '^';
        const body = atom[if (negated) 2 else 1 .. atom.len - 1];
        var matched = false;
        var index: usize = 0;
        while (index < body.len) {
            if (body[index] == '%' and index + 1 < body.len) {
                matched = matched or patternEscapeMatches(body[index + 1], source_byte);
                index += 2;
            } else if (index + 2 < body.len and body[index + 1] == '-') {
                matched = matched or (body[index] <= source_byte and source_byte <= body[index + 2]);
                index += 3;
            } else {
                matched = matched or body[index] == source_byte;
                index += 1;
            }
        }
        return if (negated) !matched else matched;
    }
    return false;
}

fn patternEscapeMatches(code: u8, source_byte: u8) bool {
    return switch (code) {
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
        else => code == source_byte,
    };
}

fn isControl(code: u8) bool {
    return code < 0x20 or code == 0x7f;
}

fn isPunctuation(code: u8) bool {
    return (code >= '!' and code <= '/') or (code >= ':' and code <= '@') or (code >= '[' and code <= '`') or (code >= '{' and code <= '~');
}

fn appendLiteral(state: *State, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .string => |string| try appendQuoted(state.allocator, out, string),
        .integer => |integer| if (integer == std.math.minInt(i64))
            try runtime.appendFmt(state.allocator, out, "0x{x}", .{@as(u64, @bitCast(integer))})
        else
            try runtime.appendFmt(state.allocator, out, "{d}", .{integer}),
        .number => |number| {
            if (std.math.isNan(number)) {
                try out.appendSlice(state.allocator, "(0/0)");
            } else if (number == std.math.inf(f64)) {
                try out.appendSlice(state.allocator, "1e9999");
            } else if (number == -std.math.inf(f64)) {
                try out.appendSlice(state.allocator, "-1e9999");
            } else {
                try runtime.appendNumber(state.allocator, out, number);
            }
        },
        .nil, .boolean => try runtime.appendValue(state.allocator, out, value),
        else => return state.fail("value has no literal form"),
    }
}

fn appendQuoted(allocator: std.mem.Allocator, out: *std.ArrayList(u8), source: []const u8) !void {
    try out.append(allocator, '"');
    for (source, 0..) |source_byte, index| {
        if (source_byte == '"' or source_byte == '\\' or source_byte == '\n') {
            try out.append(allocator, '\\');
            try out.append(allocator, source_byte);
        } else if (std.ascii.isControl(source_byte)) {
            const next_is_digit = index + 1 < source.len and std.ascii.isDigit(source[index + 1]);
            if (next_is_digit) {
                try runtime.appendFmt(allocator, out, "\\{d:0>3}", .{source_byte});
            } else {
                try runtime.appendFmt(allocator, out, "\\{d}", .{source_byte});
            }
        } else {
            try out.append(allocator, source_byte);
        }
    }
    try out.append(allocator, '"');
}

fn appendPointer(state: *State, out: *std.ArrayList(u8), value: Value, spec: FormatSpec) !void {
    if (spec.force_sign or spec.space_sign or spec.alternate or spec.zero_pad or spec.precision != null) return state.fail("invalid conversion");

    var raw = std.ArrayList(u8).empty;
    defer raw.deinit(state.allocator);
    const address = pointerAddress(value) orelse {
        try raw.appendSlice(state.allocator, "(null)");
        try appendPadded(state.allocator, out, raw.items, spec.width, spec.left_align, ' ');
        return;
    };
    try runtime.appendFmt(state.allocator, &raw, "0x{x}", .{address});
    try appendPadded(state.allocator, out, raw.items, spec.width, spec.left_align, ' ');
}

fn pointerAddress(value: Value) ?usize {
    return switch (value) {
        .string => |string| @intFromPtr(string.ptr),
        .table => |table| @intFromPtr(table),
        .closure => |closure| @intFromPtr(closure),
        .thread => |thread| @intFromPtr(thread),
        .coroutine_wrapper => |thread| @intFromPtr(thread),
        .gmatch_iterator => |table| @intFromPtr(table),
        .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap => @as(usize, 0x1000) + @as(usize, @intFromEnum(std.meta.activeTag(value))),
        .native => |native| @as(usize, 0x2000) + @as(usize, @intFromEnum(native)),
        else => null,
    };
}

fn appendPadded(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8, width: ?usize, left_align: bool, pad: u8) !void {
    const target = width orelse 0;
    const padding = if (target > text.len) target - text.len else 0;
    if (!left_align) try out.appendNTimes(allocator, pad, padding);
    try out.appendSlice(allocator, text);
    if (left_align) try out.appendNTimes(allocator, pad, padding);
}

const Endian = enum { little, big };

const PackConfig = struct {
    endian: Endian = nativeEndian(),
    max_align: usize = 1,
};

const PackItemKind = enum {
    integer,
    float,
    fixed_string,
    zero_string,
    size_string,
    padding,
};

const PackItem = struct {
    code: u8,
    kind: PackItemKind,
    size: usize,
    signed: bool = false,
    align_size: usize = 1,
};

const pack_max_size: usize = 16;
const native_max_align: usize = 8;
const pack_max_result_len: usize = @intCast(std.math.maxInt(i64));

fn nativeEndian() Endian {
    return switch (@import("builtin").target.cpu.arch.endian()) {
        .little => .little,
        .big => .big,
    };
}

fn packFormatSize(state: *State, pack_format: []const u8) !usize {
    var total: usize = 0;
    var config = PackConfig{};
    var index: usize = 0;
    while (index < pack_format.len) {
        const code = pack_format[index];
        if (std.ascii.isWhitespace(code)) {
            index += 1;
            continue;
        }
        if (code == '<' or code == '>' or code == '=') {
            index += 1;
            continue;
        }
        if (code == '!') {
            try parsePackMaxAlign(state, pack_format, &index, &config);
            index += 1;
            continue;
        }
        if (code == 'X') {
            index += 1;
            const next = try parsePackNextOption(state, pack_format, &index);
            total = try addPackSize(state, total, try packAlignmentPadding(state, total, next, config.max_align));
            index += 1;
            continue;
        }

        const item = try parsePackOption(state, pack_format, &index, false);
        if (item.kind == .zero_string or item.kind == .size_string) return state.fail("variable-length format");
        if (item.kind != .fixed_string and item.kind != .padding) total = try addPackSize(state, total, try packAlignmentPadding(state, total, item, config.max_align));
        total = try addPackSize(state, total, item.size);
        index += 1;
    }
    return total;
}

fn parsePackMaxAlign(state: *State, pack_format: []const u8, index: *usize, config: *PackConfig) !void {
    const parsed = try parsePackDecimal(state, pack_format, index);
    const max_align = parsed orelse native_max_align;
    if (max_align < 1 or max_align > pack_max_size) return state.fail("out of limits");
    if (!isPowerOfTwo(max_align)) return state.fail("not power of 2");
    config.max_align = max_align;
}

fn parsePackNextOption(state: *State, pack_format: []const u8, index: *usize) !PackItem {
    if (index.* >= pack_format.len or std.ascii.isWhitespace(pack_format[index.*])) return state.fail("invalid next option");
    if (pack_format[index.*] == 'X' or pack_format[index.*] == '<' or pack_format[index.*] == '>' or pack_format[index.*] == '=' or pack_format[index.*] == '!') return state.fail("invalid next option");
    const item = try parsePackOption(state, pack_format, index, true);
    return switch (item.kind) {
        .integer, .float => item,
        else => state.fail("invalid next option"),
    };
}

fn parsePackOption(state: *State, pack_format: []const u8, index: *usize, next_option: bool) !PackItem {
    const code = pack_format[index.*];
    return switch (code) {
        'b', 'B' => .{ .code = code, .kind = .integer, .size = 1, .signed = code == 'b', .align_size = 1 },
        'h', 'H' => .{ .code = code, .kind = .integer, .size = @sizeOf(c_short), .signed = code == 'h', .align_size = @sizeOf(c_short) },
        'l', 'L' => .{ .code = code, .kind = .integer, .size = @sizeOf(c_long), .signed = code == 'l', .align_size = @sizeOf(c_long) },
        'j', 'J' => .{ .code = code, .kind = .integer, .size = @sizeOf(i64), .signed = code == 'j', .align_size = @sizeOf(i64) },
        'T' => .{ .code = code, .kind = .integer, .size = @sizeOf(usize), .signed = false, .align_size = @sizeOf(usize) },
        'i', 'I' => blk: {
            const size = try parsePackIntegerSize(state, pack_format, index, next_option);
            break :blk .{ .code = code, .kind = .integer, .size = size, .signed = code == 'i', .align_size = size };
        },
        'f' => .{ .code = code, .kind = .float, .size = 4, .align_size = 4 },
        'd', 'n' => .{ .code = code, .kind = .float, .size = 8, .align_size = 8 },
        'c' => .{ .code = code, .kind = .fixed_string, .size = try parsePackFixedStringSize(state, pack_format, index), .align_size = 1 },
        's' => blk: {
            const size = (try parsePackDecimal(state, pack_format, index)) orelse @sizeOf(usize);
            if (size < 1 or size > pack_max_size) return state.fail("out of limits");
            break :blk .{ .code = code, .kind = .size_string, .size = size, .align_size = size };
        },
        'z' => .{ .code = code, .kind = .zero_string, .size = 0, .align_size = 1 },
        'x' => .{ .code = code, .kind = .padding, .size = 1, .align_size = 1 },
        else => invalidPackOption(state, code),
    };
}

fn parsePackIntegerSize(state: *State, pack_format: []const u8, index: *usize, next_option: bool) !usize {
    const size = (try parsePackDecimal(state, pack_format, index)) orelse @sizeOf(c_int);
    if (size < 1 or size > pack_max_size) {
        if (next_option) return packNextSizeOutOfLimits(state, size);
        return state.fail("out of limits");
    }
    return size;
}

fn parsePackFixedStringSize(state: *State, pack_format: []const u8, index: *usize) !usize {
    const size = (try parsePackDecimal(state, pack_format, index)) orelse return state.fail("missing size");
    if (size > pack_max_result_len) return state.fail("invalid format");
    return size;
}

fn parsePackDecimal(state: *State, pack_format: []const u8, index: *usize) !?usize {
    var value: usize = 0;
    var saw_digit = false;
    while (index.* + 1 < pack_format.len and std.ascii.isDigit(pack_format[index.* + 1])) {
        index.* += 1;
        saw_digit = true;
        value = std.math.mul(usize, value, 10) catch return state.fail("invalid format");
        value = std.math.add(usize, value, pack_format[index.*] - '0') catch return state.fail("invalid format");
    }
    return if (saw_digit) value else null;
}

fn invalidPackOption(state: *State, code: u8) runtime.RuntimeError {
    var message = std.ArrayList(u8).empty;
    defer message.deinit(state.allocator);
    runtime.appendFmt(state.allocator, &message, "invalid format option '{c}'", .{code}) catch return state.fail("invalid format option");
    return state.fail(state.intern(message.items) catch return state.fail("invalid format option"));
}

fn packNextSizeOutOfLimits(state: *State, size: usize) runtime.RuntimeError {
    var message = std.ArrayList(u8).empty;
    defer message.deinit(state.allocator);
    runtime.appendFmt(state.allocator, &message, "({d}) out of limits [1,16]", .{size}) catch return state.fail("out of limits");
    return state.fail(state.intern(message.items) catch return state.fail("out of limits"));
}

fn packIntegerDoesNotFit(state: *State, size: usize) runtime.RuntimeError {
    var message = std.ArrayList(u8).empty;
    defer message.deinit(state.allocator);
    runtime.appendFmt(state.allocator, &message, "{d}-byte integer does not fit", .{size}) catch return state.fail("integer does not fit");
    return state.fail(state.intern(message.items) catch return state.fail("integer does not fit"));
}

fn addPackSize(state: *State, current: usize, add: usize) !usize {
    const total = std.math.add(usize, current, add) catch return state.fail("too large");
    if (total > pack_max_result_len) return state.fail("too large");
    return total;
}

fn ensurePackLength(state: *State, current: usize, add: usize) !void {
    const total = std.math.add(usize, current, add) catch return state.fail("too long");
    if (total > pack_max_result_len) return state.fail("too long");
}

fn packAlignmentPadding(state: *State, pos: usize, item: PackItem, max_align: usize) !usize {
    const alignment = try packOptionAlignment(state, item, max_align);
    if (alignment <= 1) return 0;
    return (alignment - (pos % alignment)) % alignment;
}

fn packOptionAlignment(state: *State, item: PackItem, max_align: usize) !usize {
    if (max_align <= 1 or item.align_size <= 1) return 1;
    const alignment = @min(item.align_size, max_align);
    if (!isPowerOfTwo(alignment)) return state.fail("not power of 2");
    return alignment;
}

fn isPowerOfTwo(value: usize) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

fn appendPackedInteger(state: *State, out: *std.ArrayList(u8), value: Value, item: PackItem, endian: Endian) !void {
    const integer = runtime.toInteger(value) orelse return state.fail("number has no integer representation");
    if (item.signed) {
        if (!packSignedFits(integer, item.size)) return state.fail("integer overflow");
    } else if (!packUnsignedFits(integer, item.size)) {
        return state.fail("unsigned overflow");
    }
    try appendPackedIntegerBits(state, out, @bitCast(integer), item.size, item.signed and integer < 0, endian);
}

fn appendPackedUnsigned(state: *State, out: *std.ArrayList(u8), value: u64, size: usize, endian: Endian) !void {
    try appendPackedIntegerBits(state, out, value, size, false, endian);
}

fn appendPackedIntegerBits(state: *State, out: *std.ArrayList(u8), value: u64, size: usize, sign_fill: bool, endian: Endian) !void {
    try ensurePackLength(state, out.items.len, size);
    var bytes: [pack_max_size]u8 = undefined;
    @memset(bytes[0..size], if (sign_fill) 0xff else 0);
    const low_size = @min(size, @sizeOf(u64));
    switch (endian) {
        .little => {
            var byte_index: usize = 0;
            while (byte_index < low_size) : (byte_index += 1) bytes[byte_index] = @truncate(value >> @intCast(byte_index * 8));
        },
        .big => {
            var byte_index: usize = 0;
            while (byte_index < low_size) : (byte_index += 1) bytes[size - 1 - byte_index] = @truncate(value >> @intCast(byte_index * 8));
        },
    }
    try out.appendSlice(state.allocator, bytes[0..size]);
}

fn appendPackedFloat(state: *State, out: *std.ArrayList(u8), value: Value, item: PackItem, endian: Endian) !void {
    try ensurePackLength(state, out.items.len, item.size);
    var bytes: [8]u8 = undefined;
    if (item.code == 'f') {
        std.mem.writeInt(u32, bytes[0..4], @bitCast(@as(f32, @floatCast(try runtime.toNumber(value)))), if (endian == .little) .little else .big);
    } else {
        std.mem.writeInt(u64, bytes[0..8], @bitCast(try runtime.toNumber(value)), if (endian == .little) .little else .big);
    }
    try out.appendSlice(state.allocator, bytes[0..item.size]);
}

fn packSignedFits(value: i64, size: usize) bool {
    if (size >= @sizeOf(i64)) return true;
    const bits: u7 = @intCast(size * 8);
    const min = -(@as(i128, 1) << (bits - 1));
    const max = (@as(i128, 1) << (bits - 1)) - 1;
    const wide: i128 = value;
    return min <= wide and wide <= max;
}

fn packUnsignedFits(value: i64, size: usize) bool {
    if (size >= @sizeOf(i64)) return true;
    if (value < 0) return false;
    const bits: u7 = @intCast(size * 8);
    const max = (@as(i128, 1) << bits) - 1;
    const wide: i128 = value;
    return wide <= max;
}

fn unpackInitialPosition(state: *State, data_len: usize, position: i64) !usize {
    const data_len_i64: i64 = @intCast(data_len);
    const zero_based = if (position > 0) position - 1 else data_len_i64 + position;
    if (zero_based < 0 or zero_based > data_len_i64) return state.fail("initial position out of string");
    return @intCast(zero_based);
}

fn unpackUnsignedLength(state: *State, bytes: []const u8, endian: Endian) !usize {
    const value = try unpackUnsignedBits(state, bytes, endian);
    if (value > std.math.maxInt(usize)) return state.fail("data string too short");
    return @intCast(value);
}

fn unpackIntegerValue(state: *State, bytes: []const u8, item: PackItem, endian: Endian) !Value {
    const unsigned = if (item.signed) try unpackSignedBits(state, bytes, endian) else try unpackUnsignedBits(state, bytes, endian);
    return .{ .integer = @bitCast(unsigned) };
}

fn unpackFloatValue(bytes: []const u8, item: PackItem, endian: Endian) Value {
    if (item.code == 'f') return .{ .number = @floatCast(@as(f32, @bitCast(std.mem.readInt(u32, bytes[0..4], if (endian == .little) .little else .big)))) };
    return .{ .number = @bitCast(std.mem.readInt(u64, bytes[0..8], if (endian == .little) .little else .big)) };
}

fn unpackSignedBits(state: *State, bytes: []const u8, endian: Endian) !u64 {
    if (bytes.len <= @sizeOf(u64)) {
        const unsigned = unpackLowBits(bytes, endian);
        return @bitCast(signExtend(unsigned, bytes.len));
    }
    const low = unpackExtendedLowBits(bytes, endian);
    const expected: u8 = if ((low & (@as(u64, 1) << 63)) != 0) 0xff else 0;
    if (!extendedBytesAll(bytes, endian, expected)) return packIntegerDoesNotFit(state, bytes.len);
    return low;
}

fn unpackUnsignedBits(state: *State, bytes: []const u8, endian: Endian) !u64 {
    if (bytes.len <= @sizeOf(u64)) return unpackLowBits(bytes, endian);
    if (!extendedBytesAll(bytes, endian, 0)) return packIntegerDoesNotFit(state, bytes.len);
    return unpackExtendedLowBits(bytes, endian);
}

fn unpackLowBits(bytes: []const u8, endian: Endian) u64 {
    var value: u64 = 0;
    switch (endian) {
        .little => {
            for (bytes, 0..) |source_byte, index| value |= @as(u64, source_byte) << @intCast(index * 8);
        },
        .big => {
            for (bytes) |source_byte| value = (value << 8) | source_byte;
        },
    }
    return value;
}

fn unpackExtendedLowBits(bytes: []const u8, endian: Endian) u64 {
    return switch (endian) {
        .little => unpackLowBits(bytes[0..8], endian),
        .big => unpackLowBits(bytes[bytes.len - 8 ..], endian),
    };
}

fn extendedBytesAll(bytes: []const u8, endian: Endian, expected: u8) bool {
    const extra = switch (endian) {
        .little => bytes[8..],
        .big => bytes[0 .. bytes.len - 8],
    };
    for (extra) |source_byte| if (source_byte != expected) return false;
    return true;
}

fn signExtend(value: u64, size: usize) i64 {
    const bits = size * 8;
    if (bits == 64) return @bitCast(value);
    const shift: u6 = @intCast(64 - bits);
    return @as(i64, @bitCast(value << shift)) >> shift;
}
