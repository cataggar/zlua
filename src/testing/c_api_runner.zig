const std = @import("std");
const builtin = @import("builtin");

const process = @import("process.zig");

const Dir = std.Io.Dir;
const File = std.Io.File;

const public_symbols = [_][]const u8{
    "lua_ident",
    "lua_newstate",
    "lua_close",
    "lua_newthread",
    "lua_closethread",
    "lua_atpanic",
    "lua_version",
    "lua_absindex",
    "lua_gettop",
    "lua_settop",
    "lua_pushvalue",
    "lua_rotate",
    "lua_copy",
    "lua_checkstack",
    "lua_xmove",
    "lua_isnumber",
    "lua_isstring",
    "lua_iscfunction",
    "lua_isinteger",
    "lua_isuserdata",
    "lua_type",
    "lua_typename",
    "lua_tonumberx",
    "lua_tointegerx",
    "lua_toboolean",
    "lua_tolstring",
    "lua_rawlen",
    "lua_tocfunction",
    "lua_touserdata",
    "lua_tothread",
    "lua_topointer",
    "lua_arith",
    "lua_rawequal",
    "lua_compare",
    "lua_pushnil",
    "lua_pushnumber",
    "lua_pushinteger",
    "lua_pushlstring",
    "lua_pushexternalstring",
    "lua_pushstring",
    "lua_pushvfstring",
    "lua_pushfstring",
    "lua_pushcclosure",
    "lua_pushboolean",
    "lua_pushlightuserdata",
    "lua_pushthread",
    "lua_getglobal",
    "lua_gettable",
    "lua_getfield",
    "lua_geti",
    "lua_rawget",
    "lua_rawgeti",
    "lua_rawgetp",
    "lua_createtable",
    "lua_newuserdatauv",
    "lua_getmetatable",
    "lua_getiuservalue",
    "lua_setglobal",
    "lua_settable",
    "lua_setfield",
    "lua_seti",
    "lua_rawset",
    "lua_rawseti",
    "lua_rawsetp",
    "lua_setmetatable",
    "lua_setiuservalue",
    "lua_callk",
    "lua_pcallk",
    "lua_load",
    "lua_dump",
    "lua_yieldk",
    "lua_resume",
    "lua_status",
    "lua_isyieldable",
    "lua_setwarnf",
    "lua_warning",
    "lua_gc",
    "lua_error",
    "lua_next",
    "lua_concat",
    "lua_len",
    "lua_numbertocstring",
    "lua_stringtonumber",
    "lua_getallocf",
    "lua_setallocf",
    "lua_toclose",
    "lua_closeslot",
    "lua_getstack",
    "lua_getinfo",
    "lua_getlocal",
    "lua_setlocal",
    "lua_getupvalue",
    "lua_setupvalue",
    "lua_upvalueid",
    "lua_upvaluejoin",
    "lua_sethook",
    "lua_gethook",
    "lua_gethookmask",
    "lua_gethookcount",
    "luaL_checkversion_",
    "luaL_getmetafield",
    "luaL_callmeta",
    "luaL_tolstring",
    "luaL_argerror",
    "luaL_typeerror",
    "luaL_checklstring",
    "luaL_optlstring",
    "luaL_checknumber",
    "luaL_optnumber",
    "luaL_checkinteger",
    "luaL_optinteger",
    "luaL_checkstack",
    "luaL_checktype",
    "luaL_checkany",
    "luaL_newmetatable",
    "luaL_setmetatable",
    "luaL_testudata",
    "luaL_checkudata",
    "luaL_where",
    "luaL_error",
    "luaL_checkoption",
    "luaL_fileresult",
    "luaL_execresult",
    "luaL_alloc",
    "luaL_ref",
    "luaL_unref",
    "luaL_loadfilex",
    "luaL_loadbufferx",
    "luaL_loadstring",
    "luaL_newstate",
    "luaL_makeseed",
    "luaL_len",
    "luaL_addgsub",
    "luaL_gsub",
    "luaL_setfuncs",
    "luaL_getsubtable",
    "luaL_traceback",
    "luaL_requiref",
    "luaL_buffinit",
    "luaL_prepbuffsize",
    "luaL_addlstring",
    "luaL_addstring",
    "luaL_addvalue",
    "luaL_pushresult",
    "luaL_pushresultsize",
    "luaL_buffinitsize",
    "luaopen_base",
    "luaopen_package",
    "luaopen_coroutine",
    "luaopen_debug",
    "luaopen_io",
    "luaopen_math",
    "luaopen_os",
    "luaopen_string",
    "luaopen_table",
    "luaopen_utf8",
    "luaL_openselectedlibs",
};

