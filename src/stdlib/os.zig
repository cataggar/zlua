const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn time(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = try tableToTime(state, runtime.argValue(state, thread, op, 0)) }});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = try state.currentTime() }});
    }
}

pub fn clock(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = 0 }});
}

pub fn date(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var format = if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil)
        try state.expectArgumentString(thread, op, "os.date", 0)
    else
        "%c";
    const when = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        try state.argumentInteger(thread, op, "os.date", 1)
    else
        try state.currentTime();

    if (format.len != 0 and format[0] == '!') format = format[1..];
    if (std.mem.eql(u8, format, "*t")) {
        try state.returnValues(thread, op.base, op.return_count, &.{try timeTable(state, when)});
        return;
    }

    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try formatUtc(state, &out, format, when);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(out.items) }});
}

pub fn remove(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try state.expectArgumentString(thread, op, "os.remove", 0);
    state.removeFile(path) catch |err| switch (err) {
        error.RuntimeError => {
            const error_value = state.currentErrorValue();
            const message = if (error_value == .string) error_value.string else "cannot remove file";
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) }, .{ .integer = 2 } });
            return;
        },
        else => return err,
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn rename(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const old_path = try state.expectArgumentString(thread, op, "os.rename", 0);
    const new_path = try state.expectArgumentString(thread, op, "os.rename", 1);
    state.renameFile(old_path, new_path) catch |err| switch (err) {
        error.RuntimeError => {
            const error_value = state.currentErrorValue();
            const message = if (error_value == .string) error_value.string else "cannot rename file";
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) }, .{ .integer = 2 } });
            return;
        },
        else => return err,
    };
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn tmpname(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const timestamp = state.currentTime() catch 0;
    const name = try std.fmt.allocPrint(state.allocator, "zlua_tmp_{d}_{d}.tmp", .{ timestamp, state.table_allocations.items.len });
    defer state.allocator.free(name);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(name) }});
}

pub fn difftime(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const t2 = try state.argumentInteger(thread, op, "os.difftime", 0);
    const t1 = try state.argumentInteger(thread, op, "os.difftime", 1);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = @floatFromInt(t2 - t1) }});
}

pub fn getenv(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectArgumentString(thread, op, "os.getenv", 0);
    const value = if (state.getenv(name)) |env| Value{ .string = try state.intern(env) } else Value.nil;
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn setlocale(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const locale = if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil)
        try state.expectArgumentString(thread, op, "os.setlocale", 0)
    else
        "C";
    const value = if (std.mem.eql(u8, locale, "C")) Value{ .string = try state.intern("C") } else Value.nil;
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn execute(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (!state.processEnabled()) return state.fail("process access disabled");
    const command = try state.expectArgumentString(thread, op, "os.execute", 0);
    const io = try state.requireIo("process I/O unavailable");
    const argv = [_][]const u8{ "/bin/sh", "-c", command };
    const result = std.process.run(state.allocator, io, .{
        .argv = &argv,
        .environ_map = state.options.environment,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    }) catch return state.fail("process execution failed");
    defer state.allocator.free(result.stdout);
    defer state.allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code == 0) {
            try state.returnValues(thread, op.base, op.return_count, &.{ .{ .boolean = true }, .{ .string = try state.intern("exit") }, .{ .integer = code } });
        } else {
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("exit") }, .{ .integer = code } });
        },
        else => try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("signal") }, .{ .integer = 0 } }),
    }
}

fn timeParts(timestamp: i64) struct {
    year: i64,
    month: i64,
    day: i64,
    hour: i64,
    min: i64,
    sec: i64,
    yday: i64,
    wday: i64,
} {
    const secs: u64 = @intCast(@max(timestamp, 0));
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = secs };
    const epoch_day = epoch_seconds.getEpochDay();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    return .{
        .year = year_day.year,
        .month = @intFromEnum(month_day.month),
        .day = month_day.day_index + 1,
        .hour = day_seconds.getHoursIntoDay(),
        .min = day_seconds.getMinutesIntoHour(),
        .sec = day_seconds.getSecondsIntoMinute(),
        .yday = year_day.day + 1,
        .wday = @intCast(@mod(epoch_day.day + 4, 7) + 1),
    };
}

fn tableToTime(state: *State, value: Value) !i64 {
    const table = switch (value) {
        .table => |table| table,
        else => return state.failArgumentType("os.time", 1, "table", value),
    };
    const year = try tableField(state, table, "year");
    const month = try tableField(state, table, "month");
    const day = try tableField(state, table, "day");
    const hour = (try tableOptionalField(state, table, "hour")) orelse 12;
    const min = (try tableOptionalField(state, table, "min")) orelse 0;
    const sec = (try tableOptionalField(state, table, "sec")) orelse 0;
    try checkYearFieldBounds(state, year);
    try checkTimeFieldBounds(state, "month", month);
    try checkTimeFieldBounds(state, "day", day);
    try checkTimeFieldBounds(state, "hour", hour);
    try checkTimeFieldBounds(state, "min", min);
    try checkTimeFieldBounds(state, "sec", sec);
    const days = daysFromCivil(year, month, day);
    const timestamp = days * std.time.s_per_day + hour * 3600 + min * 60 + sec;
    const normalized = timeParts(timestamp);
    try table.set(state.allocator, .{ .string = try state.intern("year") }, .{ .integer = normalized.year });
    try table.set(state.allocator, .{ .string = try state.intern("month") }, .{ .integer = normalized.month });
    try table.set(state.allocator, .{ .string = try state.intern("day") }, .{ .integer = normalized.day });
    try table.set(state.allocator, .{ .string = try state.intern("hour") }, .{ .integer = normalized.hour });
    try table.set(state.allocator, .{ .string = try state.intern("min") }, .{ .integer = normalized.min });
    try table.set(state.allocator, .{ .string = try state.intern("sec") }, .{ .integer = normalized.sec });
    try table.set(state.allocator, .{ .string = try state.intern("wday") }, .{ .integer = normalized.wday });
    try table.set(state.allocator, .{ .string = try state.intern("yday") }, .{ .integer = normalized.yday });
    return timestamp;
}

