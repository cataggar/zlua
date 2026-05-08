const std = @import("std");
const zlua = @import("zlua");

const Budget = struct {
    remaining: i64,
    spent: i64,

    fn spend(self: *@This(), amount: i64) i64 {
        self.remaining = @max(self.remaining - amount, 0);
        self.spent += amount;
        return self.remaining;
    }

    fn refund(self: *@This(), amount: i64) i64 {
        self.remaining += amount;
        self.spent = @max(self.spent - amount, 0);
        return self.remaining;
    }

    fn spentTotal(self: *@This()) i64 {
        return self.spent;
    }

    fn available(self: *@This()) i64 {
        return self.remaining;
    }
};

fn newBudget(ctx: *zlua.Context, amount: i64) !zlua.Userdata(Budget) {
    var budget = try ctx.state().newUserdata(Budget, .{ .remaining = amount, .spent = 0 }, .{});
    errdefer budget.deinit();
    try budget.method("spend", Budget.spend);
    try budget.method("refund", Budget.refund);
    try budget.method("spent", Budget.spentTotal);
    try budget.method("available", Budget.available);
    return budget;
}

fn percent(part: f64, whole: f64) f64 {
    if (whole == 0) return 0;
    return part / whole * 100;
}

fn hostAudit(ctx: *zlua.Context) !void {
    const label = try ctx.arg(0, []const u8);
    const amount = try ctx.arg(1, i64);
    if (amount < 0) return ctx.raise("audit amounts must be non-negative");

    std.debug.print("audit: {s}={d}\n", .{ label, amount });
    try ctx.returnValues(.{ true, "recorded" });
}

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    try lua.setGlobal("settings", .{
        .name = "zlua-test integration",
        .features = &.{ "globals", "modules", "callbacks", "userdata" },
    });

    var rules = try lua.createModule("rules");
    defer rules.deinit();
    try rules.set("starting_budget", 150);
    try rules.set("warning_at", 40);
    try lua.preloadModule("rules", rules);

    try lua.addMemoryFile("plugins/planner.lua",
        \\local M = {}
        \\function M.plan(items)
        \\  local total = 0
        \\  for i = 1, #items do
        \\    total = total + items[i].cost
        \\  end
        \\  return { name = 'weekend trip', items = items, total = total }
        \\end
        \\return M
    );
    try lua.setPackagePath("plugins/?.lua");

    var new_budget = try lua.registerTyped("new_budget", newBudget);
    defer new_budget.deinit();
    try lua.setGlobal("new_budget", new_budget);

    var percent_fn = try lua.registerTyped("percent", percent);
    defer percent_fn.deinit();
    try lua.setGlobal("percent", percent_fn);

    var audit = try lua.register("host_audit", hostAudit);
    defer audit.deinit();
    try lua.setGlobal("host_audit", audit);

    var chunk = try lua.loadString(
        \\local rules = require('rules')
        \\local planner = require('planner')
        \\assert(settings.features[4] == 'userdata')
        \\
        \\local budget = new_budget(rules.starting_budget)
        \\budget:spend(37)
        \\budget:refund(5)
        \\
        \\local plan = planner.plan({
        \\  { name = 'train', cost = 41 },
        \\  { name = 'lunch', cost = 18 },
        \\  { name = 'museum', cost = 24 },
        \\})
        \\
        \\for i = 1, #plan.items do
        \\  budget:spend(plan.items[i].cost)
        \\end
        \\
        \\local ok, audit_label = host_audit('spent', budget:spent())
        \\assert(ok == true and audit_label == 'recorded')
        \\
        \\return {
        \\  title = settings.name,
        \\  plan = plan.name,
        \\  planned = plan.total,
        \\  spent = budget:spent(),
        \\  remaining = budget:available(),
        \\  used_percent = percent(budget:spent(), rules.starting_budget),
        \\  warned = budget:available() <= rules.warning_at,
        \\}, function(extra)
        \\  return budget:spend(extra)
        \\end, budget
    , .{ .name = "=zlua_test_integration" });
    defer chunk.deinit();

    const Result = zlua.Tuple(&.{ zlua.Table, zlua.Function, zlua.Userdata(Budget) });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();

    try lua.collect();

    const report = result.get(0);
    const spend_more = result.get(1);
    const budget = result.get(2);

    const after_extra = try spend_more.call(.{6}, i64);

    std.debug.print(
        "{s}: {s}, planned={d}, spent={d}, remaining={d}, used={d:.1}%, warned={}, after_extra={d}, userdata_remaining={d}\n",
        .{
            try report.get("title", []const u8),
            try report.get("plan", []const u8),
            try report.get("planned", i64),
            try report.get("spent", i64),
            try report.get("remaining", i64),
            try report.get("used_percent", f64),
            try report.get("warned", bool),
            after_extra,
            (try budget.ptr()).remaining,
        },
    );

    var failing = try lua.loadString("return host_audit('refund', -1)", .{ .name = "=zlua_test_protected_error" });
    defer failing.deinit();

    switch (try failing.protectedCall(.{}, void)) {
        .ok => return error.ExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            std.debug.print("protected error: {s}\n", .{message});
        },
    }
}
