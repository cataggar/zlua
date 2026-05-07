const std = @import("std");
const zlua = @import("zlua");

pub fn main(init: std.process.Init) !void {
    const arena_allocator = init.arena.allocator();
    const raw_args = try init.minimal.args.toSlice(arena_allocator);
    const args = try arena_allocator.alloc([]const u8, raw_args.len);
    for (raw_args, 0..) |arg, index| args[index] = arg;

    const exit_code = try zlua.testing.c_api_runner.runCli(init.gpa, init.io, args[1..]);
    std.process.exit(exit_code);
}
