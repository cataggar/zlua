const std = @import("std");
const builtin = @import("builtin");

const Dir = std.Io.Dir;
const Timeout = std.Io.Timeout;

pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: ?u8,
    signal: ?u32,
    timed_out: bool,

    pub fn deinit(self: *ProcessResult, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
        self.* = .{
            .stdout = &.{},
            .stderr = &.{},
            .exit_code = null,
            .signal = null,
            .timed_out = false,
        };
    }

    pub fn success(self: ProcessResult) bool {
        return !self.timed_out and self.signal == null and self.exit_code == 0;
    }
};

pub const RunOptions = struct {
    cwd: ?[]const u8 = null,
    timeout_ms: u64 = 5000,
    max_output_bytes: usize = 1024 * 1024,
    expand_arg0: bool = false,
    memory_limit_mb: u64 = 0,
};

pub fn runProcess(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    options: RunOptions,
) !ProcessResult {
    var wrapped_argv = std.ArrayList([]const u8).empty;
    defer wrapped_argv.deinit(allocator);

    var owned_arg0: ?[:0]u8 = null;
    defer if (owned_arg0) |arg| allocator.free(arg);

    var limit_kb_arg: ?[]u8 = null;
    defer if (limit_kb_arg) |arg| allocator.free(arg);

    var run_argv = argv;
    var expand_arg0 = options.expand_arg0;
    if (options.memory_limit_mb != 0) {
        if (builtin.os.tag != .linux) return error.UnsupportedMemoryLimit;
        if (argv.len == 0) return error.EmptyArgv;

        const limit_kb = std.math.mul(u64, options.memory_limit_mb, 1024) catch return error.MemoryLimitTooLarge;
        limit_kb_arg = try std.fmt.allocPrint(allocator, "{d}", .{limit_kb});

        if (std.mem.indexOfScalar(u8, argv[0], '/') != null) {
            owned_arg0 = try Dir.cwd().realPathFileAlloc(io, argv[0], allocator);
        }

        try wrapped_argv.appendSlice(allocator, &.{
            "/bin/sh",
            "-c",
            "limit_kb=$1; shift; ulimit -v \"$limit_kb\"; exec \"$@\"",
            "zlua-memory-limit",
            limit_kb_arg.?,
            owned_arg0 orelse argv[0],
        });
        try wrapped_argv.appendSlice(allocator, argv[1..]);
        run_argv = wrapped_argv.items;
        expand_arg0 = false;
    }

    const timeout: Timeout = if (options.timeout_ms == 0)
        .none
    else
        .{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(@intCast(options.timeout_ms)) } };

    const result = std.process.run(allocator, io, .{
        .argv = run_argv,
        .cwd = if (options.cwd) |cwd| .{ .path = cwd } else .inherit,
        .stdout_limit = .limited(options.max_output_bytes),
        .stderr_limit = .limited(options.max_output_bytes),
        .expand_arg0 = if (expand_arg0) .expand else .no_expand,
        .timeout = timeout,
    }) catch |err| switch (err) {
        error.Timeout => return .{
            .stdout = try allocator.dupe(u8, ""),
            .stderr = try allocator.dupe(u8, "process timed out\n"),
            .exit_code = null,
            .signal = null,
            .timed_out = true,
        },
        else => return err,
    };

    var exit_code: ?u8 = null;
    var signal: ?u32 = null;
    switch (result.term) {
        .exited => |code| exit_code = code,
        .signal => |sig| signal = @intFromEnum(sig),
        .stopped => |sig| signal = @intFromEnum(sig),
        .unknown => |code| signal = code,
    }

    return .{
        .stdout = result.stdout,
        .stderr = result.stderr,
        .exit_code = exit_code,
        .signal = signal,
        .timed_out = false,
    };
}

pub fn ownedResult(
    allocator: std.mem.Allocator,
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
) !ProcessResult {
    return .{
        .stdout = try allocator.dupe(u8, stdout),
        .stderr = try allocator.dupe(u8, stderr),
        .exit_code = exit_code,
        .signal = null,
        .timed_out = false,
    };
}

test "owned result reports success" {
    var result = try ownedResult(std.testing.allocator, "", "", 0);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.success());
}

test "memory limit wrapper rejects empty argv" {
    const result = runProcess(std.testing.allocator, std.Io.failing, &.{}, .{ .memory_limit_mb = 1 });
    try std.testing.expectError(error.EmptyArgv, result);
}
