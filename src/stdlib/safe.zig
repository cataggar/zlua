const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub const NativeFn = enum {
    type,
    tonumber,
    warn,
    table_concat,
    table_insert,
    table_move,
    table_pack,
    table_remove,
    table_sort,
    table_unpack,
    string_byte,
    string_char,
    string_dump,
    string_find,
    string_format,
    string_gmatch,
    string_gmatch_iter,
    string_gsub,
    string_len,
    string_lower,
    string_match,
    string_pack,
    string_packsize,
    string_rep,
    string_reverse,
    string_sub,
    string_unpack,
    string_upper,
    math_abs,
    math_acos,
    math_asin,
    math_atan,
    math_ceil,
    math_cos,
    math_deg,
    math_exp,
    math_floor,
    math_fmod,
    math_log,
    math_max,
    math_min,
    math_modf,
    math_rad,
    math_random,
    math_randomseed,
    math_sin,
    math_sqrt,
    math_tan,
    math_tointeger,
    math_type,
    math_ult,
    utf8_char,
    utf8_codepoint,
    utf8_codes,
    utf8_codes_iter,
    utf8_len,
    utf8_offset,

    pub fn name(self: NativeFn) []const u8 {
        return switch (self) {
            .type => "type",
            .tonumber => "tonumber",
            .warn => "warn",
            .table_concat => "table.concat",
            .table_insert => "table.insert",
            .table_move => "table.move",
            .table_pack => "table.pack",
            .table_remove => "table.remove",
            .table_sort => "table.sort",
            .table_unpack => "table.unpack",
            .string_byte => "string.byte",
            .string_char => "string.char",
            .string_dump => "string.dump",
            .string_find => "string.find",
            .string_format => "string.format",
            .string_gmatch => "string.gmatch",
            .string_gmatch_iter => "string.gmatch iterator",
            .string_gsub => "string.gsub",
            .string_len => "string.len",
            .string_lower => "string.lower",
            .string_match => "string.match",
            .string_pack => "string.pack",
            .string_packsize => "string.packsize",
            .string_rep => "string.rep",
            .string_reverse => "string.reverse",
            .string_sub => "string.sub",
            .string_unpack => "string.unpack",
            .string_upper => "string.upper",
            .math_abs => "math.abs",
            .math_acos => "math.acos",
            .math_asin => "math.asin",
            .math_atan => "math.atan",
            .math_ceil => "math.ceil",
            .math_cos => "math.cos",
            .math_deg => "math.deg",
            .math_exp => "math.exp",
            .math_floor => "math.floor",
            .math_fmod => "math.fmod",
            .math_log => "math.log",
            .math_max => "math.max",
            .math_min => "math.min",
            .math_modf => "math.modf",
            .math_rad => "math.rad",
            .math_random => "math.random",
            .math_randomseed => "math.randomseed",
            .math_sin => "math.sin",
            .math_sqrt => "math.sqrt",
            .math_tan => "math.tan",
            .math_tointeger => "math.tointeger",
            .math_type => "math.type",
            .math_ult => "math.ult",
            .utf8_char => "utf8.char",
            .utf8_codepoint => "utf8.codepoint",
            .utf8_codes => "utf8.codes",
            .utf8_codes_iter => "utf8.codes iterator",
            .utf8_len => "utf8.len",
            .utf8_offset => "utf8.offset",
        };
    }
};

const MathUnaryFn = enum { acos, asin, cos, exp, sin, sqrt, tan };
const MathIntegerUnaryFn = enum { ceil, floor };

