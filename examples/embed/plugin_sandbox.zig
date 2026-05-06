const std = @import("std");
const zlua = @import("zlua");

const plugin_source =
    \\emit({ kind = "loaded", version = 1 })
    \\print("plugin ready")
;

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    const files = [_]zlua.api.MemoryFile{
        .{ .path = "plugin.lua", .contents = plugin_source },
    };

    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();

    var lua = try zlua.State.init(allocator, .{
        .stdlib = .safe,
        .capabilities = .{
            .io = .{ .stdout = &output.writer },
            .filesystem = .{ .memory = &files },
            .clock = .{ .fixed = 0 },
        },
        .limits = .{
            .max_memory = 16 * 1024 * 1024,
            .max_instructions = 1_000_000,
        },
    });
    defer lua.deinit();

    try lua.register("emit", emit);
    try lua.doFile("plugin.lua", .{ .name = "@plugin.lua" });

    std.debug.print("{s}", .{output.writer.buffered()});
}

fn emit(ctx: *zlua.Context) !void {
    var event = try ctx.arg(0, zlua.Table);
    defer event.deinit();

    const kind = try event.get("kind", []const u8);
    const version = try event.get("version", i64);
    if (!std.mem.eql(u8, kind, "loaded") or version != 1) {
        return ctx.raise("unexpected plugin event");
    }

    try ctx.returnValues(.{});
}
