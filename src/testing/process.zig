const std = @import("std");

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
};

pub fn runProcess(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    options: RunOptions,
) !ProcessResult {
    const timeout: std.Io.Timeout = if (options.timeout_ms == 0)
        .none
    else
        .{ .duration = .{ .clock = .awake, .raw = .fromMilliseconds(@intCast(options.timeout_ms)) } };

    const result = std.process.run(allocator, io, .{
        .argv = argv,
        .cwd = if (options.cwd) |cwd| .{ .path = cwd } else .inherit,
        .stdout_limit = .limited(options.max_output_bytes),
        .stderr_limit = .limited(options.max_output_bytes),
        .expand_arg0 = if (options.expand_arg0) .expand else .no_expand,
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