pub fn callNative(state: *State, native: NativeFn, thread: *Thread, op: bytecode.Call) !void {
    switch (native) {
        .type => try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(typeName(runtime.argValue(state, thread, op, 0))) }}),
        .tonumber => try tonumberValue(state, thread, op),
        .warn => try warnValue(state, thread, op),
        .table_concat => try tableConcat(state, thread, op),
        .table_insert => try tableInsert(state, thread, op),
        .table_move => try tableMove(state, thread, op),
        .table_pack => try tablePack(state, thread, op),
        .table_remove => try tableRemove(state, thread, op),
        .table_sort => try tableSort(state, thread, op),
        .table_unpack => try tableUnpack(state, thread, op),
        .string_byte => try stringByte(state, thread, op),
        .string_char => try stringChar(state, thread, op),
        .string_dump => return state.fail("unable to dump given function"),
        .string_find => try stringFind(state, thread, op, true),
        .string_format => try stringFormat(state, thread, op),
        .string_gmatch => try stringGmatch(state, thread, op),
        .string_gmatch_iter => try stringGmatchIter(state, thread, op),
        .string_gsub => try stringGsub(state, thread, op),
        .string_len => try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast((try state.expectString(runtime.argValue(state, thread, op, 0))).len) }}),
        .string_lower => try stringAsciiMap(state, thread, op, true),
        .string_match => try stringFind(state, thread, op, false),
        .string_pack => try stringPack(state, thread, op),
        .string_packsize => try stringPacksize(state, thread, op),
        .string_rep => try stringRep(state, thread, op),
        .string_reverse => try stringReverse(state, thread, op),
        .string_sub => try stringSub(state, thread, op),
        .string_unpack => try stringUnpack(state, thread, op),
        .string_upper => try stringAsciiMap(state, thread, op, false),
        .math_abs => try mathAbs(state, thread, op),
        .math_acos => try mathUnary(state, thread, op, .acos),
        .math_asin => try mathUnary(state, thread, op, .asin),
        .math_atan => try mathAtan(state, thread, op),
        .math_ceil => try mathIntegerUnary(state, thread, op, .ceil),
        .math_cos => try mathUnary(state, thread, op, .cos),
        .math_deg => try mathUnaryScale(state, thread, op, 180.0 / std.math.pi),
        .math_exp => try mathUnary(state, thread, op, .exp),
        .math_floor => try mathIntegerUnary(state, thread, op, .floor),
        .math_fmod => try mathFmod(state, thread, op),
        .math_log => try mathLog(state, thread, op),
        .math_max => try mathMinMax(state, thread, op, false),
        .math_min => try mathMinMax(state, thread, op, true),
        .math_modf => try mathModf(state, thread, op),
        .math_rad => try mathUnaryScale(state, thread, op, std.math.pi / 180.0),
        .math_random => try mathRandom(state, thread, op),
        .math_randomseed => try mathRandomseed(state, thread, op),
        .math_sin => try mathUnary(state, thread, op, .sin),
        .math_sqrt => try mathUnary(state, thread, op, .sqrt),
        .math_tan => try mathUnary(state, thread, op, .tan),
        .math_tointeger => try mathTointeger(state, thread, op),
        .math_type => try mathType(state, thread, op),
        .math_ult => try mathUlt(state, thread, op),
        .utf8_char => try utf8Char(state, thread, op),
        .utf8_codepoint => try utf8Codepoint(state, thread, op),
        .utf8_codes => try utf8Codes(state, thread, op),
        .utf8_codes_iter => try utf8CodesIter(state, thread, op),
        .utf8_len => try utf8Len(state, thread, op),
        .utf8_offset => try utf8Offset(state, thread, op),
    }
}

fn tonumberValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
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

