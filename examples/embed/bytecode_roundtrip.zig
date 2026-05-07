const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var compiler = try zlua.State.init(allocator, .{});
    defer compiler.deinit();

    var chunk = try compiler.loadString(
        \\return greeting .. ", " .. ...
    , .{ .name = "=bytecode_roundtrip" });
    defer chunk.deinit();

    const bytecode = try chunk.dumpBytecode(.{ .strip_debug = true });
    defer compiler.allocator().free(bytecode);

    var runner = try zlua.State.init(allocator, .{});
    defer runner.deinit();

    var env = try runner.createTable(.{ .hash_hint = 1 });
    defer env.deinit();
    try env.set("greeting", "hello");

    var cached = try runner.loadBytecode(bytecode, .{ .environment = env });
    defer cached.deinit();

    const message = try cached.call(.{"bytecode"}, []const u8);
    std.debug.print("{s}\n", .{message});
}
