const std = @import("std");
const clua = @import("clua.zig");
const process = @import("process.zig");

const expected_archive_sha256 = "5e47bbfad7db2965d69580e918ee64edeb8d8d32de404b8dae9ce5c6d76a1472";
const archive_path = "vendor/lua-5.5.0-tests.tar.gz";

const Options = struct {
    suite_path: []const u8 = "tests/official/lua-5.5.0-tests",
    clua: ?[]const u8 = null,
    zlua: ?[]const u8 = null,
    mode: Mode = .basic,
    quick: bool = false,
    show_clua: bool = false,
    show_zlua: bool = false,
    timeout_ms: u64 = 0,
};

const Mode = enum { basic, complete, internal };
const Runner = enum { clua, zlua };

const official_basic_prelude = "_U=true; _soft=true; _port=true; _nomsg=true; T=nil; ARG=arg";
const official_complete_prelude = "T=rawget(_G, 'T'); ARG=arg";

const Counts = struct {
    clua_passed: usize = 0,
    clua_failed: usize = 0,
    zlua_passed: usize = 0,
    categorized_failed: usize = 0,
    skipped: usize = 0,
    timed_out: usize = 0,
    unexpected_failed: usize = 0,
};

pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    zlua_exe: []const u8,
    args: []const []const u8,
) !u8 {
    const options = parseArgs(args) catch |err| {
        try stderrPrint(io, "test-official: {s}\n", .{@errorName(err)});
        return 2;
    };

    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    const out = &writer.interface;

    const actual_hash = verifyArchive(allocator, io) catch |err| {
        try out.print("archive: fail {s} ({s})\n", .{ archive_path, @errorName(err) });
        try out.flush();
        return 1;
    };
    defer allocator.free(actual_hash);
    try out.print("archive: ok {s} sha256={s}\n", .{ archive_path, actual_hash });

    const discovery = try clua.detect(allocator, io, environ_map, options.clua);
    defer discovery.deinit(allocator);

    const clua_exe = switch (discovery) {
        .found => |path| path,
        .missing => |message| {
            try out.print("clua: missing ({s})\n", .{message});
            try out.flush();
            return 1;
        },
    };

    var counts: Counts = .{};
    try runIndividualSuite(allocator, io, out, clua_exe, options.zlua orelse zlua_exe, options, &counts);

    try printSummary(out, counts);
    try out.flush();
    return if (counts.unexpected_failed == 0) 0 else 1;
}

fn parseArgs(args: []const []const u8) !Options {
    var options: Options = .{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--quick")) {
            options.quick = true;
        } else if (std.mem.eql(u8, arg, "--show-clua")) {
            options.show_clua = true;
        } else if (std.mem.eql(u8, arg, "--show-zlua")) {
            options.show_zlua = true;
        } else if (std.mem.eql(u8, arg, "--clua")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.clua = args[index];
        } else if (std.mem.startsWith(u8, arg, "--clua=")) {
            options.clua = arg[7..];
        } else if (std.mem.eql(u8, arg, "--zlua")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.zlua = args[index];
        } else if (std.mem.startsWith(u8, arg, "--zlua=")) {
            options.zlua = arg[7..];
        } else if (std.mem.startsWith(u8, arg, "--mode=")) {
            options.mode = try parseMode(arg[7..]);
        } else if (std.mem.startsWith(u8, arg, "--timeout-ms=")) {
            options.timeout_ms = try std.fmt.parseInt(u64, arg[13..], 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            options.suite_path = arg;
        }
    }
    return options;
}

fn parseMode(value: []const u8) !Mode {
    inline for (@typeInfo(Mode).@"enum".fields) |field| {
        if (std.mem.eql(u8, value, field.name)) return @field(Mode, field.name);
    }
    return error.InvalidMode;
}

fn verifyArchive(allocator: std.mem.Allocator, io: std.Io) ![]u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, archive_path, allocator, .limited(1024 * 1024));
    defer allocator.free(bytes);

    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    if (!std.mem.eql(u8, &hex, expected_archive_sha256)) return error.ChecksumMismatch;
    return allocator.dupe(u8, &hex);
}