fn warnValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn tableConcat(state: *State, thread: *Thread, op: bytecode.Call) !void {
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

fn tableInsert(state: *State, thread: *Thread, op: bytecode.Call) !void {
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

fn tableMove(state: *State, thread: *Thread, op: bytecode.Call) !void {
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

fn tablePack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table_value = try state.newTableWithHints(op.arg_count, 1);
    const table = table_value.table;
    for (0..op.arg_count) |index| try table.set(state.allocator, .{ .integer = @intCast(index + 1) }, runtime.argValue(state, thread, op, @intCast(index)));
    try table.set(state.allocator, .{ .string = try state.intern("n") }, .{ .integer = op.arg_count });
    try state.returnValues(thread, op.base, op.return_count, &.{table_value});
}

fn tableRemove(state: *State, thread: *Thread, op: bytecode.Call) !void {
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

fn tableSort(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const comparator = if (op.arg_count >= 2) runtime.argValue(state, thread, op, 1) else Value.nil;
    const len = table.len();
    var i: i64 = 2;
    while (i <= len) : (i += 1) {
        var j = i;
        while (j > 1 and try tableSortLess(state, thread, comparator, table.get(.{ .integer = j }), table.get(.{ .integer = j - 1 }))) : (j -= 1) {
            const a = table.get(.{ .integer = j });
            const b = table.get(.{ .integer = j - 1 });
            try table.set(state.allocator, .{ .integer = j - 1 }, a);
            try table.set(state.allocator, .{ .integer = j }, b);
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn tableSortLess(state: *State, thread: *Thread, comparator: Value, lhs: Value, rhs: Value) !bool {
    if (comparator != .nil) return runtime.truthy(try state.callOneResult(thread, comparator, &.{ lhs, rhs }));
    return state.compareValues(thread, lhs, rhs, .lt);
}

fn tableUnpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const table = try state.expectTable(runtime.argValue(state, thread, op, 0));
    const start = if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1;
    const stop = if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse table.len() else table.len();
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index = start;
    while (index <= stop) : (index += 1) try values.append(state.allocator, table.get(.{ .integer = index }));
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

fn stringByte(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, string.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse @as(i64, @intCast(start)) else @as(i64, @intCast(start)), string.len);
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    if (start <= stop and start >= 1) {
        var index = start;
        while (index <= stop and index <= string.len) : (index += 1) try values.append(state.allocator, .{ .integer = string[index - 1] });
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

fn stringChar(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    for (0..op.arg_count) |index| {
        const byte = runtime.toInteger(runtime.argValue(state, thread, op, @intCast(index))) orelse return state.fail("number expected");
        if (byte < 0 or byte > 255) return state.fail("value out of range");
        try out.append(state.allocator, @intCast(byte));
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn stringAsciiMap(state: *State, thread: *Thread, op: bytecode.Call, lower: bool) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = try state.allocator.alloc(u8, string.len);
    defer state.allocator.free(out);
    for (string, 0..) |byte, index| out[index] = if (lower) std.ascii.toLower(byte) else std.ascii.toUpper(byte);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out) }});
}

fn stringSub(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1, string.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse -1 else -1, string.len);
    if (start > stop or start > string.len) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("") }});
        return;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(string[@max(start, 1) - 1 .. @min(stop, string.len)]) }});
}

fn stringReverse(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = try state.allocator.alloc(u8, string.len);
    defer state.allocator.free(out);
    for (string, 0..) |byte, index| out[string.len - 1 - index] = byte;
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out) }});
}

fn stringRep(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const count = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const sep = if (op.arg_count >= 3) try state.expectString(runtime.argValue(state, thread, op, 2)) else "";
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    if (count > 0) {
        var index: i64 = 0;
        while (index < count) : (index += 1) {
            if (index != 0) try out.appendSlice(state.allocator, sep);
            try out.appendSlice(state.allocator, string);
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn stringFind(state: *State, thread: *Thread, op: bytecode.Call, positions: bool) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const pattern = try state.expectString(runtime.argValue(state, thread, op, 1));
    const initial = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1, string.len);
    const plain = op.arg_count >= 4 and runtime.truthy(runtime.argValue(state, thread, op, 3));
    const start = if (initial <= 1) 0 else @min(initial - 1, string.len);
    const found = if (plain) plainFind(string, pattern, start) else simplePatternFind(string, pattern, start);
    if (found) |match| {
        if (positions) {
            try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = @intCast(match.start + 1) }, .{ .integer = @intCast(match.end) } });
        } else {
            try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(string[match.start..match.end]) }});
        }
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
    }
}

fn stringGmatch(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const state_value = try state.newTableWithHints(0, 3);
    const state_table = state_value.table;
    try state_table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = try state.expectString(runtime.argValue(state, thread, op, 0)) });
    try state_table.set(state.allocator, .{ .string = try state.intern("p") }, .{ .string = try state.expectString(runtime.argValue(state, thread, op, 1)) });
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = 0 });
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .string_gmatch_iter }, state_value, .nil });
}

fn stringGmatchIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try stringGmatchNext(state, runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn stringGmatchNext(state: *State, state_value: Value) ![2]Value {
    const state_table = try state.expectTable(state_value);
    const string = try state.expectString(state_table.get(.{ .string = "s" }));
    const pattern = try state.expectString(state_table.get(.{ .string = "p" }));
    const pos = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const found = simplePatternFind(string, pattern, @intCast(@max(pos, 0))) orelse return .{ .nil, .nil };
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(if (found.end > found.start) found.end else found.end + 1) });
    return .{ .{ .string = try state.intern(string[found.start..found.end]) }, .nil };
}