const Options = struct {
    path: []const u8 = "tests/c-api",
    zig: []const u8 = "zig",
    clua_include: []const u8 = ".zlua-deps/lua-5.5.0/src",
    clua_lib: ?[]const u8 = null,
    zlua_include: []const u8 = ".zlua-deps/lua-5.5.0/src",
    zlua_lib: ?[]const u8 = null,
    status: []const u8 = "tests/fixtures/c_api_status.toml",
    timeout_ms: u64 = 5000,
    compile_timeout_ms: u64 = 60000,
    show_build: bool = false,
};

const Counts = struct {
    passed: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
};

const Variant = enum {
    clua,
    zlua,

    fn name(self: Variant) []const u8 {
        return switch (self) {
            .clua => "clua",
            .zlua => "zlua",
        };
    }
};

pub fn runCli(allocator: std.mem.Allocator, io: std.Io, args: []const []const u8) !u8 {
    const options = parseArgs(args) catch |err| {
        try stderrPrint(io, "test-c-api: {s}\n", .{@errorName(err)});
        return 2;
    };

    var writer_buffer: [8192]u8 = undefined;
    var writer = File.stdout().writer(io, &writer_buffer);
    const out = &writer.interface;

    const status_ok = try checkStatusInventory(allocator, io, out, options.status);
    if (!status_ok) {
        try out.flush();
        return 1;
    }

    if (options.clua_lib == null) {
        try out.print("skip c-api fixtures (missing --clua-lib)\n", .{});
        try out.flush();
        return 0;
    }
    if (options.zlua_lib == null) {
        try out.print("skip c-api fixtures (missing --zlua-lib)\n", .{});
        try out.flush();
        return 0;
    }

    var tests = std.ArrayList([]u8).empty;
    defer {
        for (tests.items) |path| allocator.free(path);
        tests.deinit(allocator);
    }
    try discoverTests(allocator, io, options.path, &tests);
    std.mem.sort([]u8, tests.items, {}, lessThanString);

    var counts: Counts = .{};
    try Dir.cwd().createDirPath(io, ".zig-cache/c-api-fixtures");

    for (tests.items) |path| {
        try runOne(allocator, io, out, path, options, &counts);
    }

    try out.print("c-api summary: {d} passed, {d} failed, {d} skipped\n", .{ counts.passed, counts.failed, counts.skipped });
    try out.flush();
    return if (counts.failed == 0) 0 else 1;
}

fn parseArgs(args: []const []const u8) !Options {
    var options: Options = .{};
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        if (std.mem.eql(u8, arg, "--zig")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.zig = args[index];
        } else if (std.mem.eql(u8, arg, "--clua-include")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.clua_include = args[index];
        } else if (std.mem.eql(u8, arg, "--clua-lib")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.clua_lib = args[index];
        } else if (std.mem.eql(u8, arg, "--zlua-include")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.zlua_include = args[index];
        } else if (std.mem.eql(u8, arg, "--zlua-lib")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.zlua_lib = args[index];
        } else if (std.mem.eql(u8, arg, "--status")) {
            index += 1;
            if (index >= args.len) return error.MissingOptionValue;
            options.status = args[index];
        } else if (std.mem.startsWith(u8, arg, "--timeout-ms=")) {
            options.timeout_ms = try std.fmt.parseInt(u64, arg[13..], 10);
        } else if (std.mem.startsWith(u8, arg, "--compile-timeout-ms=")) {
            options.compile_timeout_ms = try std.fmt.parseInt(u64, arg[21..], 10);
        } else if (std.mem.eql(u8, arg, "--show-build")) {
            options.show_build = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownOption;
        } else {
            options.path = arg;
        }
    }
    return options;
}

