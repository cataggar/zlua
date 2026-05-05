const std = @import("std");
const process = @import("process.zig");

pub const Discovery = union(enum) {
    found: []u8,
    missing: []u8,

    pub fn deinit(self: Discovery, allocator: std.mem.Allocator) void {
        switch (self) {
            .found => |path| allocator.free(path),
            .missing => |message| allocator.free(message),
        }
    }
};

pub fn detect(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    explicit_path: ?[]const u8,
) !Discovery {
    if (explicit_path) |path| {
        const configured = try allocator.dupe(u8, path);
        if (try isLua55(allocator, io, configured)) {
            return .{ .found = configured };
        }
        defer allocator.free(configured);
        return .{ .missing = try std.fmt.allocPrint(
            allocator,
            "configured CLua does not identify as Lua 5.5: {s}",
            .{configured},
        ) };
    }

    if (environ_map.get("ZLUA_CLUA")) |configured_value| {
        const configured = try allocator.dupe(u8, configured_value);
        if (try isLua55(allocator, io, configured)) {
            return .{ .found = configured };
        }
        defer allocator.free(configured);
        return .{ .missing = try std.fmt.allocPrint(
            allocator,
            "ZLUA_CLUA does not identify a Lua 5.5 executable: {s}",
            .{configured},
        ) };
    }

    const candidates = [_][]const u8{ "zig-out/bin/lua5.5", "lua5.5", "lua5.5.0", "lua" };
    for (candidates) |candidate| {
        if (try isLua55(allocator, io, candidate)) {
            return .{ .found = try allocator.dupe(u8, candidate) };
        }
    }

    return .{ .missing = try allocator.dupe(
        u8,
        "could not find Lua 5.5; set ZLUA_CLUA or install lua5.5 on PATH",
    ) };
}

fn isLua55(allocator: std.mem.Allocator, io: std.Io, exe: []const u8) !bool {
    const argv = [_][]const u8{ exe, "-v" };
    var result = process.runProcess(allocator, io, &argv, .{ .timeout_ms = 2000 }) catch return false;
    defer result.deinit(allocator);

    return std.mem.indexOf(u8, result.stdout, "Lua 5.5") != null or
        std.mem.indexOf(u8, result.stderr, "Lua 5.5") != null;
}

pub fn runLoadfile(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    timeout_ms: u64,
) !process.ProcessResult {
    const quoted_path = try luaQuote(allocator, path);
    defer allocator.free(quoted_path);
    const code = try std.fmt.allocPrint(
        allocator,
        "local f, err = loadfile({s}); if not f then io.stderr:write(err, '\\n'); os.exit(1) end",
        .{quoted_path},
    );
    defer allocator.free(code);

    const argv = [_][]const u8{ exe, "-e", code };
    return process.runProcess(allocator, io, &argv, .{ .timeout_ms = timeout_ms });
}

pub fn runFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    timeout_ms: u64,
) !process.ProcessResult {
    const argv = [_][]const u8{ exe, path };
    return process.runProcess(allocator, io, &argv, .{ .timeout_ms = timeout_ms });
}

fn luaQuote(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '"' => try out.appendSlice(allocator, "\\\""),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => try out.append(allocator, byte),
        }
    }
    try out.append(allocator, '"');
    return out.toOwnedSlice(allocator);
}

test "quotes Lua strings" {
    const quoted = try luaQuote(std.testing.allocator, "a\\b\"c");
    defer std.testing.allocator.free(quoted);
    try std.testing.expect(std.mem.eql(u8, quoted, "\"a\\\\b\\\"c\""));
}
