const std = @import("std");
const zlua = @import("zlua");

const Counter = struct {
    value: i64,

    fn inc(self: *@This(), amount: i64) i64 {
        self.value += amount;
        return self.value;
    }
};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdata(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();

    try counter.method("inc", Counter.inc);
    try lua.setGlobal("counter", counter);

    try lua.doString(
        \\assert(counter:inc(2) == 2)
        \\assert(counter:inc(3) == 5)
    , .{ .name = "=userdata_counter" });

    std.debug.print("counter={d}\n", .{(try counter.ptr()).value});
}
