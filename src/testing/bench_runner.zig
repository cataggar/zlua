const std = @import("std");
const clua = @import("clua.zig");
const process = @import("process.zig");

const default_bench_root = "tests/bench";
const default_iterations = 5;
const default_warmup = 1;
const default_timeout_ms = 60_000;
const max_output_bytes = 1024 * 1024;

const Expect = enum { pass, fail, skip };

const Options = struct {
    bench_root: []const u8 = default_bench_root,
    selectors: []const []const u8 = &.{},
    clua: ?[]const u8 = null,
    zlua: ?[]const u8 = null,
    list: bool = false,
    iterations: ?usize = null,
    warmup: ?usize = null,
    timeout_ms: ?u64 = null,
    category: ?[]const u8 = null,
    debug_errors: bool = false,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        allocator.free(self.selectors);
    }
};

const Benchmark = struct {
    path: []u8,
    name: []u8,
    category: []u8,
    iterations: usize,
    warmup: usize,
    timeout_ms: u64,
    expect: Expect,
    reason: []u8,

    fn deinit(self: *Benchmark, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
        allocator.free(self.name);
        allocator.free(self.category);
        allocator.free(self.reason);
        self.* = undefined;
    }
};

const ParsedMetadata = struct {
    name: ?[]const u8 = null,
    category: []const u8 = "misc",
    iterations: usize = default_iterations,
    warmup: usize = default_warmup,
    timeout_ms: u64 = default_timeout_ms,
    expect: Expect = .pass,
    reason: []const u8 = "",
};

const TimedRun = struct {
    result: process.ProcessResult,
    elapsed_ns: u64,
};

const Counts = struct {
    benchmarked: usize = 0,
    skipped: usize = 0,
    failed: usize = 0,
    timed_out: usize = 0,
};

pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    zlua_exe: []const u8,
    args: []const []const u8,
) !u8 {
    const options = parseArgs(allocator, args) catch |err| {
        try stderrPrint(io, "test-bench: {s}\n", .{@errorName(err)});
        return 2;
    };
    defer options.deinit(allocator);

    var benchmarks = std.ArrayList(Benchmark).empty;
    defer {
        for (benchmarks.items) |*benchmark| benchmark.deinit(allocator);
        benchmarks.deinit(allocator);
    }
    try discoverBenchmarks(allocator, io, options.bench_root, &benchmarks);
    std.mem.sort(Benchmark, benchmarks.items, {}, lessThanBenchmarkPath);

    var selected = std.ArrayList(usize).empty;
    defer selected.deinit(allocator);
    if (!try resolveSelectors(allocator, io, benchmarks.items, options, &selected)) return 2;

    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    const out = &writer.interface;

    if (options.list) {
        try printList(out, benchmarks.items, selected.items);
        try out.flush();
        return 0;
    }

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

    const zlua_path = options.zlua orelse zlua_exe;
    if (!try validateZlua(allocator, io, zlua_path, options.debug_errors)) {
        try out.print("zlua: missing or not runnable ({s})\n", .{zlua_path});
        try out.flush();
        return 1;
    }

    var counts: Counts = .{};
    for (selected.items) |index| {
        try runOne(allocator, io, out, benchmarks.items[index], clua_exe, zlua_path, options, &counts);
    }
    try printSummary(out, counts);
    try out.flush();
    return if (counts.failed == 0 and counts.timed_out == 0) 0 else 1;
}

fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    var options: Options = .{};
    var selectors = std.ArrayList([]const u8).empty;
    errdefer selectors.deinit(allocator);

    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--list")) {
            options.list = true;
        } else if (std.mem.eql(u8, arg, "--debug-errors")) {
            options.debug_errors = true;
        } else if (std.mem.eql(u8, arg, "--no-warmup")) {
            options.warmup = 0;
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
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.iterations = try parsePositiveUsize(args[index]);
        } else if (std.mem.startsWith(u8, arg, "--iterations=")) {
            options.iterations = try parsePositiveUsize(arg[13..]);
        } else if (std.mem.eql(u8, arg, "--warmup")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.warmup = try std.fmt.parseInt(usize, args[index], 10);
        } else if (std.mem.startsWith(u8, arg, "--warmup=")) {
            options.warmup = try std.fmt.parseInt(usize, arg[9..], 10);
        } else if (std.mem.eql(u8, arg, "--timeout-ms")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.timeout_ms = try parsePositiveU64(args[index]);
        } else if (std.mem.startsWith(u8, arg, "--timeout-ms=")) {
            options.timeout_ms = try parsePositiveU64(arg[13..]);
        } else if (std.mem.eql(u8, arg, "--category")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.category = args[index];
        } else if (std.mem.startsWith(u8, arg, "--category=")) {
            options.category = arg[11..];
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            try selectors.append(allocator, arg);
        }
    }

    options.selectors = try selectors.toOwnedSlice(allocator);
    return options;
}

fn parsePositiveUsize(value: []const u8) !usize {
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidOptionValue;
    return parsed;
}

fn parsePositiveU64(value: []const u8) !u64 {
    const parsed = try std.fmt.parseInt(u64, value, 10);
    if (parsed == 0) return error.InvalidOptionValue;
    return parsed;
}

fn discoverBenchmarks(allocator: std.mem.Allocator, io: std.Io, root: []const u8, benchmarks: *std.ArrayList(Benchmark)) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true });
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".lua")) continue;
        const path = try std.fs.path.join(allocator, &.{ root, entry.path });
        errdefer allocator.free(path);
        try appendBenchmark(allocator, io, benchmarks, path);
    }
}

fn appendBenchmark(allocator: std.mem.Allocator, io: std.Io, benchmarks: *std.ArrayList(Benchmark), owned_path: []u8) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(io, owned_path, allocator, .limited(max_output_bytes));
    defer allocator.free(source);

    const parsed = try parseMetadata(source);
    if ((parsed.expect == .skip or parsed.expect == .fail) and parsed.reason.len == 0) return error.MissingBenchmarkReason;
    if (parsed.category.len == 0) return error.InvalidMetadataValue;

    errdefer allocator.free(owned_path);
    const name_source = parsed.name orelse owned_path;
    const benchmark: Benchmark = .{
        .path = owned_path,
        .name = try allocator.dupe(u8, name_source),
        .category = try allocator.dupe(u8, parsed.category),
        .iterations = parsed.iterations,
        .warmup = parsed.warmup,
        .timeout_ms = parsed.timeout_ms,
        .expect = parsed.expect,
        .reason = try allocator.dupe(u8, parsed.reason),
    };
    errdefer {
        allocator.free(benchmark.name);
        allocator.free(benchmark.category);
        allocator.free(benchmark.reason);
    }
    try benchmarks.append(allocator, benchmark);
}

fn parseMetadata(source: []const u8) !ParsedMetadata {
    var result: ParsedMetadata = .{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (!std.mem.startsWith(u8, line, "--")) break;

        const comment = std.mem.trim(u8, line[2..], " \t");
        const colon = std.mem.indexOfScalar(u8, comment, ':') orelse continue;
        const key = std.mem.trim(u8, comment[0..colon], " \t");
        const value = std.mem.trim(u8, comment[colon + 1 ..], " \t");

        if (std.mem.eql(u8, key, "name")) {
            if (value.len == 0) return error.InvalidMetadataValue;
            result.name = value;
        } else if (std.mem.eql(u8, key, "category")) {
            if (value.len == 0) return error.InvalidMetadataValue;
            result.category = value;
        } else if (std.mem.eql(u8, key, "iterations")) {
            result.iterations = try parsePositiveUsize(value);
        } else if (std.mem.eql(u8, key, "warmup")) {
            result.warmup = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, key, "timeout-ms")) {
            result.timeout_ms = try parsePositiveU64(value);
        } else if (std.mem.eql(u8, key, "expect")) {
            result.expect = try parseExpect(value);
        } else if (std.mem.eql(u8, key, "reason")) {
            result.reason = value;
        }
    }
    return result;
}

