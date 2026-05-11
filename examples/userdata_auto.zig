const std = @import("std");
const zlua = @import("zlua");

const Counter = struct {
    value: i64,

    pub fn inc(self: *@This(), ctx: *zlua.Context, amount: i64) !i64 {
        _ = ctx.state();
        self.value += amount;
        return self.value;
    }

    pub fn get(self: *const @This()) i64 {
        return self.value;
    }

    fn reset(self: *@This()) void {
        self.value = 0;
    }

    pub fn __tostring(self: *const @This()) []const u8 {
        _ = self;
        return "Counter";
    }
};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdataAuto(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);

    try lua.doString(
        \\assert(counter:inc(2) == 2)
        \\assert(counter:get() == 2)
        \\assert(counter.reset == nil)
        \\assert(tostring(counter) == 'Counter')
    , .{ .name = "=userdata_auto" });

    std.debug.print("counter={d}\n", .{(try counter.ptr()).value});
}
