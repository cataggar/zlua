const std = @import("std");
const clua = @import("clua.zig");
const compile = @import("../compile.zig");
const errors = @import("../errors.zig");
const expected_failures = @import("expected_failures.zig");
const frontend = @import("../frontend.zig");
const metadata = @import("metadata.zig");
const normalizer = @import("normalizer.zig");
const process = @import("process.zig");
const runtime = @import("../runtime.zig");

const Options = struct {
    path: []const u8 = "tests/diff",
    clua: ?[]const u8 = null,
    stage: ?metadata.Stage = null,
    feature: ?[]const u8 = null,
    show_clua: bool = false,
    show_zlua: bool = false,
    gc_stress: bool = false,
    debug_errors: bool = false,
    timeout_ms: u64 = 5000,
};

const Counts = struct {
    passed: usize = 0,
    failed: usize = 0,
    expected_failed: usize = 0,
    skipped: usize = 0,
    flaky: usize = 0,
    timed_out: usize = 0,
    unexpected_failed: usize = 0,
};

pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    args: []const []const u8,
) !u8 {
    const options = parseArgs(args) catch |err| {
        try stderrPrint(io, "test-diff: {s}\n", .{@errorName(err)});
        return 2;
    };

    var tests = std.ArrayList([]u8).empty;
    defer {
        for (tests.items) |path| allocator.free(path);
        tests.deinit(allocator);
    }
    try discoverTests(allocator, io, options.path, &tests);
    std.mem.sort([]u8, tests.items, {}, lessThanString);

    var registry = try expected_failures.load(allocator, io, "tests/fixtures/expected_failures.toml");
    defer registry.deinit();

    const discovery = try clua.detect(allocator, io, environ_map, options.clua);
    defer discovery.deinit(allocator);

    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    const out = &writer.interface;

    var counts: Counts = .{};
    const cwd = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd);

    const clua_exe: ?[]const u8 = switch (discovery) {
        .found => |path| path,
        .missing => |message| blk: {
            try out.print("clua: missing ({s})\n", .{message});
            break :blk null;
        },
    };

    for (tests.items) |path| {
        try runOne(allocator, io, out, path, clua_exe, registry, options, cwd, environ_map, &counts);
    }

    try printSummary(out, counts);
    try out.flush();

    return if (counts.unexpected_failed == 0) 0 else 1;
}

fn parseArgs(args: []const []const u8) !Options {
    var options: Options = .{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--show-clua")) {
            options.show_clua = true;
        } else if (std.mem.eql(u8, arg, "--show-zlua")) {
            options.show_zlua = true;
        } else if (std.mem.eql(u8, arg, "--gc-stress")) {
            options.gc_stress = true;
        } else if (std.mem.eql(u8, arg, "--debug-errors")) {
            options.debug_errors = true;
        } else if (std.mem.eql(u8, arg, "--clua")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.clua = args[index];
        } else if (std.mem.startsWith(u8, arg, "--clua=")) {
            options.clua = arg[7..];
        } else if (std.mem.eql(u8, arg, "--bless")) {
            // Accepted for command stability; fixtures remain source-of-truth in milestone 0.
        } else if (std.mem.eql(u8, arg, "--update-expected-failures")) {
            // Accepted for command stability; registry updates are intentionally manual for now.
        } else if (std.mem.startsWith(u8, arg, "--stage=")) {
            options.stage = try metadata.parseStage(arg[8..]);
        } else if (std.mem.startsWith(u8, arg, "--feature=")) {
            options.feature = arg[10..];
        } else if (std.mem.startsWith(u8, arg, "--timeout-ms=")) {
            options.timeout_ms = try std.fmt.parseInt(u64, arg[13..], 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            options.path = arg;
        }
    }
    return options;
}

fn discoverTests(allocator: std.mem.Allocator, io: std.Io, root: []const u8, tests: *std.ArrayList([]u8)) !void {
    var dir = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.NotDir => {
            if (std.mem.endsWith(u8, root, ".lua")) {
                try tests.append(allocator, try allocator.dupe(u8, root));
            }
            return;
        },
        else => return err,
    };
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".lua")) continue;
        try tests.append(allocator, try std.fs.path.join(allocator, &.{ root, entry.path }));
    }
}

