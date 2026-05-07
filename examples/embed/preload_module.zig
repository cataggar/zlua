const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var host = try lua.createModule("host");
    defer host.deinit();

    var double_fn = try lua.register("host_double", hostDouble);
    defer double_fn.deinit();
    try host.set("double", double_fn);
    try host.set("name", "host-module");
    try lua.preloadModule("host", host);

    var chunk = try lua.loadString(
        \\local host = require("host")
        \\return host.name, host.double(21)
    , .{ .name = "=preload_module" });
    defer chunk.deinit();

    const Result = zlua.Tuple(&.{ []const u8, i64 });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();

    std.debug.print("{s} {d}\n", .{ result.get(0), result.get(1) });
}

fn hostDouble(ctx: *zlua.Context) !void {
    const value = try ctx.arg(0, i64);
    try ctx.returnValues(value * 2);
}