fn checkStatusInventory(allocator: std.mem.Allocator, io: std.Io, out: anytype, path: []const u8) !bool {
    const source = try Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    defer allocator.free(source);

    var names = std.StringHashMap(void).init(allocator);
    defer names.deinit();

    var ok = true;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#' or line[0] == '[') continue;
        const equals = std.mem.indexOfScalar(u8, line, '=') orelse {
            try out.print("status inventory has malformed line: {s}\n", .{line});
            ok = false;
            continue;
        };
        const name = std.mem.trim(u8, line[0..equals], " \t");
        const value = std.mem.trim(u8, line[equals + 1 ..], " \t\r");
        if (!validStatus(value)) {
            try out.print("status inventory has invalid status for {s}: {s}\n", .{ name, value });
            ok = false;
        }
        try names.put(name, {});
    }

    for (public_symbols) |symbol| {
        if (!names.contains(symbol)) {
            try out.print("status inventory missing public C API symbol: {s}\n", .{symbol});
            ok = false;
        }
    }
    var iterator = names.keyIterator();
    while (iterator.next()) |name| {
        if (!knownSymbol(name.*)) {
            try out.print("status inventory contains unknown public C API symbol: {s}\n", .{name.*});
            ok = false;
        }
    }
    return ok;
}

fn validStatus(value: []const u8) bool {
    return std.mem.eql(u8, value, "\"not-started\"") or
        std.mem.eql(u8, value, "\"stubbed\"") or
        std.mem.eql(u8, value, "\"implemented\"") or
        std.mem.eql(u8, value, "\"tested-clua-diff\"") or
        std.mem.eql(u8, value, "\"deviation-documented\"");
}

fn knownSymbol(name: []const u8) bool {
    for (public_symbols) |symbol| {
        if (std.mem.eql(u8, name, symbol)) return true;
    }
    return false;
}

fn discoverTests(allocator: std.mem.Allocator, io: std.Io, root: []const u8, tests: *std.ArrayList([]u8)) !void {
    var dir = Dir.cwd().openDir(io, root, .{ .iterate = true }) catch |err| switch (err) {
        error.NotDir => {
            if (std.mem.endsWith(u8, root, ".c")) try tests.append(allocator, try allocator.dupe(u8, root));
            return;
        },
        else => return err,
    };
    defer dir.close(io);

    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".c")) continue;
        try tests.append(allocator, try std.fs.path.join(allocator, &.{ root, entry.path }));
    }
}

fn runOne(allocator: std.mem.Allocator, io: std.Io, out: anytype, path: []const u8, options: Options, counts: *Counts) !void {
    var clua_compile = try compileFixture(allocator, io, path, options, .clua);
    defer clua_compile.deinit(allocator);
    if (!clua_compile.success()) {
        counts.failed += 1;
        try out.print("fail {s} (CLua compile/link failed)\n{s}", .{ path, clua_compile.stderr });
        return;
    }

    var zlua_compile = try compileFixture(allocator, io, path, options, .zlua);
    defer zlua_compile.deinit(allocator);
    if (!zlua_compile.success()) {
        counts.failed += 1;
        try out.print("fail {s} (zlua compile/link failed)\n{s}", .{ path, zlua_compile.stderr });
        return;
    }

    const clua_exe = try outputPath(allocator, path, .clua);
    defer allocator.free(clua_exe);
    const zlua_exe = try outputPath(allocator, path, .zlua);
    defer allocator.free(zlua_exe);

    var clua_result = try process.runProcess(allocator, io, &.{clua_exe}, .{ .timeout_ms = options.timeout_ms });
    defer clua_result.deinit(allocator);
    var zlua_result = try process.runProcess(allocator, io, &.{zlua_exe}, .{ .timeout_ms = options.timeout_ms });
    defer zlua_result.deinit(allocator);

    if (sameResult(clua_result, zlua_result)) {
        counts.passed += 1;
        try out.print("pass {s}\n", .{path});
    } else {
        counts.failed += 1;
        try out.print("fail {s} (CLua/zlua result mismatch)\n", .{path});
        try printResult(out, "clua", clua_result);
        try printResult(out, "zlua", zlua_result);
    }
}

