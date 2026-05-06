const std = @import("std");
const compile = @import("compile.zig");
const runtime = @import("runtime.zig");

pub const base = @import("stdlib/base.zig");
pub const table = @import("stdlib/table.zig");
pub const string = @import("stdlib/string.zig");
pub const math = @import("stdlib/math.zig");
pub const utf8 = @import("stdlib/utf8.zig");
pub const coroutine = @import("stdlib/coroutine.zig");
pub const debug = @import("stdlib/debug.zig");
pub const package = @import("stdlib/package.zig");
pub const io = @import("stdlib/io.zig");
pub const os = @import("stdlib/os.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub const LibrarySelection = union(enum) {
    none,
    base,
    safe,
    full,
    libraries: LibrarySet,

    pub fn toSet(self: LibrarySelection) LibrarySet {
        return switch (self) {
            .none => .{},
            .base => .{ .base = true },
            .safe => LibrarySet.safe(),
            .full => LibrarySet.full(),
            .libraries => |libraries| libraries,
        };
    }

    pub fn isEmpty(self: LibrarySelection) bool {
        return self.toSet().isEmpty();
    }
};

pub const LibrarySet = struct {
    base: bool = false,
    table: bool = false,
    string: bool = false,
    math: bool = false,
    utf8: bool = false,
    coroutine: bool = false,
    io: bool = false,
    os: bool = false,
    debug: bool = false,
    package: bool = false,

    pub fn safe() LibrarySet {
        return .{
            .base = true,
            .table = true,
            .string = true,
            .math = true,
            .utf8 = true,
            .coroutine = true,
        };
    }

    pub fn full() LibrarySet {
        var libraries = safe();
        libraries.io = true;
        libraries.os = true;
        libraries.debug = true;
        libraries.package = true;
        return libraries;
    }

    pub fn isEmpty(self: LibrarySet) bool {
        return !self.base and !self.table and !self.string and !self.math and !self.utf8 and !self.coroutine and !self.io and !self.os and !self.debug and !self.package;
    }
};

pub fn openLibraries(state: *State, selection: LibrarySelection) !void {
    const libraries = selection.toSet();
    if (libraries.base) try openBase(state);
    if (libraries.table) try openTable(state);
    if (libraries.string) try openString(state);
    if (libraries.math) try openMath(state);
    if (libraries.utf8) try openUtf8(state);
    if (libraries.coroutine) try openCoroutine(state);
    if (libraries.io) try openIo(state);
    if (libraries.os) try openOs(state);
    if (libraries.debug) try openDebug(state);
    if (libraries.package) try openPackage(state, libraries);
}

pub fn installGlobalTable(state: *State) !void {
    const global_value = try state.newTableWithHints(0, @intCast(state.globals.count() + 1));
    const table_value = global_value.table;
    state.global_table = table_value;

    var globals = state.globals.iterator();
    while (globals.next()) |entry| {
        try table_value.set(state.allocator, .{ .string = entry.key_ptr.* }, entry.value_ptr.*);
    }

    const key = try state.intern("_G");
    try state.globals.put(key, global_value);
    try table_value.set(state.allocator, .{ .string = key }, global_value);
}