fn runOne(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
    path: []const u8,
    clua_exe: ?[]const u8,
    registry: expected_failures.Registry,
    options: Options,
    cwd: []const u8,
    environ_map: *const std.process.Environ.Map,
    counts: *Counts,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    defer allocator.free(source);

    const meta = try metadata.parse(source);
    if (options.stage) |stage| {
        if (stage != meta.stage) return;
    }
    if (options.feature) |feature| {
        if (!std.mem.eql(u8, feature, meta.feature)) return;
    }

    if (meta.expect == .skip) {
        counts.skipped += 1;
        try out.print("skip {s} ({s})\n", .{ path, meta.reason });
        return;
    }

    const expected_failure = meta.expect == .fail or registry.contains(path);
    const expected_reason = if (meta.reason.len > 0) meta.reason else registry.reason(path) orelse "expected failure";

    const exe = clua_exe orelse {
        counts.skipped += 1;
        try out.print("skip {s} (missing clua)\n", .{path});
        return;
    };

    var clua_result = try runCluaForStage(allocator, io, exe, path, meta.stage, options.timeout_ms);
    defer clua_result.deinit(allocator);
    var zlua_result = try runZluaForStage(allocator, io, source, meta.stage, options, environ_map);
    defer zlua_result.deinit(allocator);

    if (clua_result.timed_out or zlua_result.timed_out) counts.timed_out += 1;

    const same = try resultsEqual(allocator, clua_result, zlua_result, meta.stage, meta.normalize, cwd);
    if (same and !expected_failure) {
        counts.passed += 1;
        try out.print("pass {s}\n", .{path});
    } else if (!same and expected_failure) {
        counts.expected_failed += 1;
        try out.print("xfail {s} ({s})\n", .{ path, expected_reason });
        try maybeShowOutputs(out, clua_result, zlua_result, options);
    } else {
        counts.failed += 1;
        counts.unexpected_failed += 1;
        if (same) {
            try out.print("fail {s} (expected failure passed)\n", .{path});
        } else {
            try out.print("fail {s}\n", .{path});
            try printDiff(out, clua_result, zlua_result);
        }
        try maybeShowOutputs(out, clua_result, zlua_result, options);
    }
}

fn runCluaForStage(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    stage: metadata.Stage,
    timeout_ms: u64,
) !process.ProcessResult {
    return switch (stage) {
        .lex, .parse, .resolve, .compile => clua.runLoadfile(allocator, io, exe, path, timeout_ms),
        .runtime, .stdlib, .official => clua.runFile(allocator, io, exe, path, timeout_ms),
    };
}

fn runZluaForStage(
    allocator: std.mem.Allocator,
    io: std.Io,
    source: []const u8,
    stage: metadata.Stage,
    options: Options,
    environ_map: *const std.process.Environ.Map,
) !process.ProcessResult {
    return switch (stage) {
        .lex => runZluaLexStage(allocator, source),
        .parse => runZluaParseStage(allocator, source),
        .resolve => runZluaResolveStage(allocator, source),
        .compile => runZluaCompileStage(allocator, source),
        .runtime, .stdlib, .official => runtime.executeSourceWithOptions(allocator, source, .{
            .collect_after_instruction = options.gc_stress,
            .state = .{
                .io = io,
                .filesystem = .host_cwd,
                .environment = environ_map,
                .process = .disabled,
                .debug_errors = options.debug_errors,
            },
        }),
    };
}

fn runZluaLexStage(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    const tokens = frontend.lexer.lexWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot lex source");
    };
    allocator.free(tokens);
    return process.ownedResult(allocator, "", "", 0);
}

fn runZluaParseStage(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot parse source");
    };
    tree.deinit();
    return process.ownedResult(allocator, "", "", 0);
}

fn runZluaResolveStage(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot parse source");
    };
    defer tree.deinit();

    compile.resolver.resolveWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot resolve source");
    };
    return process.ownedResult(allocator, "", "", 0);
}

