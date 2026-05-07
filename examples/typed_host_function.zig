const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var host_add = try lua.registerTyped("host_add", hostAdd);
    defer host_add.deinit();
    try lua.setGlobal("host_add", host_add);

    var chunk = try lua.loadString(
        \\return host_add(20, 22)
    , .{ .name = "=typed_host_function" });
    defer chunk.deinit();

    const sum = try chunk.call(.{}, i64);
    std.debug.print("typed host_add(20, 22) = {d}\n", .{sum});
}

fn hostAdd(lhs: i64, rhs: i64) i64 {
    return lhs + rhs;
}