fn openBase(state: *State) !void {
    try state.globals.put(try state.intern("print"), .native_print);
    try state.globals.put(try state.intern("tostring"), .native_tostring);
    try state.globals.put(try state.intern("getmetatable"), .native_getmetatable);
    try state.globals.put(try state.intern("setmetatable"), .native_setmetatable);
    try state.globals.put(try state.intern("rawequal"), .native_rawequal);
    try state.globals.put(try state.intern("rawget"), .native_rawget);
    try state.globals.put(try state.intern("rawset"), .native_rawset);
    try state.globals.put(try state.intern("rawlen"), .native_rawlen);
    try state.globals.put(try state.intern("next"), .native_next);
    try state.globals.put(try state.intern("pairs"), .native_pairs);
    try state.globals.put(try state.intern("ipairs"), .native_ipairs);
    try state.globals.put(try state.intern("select"), .native_select);
    try state.globals.put(try state.intern("assert"), .native_assert);
    try state.globals.put(try state.intern("error"), .native_error);
    try state.globals.put(try state.intern("pcall"), .native_pcall);
    try state.globals.put(try state.intern("xpcall"), .native_xpcall);
    try state.globals.put(try state.intern("collectgarbage"), .native_collectgarbage);
    try state.globals.put(try state.intern("load"), .{ .native = .load });
    try state.globals.put(try state.intern("type"), .{ .native = .type });
    try state.globals.put(try state.intern("tonumber"), .{ .native = .tonumber });
    try state.globals.put(try state.intern("warn"), .{ .native = .warn });
    try state.globals.put(try state.intern("_VERSION"), .{ .string = try state.intern("Lua 5.5") });
}

fn openTable(state: *State) !void {
    const table_lib = try state.newTableWithHints(0, 8);
    try setField(state, table_lib, "concat", .{ .native = .table_concat });
    try setField(state, table_lib, "insert", .{ .native = .table_insert });
    try setField(state, table_lib, "move", .{ .native = .table_move });
    try setField(state, table_lib, "pack", .{ .native = .table_pack });
    try setField(state, table_lib, "remove", .{ .native = .table_remove });
    try setField(state, table_lib, "sort", .{ .native = .table_sort });
    try setField(state, table_lib, "unpack", .{ .native = .table_unpack });
    try setField(state, table_lib, "create", .native_table_create);
    try state.globals.put(try state.intern("table"), table_lib);
}

fn openString(state: *State) !void {
    const string_lib = try state.newTableWithHints(0, 20);
    try setField(state, string_lib, "byte", .{ .native = .string_byte });
    try setField(state, string_lib, "char", .{ .native = .string_char });
    try setField(state, string_lib, "dump", .{ .native = .string_dump });
    try setField(state, string_lib, "find", .{ .native = .string_find });
    try setField(state, string_lib, "format", .{ .native = .string_format });
    try setField(state, string_lib, "gmatch", .{ .native = .string_gmatch });
    try setField(state, string_lib, "gsub", .{ .native = .string_gsub });
    try setField(state, string_lib, "len", .{ .native = .string_len });
    try setField(state, string_lib, "lower", .{ .native = .string_lower });
    try setField(state, string_lib, "match", .{ .native = .string_match });
    try setField(state, string_lib, "pack", .{ .native = .string_pack });
    try setField(state, string_lib, "packsize", .{ .native = .string_packsize });
    try setField(state, string_lib, "rep", .{ .native = .string_rep });
    try setField(state, string_lib, "reverse", .{ .native = .string_reverse });
    try setField(state, string_lib, "sub", .{ .native = .string_sub });
    try setField(state, string_lib, "unpack", .{ .native = .string_unpack });
    try setField(state, string_lib, "upper", .{ .native = .string_upper });
    try state.globals.put(try state.intern("string"), string_lib);

    const string_metatable = try state.newTableWithHints(0, 1);
    try setField(state, string_metatable, "__index", string_lib);
    state.string_metatable = string_metatable.table;
}

