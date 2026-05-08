const std = @import("std");
const clua = @import("clua.zig");
const process = @import("process.zig");

const Dir = std.Io.Dir;
const File = std.Io.File;
const Timestamp = std.Io.Timestamp;

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
    json_path: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
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

const TimingStats = struct {
    min_ns: u64 = 0,
    median_ns: u64 = 0,
    mean_ns: u64 = 0,
    max_ns: u64 = 0,
    stddev_ns: u64 = 0,
};

const BenchStatus = enum { benchmarked, skipped, failed, timed_out };

const EngineReport = struct {
    samples_ns: []u64 = &.{},
    stats: TimingStats = .{},
    exit_code: ?u8 = null,
    signal: ?u32 = null,
    timed_out: bool = false,
};

const BenchmarkReport = struct {
    path: []const u8,
    name: []const u8,
    category: []const u8,
    status: BenchStatus,
    reason: []const u8 = "",
    iterations: usize = 0,
    warmup: usize = 0,
    timeout_ms: u64 = 0,
    clua: EngineReport = .{},
    zlua: EngineReport = .{},

    fn deinit(self: *BenchmarkReport, allocator: std.mem.Allocator) void {
        allocator.free(self.clua.samples_ns);
        allocator.free(self.zlua.samples_ns);
        self.* = undefined;
    }
};

const HumanWidths = struct {
    benchmark: usize,
    category: usize,
};