fn runZluaCompileStage(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot parse source");
    };
    defer tree.deinit();

    compile.resolver.resolveWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot resolve source");
    };

    var proto = compile.compileWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot compile source");
    };
    defer proto.deinit();

    return process.ownedResult(allocator, "", "", 0);
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

fn resultsEqual(
    allocator: std.mem.Allocator,
    clua_result: process.ProcessResult,
    zlua_result: process.ProcessResult,
    stage: metadata.Stage,
    normalize: metadata.Normalize,
    cwd: []const u8,
) !bool {
    if (stage == .lex or stage == .parse or stage == .resolve or stage == .compile) {
        return clua_result.exit_code == zlua_result.exit_code and
            clua_result.signal == zlua_result.signal and
            clua_result.timed_out == zlua_result.timed_out;
    }

    const clua_stdout = try normalizer.normalizeText(allocator, clua_result.stdout, normalize, cwd);
    defer allocator.free(clua_stdout);
    const zlua_stdout = try normalizer.normalizeText(allocator, zlua_result.stdout, normalize, cwd);
    defer allocator.free(zlua_stdout);
    const clua_stderr = try normalizer.normalizeText(allocator, clua_result.stderr, normalize, cwd);
    defer allocator.free(clua_stderr);
    const zlua_stderr = try normalizer.normalizeText(allocator, zlua_result.stderr, normalize, cwd);
    defer allocator.free(zlua_stderr);

    return clua_result.exit_code == zlua_result.exit_code and
        clua_result.signal == zlua_result.signal and
        clua_result.timed_out == zlua_result.timed_out and
        std.mem.eql(u8, clua_stdout, zlua_stdout) and
        std.mem.eql(u8, clua_stderr, zlua_stderr);
}

fn printDiff(out: anytype, clua_result: process.ProcessResult, zlua_result: process.ProcessResult) !void {
    try out.print("  clua exit={?} timeout={} signal={?}\n", .{ clua_result.exit_code, clua_result.timed_out, clua_result.signal });
    try out.print("  zlua exit={?} timeout={} signal={?}\n", .{ zlua_result.exit_code, zlua_result.timed_out, zlua_result.signal });
    if (!std.mem.eql(u8, clua_result.stdout, zlua_result.stdout)) {
        try out.print("--- clua stdout\n{s}\n+++ zlua stdout\n{s}\n", .{ clua_result.stdout, zlua_result.stdout });
    }
    if (!std.mem.eql(u8, clua_result.stderr, zlua_result.stderr)) {
        try out.print("--- clua stderr\n{s}\n+++ zlua stderr\n{s}\n", .{ clua_result.stderr, zlua_result.stderr });
    }
}

fn maybeShowOutputs(out: anytype, clua_result: process.ProcessResult, zlua_result: process.ProcessResult, options: Options) !void {
    if (options.show_clua) {
        try out.print("[clua stdout]\n{s}\n[clua stderr]\n{s}\n", .{ clua_result.stdout, clua_result.stderr });
    }
    if (options.show_zlua) {
        try out.print("[zlua stdout]\n{s}\n[zlua stderr]\n{s}\n", .{ zlua_result.stdout, zlua_result.stderr });
    }
}

fn printSummary(out: anytype, counts: Counts) !void {
    try out.print(
        \\summary:
        \\  passed={d}
        \\  failed={d}
        \\  expected_failed={d}
        \\  skipped={d}
        \\  flaky={d}
        \\  timed_out={d}
        \\  unexpected_failed={d}
        \\
    , .{
        counts.passed,
        counts.failed,
        counts.expected_failed,
        counts.skipped,
        counts.flaky,
        counts.timed_out,
        counts.unexpected_failed,
    });
}

fn lessThanString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "argument parser accepts stage and feature" {
    const args = [_][]const u8{ "tests/diff", "--stage=parse", "--feature=syntax", "--debug-errors" };
    const options = try parseArgs(&args);
    try std.testing.expectEqual(metadata.Stage.parse, options.stage.?);
    try std.testing.expect(std.mem.eql(u8, options.feature.?, "syntax"));
    try std.testing.expect(options.debug_errors);
}