fn openMath(state: *State) !void {
    const math_lib = try state.newTableWithHints(0, 32);
    try setField(state, math_lib, "abs", .{ .native = .math_abs });
    try setField(state, math_lib, "acos", .{ .native = .math_acos });
    try setField(state, math_lib, "asin", .{ .native = .math_asin });
    try setField(state, math_lib, "atan", .{ .native = .math_atan });
    try setField(state, math_lib, "ceil", .{ .native = .math_ceil });
    try setField(state, math_lib, "cos", .{ .native = .math_cos });
    try setField(state, math_lib, "deg", .{ .native = .math_deg });
    try setField(state, math_lib, "exp", .{ .native = .math_exp });
    try setField(state, math_lib, "floor", .{ .native = .math_floor });
    try setField(state, math_lib, "fmod", .{ .native = .math_fmod });
    try setField(state, math_lib, "frexp", .{ .native = .math_frexp });
    try setField(state, math_lib, "huge", .{ .number = std.math.inf(f64) });
    try setField(state, math_lib, "ldexp", .{ .native = .math_ldexp });
    try setField(state, math_lib, "log", .{ .native = .math_log });
    try setField(state, math_lib, "maxinteger", .{ .integer = std.math.maxInt(i64) });
    try setField(state, math_lib, "max", .{ .native = .math_max });
    try setField(state, math_lib, "mininteger", .{ .integer = std.math.minInt(i64) });
    try setField(state, math_lib, "min", .{ .native = .math_min });
    try setField(state, math_lib, "modf", .{ .native = .math_modf });
    try setField(state, math_lib, "pi", .{ .number = std.math.pi });
    try setField(state, math_lib, "rad", .{ .native = .math_rad });
    try setField(state, math_lib, "random", .{ .native = .math_random });
    try setField(state, math_lib, "randomseed", .{ .native = .math_randomseed });
    try setField(state, math_lib, "sin", .{ .native = .math_sin });
    try setField(state, math_lib, "sqrt", .{ .native = .math_sqrt });
    try setField(state, math_lib, "tan", .{ .native = .math_tan });
    try setField(state, math_lib, "tointeger", .{ .native = .math_tointeger });
    try setField(state, math_lib, "type", .{ .native = .math_type });
    try setField(state, math_lib, "ult", .{ .native = .math_ult });
    try state.globals.put(try state.intern("math"), math_lib);
}

fn openUtf8(state: *State) !void {
    const utf8_lib = try state.newTableWithHints(0, 6);
    try setField(state, utf8_lib, "char", .{ .native = .utf8_char });
    try setField(state, utf8_lib, "charpattern", .{ .string = try state.intern("[\x00-\x7F\xC2-\xFD][\x80-\xBF]*") });
    try setField(state, utf8_lib, "codepoint", .{ .native = .utf8_codepoint });
    try setField(state, utf8_lib, "codes", .{ .native = .utf8_codes });
    try setField(state, utf8_lib, "len", .{ .native = .utf8_len });
    try setField(state, utf8_lib, "offset", .{ .native = .utf8_offset });
    try state.globals.put(try state.intern("utf8"), utf8_lib);
}

fn openCoroutine(state: *State) !void {
    const coroutine_lib = try state.newTableWithHints(0, 8);
    try setField(state, coroutine_lib, "create", .native_coroutine_create);
    try setField(state, coroutine_lib, "resume", .native_coroutine_resume);
    try setField(state, coroutine_lib, "yield", .native_coroutine_yield);
    try setField(state, coroutine_lib, "status", .native_coroutine_status);
    try setField(state, coroutine_lib, "running", .native_coroutine_running);
    try setField(state, coroutine_lib, "isyieldable", .native_coroutine_isyieldable);
    try setField(state, coroutine_lib, "close", .native_coroutine_close);
    try setField(state, coroutine_lib, "wrap", .native_coroutine_wrap);
    try state.globals.put(try state.intern("coroutine"), coroutine_lib);
}

fn openIo(state: *State) !void {
    const io_lib = try state.newTableWithHints(0, 16);
    const stdin = try newStandardFile(state, "stdin", "r");
    const stdout = try newStandardFile(state, "stdout", "w");
    const stderr = try newStandardFile(state, "stderr", "w");
    try setField(state, io_lib, "read", .{ .native = .io_read });
    try setField(state, io_lib, "write", .{ .native = .io_write });
    try setField(state, io_lib, "open", .{ .native = .io_open });
    try setField(state, io_lib, "input", .{ .native = .io_input });
    try setField(state, io_lib, "output", .{ .native = .io_output });
    try setField(state, io_lib, "close", .{ .native = .io_close });
    try setField(state, io_lib, "flush", .{ .native = .io_flush });
    try setField(state, io_lib, "lines", .{ .native = .io_lines });
    try setField(state, io_lib, "tmpfile", .{ .native = .io_tmpfile });
    try setField(state, io_lib, "type", .{ .native = .io_type });
    try setField(state, io_lib, "stdin", stdin);
    try setField(state, io_lib, "stdout", stdout);
    try setField(state, io_lib, "stderr", stderr);
    try setField(state, io_lib, "__zlua_input", stdin);
    try setField(state, io_lib, "__zlua_output", stdout);
    try state.globals.put(try state.intern("io"), io_lib);
}

