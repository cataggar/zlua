const std = @import("std");
const zlua = @import("zlua");

pub fn main(init: std.process.Init) !void {
    const arena_allocator = init.arena.allocator();

    const raw_args = try init.minimal.args.toSlice(arena_allocator);
    const args = try arena_allocator.alloc([]const u8, raw_args.len);
    for (raw_args, 0..) |arg, index| args[index] = arg;

    const zlua_exe = try defaultZluaPath(arena_allocator, args[0]);
    const exit_code = try zlua.testing.bench_runner.runCli(init.gpa, init.io, init.environ_map, zlua_exe, args[1..]);
    std.process.exit(exit_code);
}

fn defaultZluaPath(allocator: std.mem.Allocator, arg0: []const u8) ![]const u8 {
    const dir = std.fs.path.dirname(arg0) orelse return "zlua";
    return std.fs.path.join(allocator, &.{ dir, "zlua" });
}