fn tableField(state: *State, table: *runtime.Table, name: []const u8) !i64 {
    const value = table.get(.{ .string = name });
    if (value == .nil) return state.failArgumentMessage("os.time", 1, "missing field");
    return runtime.toInteger(value) orelse state.failArgumentMessage("os.time", 1, "not an integer");
}

fn tableOptionalField(state: *State, table: *runtime.Table, name: []const u8) !?i64 {
    const value = table.get(.{ .string = name });
    if (value == .nil) return null;
    return runtime.toInteger(value) orelse state.failArgumentMessage("os.time", 1, "not an integer");
}

fn checkYearFieldBounds(state: *State, year: i64) !void {
    const min_year: i64 = @as(i64, std.math.minInt(i32)) + 1900;
    const max_year: i64 = @as(i64, std.math.maxInt(i32)) + 1900;
    if (year >= min_year and year <= max_year) return;
    return state.fail("field 'year' is out-of-bound");
}

fn checkTimeFieldBounds(state: *State, comptime name: []const u8, value: i64) !void {
    if (value >= std.math.minInt(i32) and value <= std.math.maxInt(i32)) return;
    return state.fail("field '" ++ name ++ "' is out-of-bound");
}

fn daysFromCivil(year: i64, month: i64, day: i64) i64 {
    var y = year;
    var m = month;
    y -= @intFromBool(m <= 2);
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    m = m + if (m > 2) @as(i64, -3) else @as(i64, 9);
    const doy = @divFloor(153 * m + 2, 5) + day - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

fn timeTable(state: *State, timestamp: i64) !Value {
    const parts = timeParts(timestamp);
    const value = try state.newTableWithHints(0, 9);
    const table = value.table;
    try table.set(state.allocator, .{ .string = try state.intern("year") }, .{ .integer = parts.year });
    try table.set(state.allocator, .{ .string = try state.intern("month") }, .{ .integer = parts.month });
    try table.set(state.allocator, .{ .string = try state.intern("day") }, .{ .integer = parts.day });
    try table.set(state.allocator, .{ .string = try state.intern("hour") }, .{ .integer = parts.hour });
    try table.set(state.allocator, .{ .string = try state.intern("min") }, .{ .integer = parts.min });
    try table.set(state.allocator, .{ .string = try state.intern("sec") }, .{ .integer = parts.sec });
    try table.set(state.allocator, .{ .string = try state.intern("yday") }, .{ .integer = parts.yday });
    try table.set(state.allocator, .{ .string = try state.intern("wday") }, .{ .integer = parts.wday });
    try table.set(state.allocator, .{ .string = try state.intern("isdst") }, .{ .boolean = false });
    return value;
}

fn formatUtc(state: *State, out: *std.ArrayList(u8), format: []const u8, timestamp: i64) !void {
    const parts = timeParts(timestamp);
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        if (format[index] != '%') {
            try out.append(state.allocator, format[index]);
            continue;
        }
        if (index + 1 >= format.len) return state.fail("invalid conversion specifier");
        index += 1;
        switch (format[index]) {
            '%' => try out.append(state.allocator, '%'),
            'Y' => try runtime.appendFmt(state.allocator, out, "{d:0>4}", .{@as(u64, @intCast(parts.year))}),
            'm' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, @intCast(parts.month))}),
            'd' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, @intCast(parts.day))}),
            'H' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, @intCast(parts.hour))}),
            'M' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, @intCast(parts.min))}),
            'S' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, @intCast(parts.sec))}),
            'j' => try runtime.appendFmt(state.allocator, out, "{d:0>3}", .{@as(u64, @intCast(parts.yday))}),
            'w' => try runtime.appendFmt(state.allocator, out, "{d}", .{parts.wday - 1}),
            'c' => try runtime.appendFmt(state.allocator, out, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{ @as(u64, @intCast(parts.year)), @as(u64, @intCast(parts.month)), @as(u64, @intCast(parts.day)), @as(u64, @intCast(parts.hour)), @as(u64, @intCast(parts.min)), @as(u64, @intCast(parts.sec)) }),
            'x', 'X', 'a', 'A', 'b', 'B', 'p' => try runtime.appendFmt(state.allocator, out, "{d:0>2}", .{@as(u64, 0)}),
            else => return state.fail("invalid conversion specifier"),
        }
    }
}