fn openOs(state: *State) !void {
    const os_lib = try state.newTableWithHints(0, 12);
    try setField(state, os_lib, "time", .{ .native = .os_time });
    try setField(state, os_lib, "clock", .{ .native = .os_clock });
    try setField(state, os_lib, "date", .{ .native = .os_date });
    try setField(state, os_lib, "getenv", .{ .native = .os_getenv });
    try setField(state, os_lib, "setlocale", .{ .native = .os_setlocale });
    try setField(state, os_lib, "execute", .{ .native = .os_execute });
    try setField(state, os_lib, "remove", .{ .native = .os_remove });
    try setField(state, os_lib, "rename", .{ .native = .os_rename });
    try setField(state, os_lib, "tmpname", .{ .native = .os_tmpname });
    try setField(state, os_lib, "difftime", .{ .native = .os_difftime });
    try state.globals.put(try state.intern("os"), os_lib);
}

fn openDebug(state: *State) !void {
    const debug_lib = try state.newTableWithHints(0, 10);
    try setField(state, debug_lib, "traceback", .native_debug_traceback);
    try setField(state, debug_lib, "getinfo", .{ .native = .debug_getinfo });
    try setField(state, debug_lib, "getupvalue", .{ .native = .debug_getupvalue });
    try setField(state, debug_lib, "setupvalue", .{ .native = .debug_setupvalue });
    try setField(state, debug_lib, "upvalueid", .{ .native = .debug_upvalueid });
    try setField(state, debug_lib, "upvaluejoin", .{ .native = .debug_upvaluejoin });
    try setField(state, debug_lib, "getlocal", .{ .native = .debug_getlocal });
    try setField(state, debug_lib, "setlocal", .{ .native = .debug_setlocal });
    try setField(state, debug_lib, "getregistry", .{ .native = .debug_getregistry });
    try setField(state, debug_lib, "sethook", .{ .native = .debug_sethook });
    try setField(state, debug_lib, "gethook", .{ .native = .debug_gethook });
    try setField(state, debug_lib, "setmetatable", .{ .native = .debug_setmetatable });
    try setField(state, debug_lib, "setuservalue", .{ .native = .debug_setuservalue });
    try setField(state, debug_lib, "getuservalue", .{ .native = .debug_getuservalue });
    try state.globals.put(try state.intern("debug"), debug_lib);
}

