const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const official_memory_limit_mb = b.option(u64, "official-memory-limit-mb", "Memory cap per official-suite child process in MiB (0 disables)") orelse 256;

    const clua_exe = addVendoredClua(b, target, optimize);
    b.installArtifact(clua_exe);

    const mod = b.addModule("zlua", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
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

    const official_step = b.step("test-official", "Run quick official Lua 5.5 suite subset");
    const official_cmd = b.addRunArtifact(official_exe);
    official_cmd.step.dependOn(b.getInstallStep());
    official_cmd.addArg("--clua");
    official_cmd.addArtifactArg(clua_exe);
    official_cmd.addArg("--zlua");
    official_cmd.addArtifactArg(exe);
    official_cmd.addArg("--quick");
    official_step.dependOn(&official_cmd.step);

    const official_heavy_step = b.step("test-official-heavy", "Run full official Lua 5.5 suite dashboard under a memory cap");
    const official_heavy_cmd = b.addRunArtifact(official_exe);
    official_heavy_cmd.step.dependOn(b.getInstallStep());
    official_heavy_cmd.addArg("--clua");
    official_heavy_cmd.addArtifactArg(clua_exe);
    official_heavy_cmd.addArg("--zlua");
    official_heavy_cmd.addArtifactArg(exe);
    if (official_memory_limit_mb != 0) {
        official_heavy_cmd.addArg(b.fmt("--memory-limit-mb={d}", .{official_memory_limit_mb}));
    }
    official_heavy_step.dependOn(&official_heavy_cmd.step);

    const ci_step = b.step("ci", "Run CI checks");
    ci_step.dependOn(test_step);
    ci_step.dependOn(diff_step);
    ci_step.dependOn(official_heavy_step);
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
