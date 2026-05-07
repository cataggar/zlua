const std = @import("std");
const zlua = @import("zlua");

const script =
    \\local report = assert(io.open('report.tmp', 'w'))
    \\assert(report:write('status: started\n'))
    \\assert(report:close())
    \\
    \\report = assert(io.open('report.tmp', 'a'))
    \\assert(report:write('status: complete\n'))
    \\assert(report:close())
    \\
    \\assert(os.rename('report.tmp', 'report.txt'))
;

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var filesystem = zlua.MemoryFilesystem.init(allocator);
    defer filesystem.deinit();
    try filesystem.writeFile("worker.lua", script);

    var lua = try zlua.State.init(allocator, .{
        .stdlib = .full,
        .capabilities = .{
            .filesystem = .{ .memory_rw = &filesystem },
            .clock = .{ .fixed = 0 },
        },
    });
    defer lua.deinit();

    try lua.doFile("worker.lua", .{ .name = "@worker.lua" });

    const report = try filesystem.readFileAlloc(allocator, "report.txt");
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}