fn openPackage(state: *State, libraries: LibrarySet) !void {
    try state.globals.put(try state.intern("loadfile"), .{ .native = .loadfile });
    try state.globals.put(try state.intern("dofile"), .{ .native = .dofile });
    try state.globals.put(try state.intern("require"), .{ .native = .require });

    const package_lib = try state.newTableWithHints(0, 8);
    const loaded = try state.newTableWithHints(0, 8);
    const preload = try state.newTableWithHints(0, 4);
    const searchers = try state.newTableWithHints(2, 0);
    try searchers.table.set(state.allocator, .{ .integer = 1 }, .{ .native = .package_searcher_preload });
    try searchers.table.set(state.allocator, .{ .integer = 2 }, .{ .native = .package_searcher_lua });
    if (libraries.coroutine) try setField(state, loaded, "coroutine", state.getGlobal("coroutine"));
    if (libraries.debug) try setField(state, loaded, "debug", state.getGlobal("debug"));
    if (libraries.io) try setField(state, loaded, "io", state.getGlobal("io"));
    if (libraries.math) try setField(state, loaded, "math", state.getGlobal("math"));
    if (libraries.os) try setField(state, loaded, "os", state.getGlobal("os"));
    if (libraries.string) try setField(state, loaded, "string", state.getGlobal("string"));
    if (libraries.table) try setField(state, loaded, "table", state.getGlobal("table"));
    if (libraries.utf8) try setField(state, loaded, "utf8", state.getGlobal("utf8"));
    try setField(state, loaded, "package", package_lib);
    try setField(state, package_lib, "loaded", loaded);
    try setField(state, package_lib, "preload", preload);
    try setField(state, package_lib, "searchers", searchers);
    try setField(state, package_lib, "searchpath", .{ .native = .package_searchpath });
    try setField(state, package_lib, "path", .{ .string = try state.intern("./?.lua;./?/init.lua") });
    try setField(state, package_lib, "cpath", .{ .string = try state.intern("") });
    try setField(state, package_lib, "config", .{ .string = try state.intern("/\n;\n?\n!\n-\n") });
    try state.globals.put(try state.intern("package"), package_lib);
}

fn newStandardFile(state: *State, path: []const u8, mode: []const u8) !Value {
    const value = try state.newTableWithHints(0, 10);
    const file = value.table;
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file") }, .{ .boolean = true });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_path") }, .{ .string = try state.intern(path) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_mode") }, .{ .string = try state.intern(mode) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern("") });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = 1 });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_closed") }, .{ .boolean = false });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_standard") }, .{ .boolean = true });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_buffer_mode") }, .{ .string = try state.intern("full") });
    try file.set(state.allocator, .{ .string = try state.intern("read") }, .{ .native = .io_file_read });
    try file.set(state.allocator, .{ .string = try state.intern("write") }, .{ .native = .io_file_write });
    try file.set(state.allocator, .{ .string = try state.intern("close") }, .{ .native = .io_file_close });
    try file.set(state.allocator, .{ .string = try state.intern("seek") }, .{ .native = .io_file_seek });
    try file.set(state.allocator, .{ .string = try state.intern("flush") }, .{ .native = .io_file_flush });
    try file.set(state.allocator, .{ .string = try state.intern("lines") }, .{ .native = .io_file_lines });
    try file.set(state.allocator, .{ .string = try state.intern("setvbuf") }, .{ .native = .io_file_setvbuf });
    file.metatable = try state.fileMetatable();
    return value;
}

fn setField(state: *State, table_value: Value, name: []const u8, value: Value) !void {
    try table_value.table.set(state.allocator, .{ .string = try state.intern(name) }, value);
}