fn parseExpect(value: []const u8) !Expect {
    inline for (@typeInfo(Expect).@"enum".fields) |field| {
        if (std.mem.eql(u8, value, field.name)) return @field(Expect, field.name);
    }
    return error.InvalidMetadataValue;
}

fn resolveSelectors(
    allocator: std.mem.Allocator,
    io: std.Io,
    benchmarks: []const Benchmark,
    options: Options,
    selected: *std.ArrayList(usize),
) !bool {
    if (options.selectors.len == 0) {
        for (benchmarks, 0..) |benchmark, index| {
            if (matchesCategory(benchmark, options.category)) try selected.append(allocator, index);
        }
        return true;
    }

    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = std.Io.File.stderr().writer(io, &stderr_buffer);
    const err_out = &stderr_writer.interface;
    var ok = true;

    for (options.selectors) |selector| {
        const directory_selector = selectorMatchesDirectory(benchmarks, selector);
        var matches = std.ArrayList(usize).empty;
        defer matches.deinit(allocator);

        for (benchmarks, 0..) |benchmark, index| {
            if (!matchesCategory(benchmark, options.category)) continue;
            if (selectorMatches(benchmark, selector)) try matches.append(allocator, index);
        }

        if (matches.items.len == 0) {
            try err_out.print("bench: no benchmark matches '{s}'\n", .{selector});
            try printSelectorSuggestions(err_out, benchmarks, options.category, selector);
            ok = false;
        } else if (matches.items.len > 1 and !directory_selector) {
            try err_out.print("bench: selector '{s}' is ambiguous; choose one of:\n", .{selector});
            for (matches.items) |index| try err_out.print("  {s}\n", .{benchmarks[index].path});
            ok = false;
        } else {
            for (matches.items) |index| {
                if (!containsIndex(selected.items, index)) try selected.append(allocator, index);
            }
        }
    }
    try err_out.flush();
    return ok;
}

fn printSelectorSuggestions(out: anytype, benchmarks: []const Benchmark, category: ?[]const u8, selector: []const u8) !void {
    var printed_header = false;
    for (benchmarks) |benchmark| {
        if (!matchesCategory(benchmark, category)) continue;
        const relative = relativeBenchPath(benchmark.path);
        const basename = std.fs.path.basename(benchmark.path);
        const basename_without_ext = if (std.mem.endsWith(u8, basename, ".lua")) basename[0 .. basename.len - 4] else basename;
        const relative_without_ext = if (std.mem.endsWith(u8, relative, ".lua")) relative[0 .. relative.len - 4] else relative;

        const candidates = [_][]const u8{ benchmark.name, relative_without_ext, basename_without_ext };
        for (candidates) |candidate| {
            if (candidate.len == 0) continue;
            if (editDistanceAtMost(selector, candidate, 3)) {
                if (!printed_header) {
                    try out.print("bench: did you mean:\n", .{});
                    printed_header = true;
                }
                try out.print("  {s}\n", .{candidate});
            }
        }
    }
    if (!printed_header) try out.print("bench: use --list to show available benchmarks\n", .{});
}

fn editDistanceAtMost(lhs: []const u8, rhs: []const u8, max_distance: usize) bool {
    if (lhs.len > rhs.len + max_distance or rhs.len > lhs.len + max_distance) return false;

    var distance: usize = 0;
    var lhs_index: usize = 0;
    var rhs_index: usize = 0;
    while (lhs_index < lhs.len and rhs_index < rhs.len) {
        if (lhs[lhs_index] == rhs[rhs_index]) {
            lhs_index += 1;
            rhs_index += 1;
            continue;
        }

        distance += 1;
        if (distance > max_distance) return false;

        if (lhs.len > rhs.len) {
            lhs_index += 1;
        } else if (rhs.len > lhs.len) {
            rhs_index += 1;
        } else {
            lhs_index += 1;
            rhs_index += 1;
        }
    }

    distance += lhs.len - lhs_index;
    distance += rhs.len - rhs_index;
    return distance <= max_distance;
}

