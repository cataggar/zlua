const std = @import("std");
const zlua = @import("zlua");

const Budget = struct {
    remaining: i64,

    fn spend(self: *@This(), amount: i64) i64 {
        self.remaining = @max(self.remaining - amount, 0);
        return self.remaining;
    }
};

fn newBudget(ctx: *zlua.Context, amount: i64) !zlua.Userdata(Budget) {
    var budget = try ctx.state().newUserdata(Budget, .{ .remaining = amount }, .{});
    errdefer budget.deinit();
    try budget.method("spend", Budget.spend);
    return budget;
}

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var new_budget = try lua.registerTyped("new_budget", newBudget);
    defer new_budget.deinit();
    try lua.setGlobal("new_budget", new_budget);

    var chunk = try lua.loadString(
        \\local budget = new_budget(25)
        \\assert(budget:spend(7) == 18)
        \\assert(budget:spend(20) == 0)
        \\return budget
    , .{ .name = "=typed_userdata_initializer" });
    defer chunk.deinit();

    var budget = try chunk.call(.{}, zlua.Userdata(Budget));
    defer budget.deinit();

    std.debug.print("remaining={d}\n", .{(try budget.ptr()).remaining});
}