pub const NativeFn = enum {
    load,
    type,
    tonumber,
    warn,
    table_concat,
    table_insert,
    table_move,
    table_pack,
    table_remove,
    table_sort,
    table_unpack,
    string_byte,
    string_char,
    string_dump,
    string_find,
    string_format,
    string_gmatch,
    string_gmatch_iter,
    string_gsub,
    string_len,
    string_lower,
    string_match,
    string_pack,
    string_packsize,
    string_rep,
    string_reverse,
    string_sub,
    string_unpack,
    string_upper,
    math_abs,
    math_acos,
    math_asin,
    math_atan,
    math_ceil,
    math_cos,
    math_deg,
    math_exp,
    math_floor,
    math_fmod,
    math_frexp,
    math_ldexp,
    math_log,
    math_max,
    math_min,
    math_modf,
    math_rad,
    math_random,
    math_randomseed,
    math_sin,
    math_sqrt,
    math_tan,
    math_tointeger,
    math_type,
    math_ult,
    utf8_char,
    utf8_codepoint,
    utf8_codes,
    utf8_codes_iter,
    utf8_len,
    utf8_offset,
    loadfile,
    dofile,
    require,
    package_searchpath,
    package_searcher_preload,
    package_searcher_lua,
    io_read,
    io_write,
    io_open,
    io_input,
    io_output,
    io_close,
    io_flush,
    io_lines,
    io_tmpfile,
    io_type,
    io_file_read,
    io_file_write,
    io_file_close,
    io_file_seek,
    io_file_flush,
    io_file_lines,
    io_file_setvbuf,
    io_lines_iter,
    os_time,
    os_clock,
    os_date,
    os_getenv,
    os_setlocale,
    os_execute,
    os_remove,
    os_rename,
    os_tmpname,
    os_difftime,
    debug_getinfo,
    debug_getupvalue,
    debug_setupvalue,
    debug_upvalueid,
    debug_upvaluejoin,
    debug_getlocal,
    debug_setlocal,
    debug_getregistry,
    debug_sethook,
    debug_gethook,
    debug_setmetatable,
    debug_setuservalue,
    debug_getuservalue,
    api_callback_dispatch,

    pub fn name(self: NativeFn) []const u8 {
        return switch (self) {
            .load => "load",
            .type => "type",
            .tonumber => "tonumber",
            .warn => "warn",
            .table_concat => "table.concat",
            .table_insert => "table.insert",
            .table_move => "table.move",
            .table_pack => "table.pack",
            .table_remove => "table.remove",
            .table_sort => "table.sort",
            .table_unpack => "table.unpack",
            .string_byte => "string.byte",
            .string_char => "string.char",
            .string_dump => "string.dump",
            .string_find => "string.find",
            .string_format => "string.format",
            .string_gmatch => "string.gmatch",
            .string_gmatch_iter => "string.gmatch iterator",
            .string_gsub => "string.gsub",
            .string_len => "string.len",
            .string_lower => "string.lower",
            .string_match => "string.match",
            .string_pack => "string.pack",
            .string_packsize => "string.packsize",
            .string_rep => "string.rep",
            .string_reverse => "string.reverse",
            .string_sub => "string.sub",
            .string_unpack => "string.unpack",
            .string_upper => "string.upper",
            .math_abs => "math.abs",
            .math_acos => "math.acos",
            .math_asin => "math.asin",
            .math_atan => "math.atan",
            .math_ceil => "math.ceil",
            .math_cos => "math.cos",
            .math_deg => "math.deg",
            .math_exp => "math.exp",
            .math_floor => "math.floor",
            .math_fmod => "math.fmod",
            .math_frexp => "math.frexp",
            .math_ldexp => "math.ldexp",
            .math_log => "math.log",
            .math_max => "math.max",
            .math_min => "math.min",
            .math_modf => "math.modf",
            .math_rad => "math.rad",
            .math_random => "math.random",
            .math_randomseed => "math.randomseed",
            .math_sin => "math.sin",
            .math_sqrt => "math.sqrt",
            .math_tan => "math.tan",
            .math_tointeger => "math.tointeger",
            .math_type => "math.type",
            .math_ult => "math.ult",
            .utf8_char => "utf8.char",
            .utf8_codepoint => "utf8.codepoint",
            .utf8_codes => "utf8.codes",
            .utf8_codes_iter => "utf8.codes iterator",
            .utf8_len => "utf8.len",
            .utf8_offset => "utf8.offset",
            .loadfile => "loadfile",
            .dofile => "dofile",
            .require => "require",
            .package_searchpath => "package.searchpath",
            .package_searcher_preload => "package.searchers preload",
            .package_searcher_lua => "package.searchers Lua",
            .io_read => "io.read",
            .io_write => "io.write",
            .io_open => "io.open",
            .io_input => "io.input",
            .io_output => "io.output",
            .io_close => "io.close",
            .io_flush => "io.flush",
            .io_lines => "io.lines",
            .io_tmpfile => "io.tmpfile",
            .io_type => "io.type",
            .io_file_read => "file:read",
            .io_file_write => "file:write",
            .io_file_close => "file:close",
            .io_file_seek => "file:seek",
            .io_file_flush => "file:flush",
            .io_file_lines => "file:lines",
            .io_file_setvbuf => "file:setvbuf",
            .io_lines_iter => "file lines iterator",
            .os_time => "os.time",
            .os_clock => "os.clock",
            .os_date => "os.date",
            .os_getenv => "os.getenv",
            .os_setlocale => "os.setlocale",
            .os_execute => "os.execute",
            .os_remove => "os.remove",
            .os_rename => "os.rename",
            .os_tmpname => "os.tmpname",
            .os_difftime => "os.difftime",
            .debug_getinfo => "debug.getinfo",
            .debug_getupvalue => "debug.getupvalue",
            .debug_setupvalue => "debug.setupvalue",
            .debug_upvalueid => "debug.upvalueid",
            .debug_upvaluejoin => "debug.upvaluejoin",
            .debug_getlocal => "debug.getlocal",
            .debug_setlocal => "debug.setlocal",
            .debug_getregistry => "debug.getregistry",
            .debug_sethook => "debug.sethook",
            .debug_gethook => "debug.gethook",
            .debug_setmetatable => "debug.setmetatable",
            .debug_setuservalue => "debug.setuservalue",
            .debug_getuservalue => "debug.getuservalue",
            .api_callback_dispatch => "__zlua_api_callback",
        };
    }
};