fn selectorMatches(benchmark: Benchmark, selector: []const u8) bool {
    return std.mem.eql(u8, selector, benchmark.name) or
        pathSelectorMatches(benchmark.path, selector) or
        pathSelectorMatches(relativeBenchPath(benchmark.path), selector) or
        basenameSelectorMatches(benchmark.path, selector) or
        selectorMatchesPathDirectory(benchmark.path, selector) or
        selectorMatchesPathDirectory(relativeBenchPath(benchmark.path), selector);
}

fn selectorMatchesDirectory(benchmarks: []const Benchmark, selector: []const u8) bool {
    for (benchmarks) |benchmark| {
        if (selectorMatchesPathDirectory(benchmark.path, selector) or selectorMatchesPathDirectory(relativeBenchPath(benchmark.path), selector)) {
            return true;
        }
    }
    return false;
}

fn pathSelectorMatches(path: []const u8, selector: []const u8) bool {
    if (std.mem.eql(u8, path, selector)) return true;
    if (std.mem.endsWith(u8, selector, ".lua")) return false;
    return std.mem.eql(u8, path, selectorWithLua(path, selector));
}

fn selectorWithLua(path: []const u8, selector: []const u8) []const u8 {
    if (!std.mem.endsWith(u8, path, ".lua")) return selector;
    const without_ext = path[0 .. path.len - 4];
    if (std.mem.eql(u8, without_ext, selector)) return path;
    return selector;
}

fn basenameSelectorMatches(path: []const u8, selector: []const u8) bool {
    const basename = std.fs.path.basename(path);
    if (std.mem.eql(u8, basename, selector)) return true;
    if (std.mem.endsWith(u8, selector, ".lua")) return false;
    return basename.len > 4 and std.mem.eql(u8, basename[0 .. basename.len - 4], selector);
}

fn selectorMatchesPathDirectory(path: []const u8, selector: []const u8) bool {
    var trimmed = selector;
    while (trimmed.len > 0 and trimmed[trimmed.len - 1] == '/') trimmed = trimmed[0 .. trimmed.len - 1];
    if (trimmed.len == 0) return false;
    if (!std.mem.startsWith(u8, path, trimmed)) return false;
    return path.len > trimmed.len and path[trimmed.len] == '/';
}

fn relativeBenchPath(path: []const u8) []const u8 {
    if (std.mem.startsWith(u8, path, default_bench_root ++ "/")) return path[default_bench_root.len + 1 ..];
    return path;
}

fn matchesCategory(benchmark: Benchmark, category: ?[]const u8) bool {
    return category == null or std.mem.eql(u8, benchmark.category, category.?);
}

fn containsIndex(items: []const usize, needle: usize) bool {
    for (items) |item| if (item == needle) return true;
    return false;
}

fn validateZlua(allocator: std.mem.Allocator, io: std.Io, zlua_exe: []const u8, debug_errors: bool) !bool {
    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, zlua_exe);
    if (debug_errors) try argv.append(allocator, "--debug-errors");
    try argv.append(allocator, "--version");
    var result = process.runProcess(allocator, io, argv.items, .{ .timeout_ms = 2000, .expand_arg0 = true }) catch return false;
    defer result.deinit(allocator);
    return result.success();
}