const Align = enum { left, right };

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
    var writer = File.stdout().writer(io, &buffer);
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
    if (!try validateZlua(allocator, io, zlua_path)) {
        try out.print("zlua: missing or not runnable ({s})\n", .{zlua_path});
        try out.flush();
        return 1;
    }

    var reports = std.ArrayList(BenchmarkReport).empty;
    defer {
        for (reports.items) |*report| report.deinit(allocator);
        reports.deinit(allocator);
    }

    const widths = calculateHumanWidths(benchmarks.items, selected.items);
    try printBenchmarkHeader(out, widths);

    var counts: Counts = .{};
    for (selected.items) |index| {
        try runOne(allocator, io, out, benchmarks.items[index], clua_exe, zlua_path, options, &counts, &reports, widths);
    }
    try printSummary(allocator, out, counts, reports.items);
    try out.flush();

    if (options.json_path) |path| try writeJsonReport(allocator, io, path, reports.items, counts);
    if (options.csv_path) |path| try writeCsvReport(allocator, io, path, reports.items);
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
        } else if (std.mem.eql(u8, arg, "--json")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.json_path = args[index];
        } else if (std.mem.startsWith(u8, arg, "--json=")) {
            options.json_path = arg[7..];
        } else if (std.mem.eql(u8, arg, "--csv")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.csv_path = args[index];
        } else if (std.mem.startsWith(u8, arg, "--csv=")) {
            options.csv_path = arg[6..];
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
    var dir = try Dir.cwd().openDir(io, root, .{ .iterate = true });
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
    const source = try Dir.cwd().readFileAlloc(io, owned_path, allocator, .limited(max_output_bytes));
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
    var stderr_writer = File.stderr().writer(io, &stderr_buffer);
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

fn validateZlua(allocator: std.mem.Allocator, io: std.Io, zlua_exe: []const u8) !bool {
    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    try argv.append(allocator, zlua_exe);
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
    reports: *std.ArrayList(BenchmarkReport),
    widths: HumanWidths,
) !void {
    const iterations = options.iterations orelse benchmark.iterations;
    const warmup = options.warmup orelse benchmark.warmup;
    const timeout_ms = options.timeout_ms orelse benchmark.timeout_ms;

    if (benchmark.expect == .skip or benchmark.expect == .fail) {
        counts.skipped += 1;
        try reports.append(allocator, .{
            .path = benchmark.path,
            .name = benchmark.name,
            .category = benchmark.category,
            .status = .skipped,
            .reason = benchmark.reason,
            .iterations = iterations,
            .warmup = warmup,
            .timeout_ms = timeout_ms,
        });
        try printBenchmarkRow(allocator, out, reports.items[reports.items.len - 1], widths);
        return;
    }

    try runWarmups(allocator, io, clua_exe, benchmark.path, .clua, warmup, timeout_ms, false);
    try runWarmups(allocator, io, zlua_exe, benchmark.path, .zlua, warmup, timeout_ms, options.debug_errors);

    const clua_samples = try allocator.alloc(u64, iterations);
    var own_clua_samples = true;
    errdefer if (own_clua_samples) allocator.free(clua_samples);
    const zlua_samples = try allocator.alloc(u64, iterations);
    var own_zlua_samples = true;
    errdefer if (own_zlua_samples) allocator.free(zlua_samples);

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

    const clua_report: EngineReport = .{
        .samples_ns = clua_samples,
        .stats = try calculateStats(allocator, clua_samples),
        .exit_code = first_clua.?.exit_code,
        .signal = first_clua.?.signal,
        .timed_out = first_clua.?.timed_out,
    };
    const zlua_report: EngineReport = .{
        .samples_ns = zlua_samples,
        .stats = try calculateStats(allocator, zlua_samples),
        .exit_code = first_zlua.?.exit_code,
        .signal = first_zlua.?.signal,
        .timed_out = first_zlua.?.timed_out,
    };

    const timed_out = first_clua.?.timed_out or first_zlua.?.timed_out;
    if (timed_out) counts.timed_out += 1;
    if (timed_out) {
        try reports.append(allocator, .{
            .path = benchmark.path,
            .name = benchmark.name,
            .category = benchmark.category,
            .status = .timed_out,
            .reason = "timeout",
            .iterations = iterations,
            .warmup = warmup,
            .timeout_ms = timeout_ms,
            .clua = clua_report,
            .zlua = zlua_report,
        });
        own_clua_samples = false;
        own_zlua_samples = false;
        try printBenchmarkRow(allocator, out, reports.items[reports.items.len - 1], widths);
        return;
    }

    if (!resultsEqual(first_clua.?, first_zlua.?)) {
        counts.failed += 1;
        try reports.append(allocator, .{
            .path = benchmark.path,
            .name = benchmark.name,
            .category = benchmark.category,
            .status = .failed,
            .reason = "incompatible output",
            .iterations = iterations,
            .warmup = warmup,
            .timeout_ms = timeout_ms,
            .clua = clua_report,
            .zlua = zlua_report,
        });
        own_clua_samples = false;
        own_zlua_samples = false;
        try printBenchmarkRow(allocator, out, reports.items[reports.items.len - 1], widths);
        try printDiff(out, first_clua.?, first_zlua.?);
        return;
    }
    if (!first_clua.?.success() or !first_zlua.?.success()) {
        counts.failed += 1;
        try reports.append(allocator, .{
            .path = benchmark.path,
            .name = benchmark.name,
            .category = benchmark.category,
            .status = .failed,
            .reason = "non-zero exit",
            .iterations = iterations,
            .warmup = warmup,
            .timeout_ms = timeout_ms,
            .clua = clua_report,
            .zlua = zlua_report,
        });
        own_clua_samples = false;
        own_zlua_samples = false;
        try printBenchmarkRow(allocator, out, reports.items[reports.items.len - 1], widths);
        try printDiff(out, first_clua.?, first_zlua.?);
        return;
    }

    counts.benchmarked += 1;
    try reports.append(allocator, .{
        .path = benchmark.path,
        .name = benchmark.name,
        .category = benchmark.category,
        .status = .benchmarked,
        .iterations = iterations,
        .warmup = warmup,
        .timeout_ms = timeout_ms,
        .clua = clua_report,
        .zlua = zlua_report,
    });
    own_clua_samples = false;
    own_zlua_samples = false;
    try printBenchmarkRow(allocator, out, reports.items[reports.items.len - 1], widths);
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

    const start = Timestamp.now(io, .awake);
    const result = try process.runProcess(allocator, io, argv.items, .{
        .timeout_ms = timeout_ms,
        .max_output_bytes = max_output_bytes,
        .expand_arg0 = engine == .zlua,
    });
    const elapsed = start.durationTo(Timestamp.now(io, .awake));
    return .{ .result = result, .elapsed_ns = @intCast(elapsed.toNanoseconds()) };
}

fn resultsEqual(clua_result: process.ProcessResult, zlua_result: process.ProcessResult) bool {
    return clua_result.exit_code == zlua_result.exit_code and
        clua_result.signal == zlua_result.signal and
        clua_result.timed_out == zlua_result.timed_out and
        std.mem.eql(u8, clua_result.stdout, zlua_result.stdout) and
        std.mem.eql(u8, clua_result.stderr, zlua_result.stderr);
}

fn calculateStats(allocator: std.mem.Allocator, samples: []const u64) !TimingStats {
    std.debug.assert(samples.len > 0);

    const sorted = try allocator.dupe(u64, samples);
    defer allocator.free(sorted);
    std.mem.sort(u64, sorted, {}, lessThanU64);

    const mean = meanNs(samples);
    var variance_sum: f64 = 0;
    const mean_float = @as(f64, @floatFromInt(mean));
    for (samples) |sample| {
        const delta = @as(f64, @floatFromInt(sample)) - mean_float;
        variance_sum += delta * delta;
    }
    const variance = variance_sum / @as(f64, @floatFromInt(samples.len));

    return .{
        .min_ns = sorted[0],
        .median_ns = medianSortedNs(sorted),
        .mean_ns = mean,
        .max_ns = sorted[sorted.len - 1],
        .stddev_ns = @intFromFloat(@sqrt(variance)),
    };
}

fn medianSortedNs(sorted: []const u64) u64 {
    const middle = sorted.len / 2;
    if (sorted.len % 2 == 1) return sorted[middle];
    return @intCast((@as(u128, sorted[middle - 1]) + sorted[middle]) / 2);
}

fn meanNs(samples: []const u64) u64 {
    var total: u128 = 0;
    for (samples) |sample| total += sample;
    return @intCast(total / samples.len);
}

fn lessThanU64(_: void, lhs: u64, rhs: u64) bool {
    return lhs < rhs;
}

fn printMs(out: anytype, ns: u64) !void {
    const tenths_ms = ns / 100_000;
    try out.print("{d}.{d}ms", .{ tenths_ms / 10, tenths_ms % 10 });
}

fn printRatio(out: anytype, numerator: u64, denominator: u64) !void {
    try printRatioMillionths(out, ratioMillionths(numerator, denominator));
}

fn ratioMillionths(numerator: u64, denominator: u64) u64 {
    if (denominator == 0) return std.math.maxInt(u64);
    const millionths: u128 = (@as(u128, numerator) * 1_000_000) / denominator;
    return if (millionths > std.math.maxInt(u64)) std.math.maxInt(u64) else @intCast(millionths);
}

fn printRatioMillionths(out: anytype, millionths: u64) !void {
    if (millionths == std.math.maxInt(u64)) {
        try out.print("inf", .{});
        return;
    }
    const hundredths = millionths / 10_000;
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

fn calculateHumanWidths(benchmarks: []const Benchmark, selected: []const usize) HumanWidths {
    var widths: HumanWidths = .{
        .benchmark = "benchmark".len,
        .category = "category".len,
    };
    for (selected) |index| {
        const benchmark = benchmarks[index];
        widths.benchmark = @max(widths.benchmark, relativeBenchPath(benchmark.path).len);
        widths.category = @max(widths.category, benchmark.category.len);
    }
    return widths;
}

fn printBenchmarkHeader(out: anytype, widths: HumanWidths) !void {
    try out.print("benchmarks\n", .{});
    try printCell(out, "benchmark", widths.benchmark, .left);
    try out.print("  ", .{});
    try printCell(out, "category", widths.category, .left);
    try out.print("  ", .{});
    try printCell(out, "status", 11, .left);
    try out.print("  ", .{});
    try printCell(out, "clua mean", 10, .right);
    try out.print("  ", .{});
    try printCell(out, "zlua mean", 10, .right);
    try out.print("  ", .{});
    try printCell(out, "ratio", 8, .right);
    try out.print("  ", .{});
    try printCell(out, "clua med", 10, .right);
    try out.print("  ", .{});
    try printCell(out, "zlua med", 10, .right);
    try out.print("  reason\n", .{});

    try printRule(out, widths.benchmark);
    try out.print("  ", .{});
    try printRule(out, widths.category);
    try out.print("  ", .{});
    try printRule(out, 11);
    try out.print("  ", .{});
    try printRule(out, 10);
    try out.print("  ", .{});
    try printRule(out, 10);
    try out.print("  ", .{});
    try printRule(out, 8);
    try out.print("  ", .{});
    try printRule(out, 10);
    try out.print("  ", .{});
    try printRule(out, 10);
    try out.print("  ------\n", .{});
}

fn printBenchmarkRow(allocator: std.mem.Allocator, out: anytype, report: BenchmarkReport, widths: HumanWidths) !void {
    try printCell(out, relativeBenchPath(report.path), widths.benchmark, .left);
    try out.print("  ", .{});
    try printCell(out, report.category, widths.category, .left);
    try out.print("  ", .{});
    try printCell(out, statusText(report.status), 11, .left);
    try out.print("  ", .{});

    if (report.status == .benchmarked) {
        const clua_mean = try msString(allocator, report.clua.stats.mean_ns);
        defer allocator.free(clua_mean);
        const zlua_mean = try msString(allocator, report.zlua.stats.mean_ns);
        defer allocator.free(zlua_mean);
        const ratio = try ratioString(allocator, ratioMillionths(report.zlua.stats.mean_ns, report.clua.stats.mean_ns));
        defer allocator.free(ratio);
        const clua_median = try msString(allocator, report.clua.stats.median_ns);
        defer allocator.free(clua_median);
        const zlua_median = try msString(allocator, report.zlua.stats.median_ns);
        defer allocator.free(zlua_median);

        try printCell(out, clua_mean, 10, .right);
        try out.print("  ", .{});
        try printCell(out, zlua_mean, 10, .right);
        try out.print("  ", .{});
        try printCell(out, ratio, 8, .right);
        try out.print("  ", .{});
        try printCell(out, clua_median, 10, .right);
        try out.print("  ", .{});
        try printCell(out, zlua_median, 10, .right);
    } else {
        inline for (0..5) |index| {
            if (index != 0) try out.print("  ", .{});
            try printCell(out, "-", if (index == 2) 8 else 10, .right);
        }
    }

    if (report.reason.len > 0) try out.print("  {s}", .{report.reason});
    try out.print("\n", .{});
}

fn statusText(status: BenchStatus) []const u8 {
    return switch (status) {
        .benchmarked => "ok",
        .skipped => "skip",
        .failed => "fail",
        .timed_out => "timeout",
    };
}

fn printCell(out: anytype, text: []const u8, width: usize, alignment: Align) !void {
    const padding = if (width > text.len) width - text.len else 0;
    if (alignment == .right) try printSpaces(out, padding);
    try out.print("{s}", .{text});
    if (alignment == .left) try printSpaces(out, padding);
}

fn printRule(out: anytype, width: usize) !void {
    for (0..width) |_| try out.print("-", .{});
}

fn printSpaces(out: anytype, count: usize) !void {
    for (0..count) |_| try out.print(" ", .{});
}

fn msString(allocator: std.mem.Allocator, ns: u64) ![]u8 {
    const tenths_ms = ns / 100_000;
    return std.fmt.allocPrint(allocator, "{d}.{d}ms", .{ tenths_ms / 10, tenths_ms % 10 });
}

fn ratioString(allocator: std.mem.Allocator, millionths: u64) ![]u8 {
    if (millionths == std.math.maxInt(u64)) return allocator.dupe(u8, "inf");
    const hundredths = millionths / 10_000;
    const whole = hundredths / 100;
    const frac = hundredths % 100;
    if (frac < 10) return std.fmt.allocPrint(allocator, "{d}.0{d}x", .{ whole, frac });
    return std.fmt.allocPrint(allocator, "{d}.{d}x", .{ whole, frac });
}

fn printSummary(allocator: std.mem.Allocator, out: anytype, counts: Counts, reports: []const BenchmarkReport) !void {
    try out.print("\nsummary\n", .{});
    try printCell(out, "category", summaryCategoryWidth(reports), .left);
    try out.print("  ", .{});
    try printCell(out, "count", 5, .right);
    try out.print("  ", .{});
    try printCell(out, "median ratio", 12, .right);
    try out.print("  ", .{});
    try printCell(out, "worst ratio", 11, .right);
    try out.print("\n", .{});

    try printRule(out, summaryCategoryWidth(reports));
    try out.print("  ", .{});
    try printRule(out, 5);
    try out.print("  ", .{});
    try printRule(out, 12);
    try out.print("  ", .{});
    try printRule(out, 11);
    try out.print("\n", .{});

    var printed_category = false;
    for (reports, 0..) |report, index| {
        if (report.status != .benchmarked) continue;
        if (categorySeenBefore(reports[0..index], report.category)) continue;
        printed_category = true;

        var ratios = std.ArrayList(u64).empty;
        defer ratios.deinit(allocator);
        for (reports) |candidate| {
            if (candidate.status != .benchmarked) continue;
            if (!std.mem.eql(u8, candidate.category, report.category)) continue;
            try ratios.append(allocator, ratioMillionths(candidate.zlua.stats.mean_ns, candidate.clua.stats.mean_ns));
        }
        std.mem.sort(u64, ratios.items, {}, lessThanU64);

        const median_ratio = try ratioString(allocator, medianSortedNs(ratios.items));
        defer allocator.free(median_ratio);
        const worst_ratio = try ratioString(allocator, ratios.items[ratios.items.len - 1]);
        defer allocator.free(worst_ratio);

        try printCell(out, report.category, summaryCategoryWidth(reports), .left);
        try out.print("  ", .{});
        const count_text = try std.fmt.allocPrint(allocator, "{d}", .{ratios.items.len});
        defer allocator.free(count_text);
        try printCell(out, count_text, 5, .right);
        try out.print("  ", .{});
        try printCell(out, median_ratio, 12, .right);
        try out.print("  ", .{});
        try printCell(out, worst_ratio, 11, .right);
        try out.print("\n", .{});
    }

    if (!printed_category) {
        try printCell(out, "(none)", summaryCategoryWidth(reports), .left);
        try out.print("  ", .{});
        try printCell(out, "0", 5, .right);
        try out.print("  ", .{});
        try printCell(out, "-", 12, .right);
        try out.print("  ", .{});
        try printCell(out, "-", 11, .right);
        try out.print("\n", .{});
    }

    try out.print(
        \\
        \\totals  benchmarked={d}  skipped={d}  failed={d}  timed_out={d}
        \\
    , .{ counts.benchmarked, counts.skipped, counts.failed, counts.timed_out });
}

fn summaryCategoryWidth(reports: []const BenchmarkReport) usize {
    var width = "category".len;
    for (reports) |report| {
        if (report.status == .benchmarked) width = @max(width, report.category.len);
    }
    return width;
}

fn categorySeenBefore(reports: []const BenchmarkReport, category: []const u8) bool {
    for (reports) |report| {
        if (report.status == .benchmarked and std.mem.eql(u8, report.category, category)) return true;
    }
    return false;
}

fn writeJsonReport(allocator: std.mem.Allocator, io: std.Io, path: []const u8, reports: []const BenchmarkReport, counts: Counts) !void {
    var bytes = std.ArrayList(u8).empty;
    defer bytes.deinit(allocator);
    try appendJsonReport(allocator, &bytes, reports, counts);
    try Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes.items });
}

