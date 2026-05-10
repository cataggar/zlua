const std = @import("std");
const process = @import("process.zig");

const Dir = std.Io.Dir;
const File = std.Io.File;

const Options = struct {
    path: []const u8 = "tests/extensions",
    zlua: ?[]const u8 = null,
    stdlib: []const u8 = "safe",
    show_output: bool = false,
    timeout_ms: u64 = 5000,
};

const Counts = struct {
    passed: usize = 0,
    failed: usize = 0,
};

const Expected = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: u8,

    fn deinit(self: *Expected, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
        self.* = undefined;
    }
};

pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    default_zlua: []const u8,
    args: []const []const u8,
) !u8 {
    const options = parseArgs(args) catch |err| {
        try stderrPrint(io, "test-extensions: {s}\n", .{@errorName(err)});
        return 2;
    };
    const zlua_exe = options.zlua orelse default_zlua;

    var tests = std.ArrayList([]u8).empty;
    defer {
        for (tests.items) |path| allocator.free(path);
        tests.deinit(allocator);
    }
    try discoverTests(allocator, io, options.path, &tests);
    std.mem.sort([]u8, tests.items, {}, lessThanString);

    var buffer: [8192]u8 = undefined;
    var writer = File.stdout().writer(io, &buffer);
    const out = &writer.interface;

    var counts: Counts = .{};
    for (tests.items) |path| try runOne(allocator, io, out, zlua_exe, path, options, &counts);

    try out.print(
        \\summary:
        \\  passed={d}
        \\  failed={d}
        \\
    , .{ counts.passed, counts.failed });
    try out.flush();

    return if (counts.failed == 0) 0 else 1;
}

fn parseArgs(args: []const []const u8) !Options {
    var options: Options = .{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--zlua")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.zlua = args[index];
        } else if (std.mem.startsWith(u8, arg, "--zlua=")) {
            options.zlua = arg[7..];
        } else if (std.mem.eql(u8, arg, "--stdlib")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.stdlib = args[index];
        } else if (std.mem.startsWith(u8, arg, "--stdlib=")) {
            options.stdlib = arg[9..];
        } else if (std.mem.eql(u8, arg, "--show-output")) {
            options.show_output = true;
        } else if (std.mem.startsWith(u8, arg, "--timeout-ms=")) {
            options.timeout_ms = try std.fmt.parseInt(u64, arg[13..], 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            options.path = arg;
        }
    }
    return options;
}

fn discoverTests(allocator: std.mem.Allocator, io: std.Io, root: []const u8, tests: *std.ArrayList([]u8)) !void {
    var dir = Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.NotDir => {
            if (std.mem.endsWith(u8, root, ".lua")) try tests.append(allocator, try allocator.dupe(u8, root));
            return;
        },
        else => return err,
    };
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".lua")) continue;
        try tests.append(allocator, try std.fs.path.join(allocator, &.{ root, entry.path }));
    }
}

fn runOne(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
    zlua_exe: []const u8,
    path: []const u8,
    options: Options,
    counts: *Counts,
) !void {
    var expected = try readExpected(allocator, io, path);
    defer expected.deinit(allocator);

    const argv = [_][]const u8{ zlua_exe, "--stdlib", options.stdlib, path };
    var result = try process.runProcess(allocator, io, &argv, .{ .timeout_ms = options.timeout_ms, .max_output_bytes = 1024 * 1024 });
    defer result.deinit(allocator);

    const passed = !result.timed_out and result.signal == null and result.exit_code == expected.exit_code and
        std.mem.eql(u8, result.stdout, expected.stdout) and std.mem.eql(u8, result.stderr, expected.stderr);

    if (passed) {
        counts.passed += 1;
        try out.print("pass {s}\n", .{path});
    } else {
        counts.failed += 1;
        try out.print("fail {s}\n", .{path});
        try printDiff(out, expected, result);
    }

    if (options.show_output) {
        try out.print("[stdout]\n{s}\n[stderr]\n{s}\n", .{ result.stdout, result.stderr });
    }
}

fn readExpected(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Expected {
    const stdout_path = try std.fmt.allocPrint(allocator, "{s}.out", .{path});
    defer allocator.free(stdout_path);
    const stderr_path = try std.fmt.allocPrint(allocator, "{s}.err", .{path});
    defer allocator.free(stderr_path);
    const exit_path = try std.fmt.allocPrint(allocator, "{s}.exit", .{path});
    defer allocator.free(exit_path);

    const stdout = try Dir.cwd().readFileAlloc(io, stdout_path, allocator, .limited(1024 * 1024));
    errdefer allocator.free(stdout);
    const stderr = Dir.cwd().readFileAlloc(io, stderr_path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, ""),
        else => return err,
    };
    errdefer allocator.free(stderr);
    const exit_code = try readExpectedExit(allocator, io, exit_path);

    return .{ .stdout = stdout, .stderr = stderr, .exit_code = exit_code };
}

fn readExpectedExit(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !u8 {
    const contents = Dir.cwd().readFileAlloc(io, path, allocator, .limited(128)) catch |err| switch (err) {
        error.FileNotFound => return 0,
        else => return err,
    };
    defer allocator.free(contents);
    return try std.fmt.parseInt(u8, std.mem.trim(u8, contents, " \t\r\n"), 10);
}

fn printDiff(out: anytype, expected: Expected, actual: process.ProcessResult) !void {
    try out.print("  expected exit={d}\n", .{expected.exit_code});
    try out.print("  actual exit={?} timeout={} signal={?}\n", .{ actual.exit_code, actual.timed_out, actual.signal });
    if (!std.mem.eql(u8, expected.stdout, actual.stdout)) {
        try out.print("--- expected stdout\n{s}\n+++ actual stdout\n{s}\n", .{ expected.stdout, actual.stdout });
    }
    if (!std.mem.eql(u8, expected.stderr, actual.stderr)) {
        try out.print("--- expected stderr\n{s}\n+++ actual stderr\n{s}\n", .{ expected.stderr, actual.stderr });
    }
}

fn lessThanString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "argument parser accepts zlua and path" {
    const args = [_][]const u8{ "--zlua", "zig-out/bin/zlua", "tests/extensions/json" };
    const options = try parseArgs(&args);
    try std.testing.expectEqualStrings("zig-out/bin/zlua", options.zlua.?);
    try std.testing.expectEqualStrings("tests/extensions/json", options.path);
}