fn stringGsub(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const pattern = try state.expectString(runtime.argValue(state, thread, op, 1));
    const replacement = try state.expectString(runtime.argValue(state, thread, op, 2));
    const max_count = if (op.arg_count >= 4) runtime.toInteger(runtime.argValue(state, thread, op, 3)) orelse std.math.maxInt(i64) else std.math.maxInt(i64);
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var pos: usize = 0;
    var count: i64 = 0;
    while (pos <= string.len and count < max_count) {
        const found = simplePatternFind(string, pattern, pos) orelse break;
        try out.appendSlice(state.allocator, string[pos..found.start]);
        try out.appendSlice(state.allocator, replacement);
        pos = if (found.end > found.start) found.end else found.end + 1;
        count += 1;
    }
    try out.appendSlice(state.allocator, string[@min(pos, string.len)..]);
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .string = try state.intern(out.items) }, .{ .integer = count } });
}

fn stringFormat(state: *State, thread: *Thread, op: bytecode.Call) !void {
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
            'f', 'e', 'E', 'g', 'G' => try runtime.appendNumber(state.allocator, &out, try runtime.toNumber(value)),
            else => return state.fail("invalid format"),
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn stringPacksize(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const format = try state.expectString(runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(try packFormatSize(state, format)) }});
}

fn stringPack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const format = try state.expectString(runtime.argValue(state, thread, op, 0));
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    var arg: u16 = 1;
    var endian: Endian = nativeEndian();
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        const code = format[index];
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
        const size = packCodeSize(code, format, &index) orelse return state.fail("invalid format option");
        const value = runtime.argValue(state, thread, op, arg);
        arg += 1;
        try appendPackedValue(state.allocator, &out, value, code, size, endian);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn stringUnpack(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const format = try state.expectString(runtime.argValue(state, thread, op, 0));
    const data = try state.expectString(runtime.argValue(state, thread, op, 1));
    var pos: usize = @intCast(@max(1, if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else 1) - 1);
    var endian: Endian = nativeEndian();
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        const code = format[index];
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
        const size = packCodeSize(code, format, &index) orelse return state.fail("invalid format option");
        if (pos + size > data.len) return state.fail("data string too short");
        try values.append(state.allocator, unpackValue(data[pos .. pos + size], code, endian));
        pos += size;
    }
    try values.append(state.allocator, .{ .integer = @intCast(pos + 1) });
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

fn mathAbs(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    const result: Value = switch (value) {
        .integer => |integer| .{ .integer = if (integer == std.math.minInt(i64)) integer else @intCast(@abs(integer)) },
        else => .{ .number = @abs(try runtime.toNumber(value)) },
    };
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

fn mathUnary(state: *State, thread: *Thread, op: bytecode.Call, func: MathUnaryFn) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const result = switch (func) {
        .acos => std.math.acos(value),
        .asin => std.math.asin(value),
        .cos => @cos(value),
        .exp => @exp(value),
        .sin => @sin(value),
        .sqrt => @sqrt(value),
        .tan => @tan(value),
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = result }});
}

fn mathUnaryScale(state: *State, thread: *Thread, op: bytecode.Call, scale: f64) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = (try runtime.toNumber(runtime.argValue(state, thread, op, 0))) * scale }});
}

fn mathIntegerUnary(state: *State, thread: *Thread, op: bytecode.Call, func: MathIntegerUnaryFn) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const number = switch (func) {
        .ceil => @ceil(value),
        .floor => @floor(value),
    };
    if (runtime.floatToInteger(number)) |integer| {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = integer }});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = number }});
    }
}

fn mathAtan(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const y = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const x = if (op.arg_count >= 2) try runtime.toNumber(runtime.argValue(state, thread, op, 1)) else 1.0;
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = std.math.atan2(y, x) }});
}

fn mathFmod(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const lhs = runtime.argValue(state, thread, op, 0);
    const rhs = runtime.argValue(state, thread, op, 1);
    if (runtime.toInteger(lhs)) |left| if (runtime.toInteger(rhs)) |right| {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @rem(left, right) }});
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = @rem(try runtime.toNumber(lhs), try runtime.toNumber(rhs)) }});
}

fn mathLog(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const result = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        std.math.log(f64, try runtime.toNumber(runtime.argValue(state, thread, op, 1)), value)
    else
        @log(value);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = result }});
}

fn mathMinMax(state: *State, thread: *Thread, op: bytecode.Call, min: bool) !void {
    if (op.arg_count == 0) return state.fail("value expected");
    var best = runtime.argValue(state, thread, op, 0);
    var index: u16 = 1;
    while (index < op.arg_count) : (index += 1) {
        const value = runtime.argValue(state, thread, op, index);
        const choose = if (min) try state.compareValues(thread, value, best, .lt) else try state.compareValues(thread, best, value, .lt);
        if (choose) best = value;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{best});
}

