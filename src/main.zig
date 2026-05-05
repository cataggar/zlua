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

    const source = std.Io.Dir.cwd().readFileAlloc(io, command, allocator, .limited(1024 * 1024)) catch |err| {
        try stderrPrint(io, "cannot read script {s}: {s}\n", .{ command, @errorName(err) });
        std.process.exit(1);
    };
    var result = try zlua.runtime.executeSourceWithOptions(allocator, source, .{
        .state = .{
            .io = io,
            .filesystem = .host_cwd,
            .environment = init.environ_map,
            .process = .enabled,
        },
    });
    defer result.deinit(allocator);

    try stdoutWrite(io, result.stdout);
    try stderrWrite(io, result.stderr);
    std.process.exit(result.exit_code orelse 1);
}

fn printVersion(io: std.Io) !void {
    try stdoutPrint(io, "zlua {s} ({s} target)\n", .{ zlua.version, zlua.lua_target_version });
}

fn printUsage(io: std.Io) !void {
    try stdoutPrint(io,
        \\Usage: zlua [--version] <command|script>
        \\
        \\Commands:
        \\  test-diff [path] [--stage=name] [--feature=name] [--gc-stress] [--show-clua] [--show-zlua]
        \\
    , .{});
}

fn stdoutPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

fn stdoutWrite(io: std.Io, bytes: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

fn stderrWrite(io: std.Io, bytes: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
}

test "version constants are wired" {
    try std.testing.expect(std.mem.eql(u8, zlua.lua_target_version, "Lua 5.5"));
}
