const std = @import("std");
const zlua = @import("zlua");

const CliError = error{Usage};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena_allocator = init.arena.allocator();

    const raw_args = try init.minimal.args.toSlice(arena_allocator);
    const args = try arena_allocator.alloc([]const u8, raw_args.len);
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

    if (std.mem.eql(u8, command, "--debug-errors") or std.mem.eql(u8, command, "--") or std.mem.eql(u8, command, "-e") or std.mem.startsWith(u8, command, "-e")) {
        const exit_code = try runCliProgram(arena_allocator, io, init.environ_map, args[1..]);
        std.process.exit(exit_code);
    }

    if (std.mem.startsWith(u8, command, "-")) {
        try stderrPrint(io, "unknown option: {s}\n", .{command});
        return CliError.Usage;
    }

    const exit_code = try runCliProgram(arena_allocator, io, init.environ_map, args[1..]);
    std.process.exit(exit_code);
}

fn runCliProgram(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    args: []const []const u8,
) !u8 {
    var evals = std.ArrayList([]const u8).empty;
    defer evals.deinit(allocator);

    var script_path: ?[]const u8 = null;
    var script_args: []const []const u8 = &.{};
    var debug_errors = false;
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--")) {
            index += 1;
            if (index < args.len) {
                script_path = args[index];
                script_args = args[index + 1 ..];
            }
            break;
        } else if (std.mem.eql(u8, arg, "--debug-errors")) {
            debug_errors = true;
        } else if (std.mem.eql(u8, arg, "-e")) {
            index += 1;
            if (index >= args.len) {
                try stderrPrint(io, "-e requires an argument\n", .{});
                return 2;
            }
            try evals.append(allocator, args[index]);
        } else if (std.mem.startsWith(u8, arg, "-e")) {
            try evals.append(allocator, arg[2..]);
        } else if (std.mem.startsWith(u8, arg, "-")) {
            try stderrPrint(io, "unknown option: {s}\n", .{arg});
            return 2;
        } else {
            script_path = arg;
            script_args = args[index + 1 ..];
            break;
        }
    }

    if (evals.items.len == 0 and script_path == null) {
        try printUsage(io);
        return 0;
    }

    const state_allocator = std.heap.smp_allocator;

    var state = try zlua.runtime.State.initWithOptions(state_allocator, .{
        .io = io,
        .filesystem = .host_cwd,
        .environment = environ_map,
        .process = .enabled,
        .debug_errors = debug_errors,
    });
    defer state.deinit();

    try installArgTable(state_allocator, &state, script_path, script_args);

    for (evals.items) |source| {
        if (try executeChunk(state_allocator, &state, source)) |exit_code| return exit_code;
    }

    if (script_path) |path| {
        const source = std.Io.Dir.cwd().readFileAlloc(io, path, state_allocator, .limited(1024 * 1024)) catch |err| {
            try stderrPrint(io, "cannot read script {s}: {s}\n", .{ path, @errorName(err) });
            return 1;
        };
        defer state_allocator.free(source);
        const source_name = try std.fmt.allocPrint(state_allocator, "@{s}", .{path});
        defer state_allocator.free(source_name);
        if (try executeChunkNamed(state_allocator, &state, stripInitialShebang(source), source_name)) |exit_code| return exit_code;
    }

    try stdoutWrite(io, state.stdout.items);
    try stderrWrite(io, state.stderr.items);
    return 0;
}

fn executeChunk(allocator: std.mem.Allocator, state: *zlua.runtime.State, source: []const u8) !?u8 {
    state.executeSourceChunk(source) catch |err| {
        const detail = try state.errorDetailAlloc(allocator, err);
        defer allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "{s}\n", .{detail});
        defer allocator.free(message);
        try stdoutWrite(state.options.io.?, state.stdout.items);
        try stderrWrite(state.options.io.?, state.stderr.items);
        try stderrWrite(state.options.io.?, message);
        return 1;
    };
    return null;
}

fn executeChunkNamed(allocator: std.mem.Allocator, state: *zlua.runtime.State, source: []const u8, source_name: []const u8) !?u8 {
    state.executeSourceChunkNamed(source, source_name) catch |err| {
        const detail = try state.errorDetailAlloc(allocator, err);
        defer allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "{s}\n", .{detail});
        defer allocator.free(message);
        try stdoutWrite(state.options.io.?, state.stdout.items);
        try stderrWrite(state.options.io.?, state.stderr.items);
        try stderrWrite(state.options.io.?, message);
        return 1;
    };
    return null;
}

fn installArgTable(
    allocator: std.mem.Allocator,
    state: *zlua.runtime.State,
    script_path: ?[]const u8,
    script_args: []const []const u8,
) !void {
    const arg_value = try state.newTableWithHints(@intCast(script_args.len + 1), 0);
    const table = arg_value.table;
    if (script_path) |path| {
        try table.set(allocator, .{ .integer = 0 }, .{ .string = try state.intern(path) });
    }
    for (script_args, 0..) |arg, arg_index| {
        try table.set(allocator, .{ .integer = @intCast(arg_index + 1) }, .{ .string = try state.intern(arg) });
    }
    try state.putGlobal("arg", arg_value);
}

fn stripInitialShebang(source: []const u8) []const u8 {
    if (source.len == 0 or source[0] != '#') return source;
    const newline = std.mem.indexOfScalar(u8, source, '\n') orelse return "";
    return source[newline + 1 ..];
}

fn printVersion(io: std.Io) !void {
    try stdoutPrint(io, "zlua {s} ({s} target)\n", .{ zlua.version, zlua.lua_target_version });
}

fn printUsage(io: std.Io) !void {
    try stdoutPrint(io,
        \\Usage: zlua [options] [script [args...]]
        \\
        \\Options:
        \\  --version, -v
        \\  --debug-errors <script>
        \\  -e 'chunk' [script [args...]]
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

test "strips initial shebang for script execution" {
    try std.testing.expect(std.mem.eql(u8, stripInitialShebang("#!lua\nprint(1)"), "print(1)"));
}