fn mathModf(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const number = try runtime.toNumber(runtime.argValue(state, thread, op, 0));
    const integral = if (number >= 0) @floor(number) else @ceil(number);
    const int_value: Value = if (runtime.floatToInteger(integral)) |integer| .{ .integer = integer } else .{ .number = integral };
    try state.returnValues(thread, op.base, op.return_count, &.{ int_value, .{ .number = number - integral } });
}

fn mathRandom(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const raw = nextRandomUnit(state);
    if (op.arg_count == 0) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = raw }});
        return;
    }
    const low: i64 = if (op.arg_count == 1) 1 else runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected");
    const high: i64 = if (op.arg_count == 1) runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected") else runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    if (low > high) return state.fail("interval is empty");
    const span: u64 = @intCast(high - low + 1);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = low + @as(i64, @intCast(state.random_state % span)) }});
}

fn mathRandomseed(state: *State, thread: *Thread, op: bytecode.Call) !void {
    state.random_state = @bitCast(runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse 0);
    _ = nextRandomUnit(state);
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn mathTointeger(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = runtime.argValue(state, thread, op, 0);
    const result: Value = if (runtime.toInteger(value)) |integer| .{ .integer = integer } else if (value == .number) if (runtime.floatToInteger(value.number)) |integer| .{ .integer = integer } else .nil else .nil;
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

fn mathType(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const result: Value = switch (runtime.argValue(state, thread, op, 0)) {
        .integer => .{ .string = try state.intern("integer") },
        .number => .{ .string = try state.intern("float") },
        else => .nil,
    };
    try state.returnValues(thread, op.base, op.return_count, &.{result});
}

fn mathUlt(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const lhs = runtime.toInteger(runtime.argValue(state, thread, op, 0)) orelse return state.fail("number expected");
    const rhs = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = @as(u64, @bitCast(lhs)) < @as(u64, @bitCast(rhs)) }});
}

fn utf8Char(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    for (0..op.arg_count) |index| {
        const code = runtime.toInteger(runtime.argValue(state, thread, op, @intCast(index))) orelse return state.fail("integer expected");
        var bytes: [4]u8 = undefined;
        const len = utf8Encode(@intCast(code), &bytes) orelse return state.fail("value out of range");
        try out.appendSlice(state.allocator, bytes[0..len]);
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

fn utf8Codepoint(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, string.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse @as(i64, @intCast(start)) else @as(i64, @intCast(start)), string.len);
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, string.len);
    while (pos < end) {
        const decoded = utf8DecodeAt(string, pos) orelse return state.fail("invalid UTF-8 code");
        try values.append(state.allocator, .{ .integer = decoded.codepoint });
        pos += decoded.len;
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

fn utf8Codes(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const state_value = try state.newTableWithHints(0, 2);
    try state_value.table.set(state.allocator, .{ .string = try state.intern("s") }, .{ .string = string });
    try state_value.table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = 0 });
    try state.returnValues(thread, op.base, op.return_count, &.{ .{ .native = .utf8_codes_iter }, state_value, .nil });
}

fn utf8CodesIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try utf8CodesNext(state, runtime.argValue(state, thread, op, 0), runtime.argValue(state, thread, op, 1));
    try state.returnValues(thread, op.base, op.return_count, values[0..2]);
}

pub fn utf8CodesNext(state: *State, state_value: Value, index_value: Value) ![2]Value {
    _ = index_value;
    const state_table = try state.expectTable(state_value);
    const string = try state.expectString(state_table.get(.{ .string = "s" }));
    const current = runtime.toInteger(state_table.get(.{ .string = "i" })) orelse 0;
    const pos: usize = @intCast(@max(current, 0));
    if (pos >= string.len) return .{ .nil, .nil };
    const decoded = utf8DecodeAt(string, pos) orelse return state.fail("invalid UTF-8 code");
    try state_table.set(state.allocator, .{ .string = try state.intern("i") }, .{ .integer = @intCast(pos + decoded.len) });
    return .{ .{ .integer = @intCast(pos + 1) }, .{ .integer = decoded.codepoint } };
}