fn runOne(
    allocator: std.mem.Allocator,
    io: std.Io,
    out: anytype,
    benchmark: Benchmark,
    clua_exe: []const u8,
    zlua_exe: []const u8,
    options: Options,
    counts: *Counts,
) !void {
    if (benchmark.expect == .skip or benchmark.expect == .fail) {
        counts.skipped += 1;
        try out.print("skip {s} ({s})\n", .{ benchmark.path, benchmark.reason });
        return;
    }

    const iterations = options.iterations orelse benchmark.iterations;
    const warmup = options.warmup orelse benchmark.warmup;
    const timeout_ms = options.timeout_ms orelse benchmark.timeout_ms;

    try runWarmups(allocator, io, clua_exe, benchmark.path, .clua, warmup, timeout_ms, false);
    try runWarmups(allocator, io, zlua_exe, benchmark.path, .zlua, warmup, timeout_ms, options.debug_errors);

    const clua_samples = try allocator.alloc(u64, iterations);
    defer allocator.free(clua_samples);
    const zlua_samples = try allocator.alloc(u64, iterations);
    defer allocator.free(zlua_samples);

    var first_clua: ?process.ProcessResult = null;
    defer if (first_clua) |*result| result.deinit(allocator);
    var first_zlua: ?process.ProcessResult = null;
    defer if (first_zlua) |*result| result.deinit(allocator);

    for (clua_samples, 0..) |*sample, index| {
        var timed = try runTimed(allocator, io, clua_exe, benchmark.path, .clua, timeout_ms, false);
        sample.* = timed.elapsed_ns;
        if (index == 0) {
            first_clua = timed.result;
        } else {
            timed.result.deinit(allocator);
        }
    }
    for (zlua_samples, 0..) |*sample, index| {
        var timed = try runTimed(allocator, io, zlua_exe, benchmark.path, .zlua, timeout_ms, options.debug_errors);
        sample.* = timed.elapsed_ns;
        if (index == 0) {
            first_zlua = timed.result;
        } else {
            timed.result.deinit(allocator);
        }
    }

    if (first_clua.?.timed_out or first_zlua.?.timed_out) counts.timed_out += 1;
    if (!resultsEqual(first_clua.?, first_zlua.?)) {
        counts.failed += 1;
        try out.print("fail {s} (incompatible output)\n", .{benchmark.path});
        try printDiff(out, first_clua.?, first_zlua.?);
        return;
    }
    if (first_clua.?.timed_out or first_zlua.?.timed_out) {
        try out.print("fail {s} (timeout)\n", .{benchmark.path});
        return;
    }
    if (!first_clua.?.success() or !first_zlua.?.success()) {
        counts.failed += 1;
        try out.print("fail {s} (non-zero exit)\n", .{benchmark.path});
        try printDiff(out, first_clua.?, first_zlua.?);
        return;
    }

    const clua_mean = meanNs(clua_samples);
    const zlua_mean = meanNs(zlua_samples);
    counts.benchmarked += 1;

    try out.print("bench {s}  clua ", .{benchmark.path});
    try printMs(out, clua_mean);
    try out.print("  zlua ", .{});
    try printMs(out, zlua_mean);
    try out.print("  ratio ", .{});
    try printRatio(out, zlua_mean, clua_mean);
    try out.print("\n", .{});
}

const Engine = enum { clua, zlua };

fn runWarmups(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    engine: Engine,
    count: usize,
    timeout_ms: u64,
    debug_errors: bool,
) !void {
    for (0..count) |_| {
        var timed = try runTimed(allocator, io, exe, path, engine, timeout_ms, debug_errors);
        timed.result.deinit(allocator);
    }
}

fn runTimed(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    engine: Engine,
    timeout_ms: u64,
    debug_errors: bool,
) !TimedRun {
    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, exe);
    if (engine == .zlua and debug_errors) try argv.append(allocator, "--debug-errors");
    try argv.append(allocator, path);

    const start = std.Io.Timestamp.now(io, .awake);
    const result = try process.runProcess(allocator, io, argv.items, .{
        .timeout_ms = timeout_ms,
        .max_output_bytes = max_output_bytes,
        .expand_arg0 = engine == .zlua,
    });
    const elapsed = start.durationTo(std.Io.Timestamp.now(io, .awake));
    return .{ .result = result, .elapsed_ns = @intCast(elapsed.toNanoseconds()) };
}

