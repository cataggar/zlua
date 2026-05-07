const std = @import("std");

const EmbeddingExample = struct {
    key: []const u8,
    name: []const u8,
    path: []const u8,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const official_memory_limit_mb = b.option(u64, "official-memory-limit-mb", "Memory cap per official-suite child process in MiB (0 disables)") orelse 256;
    const example_filter = b.option([]const u8, "example", "Embedding example to run by file name or basename") orelse null;

    const clua_optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const clua_exe = addVendoredClua(b, target, clua_optimize);
    b.installArtifact(clua_exe);

    const mod = b.addModule("zlua", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const bench_optimize: std.builtin.OptimizeMode = .ReleaseSafe;
    const bench_mod = b.addModule("zlua-bench-release-safe", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = bench_optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zlua",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zlua", .module = mod }},
        }),
    });
    b.installArtifact(exe);

    const bench_zlua_exe = b.addExecutable(.{
        .name = "zlua-bench-release-safe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = bench_optimize,
            .imports = &.{.{ .name = "zlua", .module = bench_mod }},
        }),
    });

    const diff_exe = b.addExecutable(.{
        .name = "zlua-test-diff",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_diff_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zlua", .module = mod }},
        }),
    });
    b.installArtifact(diff_exe);

    const official_exe = b.addExecutable(.{
        .name = "zlua-test-official",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_official_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zlua", .module = mod }},
        }),
    });
    b.installArtifact(official_exe);

    const bench_exe = b.addExecutable(.{
        .name = "zlua-test-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/test_bench_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zlua", .module = mod }},
        }),
    });
    b.installArtifact(bench_exe);

    const embedding_examples = [_]EmbeddingExample{
        .{ .key = "run_script", .name = "zlua-embed-run-script", .path = "examples/embed/run_script.zig" },
        .{ .key = "register_function", .name = "zlua-embed-register-function", .path = "examples/embed/register_function.zig" },
        .{ .key = "plugin_sandbox", .name = "zlua-embed-plugin-sandbox", .path = "examples/embed/plugin_sandbox.zig" },
        .{ .key = "memory_rw_files", .name = "zlua-embed-memory-rw-files", .path = "examples/embed/memory_rw_files.zig" },
        .{ .key = "userdata_counter", .name = "zlua-embed-userdata-counter", .path = "examples/embed/userdata_counter.zig" },
        .{ .key = "preload_module", .name = "zlua-embed-preload-module", .path = "examples/embed/preload_module.zig" },
    };

    const examples_step = b.step("examples", "Compile embedding examples");
    const run_example_step = b.step("run-example", "Run embedding examples, or one selected by -Dexample=name");
    var matched_example = false;
    for (embedding_examples) |example| {
        const example_exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "zlua", .module = mod }},
            }),
        });
        examples_step.dependOn(&example_exe.step);

        if (example_filter == null or exampleMatches(example, example_filter.?)) {
            matched_example = true;
            const run_example = b.addRunArtifact(example_exe);
            run_example_step.dependOn(&run_example.step);
        }
    }
    if (example_filter) |filter| {
        if (!matched_example) std.debug.panic("unknown embedding example '{s}'", .{filter});
    }

    const run_step = b.step("run", "Run zlua");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    const run_diff_step = b.step("run-test-diff", "Run CLua differential harness");
    const run_diff_cmd = b.addRunArtifact(diff_exe);
    run_diff_cmd.step.dependOn(b.getInstallStep());
    run_diff_cmd.addArg("--clua");
    run_diff_cmd.addArtifactArg(clua_exe);
    if (b.args) |args| run_diff_cmd.addArgs(args);
    run_diff_step.dependOn(&run_diff_cmd.step);

    const run_official_step = b.step("run-test-official", "Run official Lua 5.5 suite harness");
    const run_official_cmd = b.addRunArtifact(official_exe);
    run_official_cmd.step.dependOn(b.getInstallStep());
    run_official_cmd.addArg("--clua");
    run_official_cmd.addArtifactArg(clua_exe);
    run_official_cmd.addArg("--zlua");
    run_official_cmd.addArtifactArg(exe);
    if (b.args) |args| run_official_cmd.addArgs(args);
    run_official_step.dependOn(&run_official_cmd.step);

    const run_bench_step = b.step("run-test-bench", "Run zlua vs CLua benchmark harness");
    const run_bench_cmd = b.addRunArtifact(bench_exe);
    run_bench_cmd.addArg("--clua");
    run_bench_cmd.addArtifactArg(clua_exe);
    run_bench_cmd.addArg("--zlua");
    run_bench_cmd.addArtifactArg(bench_zlua_exe);
    if (b.args) |args| run_bench_cmd.addArgs(args);
    run_bench_step.dependOn(&run_bench_cmd.step);

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    const diff_step = b.step("test-diff", "Run CLua differential tests");
    const diff_cmd = b.addRunArtifact(diff_exe);
    diff_cmd.step.dependOn(b.getInstallStep());
    diff_cmd.addArg("--clua");
    diff_cmd.addArtifactArg(clua_exe);
    diff_step.dependOn(&diff_cmd.step);

    const official_step = b.step("test-official", "Run full official Lua 5.5 suite dashboard under a memory cap");
    const official_cmd = b.addRunArtifact(official_exe);
    official_cmd.step.dependOn(b.getInstallStep());
    official_cmd.addArg("--clua");
    official_cmd.addArtifactArg(clua_exe);
    official_cmd.addArg("--zlua");
    official_cmd.addArtifactArg(exe);
    if (official_memory_limit_mb != 0) {
        official_cmd.addArg(b.fmt("--memory-limit-mb={d}", .{official_memory_limit_mb}));
    }
    official_step.dependOn(&official_cmd.step);

    const ci_step = b.step("ci", "Run CI checks");
    ci_step.dependOn(test_step);
    ci_step.dependOn(examples_step);
    ci_step.dependOn(diff_step);
    ci_step.dependOn(official_step);
}