fn utf8Len(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const start = normalizeStringIndex(if (op.arg_count >= 2) runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse 1 else 1, string.len);
    const stop = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse -1 else -1, string.len);
    var count: i64 = 0;
    var pos = if (start <= 1) @as(usize, 0) else start - 1;
    const end = @min(stop, string.len);
    while (pos < end) {
        const decoded = utf8DecodeAt(string, pos) orelse {
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .integer = @intCast(pos + 1) } });
            return;
        };
        count += 1;
        pos += decoded.len;
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = count }});
}

fn utf8Offset(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const string = try state.expectString(runtime.argValue(state, thread, op, 0));
    const n = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected");
    const pos = normalizeStringIndex(if (op.arg_count >= 3) runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse 1 else if (n >= 0) 1 else -1, string.len);
    if (pos < 1 or pos > string.len + 1) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    var byte_pos = pos - 1;
    while (byte_pos > 0 and isUtf8Continuation(string[byte_pos])) byte_pos -= 1;
    if (n == 0) {
        const decoded = utf8DecodeAt(string, byte_pos) orelse return state.fail("invalid UTF-8 code");
        try state.returnValues(thread, op.base, op.return_count, &.{ .{ .integer = @intCast(byte_pos + 1) }, .{ .integer = @intCast(byte_pos + decoded.len) } });
        return;
    }
    var remaining = if (n > 0) n - 1 else -n;
    while (remaining > 0) : (remaining -= 1) {
        if (n > 0) {
            const decoded = utf8DecodeAt(string, byte_pos) orelse return state.fail("invalid UTF-8 code");
            byte_pos += decoded.len;
            if (byte_pos >= string.len and remaining > 1) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
        } else {
            if (byte_pos == 0) {
                try state.returnValues(thread, op.base, op.return_count, &.{.nil});
                return;
            }
            byte_pos -= 1;
            while (byte_pos > 0 and isUtf8Continuation(string[byte_pos])) byte_pos -= 1;
        }
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(byte_pos + 1) }});
}