pub fn callNative(state: *State, native: NativeFn, thread: *Thread, op: bytecode.Call) !void {
    switch (native) {
        .load => try base.load(state, thread, op),
        .type => try base.typeValue(state, thread, op),
        .tonumber => try base.tonumber(state, thread, op),
        .warn => try base.warn(state, thread, op),
        .table_concat => try table.concat(state, thread, op),
        .table_insert => try table.insert(state, thread, op),
        .table_move => try table.move(state, thread, op),
        .table_pack => try table.pack(state, thread, op),
        .table_remove => try table.remove(state, thread, op),
        .table_sort => try table.sort(state, thread, op),
        .table_unpack => try table.unpack(state, thread, op),
        .string_byte => try string.byte(state, thread, op),
        .string_char => try string.char(state, thread, op),
        .string_dump => try string.dump(state, thread, op),
        .string_find => try string.find(state, thread, op),
        .string_format => try string.format(state, thread, op),
        .string_gmatch => try string.gmatch(state, thread, op),
        .string_gmatch_iter => try string.gmatchIter(state, thread, op),
        .string_gsub => try string.gsub(state, thread, op),
        .string_len => try string.len(state, thread, op),
        .string_lower => try string.lower(state, thread, op),
        .string_match => try string.match(state, thread, op),
        .string_pack => try string.pack(state, thread, op),
        .string_packsize => try string.packsize(state, thread, op),
        .string_rep => try string.rep(state, thread, op),
        .string_reverse => try string.reverse(state, thread, op),
        .string_sub => try string.sub(state, thread, op),
        .string_unpack => try string.unpack(state, thread, op),
        .string_upper => try string.upper(state, thread, op),
        .math_abs => try math.abs(state, thread, op),
        .math_acos => try math.acos(state, thread, op),
        .math_asin => try math.asin(state, thread, op),
        .math_atan => try math.atan(state, thread, op),
        .math_ceil => try math.ceil(state, thread, op),
        .math_cos => try math.cos(state, thread, op),
        .math_deg => try math.deg(state, thread, op),
        .math_exp => try math.exp(state, thread, op),
        .math_floor => try math.floor(state, thread, op),
        .math_fmod => try math.fmod(state, thread, op),
        .math_frexp => try math.frexp(state, thread, op),
        .math_ldexp => try math.ldexp(state, thread, op),
        .math_log => try math.log(state, thread, op),
        .math_max => try math.max(state, thread, op),
        .math_min => try math.min(state, thread, op),
        .math_modf => try math.modf(state, thread, op),
        .math_rad => try math.rad(state, thread, op),
        .math_random => try math.random(state, thread, op),
        .math_randomseed => try math.randomseed(state, thread, op),
        .math_sin => try math.sin(state, thread, op),
        .math_sqrt => try math.sqrt(state, thread, op),
        .math_tan => try math.tan(state, thread, op),
        .math_tointeger => try math.tointeger(state, thread, op),
        .math_type => try math.typeValue(state, thread, op),
        .math_ult => try math.ult(state, thread, op),
        .utf8_char => try utf8.char(state, thread, op),
        .utf8_codepoint => try utf8.codepoint(state, thread, op),
        .utf8_codes => try utf8.codes(state, thread, op),
        .utf8_codes_iter => try utf8.codesIter(state, thread, op),
        .utf8_len => try utf8.len(state, thread, op),
        .utf8_offset => try utf8.offset(state, thread, op),
        .loadfile => try package.loadfile(state, thread, op),
        .dofile => try package.dofile(state, thread, op),
        .require => try package.require(state, thread, op),
        .package_searchpath => try package.searchpath(state, thread, op),
        .package_searcher_preload => try package.searcherPreload(state, thread, op),
        .package_searcher_lua => try package.searcherLua(state, thread, op),
        .io_read => try io.read(state, thread, op),
        .io_write => try io.write(state, thread, op),
        .io_open => try io.open(state, thread, op),
        .io_input => try io.input(state, thread, op),
        .io_output => try io.output(state, thread, op),
        .io_close => try io.close(state, thread, op),
        .io_flush => try io.flush(state, thread, op),
        .io_lines => try io.lines(state, thread, op),
        .io_tmpfile => try io.tmpfile(state, thread, op),
        .io_type => try io.typeValue(state, thread, op),
        .io_file_read => try io.fileRead(state, thread, op),
        .io_file_write => try io.fileWrite(state, thread, op),
        .io_file_close => try io.fileClose(state, thread, op),
        .io_file_seek => try io.fileSeek(state, thread, op),
        .io_file_flush => try io.fileFlush(state, thread, op),
        .io_file_lines => try io.fileLines(state, thread, op),
        .io_file_setvbuf => try io.fileSetvbuf(state, thread, op),
        .io_lines_iter => try io.linesIter(state, thread, op),
        .os_time => try os.time(state, thread, op),
        .os_clock => try os.clock(state, thread, op),
        .os_date => try os.date(state, thread, op),
        .os_getenv => try os.getenv(state, thread, op),
        .os_setlocale => try os.setlocale(state, thread, op),
        .os_execute => try os.execute(state, thread, op),
        .os_remove => try os.remove(state, thread, op),
        .os_rename => try os.rename(state, thread, op),
        .os_tmpname => try os.tmpname(state, thread, op),
        .os_difftime => try os.difftime(state, thread, op),
        .debug_getinfo => try debug.getinfo(state, thread, op),
        .debug_getupvalue => try debug.getupvalue(state, thread, op),
        .debug_setupvalue => try debug.setupvalue(state, thread, op),
        .debug_upvalueid => try debug.upvalueid(state, thread, op),
        .debug_upvaluejoin => try debug.upvaluejoin(state, thread, op),
        .debug_getlocal => try debug.getlocal(state, thread, op),
        .debug_setlocal => try debug.setlocal(state, thread, op),
        .debug_getregistry => try debug.getregistry(state, thread, op),
        .debug_sethook => try debug.sethook(state, thread, op),
        .debug_gethook => try debug.gethook(state, thread, op),
        .debug_setmetatable => try debug.setmetatable(state, thread, op),
        .debug_setuservalue => try debug.setuservalue(state, thread, op),
        .debug_getuservalue => try debug.getuservalue(state, thread, op),
        .api_callback_dispatch => try state.callApiCallbackDispatch(thread, op),
    }
}

test {
    _ = base;
    _ = table;
    _ = string;
    _ = math;
    _ = utf8;
    _ = coroutine;
    _ = debug;
    _ = package;
    _ = io;
    _ = os;
}