fn runIndividualSuite(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
    clua_exe: []const u8,
    zlua_exe: []const u8,
    options: Options,
    counts: *Counts,
) !void {
    if (options.mode == .internal) {
        counts.skipped += 1;
        try out.print("skip internal (testC-enabled CLua/zlua builds are not wired yet)\n", .{});
        return;
    }

    if (options.quick) {
        try out.print("mode: quick {s} official files (excluding heavy.lua)\n", .{@tagName(options.mode)});
    } else {
        try out.print("mode: {s} official files\n", .{@tagName(options.mode)});
    }
    var files = std.ArrayList([]u8).empty;
    defer {
        for (files.items) |file| allocator.free(file);
        files.deinit(allocator);
    }

    try discoverOfficialFiles(allocator, io, options.suite_path, &files);
    std.mem.sort([]u8, files.items, {}, lessThanString);

    for (files.items) |file| {
        if (options.quick and std.mem.eql(u8, std.fs.path.basename(file), "heavy.lua")) {
            counts.skipped += 1;
            try out.print("skip heavy.lua (memory-stress test; run test-official-heavy)\n", .{});
            continue;
        }

        var clua_result = try runOfficialFile(allocator, io, clua_exe, file, options, .clua);
        defer clua_result.deinit(allocator);
        var zlua_result = try runOfficialFile(allocator, io, zlua_exe, file, options, .zlua);
        defer zlua_result.deinit(allocator);

        if (clua_result.timed_out or zlua_result.timed_out) counts.timed_out += 1;
        if (clua_result.success()) {
            counts.clua_passed += 1;
        } else {
            counts.clua_failed += 1;
            counts.unexpected_failed += 1;
            try out.print("fail clua {s}\n", .{std.fs.path.basename(file)});
            try printProcess(out, "clua", clua_result, true);
            continue;
        }

        if (zlua_result.success()) {
            counts.zlua_passed += 1;
            try out.print("pass {s}\n", .{std.fs.path.basename(file)});
        } else {
            counts.categorized_failed += 1;
            try out.print("xfail {s} feature={s}\n", .{ std.fs.path.basename(file), classifyFailure(zlua_result) });
            try printProcess(out, "zlua", zlua_result, options.show_zlua);
        }
        try printProcess(out, "clua", clua_result, options.show_clua);
    }
}

fn discoverOfficialFiles(allocator: std.mem.Allocator, io: std.Io, suite_path: []const u8, files: *std.ArrayList([]u8)) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, suite_path, .{ .iterate = true });
    defer dir.close(io);

    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".lua")) continue;
        if (std.mem.eql(u8, entry.name, "all.lua")) continue;
        try files.append(allocator, try std.fs.path.join(allocator, &.{ suite_path, entry.name }));
    }
}

fn runOfficialFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    file: []const u8,
    options: Options,
    runner: Runner,
) !process.ProcessResult {
    const prelude = switch (options.mode) {
        .basic => official_basic_prelude,
        .complete => official_complete_prelude,
        .internal => unreachable,
    };
    const argv = [_][]const u8{ exe, "-e", prelude, std.fs.path.basename(file) };
    return process.runProcess(allocator, io, &argv, .{
        .cwd = options.suite_path,
        .timeout_ms = options.timeout_ms,
        .max_output_bytes = 4 * 1024 * 1024,
        .expand_arg0 = runner == .zlua,
    });
}

fn lessThanString(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn classifyFailure(result: process.ProcessResult) []const u8 {
    if (contains(result.stderr, "parser") or contains(result.stdout, "parser")) return "frontend.parse";
    if (contains(result.stderr, "resolver") or contains(result.stdout, "resolver")) return "resolve";
    if (contains(result.stderr, "compiler") or contains(result.stdout, "compiler")) return "compile";
    if (contains(result.stderr, "filesystem") or contains(result.stderr, "cannot open")) return "system-stdlib.filesystem";
    if (contains(result.stderr, "process") or contains(result.stderr, "execute")) return "system-stdlib.process";
    if (contains(result.stderr, "unsupported")) return "runtime.unsupported";
    if (contains(result.stderr, "runtime error")) return "runtime";
    return "official-suite";
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn printProcess(out: anytype, label: []const u8, result: process.ProcessResult, show_output: bool) !void {
    if (result.timed_out) {
        try out.print("  {s} exit={?} timeout=true signal={?}\n", .{ label, result.exit_code, result.signal });
    } else {
        try out.print("  {s} exit={?} signal={?}\n", .{ label, result.exit_code, result.signal });
    }
    if (show_output) {
        try out.print("[{s} stdout]\n{s}\n[{s} stderr]\n{s}\n", .{ label, result.stdout, label, result.stderr });
    }
}

fn printSummary(out: anytype, counts: Counts) !void {
    try out.print(
        \\summary:
        \\  clua_passed={d}
        \\  clua_failed={d}
        \\  zlua_passed={d}
        \\  categorized_failed={d}
        \\  skipped={d}
        \\  timed_out={d}
        \\  unexpected_failed={d}
        \\
    , .{
        counts.clua_passed,
        counts.clua_failed,
        counts.zlua_passed,
        counts.categorized_failed,
        counts.skipped,
        counts.timed_out,
        counts.unexpected_failed,
    });
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "argument parser accepts quick and complete mode" {
    const args = [_][]const u8{ "--quick", "--mode=complete", "--timeout-ms=10" };
    const options = try parseArgs(&args);
    try std.testing.expect(options.quick);
    try std.testing.expectEqual(Mode.complete, options.mode);
    try std.testing.expectEqual(@as(u64, 10), options.timeout_ms);
}

test "failure classifier maps frontend errors" {
    var result = try process.ownedResult(std.testing.allocator, "", "zlua parser rejected official file\n", 1);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.eql(u8, classifyFailure(result), "frontend.parse"));
}