fn compileFixture(allocator: std.mem.Allocator, io: std.Io, path: []const u8, options: Options, variant: Variant) !process.ProcessResult {
    const out_path = try outputPath(allocator, path, variant);
    defer allocator.free(out_path);

    const include_dir = switch (variant) {
        .clua => options.clua_include,
        .zlua => options.zlua_include,
    };
    const lib_path = switch (variant) {
        .clua => options.clua_lib.?,
        .zlua => options.zlua_lib.?,
    };

    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{
        options.zig,
        "cc",
        "-std=c99",
        "-Wall",
        "-Wextra",
        "-I",
        include_dir,
        path,
        lib_path,
        "-o",
        out_path,
    });
    if (variant == .clua and builtin.os.tag != .windows) try argv.append(allocator, "-lm");
    if (variant == .clua and builtin.os.tag == .linux) try argv.append(allocator, "-ldl");

    if (options.show_build) {
        var buffer: [8192]u8 = undefined;
        var writer = File.stdout().writer(io, &buffer);
        const out = &writer.interface;
        try out.print("build {s}:", .{variant.name()});
        for (argv.items) |arg| try out.print(" {s}", .{arg});
        try out.print("\n", .{});
        try out.flush();
    }

    return process.runProcess(allocator, io, argv.items, .{ .timeout_ms = options.compile_timeout_ms });
}

fn outputPath(allocator: std.mem.Allocator, path: []const u8, variant: Variant) ![]u8 {
    const name = try allocator.dupe(u8, path);
    defer allocator.free(name);
    for (name) |*byte| {
        if (byte.* == '/' or byte.* == '\\' or byte.* == '.') byte.* = '_';
    }
    const suffix = if (builtin.os.tag == .windows) ".exe" else "";
    const file_name = try std.fmt.allocPrint(allocator, "{s}-{s}{s}", .{ name, variant.name(), suffix });
    defer allocator.free(file_name);
    return std.fs.path.join(allocator, &.{ ".zig-cache", "c-api-fixtures", file_name });
}

fn sameResult(a: process.ProcessResult, b: process.ProcessResult) bool {
    return a.exit_code == b.exit_code and
        a.signal == b.signal and
        a.timed_out == b.timed_out and
        std.mem.eql(u8, a.stdout, b.stdout) and
        std.mem.eql(u8, a.stderr, b.stderr);
}

fn printResult(out: anytype, label: []const u8, result: process.ProcessResult) !void {
    try out.print("{s}: exit={?d} signal={?d} timeout={}\n", .{ label, result.exit_code, result.signal, result.timed_out });
    if (result.stdout.len > 0) try out.print("{s} stdout:\n{s}", .{ label, result.stdout });
    if (result.stderr.len > 0) try out.print("{s} stderr:\n{s}", .{ label, result.stderr });
}

fn lessThanString(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn stderrPrint(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var buffer: [1024]u8 = undefined;
    var writer = File.stderr().writer(io, &buffer);
    try writer.interface.print(fmt, args);
    try writer.interface.flush();
}

test "public symbol inventory has entries" {
    try std.testing.expect(public_symbols.len > 100);
    try std.testing.expect(knownSymbol("lua_newstate"));
    try std.testing.expect(!knownSymbol("lua_call"));
}