fn appendJsonReport(allocator: std.mem.Allocator, out: *std.ArrayList(u8), reports: []const BenchmarkReport, counts: Counts) !void {
    try out.appendSlice(allocator,
        \\{
        \\  "format_version": 1,
        \\  "counts": {
        \\
    );
    try appendFmt(allocator, out,
        \\    "benchmarked": {d},
        \\    "skipped": {d},
        \\    "failed": {d},
        \\    "timed_out": {d}
        \\  }},
        \\  "benchmarks": [
        \\
    , .{ counts.benchmarked, counts.skipped, counts.failed, counts.timed_out });

    for (reports, 0..) |report, index| {
        if (index != 0) try out.appendSlice(allocator, ",\n");
        try out.appendSlice(allocator, "    {\n");
        try out.appendSlice(allocator, "      \"path\": ");
        try appendJsonString(allocator, out, report.path);
        try out.appendSlice(allocator, ",\n      \"name\": ");
        try appendJsonString(allocator, out, report.name);
        try out.appendSlice(allocator, ",\n      \"category\": ");
        try appendJsonString(allocator, out, report.category);
        try appendFmt(allocator, out,
            \\,
            \\      "status": "{s}",
            \\      "iterations": {d},
            \\      "warmup": {d},
            \\      "timeout_ms": {d},
            \\      "ratio_zlua_clua_millionths": 
        , .{ @tagName(report.status), report.iterations, report.warmup, report.timeout_ms });
        try appendReportRatioJson(allocator, out, report);
        try out.appendSlice(allocator, ",\n      \"reason\": ");
        try appendJsonString(allocator, out, report.reason);
        try out.appendSlice(allocator, ",\n      \"clua\": ");
        try appendEngineJson(allocator, out, report.clua);
        try out.appendSlice(allocator, ",\n      \"zlua\": ");
        try appendEngineJson(allocator, out, report.zlua);
        try out.appendSlice(allocator, "\n    }");
    }

    try out.appendSlice(allocator, "\n  ]\n}\n");
}

fn appendReportRatioJson(allocator: std.mem.Allocator, out: *std.ArrayList(u8), report: BenchmarkReport) !void {
    if (report.status != .benchmarked) {
        try out.appendSlice(allocator, "null");
        return;
    }
    try appendFmt(allocator, out, "{d}", .{ratioMillionths(report.zlua.stats.mean_ns, report.clua.stats.mean_ns)});
}

fn appendEngineJson(allocator: std.mem.Allocator, out: *std.ArrayList(u8), engine: EngineReport) !void {
    try out.appendSlice(allocator, "{\n        \"samples_ns\": [");
    for (engine.samples_ns, 0..) |sample, index| {
        if (index != 0) try out.appendSlice(allocator, ", ");
        try appendFmt(allocator, out, "{d}", .{sample});
    }
    try appendFmt(allocator, out,
        \\],
        \\        "min_ns": {d},
        \\        "median_ns": {d},
        \\        "mean_ns": {d},
        \\        "max_ns": {d},
        \\        "stddev_ns": {d},
        \\        "exit_code": 
    , .{ engine.stats.min_ns, engine.stats.median_ns, engine.stats.mean_ns, engine.stats.max_ns, engine.stats.stddev_ns });
    try appendOptionalU8Json(allocator, out, engine.exit_code);
    try out.appendSlice(allocator, ",\n        \"signal\": ");
    try appendOptionalU32Json(allocator, out, engine.signal);
    try appendFmt(allocator, out, ",\n        \"timed_out\": {s}\n      }}", .{if (engine.timed_out) "true" else "false"});
}

