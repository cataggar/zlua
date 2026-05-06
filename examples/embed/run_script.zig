const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local name = ...
        \\return "hello, " .. name
    , .{ .name = "=run_script" });
    defer chunk.deinit();

    const message = try chunk.call(.{"zlua"}, []const u8);
    std.debug.print("{s}\n", .{message});
}
