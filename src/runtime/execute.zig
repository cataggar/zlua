const std = @import("std");
const compile = @import("../compile.zig");
const errors = @import("../errors.zig");
const frontend = @import("../frontend.zig");
const process = @import("../testing/process.zig");
const state_mod = @import("state.zig");

pub const ExecuteOptions = struct {
    collect_after_instruction: bool = false,
    state: state_mod.StateOptions = .{},
};

pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    return executeSourceWithOptions(allocator, source, .{});
}

pub fn executeSourceWithOptions(allocator: std.mem.Allocator, source: []const u8, options: ExecuteOptions) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot load source");
    };
    defer tree.deinit();

    compile.resolver.resolveWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot resolve source");
    };

    var proto = compile.compileWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot compile source");
    };
    defer proto.deinit();

    var state = try state_mod.State.initWithOptions(allocator, options.state);
    defer state.deinit();
    state.collect_after_instruction = options.collect_after_instruction;
    state.execute(&proto) catch |err| {
        const detail = try state.errorDetailAlloc(allocator, err);
        defer allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "{s}\n", .{detail});
        defer allocator.free(message);
        var stderr = std.ArrayList(u8).empty;
        errdefer stderr.deinit(allocator);
        try stderr.appendSlice(allocator, state.stderr.items);
        try stderr.appendSlice(allocator, message);
        return .{
            .stdout = try allocator.dupe(u8, state.stdout.items),
            .stderr = try stderr.toOwnedSlice(allocator),
            .exit_code = 1,
            .signal = null,
            .timed_out = false,
        };
    };

    return .{
        .stdout = try allocator.dupe(u8, state.stdout.items),
        .stderr = try allocator.dupe(u8, state.stderr.items),
        .exit_code = 0,
        .signal = null,
        .timed_out = false,
    };
}

fn sourceFailureResult(allocator: std.mem.Allocator, source: []const u8, diagnostic: ?errors.Diagnostic, fallback: []const u8) !process.ProcessResult {
    const rendered = if (diagnostic) |diag|
        try errors.renderLoadDiagnostic(allocator, null, source, diag)
    else
        try allocator.dupe(u8, fallback);
    defer allocator.free(rendered);
    const message = try std.fmt.allocPrint(allocator, "{s}\n", .{rendered});
    defer allocator.free(message);
    return process.ownedResult(allocator, "", message, 1);
}
