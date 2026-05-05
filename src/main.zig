const std = @import("std");
const zlua = @import("zlua");

const CliError = error{Usage};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    const raw_args = try init.minimal.args.toSlice(allocator);
    const args = try allocator.alloc([]const u8, raw_args.len);
    for (raw_args, 0..) |arg, index| args[index] = arg;

    if (args.len == 1) {
        try printUsage(io);
        return;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try printVersion(io);
        return;
    }

    if (std.mem.eql(u8, command, "test-diff")) {
        const exit_code = try zlua.testing.diff_runner.runCli(allocator, io, init.environ_map, args[2..]);
        std.process.exit(exit_code);
    }

    if (std.mem.startsWith(u8, command, "-")) {
        try stderrPrint(io, "unknown option: {s}\n", .{command});
        return CliError.Usage;
    }

    try stderrPrint(io, "script execution is not implemented yet: {s}\n", .{command});
    std.process.exit(1);
}

fn printVersion(io: std.Io) !void {
    try stdoutPrint(io, "zlua {s} ({s} target)\n", .{ zlua.version, zlua.lua_target_version });
}

fn printUsage(io: std.Io) !void {
    try stdoutPrint(io,
        \\Usage: zlua [--version] <command|script>
        \\
        \\Commands:
        \\  test-diff [path] [--stage=name] [--feature=name] [--show-clua] [--show-zlua]
        \\
    , .{});
}

fn stdoutPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "version constants are wired" {
    try std.testing.expect(std.mem.eql(u8, zlua.lua_target_version, "Lua 5.5"));
}