fn appendOptionalU8Json(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: ?u8) !void {
    if (value) |number| {
        try appendFmt(allocator, out, "{d}", .{number});
    } else {
        try out.appendSlice(allocator, "null");
    }
}

fn appendOptionalU32Json(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: ?u32) !void {
    if (value) |number| {
        try appendFmt(allocator, out, "{d}", .{number});
    } else {
        try out.appendSlice(allocator, "null");
    }
}

fn appendJsonString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) !void {
    try out.append(allocator, '"');
    for (text) |byte| {
        switch (byte) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            '\n' => try out.appendSlice(allocator, "\\n"),
            '\r' => try out.appendSlice(allocator, "\\r"),
            '\t' => try out.appendSlice(allocator, "\\t"),
            else => {
                if (byte < 0x20) {
                    try appendFmt(allocator, out, "\\u00{x:0>2}", .{byte});
                } else {
                    try out.append(allocator, byte);
                }
            },
        }
    }
    try out.append(allocator, '"');
}

fn writeCsvReport(allocator: std.mem.Allocator, io: std.Io, path: []const u8, reports: []const BenchmarkReport) !void {
    var bytes = std.ArrayList(u8).empty;
    defer bytes.deinit(allocator);
    try appendCsvReport(allocator, &bytes, reports);
    try Dir.cwd().writeFile(io, .{ .sub_path = path, .data = bytes.items });
}