fn nextRandomUnit(state: *State) f64 {
    state.random_state = state.random_state *% 6364136223846793005 +% 1442695040888963407;
    return @as(f64, @floatFromInt(state.random_state >> 11)) / @as(f64, @floatFromInt(@as(u64, 1) << 53));
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

fn normalizeStringIndex(index: i64, len: usize) usize {
    const length: i64 = @intCast(len);
    const normalized = if (index < 0) length + index + 1 else index;
    if (normalized <= 0) return 0;
    return @intCast(normalized);
}

const MatchRange = struct { start: usize, end: usize };

fn plainFind(string: []const u8, pattern: []const u8, start: usize) ?MatchRange {
    if (pattern.len == 0) return .{ .start = @min(start, string.len), .end = @min(start, string.len) };
    if (start > string.len) return null;
    const relative = std.mem.indexOf(u8, string[start..], pattern) orelse return null;
    return .{ .start = start + relative, .end = start + relative + pattern.len };
}

fn simplePatternFind(string: []const u8, pattern: []const u8, start: usize) ?MatchRange {
    if (pattern.len == 0) return .{ .start = @min(start, string.len), .end = @min(start, string.len) };
    var candidate = start;
    while (candidate <= string.len) : (candidate += 1) {
        if (matchSimplePatternAt(string, pattern, candidate)) |end| return .{ .start = candidate, .end = end };
    }
    return null;
}

fn matchSimplePatternAt(string: []const u8, pattern: []const u8, start: usize) ?usize {
    var s = start;
    var p: usize = 0;
    while (p < pattern.len) {
        const atom_start = p;
        p = nextPatternAtom(pattern, p);
        const quantifier = if (p < pattern.len and std.mem.indexOfScalar(u8, "*+-?", pattern[p]) != null) pattern[p] else 0;
        if (quantifier != 0) p += 1;
        switch (quantifier) {
            0 => {
                if (s >= string.len or !patternAtomMatches(pattern[atom_start..p], string[s])) return null;
                s += 1;
            },
            '?' => {
                if (s < string.len and patternAtomMatches(pattern[atom_start .. p - 1], string[s])) s += 1;
            },
            '+', '*' => {
                var count: usize = 0;
                while (s < string.len and patternAtomMatches(pattern[atom_start .. p - 1], string[s])) : (s += 1) count += 1;
                if (quantifier == '+' and count == 0) return null;
            },
            '-' => {},
            else => unreachable,
        }
    }
    return s;
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

fn patternAtomMatches(atom: []const u8, byte: u8) bool {
    if (atom.len == 1) return atom[0] == '.' or atom[0] == byte;
    if (atom[0] == '%') return switch (atom[1]) {
        'a' => std.ascii.isAlphabetic(byte),
        'A' => !std.ascii.isAlphabetic(byte),
        'd' => std.ascii.isDigit(byte),
        'D' => !std.ascii.isDigit(byte),
        'l' => std.ascii.isLower(byte),
        'L' => !std.ascii.isLower(byte),
        's' => std.ascii.isWhitespace(byte),
        'S' => !std.ascii.isWhitespace(byte),
        'u' => std.ascii.isUpper(byte),
        'U' => !std.ascii.isUpper(byte),
        'w' => std.ascii.isAlphanumeric(byte),
        'W' => !std.ascii.isAlphanumeric(byte),
        'x' => std.ascii.isHex(byte),
        'X' => !std.ascii.isHex(byte),
        else => atom[1] == byte,
    };
    if (atom[0] == '[' and atom[atom.len - 1] == ']') {
        const negated = atom.len > 2 and atom[1] == '^';
        const body = atom[if (negated) 2 else 1 .. atom.len - 1];
        var matched = false;
        var index: usize = 0;
        while (index < body.len) : (index += 1) {
            if (index + 2 < body.len and body[index + 1] == '-') {
                matched = matched or (body[index] <= byte and byte <= body[index + 2]);
                index += 2;
            } else {
                matched = matched or body[index] == byte;
            }
        }
        return if (negated) !matched else matched;
    }
    return false;
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

fn appendQuoted(allocator: std.mem.Allocator, out: *std.ArrayList(u8), string: []const u8) !void {
    try out.append(allocator, '"');
    for (string) |byte| switch (byte) {
        '\\' => try out.appendSlice(allocator, "\\\\"),
        '"' => try out.appendSlice(allocator, "\\\""),
        '\n' => try out.appendSlice(allocator, "\\n"),
        '\r' => try out.appendSlice(allocator, "\\r"),
        '\t' => try out.appendSlice(allocator, "\\t"),
        else => try out.append(allocator, byte),
    };
    try out.append(allocator, '"');
}

const Endian = enum { little, big };

fn nativeEndian() Endian {
    return switch (@import("builtin").target.cpu.arch.endian()) {
        .little => .little,
        .big => .big,
    };
}

fn packFormatSize(state: *State, format: []const u8) !usize {
    var total: usize = 0;
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        const code = format[index];
        if (std.ascii.isWhitespace(code) or code == '<' or code == '>' or code == '=' or code == '!') continue;
        total += packCodeSize(code, format, &index) orelse return state.fail("invalid format option");
    }
    return total;
}

fn packCodeSize(code: u8, format: []const u8, index: *usize) ?usize {
    return switch (code) {
        'b', 'B' => 1,
        'h', 'H' => 2,
        'l', 'L', 'j', 'J', 'T', 'n', 'd' => 8,
        'f' => 4,
        'i', 'I' => parsePackSize(format, index),
        else => null,
    };
}

fn parsePackSize(format: []const u8, index: *usize) ?usize {
    var size: usize = 0;
    while (index.* + 1 < format.len and std.ascii.isDigit(format[index.* + 1])) {
        index.* += 1;
        size = size * 10 + format[index.*] - '0';
    }
    if (size == 0) size = @sizeOf(isize);
    if (size != 1 and size != 2 and size != 4 and size != 8) return null;
    return size;
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

const Utf8Decoded = struct { codepoint: i64, len: usize };

fn utf8DecodeAt(bytes: []const u8, pos: usize) ?Utf8Decoded {
    if (pos >= bytes.len) return null;
    const first = bytes[pos];
    if (first < 0x80) return .{ .codepoint = first, .len = 1 };
    const len: usize = if ((first & 0xe0) == 0xc0) 2 else if ((first & 0xf0) == 0xe0) 3 else if ((first & 0xf8) == 0xf0) 4 else return null;
    if (pos + len > bytes.len) return null;
    var code: i64 = first & (@as(u8, 0x7f) >> @intCast(len));
    for (bytes[pos + 1 .. pos + len]) |byte| {
        if (!isUtf8Continuation(byte)) return null;
        code = (code << 6) | (byte & 0x3f);
    }
    return .{ .codepoint = code, .len = len };
}

fn utf8Encode(code: u21, out: *[4]u8) ?usize {
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

fn isUtf8Continuation(byte: u8) bool {
    return (byte & 0xc0) == 0x80;
}