fn addVendoredClua(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const lua_sources = [_][]const u8{
        "lapi.c",
        "lauxlib.c",
        "lbaselib.c",
        "lcode.c",
        "lcorolib.c",
        "lctype.c",
        "ldblib.c",
        "ldebug.c",
        "ldo.c",
        "ldump.c",
        "lfunc.c",
        "lgc.c",
        "linit.c",
        "liolib.c",
        "llex.c",
        "lmathlib.c",
        "lmem.c",
        "loadlib.c",
        "lobject.c",
        "lopcodes.c",
        "loslib.c",
        "lparser.c",
        "lstate.c",
        "lstring.c",
        "lstrlib.c",
        "ltable.c",
        "ltablib.c",
        "ltm.c",
        "lua.c",
        "lundump.c",
        "lutf8lib.c",
        "lvm.c",
        "lzio.c",
    };

    const clua_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const clua_cflags: []const []const u8 = switch (target.result.os.tag) {
        .linux => &.{ "-std=gnu99", "-DLUA_USE_LINUX" },
        .macos, .freebsd, .netbsd, .openbsd, .dragonfly, .illumos => &.{ "-std=gnu99", "-DLUA_USE_POSIX" },
        else => &.{"-std=gnu99"},
    };

    clua_mod.addCSourceFiles(.{
        .root = b.path("vendor/lua-5.5.0/src"),
        .files = &lua_sources,
        .flags = clua_cflags,
    });
    if (target.result.os.tag != .windows) {
        clua_mod.linkSystemLibrary("m", .{});
    }
    if (target.result.os.tag == .linux) {
        clua_mod.linkSystemLibrary("dl", .{});
    }

    return b.addExecutable(.{
        .name = "lua5.5",
        .root_module = clua_mod,
    });
}

fn exampleMatches(example: EmbeddingExample, filter: []const u8) bool {
    if (std.mem.eql(u8, filter, example.key)) return true;
    if (std.mem.eql(u8, filter, example.name)) return true;
    if (std.mem.eql(u8, filter, example.path)) return true;

    const basename = std.fs.path.basename(example.path);
    if (std.mem.eql(u8, filter, basename)) return true;
    if (std.mem.endsWith(u8, basename, ".zig")) {
        return std.mem.eql(u8, filter, basename[0 .. basename.len - ".zig".len]);
    }
    return false;
}