fn appendCsvReport(allocator: std.mem.Allocator, out: *std.ArrayList(u8), reports: []const BenchmarkReport) !void {
    try out.appendSlice(allocator, "path,name,category,status,iterations,warmup,timeout_ms,clua_min_ns,clua_median_ns,clua_mean_ns,clua_max_ns,clua_stddev_ns,zlua_min_ns,zlua_median_ns,zlua_mean_ns,zlua_max_ns,zlua_stddev_ns,ratio_zlua_clua,clua_exit_code,zlua_exit_code,clua_timeout,zlua_timeout,reason\n");
    for (reports) |report| {
        try appendCsvField(allocator, out, report.path);
        try out.append(allocator, ',');
        try appendCsvField(allocator, out, report.name);
        try out.append(allocator, ',');
        try appendCsvField(allocator, out, report.category);
        try appendFmt(allocator, out, ",{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{
            @tagName(report.status),
            report.iterations,
            report.warmup,
            report.timeout_ms,
            report.clua.stats.min_ns,
            report.clua.stats.median_ns,
            report.clua.stats.mean_ns,
            report.clua.stats.max_ns,
            report.clua.stats.stddev_ns,
            report.zlua.stats.min_ns,
            report.zlua.stats.median_ns,
            report.zlua.stats.mean_ns,
            report.zlua.stats.max_ns,
            report.zlua.stats.stddev_ns,
        });
        if (report.status == .benchmarked) {
            try appendRatioDecimal(allocator, out, ratioMillionths(report.zlua.stats.mean_ns, report.clua.stats.mean_ns));
        }
        try out.append(allocator, ',');
        try appendOptionalU8Csv(allocator, out, report.clua.exit_code);
        try out.append(allocator, ',');
        try appendOptionalU8Csv(allocator, out, report.zlua.exit_code);
        try appendFmt(allocator, out, ",{s},{s},", .{ if (report.clua.timed_out) "true" else "false", if (report.zlua.timed_out) "true" else "false" });
        try appendCsvField(allocator, out, report.reason);
        try out.append(allocator, '\n');
    }
}