fn resultsEqual(clua_result: process.ProcessResult, zlua_result: process.ProcessResult) bool {
    return clua_result.exit_code == zlua_result.exit_code and
        clua_result.signal == zlua_result.signal and
        clua_result.timed_out == zlua_result.timed_out and
        std.mem.eql(u8, clua_result.stdout, zlua_result.stdout) and
        std.mem.eql(u8, clua_result.stderr, zlua_result.stderr);
}

fn meanNs(samples: []const u64) u64 {
    var total: u128 = 0;
    for (samples) |sample| total += sample;
    return @intCast(total / samples.len);
}

fn printMs(out: anytype, ns: u64) !void {
    const tenths_ms = ns / 100_000;
    try out.print("{d}.{d}ms", .{ tenths_ms / 10, tenths_ms % 10 });
}

fn printRatio(out: anytype, numerator: u64, denominator: u64) !void {
    if (denominator == 0) {
        try out.print("inf", .{});
        return;
    }
    const hundredths: u128 = (@as(u128, numerator) * 100) / denominator;
    const whole = hundredths / 100;
    const frac = hundredths % 100;
    if (frac < 10) {
        try out.print("{d}.0{d}x", .{ whole, frac });
    } else {
        try out.print("{d}.{d}x", .{ whole, frac });
    }
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

fn printList(out: anytype, benchmarks: []const Benchmark, selected: []const usize) !void {
    for (selected) |index| {
        const benchmark = benchmarks[index];
        try out.print("{s}\tcategory={s}\tpath={s}\n", .{ benchmark.name, benchmark.category, benchmark.path });
    }
}

fn printSummary(out: anytype, counts: Counts) !void {
    try out.print(
        \\summary:
        \\  benchmarked={d}
        \\  skipped={d}
        \\  failed={d}
        \\  timed_out={d}
        \\
    , .{ counts.benchmarked, counts.skipped, counts.failed, counts.timed_out });
}

fn lessThanBenchmarkPath(_: void, lhs: Benchmark, rhs: Benchmark) bool {
    return std.mem.lessThan(u8, lhs.path, rhs.path);
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "argument parser accepts benchmark overrides" {
    const args = [_][]const u8{ "vm/arithmetic", "--iterations=3", "--warmup", "0", "--timeout-ms=10", "--category=vm", "--debug-errors" };
    const options = try parseArgs(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), options.selectors.len);
    try std.testing.expectEqualStrings("vm/arithmetic", options.selectors[0]);
    try std.testing.expectEqual(@as(usize, 3), options.iterations.?);
    try std.testing.expectEqual(@as(usize, 0), options.warmup.?);
    try std.testing.expectEqual(@as(u64, 10), options.timeout_ms.?);
    try std.testing.expect(options.debug_errors);
}

test "metadata parser accepts benchmark fields" {
    const parsed = try parseMetadata(
        \\-- name: vm/arithmetic
        \\-- category: vm
        \\-- iterations: 2
        \\-- warmup: 0
        \\-- timeout-ms: 100
        \\-- expect: pass
        \\
        \\print(1)
    );
    try std.testing.expectEqualStrings("vm/arithmetic", parsed.name.?);
    try std.testing.expectEqualStrings("vm", parsed.category);
    try std.testing.expectEqual(@as(usize, 2), parsed.iterations);
    try std.testing.expectEqual(@as(usize, 0), parsed.warmup);
    try std.testing.expectEqual(@as(u64, 100), parsed.timeout_ms);
    try std.testing.expectEqual(Expect.pass, parsed.expect);
}
