const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn time(state: *State, thread: *Thread, op: bytecode.Call) !void {
    _ = runtime.argValue(state, thread, op, 0);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = try state.currentTime() }});
}

pub fn clock(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .number = 0 }});
}

pub fn date(state: *State, thread: *Thread, op: bytecode.Call) !void {
    var format = if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil)
        try state.expectString(runtime.argValue(state, thread, op, 0))
    else
        "%c";
    const when = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("number expected")
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

pub fn getenv(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectString(runtime.argValue(state, thread, op, 0));
    const value = if (state.getenv(name)) |env| Value{ .string = try state.intern(env) } else Value.nil;
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn setlocale(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const locale = if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil)
        try state.expectString(runtime.argValue(state, thread, op, 0))
    else
        "C";
    const value = if (std.mem.eql(u8, locale, "C")) Value{ .string = try state.intern("C") } else Value.nil;
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

pub fn execute(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (!state.processEnabled()) return state.fail("process access disabled");
    const command = try state.expectString(runtime.argValue(state, thread, op, 0));
    const io = state.options.io orelse return state.fail("process I/O unavailable");
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
        if (format[index] != '%' or index + 1 >= format.len) {
            try out.append(state.allocator, format[index]);
            continue;
        }
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
            else => return state.fail("unsupported date format"),
        }
    }
}