fn appendCsvField(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) !void {
    const needs_quotes = std.mem.indexOfAny(u8, text, ",\"\n\r") != null;
    if (!needs_quotes) {
        try out.appendSlice(allocator, text);
        return;
    }
    try out.append(allocator, '"');
    for (text) |byte| {
        if (byte == '"') try out.append(allocator, '"');
        try out.append(allocator, byte);
    }
    try out.append(allocator, '"');
}

fn appendOptionalU8Csv(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: ?u8) !void {
    if (value) |number| try appendFmt(allocator, out, "{d}", .{number});
}

fn appendRatioDecimal(allocator: std.mem.Allocator, out: *std.ArrayList(u8), millionths: u64) !void {
    if (millionths == std.math.maxInt(u64)) {
        try out.appendSlice(allocator, "inf");
        return;
    }
    try appendFmt(allocator, out, "{d}.{d:0>6}", .{ millionths / 1_000_000, millionths % 1_000_000 });
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn lessThanBenchmarkPath(_: void, lhs: Benchmark, rhs: Benchmark) bool {
    return std.mem.lessThan(u8, lhs.path, rhs.path);
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "argument parser accepts benchmark overrides" {
    const args = [_][]const u8{ "vm/arithmetic", "--iterations=3", "--warmup", "0", "--timeout-ms=10", "--category=vm", "--json", "bench.json", "--csv=bench.csv", "--debug-errors" };
    const options = try parseArgs(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), options.selectors.len);
    try std.testing.expectEqualStrings("vm/arithmetic", options.selectors[0]);
    try std.testing.expectEqual(@as(usize, 3), options.iterations.?);
    try std.testing.expectEqual(@as(usize, 0), options.warmup.?);
    try std.testing.expectEqual(@as(u64, 10), options.timeout_ms.?);
    try std.testing.expectEqualStrings("bench.json", options.json_path.?);
    try std.testing.expectEqualStrings("bench.csv", options.csv_path.?);
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

test "timing stats include aggregate metrics" {
    const samples = [_]u64{ 400, 100, 300, 200 };
    const stats = try calculateStats(std.testing.allocator, &samples);
    try std.testing.expectEqual(@as(u64, 100), stats.min_ns);
    try std.testing.expectEqual(@as(u64, 250), stats.median_ns);
    try std.testing.expectEqual(@as(u64, 250), stats.mean_ns);
    try std.testing.expectEqual(@as(u64, 400), stats.max_ns);
    try std.testing.expect(stats.stddev_ns > 0);
}

test "json report includes raw samples and metrics" {
    var clua_samples = [_]u64{ 100, 200 };
    var zlua_samples = [_]u64{ 300, 500 };
    const reports = [_]BenchmarkReport{.{
        .path = "tests/bench/vm/arithmetic.lua",
        .name = "vm/arithmetic",
        .category = "vm",
        .status = .benchmarked,
        .iterations = 2,
        .warmup = 1,
        .timeout_ms = 1000,
        .clua = .{
            .samples_ns = clua_samples[0..],
            .stats = .{ .min_ns = 100, .median_ns = 150, .mean_ns = 150, .max_ns = 200, .stddev_ns = 50 },
            .exit_code = 0,
        },
        .zlua = .{
            .samples_ns = zlua_samples[0..],
            .stats = .{ .min_ns = 300, .median_ns = 400, .mean_ns = 400, .max_ns = 500, .stddev_ns = 100 },
            .exit_code = 0,
        },
    }};

    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.testing.allocator);
    try appendJsonReport(std.testing.allocator, &out, &reports, .{ .benchmarked = 1 });

    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"samples_ns\": [100, 200]") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"median_ns\": 150") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"stddev_ns\": 100") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"ratio_zlua_clua_millionths\": 2666666") != null);
}

test "csv report escapes fields and includes metrics" {
    const reports = [_]BenchmarkReport{.{
        .path = "tests/bench/vm/a,b.lua",
        .name = "vm/a,b",
        .category = "vm",
        .status = .skipped,
        .reason = "needs \"support\"",
    }};

    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.testing.allocator);
    try appendCsvReport(std.testing.allocator, &out, &reports);

    try std.testing.expect(std.mem.indexOf(u8, out.items, "clua_median_ns") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"tests/bench/vm/a,b.lua\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "\"needs \"\"support\"\"\"") != null);
}
