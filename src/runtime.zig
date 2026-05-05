const std = @import("std");
const compile = @import("compile.zig");
const frontend = @import("frontend.zig");
const process = @import("testing/process.zig");
const stdlib = @import("stdlib.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

pub const RuntimeError = error{
    RuntimeError,
    StackOverflow,
    UnsupportedOpcode,
};

const max_stack_values: usize = 8192;
const max_call_frames: usize = 256;
const max_metamethod_depth: usize = 15;
pub const binary_chunk_signature = "\x1bLua";
pub const binary_chunk_payload_magic = "zlua\x00dump";

pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: *Table,
    closure: *Closure,
    thread: *Thread,
    coroutine_wrapper: *Thread,
    native_print,
    native_tostring,
    native_getmetatable,
    native_setmetatable,
    native_rawequal,
    native_rawget,
    native_rawset,
    native_rawlen,
    native_next,
    native_pairs,
    native_ipairs,
    native_ipairs_iter,
    native_table_create,
    native_select,
    native_assert,
    native_error,
    native_pcall,
    native_xpcall,
    native_collectgarbage,
    native_debug_traceback,
    native_coroutine_create,
    native_coroutine_resume,
    native_coroutine_yield,
    native_coroutine_status,
    native_coroutine_running,
    native_coroutine_wrap,
    native: NativeFn,
};

pub const NativeFn = stdlib.NativeFn;

pub const ProtectedCallResult = union(enum) {
    success: []Value,
    failure: Value,
};

pub fn appendBinaryChunkHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
    try out.appendSlice(allocator, binary_chunk_signature);
    try out.append(allocator, 0x55);
    try out.append(allocator, 0);
    try out.appendSlice(allocator, "\x19\x93\r\n\x1a\n");
    try out.append(allocator, @sizeOf(c_int));
    try appendHeaderInt(allocator, out, -0x5678, @sizeOf(c_int));
    try out.append(allocator, 4);
    try appendHeaderInt(allocator, out, 0x12345678, 4);
    try out.append(allocator, @sizeOf(i64));
    try appendHeaderInt(allocator, out, -0x5678, @sizeOf(i64));
    try out.append(allocator, @sizeOf(f64));
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], @bitCast(@as(f64, -370.5)), nativeEndian());
    try out.appendSlice(allocator, bytes[0..8]);
}

fn appendHeaderInt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: i64, size: usize) !void {
    var bytes: [8]u8 = undefined;
    const unsigned: u64 = @bitCast(value);
    switch (size) {
        1 => bytes[0] = @truncate(unsigned),
        2 => std.mem.writeInt(u16, bytes[0..2], @truncate(unsigned), nativeEndian()),
        4 => std.mem.writeInt(u32, bytes[0..4], @truncate(unsigned), nativeEndian()),
        8 => std.mem.writeInt(u64, bytes[0..8], unsigned, nativeEndian()),
        else => unreachable,
    }
    try out.appendSlice(allocator, bytes[0..size]);
}

fn nativeEndian() std.builtin.Endian {
    return switch (@import("builtin").target.cpu.arch.endian()) {
        .little => .little,
        .big => .big,
    };
}

const CoroutineResumeResult = union(enum) {
    success: []Value,
    failure: Value,
};

const Closure = struct {
    proto: *const proto_mod.Proto,
    upvalues: []*Upvalue,
    marked: bool = false,
};

pub const Upvalue = struct {
    owner: *Thread,
    stack_index: usize,
    closed: Value = .nil,
    is_open: bool = true,
    next: ?*Upvalue = null,
    marked: bool = false,
};

const TableEntry = struct {
    key: Value,
    value: Value,
};

pub const Table = struct {
    array: std.ArrayList(Value) = .empty,
    entries: std.ArrayList(TableEntry) = .empty,
    metatable: ?*Table = null,
    marked: bool = false,
    finalized: bool = false,

    fn init(allocator: std.mem.Allocator, array_hint: u32, hash_hint: u32) !Table {
        var table = Table{};
        errdefer table.deinit(allocator);
        try table.array.ensureTotalCapacity(allocator, array_hint);
        try table.entries.ensureTotalCapacity(allocator, hash_hint);
        return table;
    }

    fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.array.deinit(allocator);
        self.* = undefined;
    }

    pub fn get(self: Table, key: Value) Value {
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.array.items[index - 1];
        }
        for (self.entries.items) |entry| {
            if (valuesEqual(entry.key, key)) return entry.value;
        }
        return .nil;
    }

    pub fn set(self: *Table, allocator: std.mem.Allocator, key: Value, value: Value) !void {
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) {
                self.array.items[index - 1] = value;
                return;
            }
            if (value != .nil and (index == self.array.items.len + 1 or index <= self.array.capacity)) {
                const old_len = self.array.items.len;
                try self.array.resize(allocator, index);
                @memset(self.array.items[old_len..], .nil);
                self.array.items[index - 1] = value;
                self.removeHashKey(key);
                return;
            }
        }
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                if (value == .nil) {
                    _ = self.entries.swapRemove(index);
                } else {
                    self.entries.items[index].value = value;
                }
                return;
            }
        }
        if (value != .nil) try self.entries.append(allocator, .{ .key = key, .value = value });
    }

    pub fn len(self: Table) i64 {
        var result = self.array.items.len;
        while (result > 0 and self.array.items[result - 1] == .nil) result -= 1;
        while (result < std.math.maxInt(i64)) {
            const next_index = result + 1;
            if (self.get(.{ .integer = @intCast(next_index) }) == .nil) break;
            result = next_index;
        }
        return @intCast(result);
    }

    fn next(self: Table, key: Value) ![2]Value {
        if (key == .nil) return self.firstEntryAfterArray(0);
        if (arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.firstEntryAfterArray(index);
        }
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                if (index + 1 < self.entries.items.len) {
                    const next_entry = self.entries.items[index + 1];
                    return .{ next_entry.key, next_entry.value };
                }
                return .{ .nil, .nil };
            }
        }
        return error.RuntimeError;
    }

    fn firstEntryAfterArray(self: Table, index: usize) [2]Value {
        var next_index = index;
        while (next_index < self.array.items.len) {
            next_index += 1;
            const value = self.array.items[next_index - 1];
            if (value != .nil) return .{ .{ .integer = @intCast(next_index) }, value };
        }
        if (self.entries.items.len == 0) return .{ .nil, .nil };
        const entry = self.entries.items[0];
        return .{ entry.key, entry.value };
    }

    fn removeHashKey(self: *Table, key: Value) void {
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, key)) {
                _ = self.entries.swapRemove(index);
                return;
            }
        }
    }
};

pub const Thread = struct {
    stack: std.ArrayList(Value) = .empty,
    frames: std.ArrayList(CallFrame) = .empty,
    yield_values: std.ArrayList(Value) = .empty,
    open_upvalues: ?*Upvalue = null,
    last_result_base: usize = 0,
    last_result_count: usize = 0,
    yield_result_base: usize = 0,
    yield_result_count: u16 = 0,
    yield_tail_return: bool = false,
    yield_tail_base: bytecode.Register = 0,
    yield_tail_count: u16 = 0,
    native_call_depth: usize = 0,
    entry: ?*Closure = null,
    marked: bool = false,
    started: bool = false,
    is_main: bool = false,
    status: ThreadStatus = .suspended,

    pub fn initRoot(allocator: std.mem.Allocator, closure: *Closure) !Thread {
        var thread = Thread{};
        thread.entry = closure;
        thread.started = true;
        thread.is_main = true;
        thread.status = .running;
        errdefer thread.deinit(allocator);
        const proto = closure.proto;
        try thread.ensureStack(allocator, @max(proto.max_registers, 1));
        try thread.frames.append(allocator, .{ .closure = closure, .proto = proto, .base = 0, .pc = 0, .return_start = 0, .return_count = 0, .varargs = &.{} });
        return thread;
    }

    pub fn initCoroutine(closure: *Closure) Thread {
        return .{ .entry = closure, .status = .suspended };
    }

    pub fn deinit(self: *Thread, allocator: std.mem.Allocator) void {
        for (self.frames.items) |*frame| frame.deinit(allocator);
        self.yield_values.deinit(allocator);
        self.frames.deinit(allocator);
        self.stack.deinit(allocator);
        self.* = undefined;
    }

    fn ensureStack(self: *Thread, allocator: std.mem.Allocator, size: usize) !void {
        if (size > max_stack_values) return error.StackOverflow;
        const old_len = self.stack.items.len;
        if (size <= old_len) return;
        try self.stack.resize(allocator, size);
        @memset(self.stack.items[old_len..], .nil);
    }
};

const ThreadStatus = enum {
    suspended,
    running,
    normal,
    dead,
};

const CallFrame = struct {
    closure: *Closure,
    proto: *const proto_mod.Proto,
    base: usize,
    pc: usize,
    return_start: usize,
    return_count: u16,
    varargs: []const Value,
    owns_varargs: bool = false,

    fn deinit(self: *CallFrame, allocator: std.mem.Allocator) void {
        if (self.owns_varargs) allocator.free(self.varargs);
        self.varargs = &.{};
        self.owns_varargs = false;
    }
};

const StringAllocation = struct {
    bytes: []const u8,
    marked: bool = false,
};

const GcMode = enum {
    incremental,
    generational,

    fn name(self: GcMode) []const u8 {
        return switch (self) {
            .incremental => "incremental",
            .generational => "generational",
        };
    }
};

const GcParam = enum {
    minormul,
    majorminor,
    minormajor,
    pause,
    stepmul,
    stepsize,
};

const GcParams = struct {
    minormul: i64 = 20,
    majorminor: i64 = 50,
    minormajor: i64 = 70,
    pause: i64 = 250,
    stepmul: i64 = 200,
    stepsize: i64 = 200,

    fn get(self: GcParams, param: GcParam) i64 {
        return switch (param) {
            .minormul => self.minormul,
            .majorminor => self.majorminor,
            .minormajor => self.minormajor,
            .pause => self.pause,
            .stepmul => self.stepmul,
            .stepsize => self.stepsize,
        };
    }

    fn set(self: *GcParams, param: GcParam, value: i64) void {
        switch (param) {
            .minormul => self.minormul = value,
            .majorminor => self.majorminor = value,
            .minormajor => self.minormajor = value,
            .pause => self.pause = value,
            .stepmul => self.stepmul = value,
            .stepsize => self.stepsize = value,
        }
    }
};

const WeakMode = struct {
    keys: bool = false,
    values: bool = false,
};

const RuntimeAllocationStats = struct {
    strings: usize,
    tables: usize,
    closures: usize,
    upvalues: usize,
    threads: usize,
    bytes: usize,

    fn total(self: RuntimeAllocationStats) usize {
        return self.bytes;
    }
};

pub const StdlibMode = enum {
    none,
    base,
    safe,
    full,
};

pub const MemoryFile = struct {
    path: []const u8,
    contents: []const u8,
};

pub const FilesystemCapability = union(enum) {
    disabled,
    memory: []const MemoryFile,
    host_cwd,
};

pub const ClockCapability = union(enum) {
    disabled,
    fixed: i64,
    system,
};

pub const ProcessCapability = enum {
    disabled,
    enabled,
};

pub const StateOptions = struct {
    stdlib: StdlibMode = .full,
    io: ?std.Io = null,
    filesystem: FilesystemCapability = .disabled,
    environment: ?*const std.process.Environ.Map = null,
    clock: ClockCapability = .system,
    process: ProcessCapability = .disabled,
    stdin: []const u8 = "",
};

pub const ExecuteOptions = struct {
    collect_after_instruction: bool = false,
    state: StateOptions = .{},
};

pub const State = struct {
    allocator: std.mem.Allocator,
    globals: std.StringHashMap(Value),
    global_table: ?*Table = null,
    strings: std.StringHashMap([]const u8),
    string_allocations: std.ArrayList(StringAllocation) = .empty,
    table_allocations: std.ArrayList(*Table) = .empty,
    closure_allocations: std.ArrayList(*Closure) = .empty,
    upvalue_allocations: std.ArrayList(*Upvalue) = .empty,
    thread_allocations: std.ArrayList(*Thread) = .empty,
    proto_allocations: std.ArrayList(*proto_mod.Proto) = .empty,
    source_allocations: std.ArrayList([]const u8) = .empty,
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    options: StateOptions,
    stdin_pos: usize = 0,
    last_error: ?[]const u8 = null,
    last_error_value: Value = .nil,
    current_thread: ?*Thread = null,
    string_metatable: ?*Table = null,
    is_collecting: bool = false,
    collect_after_instruction: bool = false,
    gc_running: bool = true,
    gc_mode: GcMode = .generational,
    gc_params: GcParams = .{},
    gc_next_total: usize = 0,
    mark_all_stack_registers: bool = false,
    random_state: [4]u64 = .{ 0x123456789abcdef0, 0xff, 0xfedcba9876543210, 0 },

    pub fn init(allocator: std.mem.Allocator) !State {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: StateOptions) !State {
        var state = State{
            .allocator = allocator,
            .globals = std.StringHashMap(Value).init(allocator),
            .strings = std.StringHashMap([]const u8).init(allocator),
            .options = options,
        };
        errdefer state.deinit();
        try state.openLibraries(options.stdlib);
        if (options.stdlib != .none) try state.installGlobalTable();
        state.resetAutoGcThreshold();
        return state;
    }

    fn openLibraries(state: *State, mode: StdlibMode) !void {
        switch (mode) {
            .none => return,
            .base => try state.openBaseLibrary(),
            .safe => {
                try state.openBaseLibrary();
                try state.openSafeLibraries();
            },
            .full => {
                try state.openBaseLibrary();
                try state.openSafeLibraries();
                try state.openSystemLibraries();
            },
        }
    }

    fn installGlobalTable(state: *State) !void {
        const global_value = try state.newTableWithHints(0, @intCast(state.globals.count() + 1));
        const table = global_value.table;
        state.global_table = table;

        var globals = state.globals.iterator();
        while (globals.next()) |entry| {
            try table.set(state.allocator, .{ .string = entry.key_ptr.* }, entry.value_ptr.*);
        }

        const key = try state.intern("_G");
        try state.globals.put(key, global_value);
        try table.set(state.allocator, .{ .string = key }, global_value);
    }

    fn openBaseLibrary(state: *State) !void {
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

    fn openSafeLibraries(state: *State) !void {
        const table_lib = try state.newTableWithHints(0, 8);
        try state.setTable(table_lib, .{ .string = try state.intern("concat") }, .{ .native = .table_concat });
        try state.setTable(table_lib, .{ .string = try state.intern("insert") }, .{ .native = .table_insert });
        try state.setTable(table_lib, .{ .string = try state.intern("move") }, .{ .native = .table_move });
        try state.setTable(table_lib, .{ .string = try state.intern("pack") }, .{ .native = .table_pack });
        try state.setTable(table_lib, .{ .string = try state.intern("remove") }, .{ .native = .table_remove });
        try state.setTable(table_lib, .{ .string = try state.intern("sort") }, .{ .native = .table_sort });
        try state.setTable(table_lib, .{ .string = try state.intern("unpack") }, .{ .native = .table_unpack });
        try state.setTable(table_lib, .{ .string = try state.intern("create") }, .native_table_create);
        try state.globals.put(try state.intern("table"), table_lib);

        const string_lib = try state.newTableWithHints(0, 20);
        try state.setTable(string_lib, .{ .string = try state.intern("byte") }, .{ .native = .string_byte });
        try state.setTable(string_lib, .{ .string = try state.intern("char") }, .{ .native = .string_char });
        try state.setTable(string_lib, .{ .string = try state.intern("dump") }, .{ .native = .string_dump });
        try state.setTable(string_lib, .{ .string = try state.intern("find") }, .{ .native = .string_find });
        try state.setTable(string_lib, .{ .string = try state.intern("format") }, .{ .native = .string_format });
        try state.setTable(string_lib, .{ .string = try state.intern("gmatch") }, .{ .native = .string_gmatch });
        try state.setTable(string_lib, .{ .string = try state.intern("gsub") }, .{ .native = .string_gsub });
        try state.setTable(string_lib, .{ .string = try state.intern("len") }, .{ .native = .string_len });
        try state.setTable(string_lib, .{ .string = try state.intern("lower") }, .{ .native = .string_lower });
        try state.setTable(string_lib, .{ .string = try state.intern("match") }, .{ .native = .string_match });
        try state.setTable(string_lib, .{ .string = try state.intern("pack") }, .{ .native = .string_pack });
        try state.setTable(string_lib, .{ .string = try state.intern("packsize") }, .{ .native = .string_packsize });
        try state.setTable(string_lib, .{ .string = try state.intern("rep") }, .{ .native = .string_rep });
        try state.setTable(string_lib, .{ .string = try state.intern("reverse") }, .{ .native = .string_reverse });
        try state.setTable(string_lib, .{ .string = try state.intern("sub") }, .{ .native = .string_sub });
        try state.setTable(string_lib, .{ .string = try state.intern("unpack") }, .{ .native = .string_unpack });
        try state.setTable(string_lib, .{ .string = try state.intern("upper") }, .{ .native = .string_upper });
        try state.globals.put(try state.intern("string"), string_lib);

        const string_metatable = try state.newTableWithHints(0, 1);
        try state.setTable(string_metatable, .{ .string = try state.intern("__index") }, string_lib);
        state.string_metatable = string_metatable.table;

        const math_lib = try state.newTableWithHints(0, 32);
        try state.setTable(math_lib, .{ .string = try state.intern("abs") }, .{ .native = .math_abs });
        try state.setTable(math_lib, .{ .string = try state.intern("acos") }, .{ .native = .math_acos });
        try state.setTable(math_lib, .{ .string = try state.intern("asin") }, .{ .native = .math_asin });
        try state.setTable(math_lib, .{ .string = try state.intern("atan") }, .{ .native = .math_atan });
        try state.setTable(math_lib, .{ .string = try state.intern("ceil") }, .{ .native = .math_ceil });
        try state.setTable(math_lib, .{ .string = try state.intern("cos") }, .{ .native = .math_cos });
        try state.setTable(math_lib, .{ .string = try state.intern("deg") }, .{ .native = .math_deg });
        try state.setTable(math_lib, .{ .string = try state.intern("exp") }, .{ .native = .math_exp });
        try state.setTable(math_lib, .{ .string = try state.intern("floor") }, .{ .native = .math_floor });
        try state.setTable(math_lib, .{ .string = try state.intern("fmod") }, .{ .native = .math_fmod });
        try state.setTable(math_lib, .{ .string = try state.intern("frexp") }, .{ .native = .math_frexp });
        try state.setTable(math_lib, .{ .string = try state.intern("huge") }, .{ .number = std.math.inf(f64) });
        try state.setTable(math_lib, .{ .string = try state.intern("ldexp") }, .{ .native = .math_ldexp });
        try state.setTable(math_lib, .{ .string = try state.intern("log") }, .{ .native = .math_log });
        try state.setTable(math_lib, .{ .string = try state.intern("maxinteger") }, .{ .integer = std.math.maxInt(i64) });
        try state.setTable(math_lib, .{ .string = try state.intern("max") }, .{ .native = .math_max });
        try state.setTable(math_lib, .{ .string = try state.intern("mininteger") }, .{ .integer = std.math.minInt(i64) });
        try state.setTable(math_lib, .{ .string = try state.intern("min") }, .{ .native = .math_min });
        try state.setTable(math_lib, .{ .string = try state.intern("modf") }, .{ .native = .math_modf });
        try state.setTable(math_lib, .{ .string = try state.intern("pi") }, .{ .number = std.math.pi });
        try state.setTable(math_lib, .{ .string = try state.intern("rad") }, .{ .native = .math_rad });
        try state.setTable(math_lib, .{ .string = try state.intern("random") }, .{ .native = .math_random });
        try state.setTable(math_lib, .{ .string = try state.intern("randomseed") }, .{ .native = .math_randomseed });
        try state.setTable(math_lib, .{ .string = try state.intern("sin") }, .{ .native = .math_sin });
        try state.setTable(math_lib, .{ .string = try state.intern("sqrt") }, .{ .native = .math_sqrt });
        try state.setTable(math_lib, .{ .string = try state.intern("tan") }, .{ .native = .math_tan });
        try state.setTable(math_lib, .{ .string = try state.intern("tointeger") }, .{ .native = .math_tointeger });
        try state.setTable(math_lib, .{ .string = try state.intern("type") }, .{ .native = .math_type });
        try state.setTable(math_lib, .{ .string = try state.intern("ult") }, .{ .native = .math_ult });
        try state.globals.put(try state.intern("math"), math_lib);

        const utf8_lib = try state.newTableWithHints(0, 6);
        try state.setTable(utf8_lib, .{ .string = try state.intern("char") }, .{ .native = .utf8_char });
        try state.setTable(utf8_lib, .{ .string = try state.intern("charpattern") }, .{ .string = try state.intern("[\x00-\x7F\xC2-\xFD][\x80-\xBF]*") });
        try state.setTable(utf8_lib, .{ .string = try state.intern("codepoint") }, .{ .native = .utf8_codepoint });
        try state.setTable(utf8_lib, .{ .string = try state.intern("codes") }, .{ .native = .utf8_codes });
        try state.setTable(utf8_lib, .{ .string = try state.intern("len") }, .{ .native = .utf8_len });
        try state.setTable(utf8_lib, .{ .string = try state.intern("offset") }, .{ .native = .utf8_offset });
        try state.globals.put(try state.intern("utf8"), utf8_lib);

        const coroutine_lib = try state.newTableWithHints(0, 6);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("create") }, .native_coroutine_create);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("resume") }, .native_coroutine_resume);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("yield") }, .native_coroutine_yield);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("status") }, .native_coroutine_status);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("running") }, .native_coroutine_running);
        try state.setTable(coroutine_lib, .{ .string = try state.intern("wrap") }, .native_coroutine_wrap);
        try state.globals.put(try state.intern("coroutine"), coroutine_lib);
    }

    fn openSystemLibraries(state: *State) !void {
        try state.globals.put(try state.intern("loadfile"), .{ .native = .loadfile });
        try state.globals.put(try state.intern("dofile"), .{ .native = .dofile });
        try state.globals.put(try state.intern("require"), .{ .native = .require });

        const io_lib = try state.newTableWithHints(0, 4);
        try state.setTable(io_lib, .{ .string = try state.intern("read") }, .{ .native = .io_read });
        try state.setTable(io_lib, .{ .string = try state.intern("write") }, .{ .native = .io_write });
        try state.setTable(io_lib, .{ .string = try state.intern("open") }, .{ .native = .io_open });
        try state.setTable(io_lib, .{ .string = try state.intern("type") }, .{ .native = .io_type });
        try state.globals.put(try state.intern("io"), io_lib);

        const os_lib = try state.newTableWithHints(0, 4);
        try state.setTable(os_lib, .{ .string = try state.intern("time") }, .{ .native = .os_time });
        try state.setTable(os_lib, .{ .string = try state.intern("clock") }, .{ .native = .os_clock });
        try state.setTable(os_lib, .{ .string = try state.intern("date") }, .{ .native = .os_date });
        try state.setTable(os_lib, .{ .string = try state.intern("getenv") }, .{ .native = .os_getenv });
        try state.setTable(os_lib, .{ .string = try state.intern("setlocale") }, .{ .native = .os_setlocale });
        try state.setTable(os_lib, .{ .string = try state.intern("execute") }, .{ .native = .os_execute });
        try state.globals.put(try state.intern("os"), os_lib);

        const debug_lib = try state.newTableWithHints(0, 6);
        try state.setTable(debug_lib, .{ .string = try state.intern("traceback") }, .native_debug_traceback);
        try state.setTable(debug_lib, .{ .string = try state.intern("getinfo") }, .{ .native = .debug_getinfo });
        try state.setTable(debug_lib, .{ .string = try state.intern("getupvalue") }, .{ .native = .debug_getupvalue });
        try state.setTable(debug_lib, .{ .string = try state.intern("setupvalue") }, .{ .native = .debug_setupvalue });
        try state.setTable(debug_lib, .{ .string = try state.intern("upvalueid") }, .{ .native = .debug_upvalueid });
        try state.setTable(debug_lib, .{ .string = try state.intern("upvaluejoin") }, .{ .native = .debug_upvaluejoin });
        try state.globals.put(try state.intern("debug"), debug_lib);

        const package_lib = try state.newTableWithHints(0, 8);
        const loaded = try state.newTableWithHints(0, 8);
        const preload = try state.newTableWithHints(0, 4);
        const searchers = try state.newTableWithHints(2, 0);
        try searchers.table.set(state.allocator, .{ .integer = 1 }, .{ .native = .package_searcher_preload });
        try searchers.table.set(state.allocator, .{ .integer = 2 }, .{ .native = .package_searcher_lua });
        try state.setTable(loaded, .{ .string = try state.intern("coroutine") }, state.getGlobal("coroutine"));
        try state.setTable(loaded, .{ .string = try state.intern("debug") }, debug_lib);
        try state.setTable(loaded, .{ .string = try state.intern("io") }, io_lib);
        try state.setTable(loaded, .{ .string = try state.intern("math") }, state.getGlobal("math"));
        try state.setTable(loaded, .{ .string = try state.intern("os") }, os_lib);
        try state.setTable(loaded, .{ .string = try state.intern("package") }, package_lib);
        try state.setTable(loaded, .{ .string = try state.intern("string") }, state.getGlobal("string"));
        try state.setTable(loaded, .{ .string = try state.intern("table") }, state.getGlobal("table"));
        try state.setTable(loaded, .{ .string = try state.intern("utf8") }, state.getGlobal("utf8"));
        try state.setTable(package_lib, .{ .string = try state.intern("loaded") }, loaded);
        try state.setTable(package_lib, .{ .string = try state.intern("preload") }, preload);
        try state.setTable(package_lib, .{ .string = try state.intern("searchers") }, searchers);
        try state.setTable(package_lib, .{ .string = try state.intern("searchpath") }, .{ .native = .package_searchpath });
        try state.setTable(package_lib, .{ .string = try state.intern("path") }, .{ .string = try state.intern("./?.lua;./?/init.lua") });
        try state.setTable(package_lib, .{ .string = try state.intern("cpath") }, .{ .string = try state.intern("") });
        try state.setTable(package_lib, .{ .string = try state.intern("config") }, .{ .string = try state.intern("/\n;\n?\n!\n-\n") });
        try state.globals.put(try state.intern("package"), package_lib);
    }

    pub fn deinit(self: *State) void {
        self.stdout.deinit(self.allocator);
        self.stderr.deinit(self.allocator);
        self.globals.deinit();
        self.strings.deinit();
        for (self.thread_allocations.items) |thread| self.destroyThread(thread);
        for (self.closure_allocations.items) |closure| self.destroyClosure(closure);
        for (self.upvalue_allocations.items) |upvalue| self.allocator.destroy(upvalue);
        for (self.table_allocations.items) |table| self.destroyTable(table);
        for (self.proto_allocations.items) |proto| {
            proto.deinit();
            self.allocator.destroy(proto);
        }
        for (self.source_allocations.items) |source| self.allocator.free(source);
        for (self.string_allocations.items) |allocation| self.allocator.free(allocation.bytes);
        self.source_allocations.deinit(self.allocator);
        self.proto_allocations.deinit(self.allocator);
        self.thread_allocations.deinit(self.allocator);
        self.upvalue_allocations.deinit(self.allocator);
        self.closure_allocations.deinit(self.allocator);
        self.table_allocations.deinit(self.allocator);
        self.string_allocations.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn execute(self: *State, proto: *const proto_mod.Proto) !void {
        try self.executeClosure(try self.newRootClosure(proto));
    }

    pub fn executeSourceChunk(self: *State, source: []const u8) !void {
        const loaded = try self.loadSourceAsClosure(source);
        try self.executeClosure(loaded.closure);
    }

    fn executeClosure(self: *State, closure: *Closure) !void {
        var thread = try Thread.initRoot(self.allocator, closure);
        defer thread.deinit(self.allocator);
        const previous_thread = self.current_thread;
        self.current_thread = &thread;
        defer self.current_thread = previous_thread;
        self.runThreadUntil(&thread, 0) catch |err| {
            self.closeFramesTo(&thread, 0, self.currentErrorValue()) catch |close_err| return close_err;
            thread.status = .dead;
            return err;
        };
        thread.status = .dead;
    }

    fn runThreadUntil(self: *State, thread: *Thread, target_frame_count: usize) anyerror!void {
        while (thread.frames.items.len > target_frame_count) {
            var frame = &thread.frames.items[thread.frames.items.len - 1];
            const proto = frame.proto;
            if (frame.pc >= proto.instructions.items.len) {
                try self.returnFromFrame(thread, 0, 0);
                continue;
            }
            const instruction = proto.instructions.items[frame.pc];
            frame.pc += 1;

            switch (instruction) {
                .load_nil => |dest| self.set(thread, dest, .nil),
                .load_bool => |op| self.set(thread, op.dest, .{ .boolean = op.value }),
                .load_const => |op| self.set(thread, op.dest, try self.loadConstant(proto.constants.items[op.constant])),
                .move => |op| self.set(thread, op.dest, self.get(thread, op.source)),
                .get_global => |op| self.set(thread, op.register, self.getGlobalValue(constantString(proto, op.name))),
                .set_global => |op| try self.setGlobal(constantString(proto, op.name), self.get(thread, op.register)),
                .add => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .add)),
                .sub => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .sub)),
                .mul => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .mul)),
                .div => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .div)),
                .idiv => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .idiv)),
                .mod => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .mod)),
                .pow => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .pow)),
                .band => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .band)),
                .bor => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .bor)),
                .bxor => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .bxor)),
                .shl => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .shl)),
                .shr => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .shr)),
                .unm => |op| self.set(thread, op.dest, try self.unaryOp(thread, self.get(thread, op.source), .unm)),
                .bnot => |op| self.set(thread, op.dest, try self.unaryOp(thread, self.get(thread, op.source), .bnot)),
                .concat => |op| self.set(thread, op.dest, try self.binaryOp(thread, self.get(thread, op.left), self.get(thread, op.right), .concat)),
                .eq => |op| self.set(thread, op.dest, .{ .boolean = try self.equalValues(thread, self.get(thread, op.left), self.get(thread, op.right)) }),
                .lt => |op| self.set(thread, op.dest, .{ .boolean = try self.compareValues(thread, self.get(thread, op.left), self.get(thread, op.right), .lt) }),
                .le => |op| self.set(thread, op.dest, .{ .boolean = try self.compareValues(thread, self.get(thread, op.left), self.get(thread, op.right), .le) }),
                .not => |op| self.set(thread, op.dest, .{ .boolean = !truthy(self.get(thread, op.source)) }),
                .len => |op| self.set(thread, op.dest, try self.lengthOf(thread, self.get(thread, op.source))),
                .new_table => |op| self.set(thread, op.dest, try self.newTableWithHints(op.array_hint, op.hash_hint)),
                .set_list => |op| try self.setList(thread, op),
                .get_table => |op| self.set(thread, op.dest, try self.getTableDepth(thread, self.get(thread, op.table), self.get(thread, op.key), 0)),
                .set_table => |op| try self.setTableFromThread(thread, self.get(thread, op.table), self.get(thread, op.key), self.get(thread, op.value)),
                .get_field => |op| self.set(thread, op.dest, try self.getTableDepth(thread, self.get(thread, op.table), .{ .string = constantString(proto, op.name) }, 0)),
                .set_field => |op| try self.setTableFromThread(thread, self.get(thread, op.table), .{ .string = constantString(proto, op.name) }, self.get(thread, op.value)),
                .jmp => |offset| try self.jumpThread(thread, offset, true),
                .test_op => |op| if (truthy(self.get(thread, op.register)) == op.jump_if_truthy) try self.jumpThread(thread, op.offset, true),
                .test_set => |op| {
                    const value = self.get(thread, op.source);
                    self.set(thread, op.dest, value);
                    if (truthy(value) == op.jump_if_truthy) try self.jumpThread(thread, op.offset, true);
                },
                .call => |op| try self.callValue(thread, op),
                .tail_call => |op| try self.tailCallValue(thread, op),
                .ret => |op| try self.returnFromFrame(thread, op.first, op.count),
                .vararg => |op| try self.loadVarargs(thread, op),
                .for_prep => |op| try self.forPrep(thread, op),
                .for_loop => |op| try self.forLoop(thread, op),
                .tfor_prep => |op| if (!(try self.advanceGenericFor(thread, op))) try self.jumpThread(thread, op.offset, false),
                .tfor_call => |op| _ = try self.advanceGenericFor(thread, op),
                .tfor_loop => |op| try self.jumpThread(thread, op.offset, false),
                .closure => |op| self.set(thread, op.dest, try self.newClosure(thread, proto.children.items[op.proto])),
                .get_upvalue => |op| self.set(thread, op.register, self.readUpvalue(thread, op.upvalue)),
                .set_upvalue => |op| self.writeUpvalue(thread, op.upvalue, self.get(thread, op.register)),
                .close => |register| self.closeUpvalues(thread, thread.frames.items[thread.frames.items.len - 1].base + register),
                .check_close => |register| try self.checkToBeClosedValue(self.get(thread, register)),
                .close_tbc => |register| try self.closeToBeClosedRegister(thread, register, .nil),
            }

            if (self.gc_running and (self.collect_after_instruction or self.shouldRunAutoGc())) try self.collectGarbageConservatively(thread);
        }
    }

    fn get(_: *State, thread: *Thread, register: bytecode.Register) Value {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        return thread.stack.items[frame.base + register];
    }

    fn set(_: *State, thread: *Thread, register: bytecode.Register, value: Value) void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        thread.stack.items[frame.base + register] = value;
    }

    fn setGlobal(self: *State, name: []const u8, value: Value) !void {
        const key = if (self.globals.contains(name)) name else try self.intern(name);
        try self.globals.put(key, value);
        if (self.global_table) |table| {
            try table.set(self.allocator, .{ .string = key }, value);
            self.writeTableBarrier(table, .{ .string = key }, value);
        }
        self.markValue(value);
    }

    fn getGlobalValue(self: *State, name: []const u8) Value {
        if (self.global_table) |table| return table.get(.{ .string = name });
        return self.globals.get(name) orelse .nil;
    }

    pub fn getGlobal(self: *State, name: []const u8) Value {
        return self.getGlobalValue(name);
    }

    pub fn currentLine(self: *State, thread: *Thread, level: i64) ?usize {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        if (frame.proto.line_info.items.len == 0) return null;
        const pc = if (frame.pc == 0) @as(usize, 0) else frame.pc - 1;
        return frame.proto.line_info.items[@min(pc, frame.proto.line_info.items.len - 1)].line;
    }

    pub fn currentExtraArgs(self: *State, thread: *Thread, level: i64) ?usize {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - depth];
        return frame.varargs.len;
    }

    pub fn currentFunctionName(self: *State, thread: *Thread, level: i64) ?[]const u8 {
        _ = self;
        if (level < 1) return null;
        const depth: usize = @intCast(level);
        if (depth > thread.frames.items.len) return null;
        return thread.frames.items[thread.frames.items.len - depth].proto.debug_name;
    }

    pub fn putGlobal(self: *State, name: []const u8, value: Value) !void {
        try self.setGlobal(name, value);
    }

    pub fn readFileAlloc(self: *State, path: []const u8) ![]const u8 {
        switch (self.options.filesystem) {
            .disabled => return self.fail("filesystem access disabled"),
            .memory => |files| {
                for (files) |file| {
                    if (std.mem.eql(u8, file.path, path)) return self.allocator.dupe(u8, file.contents);
                }
                return self.fail("cannot open file");
            },
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                return std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(1024 * 1024)) catch return self.fail("cannot open file");
            },
        }
    }

    pub fn writeFile(self: *State, path: []const u8, data: []const u8) !void {
        switch (self.options.filesystem) {
            .disabled, .memory => return self.fail("filesystem write access disabled"),
            .host_cwd => {
                const io = self.options.io orelse return self.fail("filesystem I/O unavailable");
                std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = data }) catch return self.fail("cannot write file");
            },
        }
    }

    pub fn getenv(self: *State, name: []const u8) ?[]const u8 {
        const environment = self.options.environment orelse return null;
        return environment.get(name);
    }

    pub fn currentTime(self: *State) !i64 {
        return switch (self.options.clock) {
            .disabled => self.fail("clock access disabled"),
            .fixed => |value| value,
            .system => {
                const io = self.options.io orelse return self.fail("clock I/O unavailable");
                return @intCast(@divTrunc(std.Io.Clock.real.now(io).nanoseconds, std.time.ns_per_s));
            },
        };
    }

    pub fn processEnabled(self: *State) bool {
        return self.options.process == .enabled;
    }

    pub fn readStdin(self: *State, spec: []const u8) !Value {
        const input = self.options.stdin;
        if (std.mem.eql(u8, spec, "*a") or std.mem.eql(u8, spec, "a")) {
            const remaining = input[self.stdin_pos..];
            self.stdin_pos = input.len;
            return .{ .string = try self.intern(remaining) };
        }
        if (std.mem.eql(u8, spec, "*l") or std.mem.eql(u8, spec, "l")) {
            if (self.stdin_pos >= input.len) return .nil;
            const start = self.stdin_pos;
            while (self.stdin_pos < input.len and input[self.stdin_pos] != '\n') self.stdin_pos += 1;
            const line = input[start..self.stdin_pos];
            if (self.stdin_pos < input.len and input[self.stdin_pos] == '\n') self.stdin_pos += 1;
            return .{ .string = try self.intern(line) };
        }
        return self.fail("unsupported read option");
    }

    pub fn loadSourceAsClosure(self: *State, source: []const u8) !Value {
        return self.loadSourceAsClosureNamed(source, null);
    }

    pub fn loadSourceAsClosureNamed(self: *State, source: []const u8, source_name: ?[]const u8) !Value {
        return self.loadSourceAsClosureNamedEnv(source, source_name, self.defaultEnvironment());
    }

    pub fn loadSourceAsClosureNamedEnv(self: *State, source: []const u8, source_name: ?[]const u8, environment: Value) !Value {
        var tree = frontend.parse(self.allocator, source) catch return self.fail("cannot load source");
        defer tree.deinit();

        compile.resolver.resolve(self.allocator, &tree) catch return self.fail("cannot resolve source");
        const proto = try self.allocator.create(proto_mod.Proto);
        errdefer self.allocator.destroy(proto);
        proto.* = compile.compile(self.allocator, &tree) catch |err| switch (err) {
            error.TooManyReturns => return self.fail("too many returns"),
            else => return self.fail("cannot compile source"),
        };
        if (source_name) |name| proto.source_name = try proto.arena.allocator().dupe(u8, name);
        errdefer proto.deinit();
        try self.proto_allocations.append(self.allocator, proto);
        errdefer _ = self.proto_allocations.pop();
        return .{ .closure = try self.newRootClosureWithEnv(proto, environment) };
    }

    pub fn loadBinaryDump(self: *State, source: []const u8, environment: Value) !Value {
        var header = std.ArrayList(u8).empty;
        defer header.deinit(self.allocator);
        try appendBinaryChunkHeader(self.allocator, &header);

        if (source.len < header.items.len) return self.fail("truncated binary chunk");
        if (!std.mem.eql(u8, source[0..header.items.len], header.items)) return self.fail("bad binary chunk");

        var pos = header.items.len;
        const payload_len = binary_chunk_payload_magic.len + @sizeOf(u64) + @sizeOf(u32);
        if (source.len < pos + payload_len) return self.fail("truncated binary chunk");
        if (!std.mem.eql(u8, source[pos .. pos + binary_chunk_payload_magic.len], binary_chunk_payload_magic)) return self.fail("bad binary chunk");
        pos += binary_chunk_payload_magic.len;

        const proto_addr = std.mem.readInt(u64, source[pos..][0..@sizeOf(u64)], .little);
        pos += @sizeOf(u64);
        const debug_len = std.mem.readInt(u32, source[pos..][0..@sizeOf(u32)], .little);
        pos += @sizeOf(u32);
        if (source.len < pos + debug_len) return self.fail("truncated binary chunk");

        const proto: *const proto_mod.Proto = @ptrFromInt(@as(usize, @intCast(proto_addr)));
        return self.newDumpedClosure(proto, environment);
    }

    pub fn loadFileAsClosure(self: *State, path: []const u8) !Value {
        const source = try self.readFileAlloc(path);
        errdefer self.allocator.free(source);
        const closure = try self.loadSourceAsClosure(source);
        try self.source_allocations.append(self.allocator, source);
        return closure;
    }

    pub fn callCollect(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror![]Value {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[frame_count - 1];
        const relative_base: bytecode.Register = frame.proto.max_registers;
        const base = frame.base + @as(usize, relative_base);
        try thread.ensureStack(self.allocator, base + 1 + args.len);
        thread.stack.items[base] = callable;
        for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

        try self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = bytecode.multret_count }, 0);
        try self.runThreadUntil(thread, frame_count);
        return self.copyStackSlice(thread, thread.last_result_base, thread.last_result_count);
    }

    fn loadConstant(self: *State, constant: bytecode.Constant) !Value {
        return switch (constant) {
            .nil => .nil,
            .boolean => |value| .{ .boolean = value },
            .integer => |lexeme| try parseIntegerLiteral(lexeme),
            .number => |lexeme| .{ .number = try parseLuaNumber(lexeme) },
            .string => |lexeme| .{ .string = try self.decodeStringLiteral(lexeme) },
        };
    }

    pub fn intern(self: *State, bytes: []const u8) ![]const u8 {
        if (self.strings.get(bytes)) |interned| return interned;
        const interned = try self.allocateString(bytes);
        try self.strings.put(interned, interned);
        return interned;
    }

    pub fn allocateString(self: *State, bytes: []const u8) ![]const u8 {
        const allocated = try self.allocator.dupe(u8, bytes);
        errdefer self.allocator.free(allocated);
        try self.string_allocations.append(self.allocator, .{ .bytes = allocated });
        return allocated;
    }

    fn decodeStringLiteral(self: *State, lexeme: []const u8) ![]const u8 {
        if (lexeme.len < 2) return lexeme;
        if (lexeme[0] == '\'' or lexeme[0] == '"') return self.decodeShortString(lexeme);
        if (lexeme[0] == '[') return self.decodeLongString(lexeme);
        return lexeme;
    }

    fn decodeShortString(self: *State, lexeme: []const u8) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);

        var index: usize = 1;
        while (index + 1 < lexeme.len) {
            const byte = lexeme[index];
            index += 1;
            if (byte != '\\') {
                try out.append(self.allocator, byte);
                continue;
            }
            if (index >= lexeme.len - 1) return self.fail("unfinished string escape");
            const escaped = lexeme[index];
            index += 1;
            switch (escaped) {
                'a' => try out.append(self.allocator, 0x07),
                'b' => try out.append(self.allocator, 0x08),
                'f' => try out.append(self.allocator, 0x0c),
                'n' => try out.append(self.allocator, '\n'),
                'r' => try out.append(self.allocator, '\r'),
                't' => try out.append(self.allocator, '\t'),
                'v' => try out.append(self.allocator, 0x0b),
                '\\', '"', '\'' => try out.append(self.allocator, escaped),
                'x' => {
                    if (index + 1 >= lexeme.len) return self.fail("invalid hexadecimal escape");
                    const value = hexValue(lexeme[index]) * 16 + hexValue(lexeme[index + 1]);
                    index += 2;
                    try out.append(self.allocator, @intCast(value));
                },
                '0'...'9' => {
                    var value: u32 = escaped - '0';
                    var count: usize = 1;
                    while (count < 3 and index < lexeme.len - 1 and std.ascii.isDigit(lexeme[index])) : (count += 1) {
                        value = value * 10 + lexeme[index] - '0';
                        index += 1;
                    }
                    try out.append(self.allocator, @intCast(value));
                },
                'z' => while (index < lexeme.len - 1 and std.ascii.isWhitespace(lexeme[index])) : (index += 1) {},
                'u' => {
                    if (index >= lexeme.len - 1 or lexeme[index] != '{') return self.fail("invalid unicode escape");
                    index += 1;
                    var value: u32 = 0;
                    var count: usize = 0;
                    while (index < lexeme.len - 1 and lexeme[index] != '}') : (index += 1) {
                        value = appendUnicodeEscapeDigit(value, hexValue(lexeme[index]));
                        count += 1;
                    }
                    if (count == 0 or index >= lexeme.len - 1 or lexeme[index] != '}' or value > max_lua_utf8_codepoint) return self.fail("invalid unicode escape");
                    index += 1;
                    var encoded: [6]u8 = undefined;
                    const len = encodeLuaUtf8(value, &encoded) orelse return self.fail("invalid unicode escape");
                    try out.appendSlice(self.allocator, encoded[0..len]);
                },
                '\n' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\r') index += 1;
                    try out.append(self.allocator, '\n');
                },
                '\r' => {
                    if (index < lexeme.len - 1 and lexeme[index] == '\n') index += 1;
                    try out.append(self.allocator, '\n');
                },
                else => return self.fail("invalid string escape"),
            }
        }

        const bytes = try self.intern(out.items);
        out.deinit(self.allocator);
        return bytes;
    }

    fn decodeLongString(self: *State, lexeme: []const u8) ![]const u8 {
        var level: usize = 0;
        while (1 + level < lexeme.len and lexeme[1 + level] == '=') level += 1;
        const content_start = level + 2;
        const content_end = lexeme.len - level - 2;
        var content = lexeme[content_start..content_end];
        if (std.mem.startsWith(u8, content, "\r\n") or std.mem.startsWith(u8, content, "\n\r")) {
            content = content[2..];
        } else if (std.mem.startsWith(u8, content, "\n") or std.mem.startsWith(u8, content, "\r")) {
            content = content[1..];
        }
        if (std.mem.indexOfScalar(u8, content, '\r')) |_| {
            const normalized = try self.normalizeLongStringLineEnds(content);
            defer self.allocator.free(normalized);
            return self.intern(normalized);
        }
        return self.intern(content);
    }

    fn normalizeLongStringLineEnds(self: *State, content: []const u8) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.allocator);
        var index: usize = 0;
        while (index < content.len) {
            const byte = content[index];
            if (byte == '\r') {
                try out.append(self.allocator, '\n');
                index += if (index + 1 < content.len and content[index + 1] == '\n') 2 else 1;
            } else if (byte == '\n' and index + 1 < content.len and content[index + 1] == '\r') {
                try out.append(self.allocator, '\n');
                index += 2;
            } else {
                try out.append(self.allocator, byte);
                index += 1;
            }
        }
        return out.toOwnedSlice(self.allocator);
    }

    pub fn newTableWithHints(self: *State, array_hint: u32, hash_hint: u32) !Value {
        const table = try self.allocator.create(Table);
        errdefer self.allocator.destroy(table);
        table.* = try Table.init(self.allocator, array_hint, hash_hint);
        errdefer table.deinit(self.allocator);
        try self.table_allocations.append(self.allocator, table);
        return .{ .table = table };
    }

    fn newRootClosure(self: *State, proto: *const proto_mod.Proto) !*Closure {
        return self.newRootClosureWithEnv(proto, self.defaultEnvironment());
    }

    fn newRootClosureWithEnv(self: *State, proto: *const proto_mod.Proto, environment: Value) !*Closure {
        var upvalues: []*Upvalue = if (proto.upvalues.items.len == 0)
            &.{}
        else
            try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer if (upvalues.len != 0) self.allocator.free(upvalues);

        for (proto.upvalues.items, 0..) |desc, index| {
            const upvalue = try self.allocator.create(Upvalue);
            errdefer self.allocator.destroy(upvalue);
            upvalue.* = .{
                .owner = undefined,
                .stack_index = 0,
                .closed = if (std.mem.eql(u8, desc.name, "_ENV")) environment else .nil,
                .is_open = false,
            };
            try self.upvalue_allocations.append(self.allocator, upvalue);
            upvalues[index] = upvalue;
        }

        const closure = try self.allocator.create(Closure);
        errdefer self.allocator.destroy(closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues };
        try self.closure_allocations.append(self.allocator, closure);
        return closure;
    }

    fn defaultEnvironment(self: *State) Value {
        return if (self.global_table) |table| .{ .table = table } else self.getGlobalValue("_G");
    }

    fn newDumpedClosure(self: *State, proto: *const proto_mod.Proto, environment: Value) !Value {
        var upvalues: []*Upvalue = if (proto.upvalues.items.len == 0)
            &.{}
        else
            try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer if (upvalues.len != 0) self.allocator.free(upvalues);

        const owner = self.current_thread orelse return self.fail("cannot load binary chunk outside a thread");
        for (proto.upvalues.items, 0..) |desc, index| {
            const upvalue = try self.allocator.create(Upvalue);
            errdefer self.allocator.destroy(upvalue);
            upvalue.* = .{
                .owner = owner,
                .stack_index = 0,
                .closed = if (std.mem.eql(u8, desc.name, "_ENV")) environment else .nil,
                .is_open = false,
            };
            try self.upvalue_allocations.append(self.allocator, upvalue);
            upvalues[index] = upvalue;
        }

        const closure = try self.allocator.create(Closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues };
        errdefer self.destroyClosure(closure);
        try self.closure_allocations.append(self.allocator, closure);
        return .{ .closure = closure };
    }

    fn newClosure(self: *State, thread: *Thread, proto: *const proto_mod.Proto) !Value {
        const parent = thread.frames.items[thread.frames.items.len - 1];
        const upvalues = try self.allocator.alloc(*Upvalue, proto.upvalues.items.len);
        errdefer self.allocator.free(upvalues);
        for (proto.upvalues.items, 0..) |desc, index| {
            upvalues[index] = if (desc.in_stack)
                try self.captureUpvalue(thread, parent.base + desc.index)
            else
                parent.closure.upvalues[desc.index];
        }

        const closure = try self.allocator.create(Closure);
        closure.* = .{ .proto = proto, .upvalues = upvalues };
        errdefer self.destroyClosure(closure);
        try self.closure_allocations.append(self.allocator, closure);
        return .{ .closure = closure };
    }

    fn captureUpvalue(self: *State, thread: *Thread, stack_index: usize) !*Upvalue {
        var current = thread.open_upvalues;
        while (current) |upvalue| : (current = upvalue.next) {
            if (upvalue.is_open and upvalue.stack_index == stack_index) return upvalue;
        }

        const upvalue = try self.allocator.create(Upvalue);
        errdefer self.allocator.destroy(upvalue);
        upvalue.* = .{ .owner = thread, .stack_index = stack_index, .next = thread.open_upvalues };
        try self.upvalue_allocations.append(self.allocator, upvalue);
        thread.open_upvalues = upvalue;
        return upvalue;
    }

    fn readUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex) Value {
        _ = self;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        return if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
    }

    fn writeUpvalue(self: *State, thread: *Thread, index: bytecode.UpvalueIndex, value: Value) void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const upvalue = frame.closure.upvalues[index];
        if (upvalue.is_open) {
            upvalue.owner.stack.items[upvalue.stack_index] = value;
        } else {
            upvalue.closed = value;
            self.writeBarrier(upvalue.marked, value);
        }
    }

    fn closeUpvalues(self: *State, thread: *Thread, first_stack_index: usize) void {
        _ = self;
        var previous: ?*Upvalue = null;
        var current = thread.open_upvalues;
        while (current) |upvalue| {
            const next = upvalue.next;
            if (upvalue.is_open and upvalue.stack_index >= first_stack_index) {
                upvalue.closed = thread.stack.items[upvalue.stack_index];
                upvalue.is_open = false;
                upvalue.next = null;
                if (previous) |prev| {
                    prev.next = next;
                } else {
                    thread.open_upvalues = next;
                }
            } else {
                previous = upvalue;
            }
            current = next;
        }
    }

    fn checkToBeClosedValue(self: *State, value: Value) !void {
        if (value == .nil) return;
        if (value == .boolean and !value.boolean) return;
        if ((try self.getMetamethod(value, "__close")) == null) return self.fail("variable got a non-closable value");
    }

    fn closeToBeClosedRegister(self: *State, thread: *Thread, register: bytecode.Register, error_value: Value) anyerror!void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const absolute_register = frame.base + register;
        const value = thread.stack.items[absolute_register];
        if (value == .nil) return;
        if (value == .boolean and !value.boolean) return;
        const metamethod = (try self.getMetamethod(value, "__close")) orelse {
            thread.stack.items[absolute_register] = .nil;
            return self.fail("variable got a non-closable value");
        };
        _ = self.callOneResult(thread, metamethod, &.{ value, error_value }) catch |err| {
            thread.stack.items[absolute_register] = .nil;
            return err;
        };
    }

    fn jumpThread(self: *State, thread: *Thread, offset: bytecode.JumpOffset, auto_gc: bool) !void {
        const frame_index = thread.frames.items.len - 1;
        const source_pc = thread.frames.items[frame_index].pc;
        const target_pc = jumpTarget(source_pc, offset);
        try self.closeToBeClosedExitingPc(thread, frame_index, source_pc, target_pc, .nil);
        thread.frames.items[frame_index].pc = target_pc;
        if (auto_gc and self.gc_running and target_pc < source_pc and !self.is_collecting) try self.collectGarbageWithFinalizers(thread);
    }

    fn forPrep(self: *State, thread: *Thread, op: bytecode.ForLoop) !void {
        const initial = self.get(thread, op.base);
        const limit = self.get(thread, op.base + 1);
        const step = self.get(thread, op.base + 2);
        if (toInteger(initial)) |initial_integer| {
            if (toInteger(limit)) |limit_integer| {
                if (toInteger(step)) |step_integer| {
                    if (step_integer == 0) return self.fail("'for' step is zero");
                    self.set(thread, op.base, .{ .integer = initial_integer });
                    self.set(thread, op.base + 1, .{ .integer = limit_integer });
                    self.set(thread, op.base + 2, .{ .integer = step_integer });
                    if (!forLoopContinuesInteger(initial_integer, limit_integer, step_integer)) try self.jumpThread(thread, op.offset, false);
                    return;
                }
            }
        }

        const initial_number = toNumberMaybe(initial) orelse return self.fail("'for' initial value must be a number");
        const limit_number = toNumberMaybe(limit) orelse return self.fail("'for' limit must be a number");
        const step_number = toNumberMaybe(step) orelse return self.fail("'for' step must be a number");
        if (step_number == 0) return self.fail("'for' step is zero");
        self.set(thread, op.base, .{ .number = initial_number });
        self.set(thread, op.base + 1, .{ .number = limit_number });
        self.set(thread, op.base + 2, .{ .number = step_number });
        if (!forLoopContinuesNumber(initial_number, limit_number, step_number)) try self.jumpThread(thread, op.offset, false);
    }

    fn forLoop(self: *State, thread: *Thread, op: bytecode.ForLoop) !void {
        const current = self.get(thread, op.base);
        const limit = self.get(thread, op.base + 1);
        const step = self.get(thread, op.base + 2);
        if (current == .integer and limit == .integer and step == .integer) {
            const next = current.integer +% step.integer;
            self.set(thread, op.base, .{ .integer = next });
            if (forLoopContinuesInteger(next, limit.integer, step.integer)) try self.jumpThread(thread, op.offset, false);
            return;
        }

        const next = (try toNumber(current)) + (try toNumber(step));
        self.set(thread, op.base, .{ .number = next });
        if (forLoopContinuesNumber(next, try toNumber(limit), try toNumber(step))) try self.jumpThread(thread, op.offset, false);
    }

    fn closeToBeClosedExitingPc(self: *State, thread: *Thread, frame_index: usize, source_pc: usize, target_pc: usize, error_value: Value) !void {
        const frame = thread.frames.items[frame_index];
        var pending_error = error_value;
        var close_failed = false;

        var index = frame.proto.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = frame.proto.locals.items[index];
            if (!local.to_close) continue;
            if (!localActiveAt(local, source_pc) or localActiveAt(local, target_pc)) continue;

            self.closeToBeClosedRegister(thread, local.register, pending_error) catch |err| {
                self.discardFramesTo(thread, frame_index + 1);
                pending_error = self.currentErrorValue();
                close_failed = close_failed or isRuntimeError(err);
                if (!isRuntimeError(err)) return err;
            };
        }

        if (close_failed) return self.throwValue(pending_error);
    }

    fn closeActiveToBeClosedInTopFrame(self: *State, thread: *Thread, error_value: Value) !void {
        const frame_index = thread.frames.items.len - 1;
        const frame = thread.frames.items[frame_index];
        const pc = frame.pc;
        var pending_error = error_value;
        var close_failed = false;

        var index = frame.proto.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = frame.proto.locals.items[index];
            if (!local.to_close or !localActiveAt(local, pc)) continue;

            self.closeToBeClosedRegister(thread, local.register, pending_error) catch |err| {
                self.discardFramesTo(thread, frame_index + 1);
                pending_error = self.currentErrorValue();
                close_failed = close_failed or isRuntimeError(err);
                if (!isRuntimeError(err)) return err;
            };
        }

        if (close_failed) return self.throwValue(pending_error);
    }

    fn closeFramesTo(self: *State, thread: *Thread, frame_count: usize, error_value: Value) !void {
        var pending_error = error_value;
        var close_failed = false;
        while (thread.frames.items.len > frame_count) {
            self.closeActiveToBeClosedInTopFrame(thread, pending_error) catch |err| {
                pending_error = self.currentErrorValue();
                close_failed = close_failed or isRuntimeError(err);
                if (!isRuntimeError(err)) return err;
            };
            const frame = thread.frames.items[thread.frames.items.len - 1];
            self.closeUpvalues(thread, frame.base);
            thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
            thread.frames.items.len -= 1;
        }
        if (close_failed) return self.throwValue(pending_error);
    }

    fn discardFramesTo(self: *State, thread: *Thread, frame_count: usize) void {
        while (thread.frames.items.len > frame_count) {
            const frame = thread.frames.items[thread.frames.items.len - 1];
            self.closeUpvalues(thread, frame.base);
            thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
            thread.frames.items.len -= 1;
        }
    }

    fn getTable(self: *State, table_value: Value, key_value: Value) !Value {
        return self.getTableDepth(null, table_value, key_value, 0);
    }

    pub fn getTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value) !Value {
        return self.getTableDepth(thread, table_value, key_value, 0);
    }

    fn getTableDepth(self: *State, thread: ?*Thread, table_value: Value, key_value: Value, depth: usize) !Value {
        if (depth > max_metamethod_depth) return self.fail("'__index' chain too long");
        const key = try self.readableTableKey(key_value) orelse return .nil;

        if (table_value == .table) {
            const value = table_value.table.get(key);
            if (value != .nil) return value;
        }

        const metamethod = try self.getMetamethod(table_value, "__index") orelse {
            if (table_value == .table) return .nil;
            return self.fail(indexErrorMessage(table_value));
        };

        return switch (metamethod) {
            .table => self.getTableDepth(thread, metamethod, key, depth + 1),
            else => if (thread) |active_thread|
                try self.callOneResult(active_thread, metamethod, &.{ table_value, key })
            else
                self.fail("attempt to call a non-function value"),
        };
    }

    fn rawGet(self: *State, table_value: Value, key_value: Value) !Value {
        const table = switch (table_value) {
            .table => |table| table,
            else => return self.fail(indexErrorMessage(table_value)),
        };
        const key = try self.readableTableKey(key_value) orelse return .nil;
        return table.get(key);
    }

    fn setTable(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTableDepth(null, table_value, key_value, value, 0);
    }

    pub fn setTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value) !void {
        try self.setTableDepth(thread, table_value, key_value, value, 0);
    }

    fn setTableDepth(self: *State, thread: ?*Thread, table_value: Value, key_value: Value, value: Value, depth: usize) !void {
        if (depth > max_metamethod_depth) return self.fail("'__newindex' chain too long");
        const key = try self.writableTableKey(key_value);

        if (table_value == .table) {
            const table = table_value.table;
            if (table.get(key) != .nil) {
                try table.set(self.allocator, key, value);
                self.writeTableBarrier(table, key, value);
                return;
            }
        }

        const metamethod = try self.getMetamethod(table_value, "__newindex") orelse {
            if (table_value == .table) {
                try table_value.table.set(self.allocator, key, value);
                self.writeTableBarrier(table_value.table, key, value);
                return;
            }
            return self.fail(indexErrorMessage(table_value));
        };

        switch (metamethod) {
            .table => try self.setTableDepth(thread, metamethod, key, value, depth + 1),
            else => if (thread) |active_thread| {
                _ = try self.callOneResult(active_thread, metamethod, &.{ table_value, key, value });
            } else {
                return self.fail("attempt to call a non-function value");
            },
        }
    }

    fn readableTableKey(self: *State, value: Value) !?Value {
        _ = self;
        return switch (value) {
            .nil => null,
            .number => |number| if (std.math.isNan(number)) null else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    fn writableTableKey(self: *State, value: Value) !Value {
        return switch (value) {
            .nil => self.fail("table index is nil"),
            .number => |number| if (std.math.isNan(number)) self.fail("table index is NaN") else if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
            else => value,
        };
    }

    pub fn lengthOf(self: *State, thread: *Thread, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
            .table => |table| if ((try self.getMetamethod(value, "__len"))) |metamethod|
                try self.callOneResult(thread, metamethod, &.{value})
            else
                .{ .integer = table.len() },
            else => self.fail("attempt to get length of a non-string value"),
        };
    }

    fn concatValues(self: *State, lhs: Value, rhs: Value) !Value {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try appendLuaString(self.allocator, &out, lhs);
        try appendLuaString(self.allocator, &out, rhs);
        return .{ .string = try self.allocateString(out.items) };
    }

    fn callValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const resolved = try self.resolveCall(thread, op);
        try self.invokeValue(thread, resolved, 0);
    }

    fn invokeValue(self: *State, thread: *Thread, resolved: bytecode.Call, depth: usize) anyerror!void {
        if (depth > max_metamethod_depth) return self.fail("'__call' chain too long");
        const callee = self.get(thread, resolved.base);
        if (callee == .coroutine_wrapper) {
            try self.callCoroutineWrapper(thread, resolved, callee.coroutine_wrapper);
            return;
        }

        const entering_native = isNativeCallable(callee);
        if (entering_native) thread.native_call_depth += 1;
        defer {
            if (entering_native) thread.native_call_depth -= 1;
        }
        switch (callee) {
            .closure => |closure| try self.callClosure(thread, resolved, closure),
            .native_print => {
                for (0..resolved.arg_count) |index| {
                    if (index != 0) try self.stdout.append(self.allocator, '\t');
                    const text = try self.valueToString(thread, self.get(thread, resolved.base + 1 + @as(bytecode.Register, @intCast(index))));
                    try self.stdout.appendSlice(self.allocator, text);
                }
                try self.stdout.append(self.allocator, '\n');
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{});
            },
            .native_tostring => {
                const value = if (resolved.arg_count == 0) Value.nil else self.get(thread, resolved.base + 1);
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{.{ .string = try self.valueToString(thread, value) }});
            },
            .native_getmetatable => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.getMetatableValue(argValue(self, thread, resolved, 0))}),
            .native_setmetatable => {
                const table_value = argValue(self, thread, resolved, 0);
                try self.setMetatableValue(table_value, argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{table_value});
            },
            .native_rawequal => try self.returnValues(thread, resolved.base, resolved.return_count, &.{.{ .boolean = valuesEqual(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1)) }}),
            .native_rawget => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.rawGet(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1))}),
            .native_rawset => {
                const table = argValue(self, thread, resolved, 0);
                try self.rawSet(table, argValue(self, thread, resolved, 1), argValue(self, thread, resolved, 2));
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{table});
            },
            .native_rawlen => try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.rawLen(argValue(self, thread, resolved, 0))}),
            .native_next => {
                const values = try self.nextValues(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_pairs => {
                const table = try self.expectTable(argValue(self, thread, resolved, 0));
                _ = table;
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_next, argValue(self, thread, resolved, 0), .nil });
            },
            .native_ipairs => {
                const table = try self.expectTable(argValue(self, thread, resolved, 0));
                _ = table;
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{ .native_ipairs_iter, argValue(self, thread, resolved, 0), .{ .integer = 0 } });
            },
            .native_ipairs_iter => {
                const values = try self.ipairsIterValues(argValue(self, thread, resolved, 0), argValue(self, thread, resolved, 1));
                try self.returnValues(thread, resolved.base, resolved.return_count, &values);
            },
            .native_table_create => {
                const array_hint = try self.tableCreateHint(argValue(self, thread, resolved, 0), 1);
                const hash_hint = if (resolved.arg_count >= 2) try self.tableCreateHint(argValue(self, thread, resolved, 1), 2) else 0;
                if (hash_hint == std.math.maxInt(i32)) return self.fail("table overflow");
                try self.returnValues(thread, resolved.base, resolved.return_count, &.{try self.newTableWithHints(array_hint, hash_hint)});
            },
            .native_select => try self.selectValues(thread, resolved),
            .native_assert => try self.assertValues(thread, resolved),
            .native_error => try self.errorValue(thread, resolved),
            .native_pcall => try self.pcallValues(thread, resolved),
            .native_xpcall => try self.xpcallValues(thread, resolved),
            .native_collectgarbage => try self.collectGarbageValue(thread, resolved),
            .native_debug_traceback => try self.tracebackValue(thread, resolved),
            .native_coroutine_create => try self.coroutineCreate(thread, resolved),
            .native_coroutine_resume => try self.coroutineResume(thread, resolved),
            .native_coroutine_yield => try self.coroutineYield(thread, resolved),
            .native_coroutine_status => try self.coroutineStatus(thread, resolved),
            .native_coroutine_running => try self.coroutineRunning(thread, resolved),
            .native_coroutine_wrap => try self.coroutineWrap(thread, resolved),
            .native => |native| try self.callNative(native, thread, resolved),
            else => {
                const metamethod = try self.getMetamethod(callee, "__call") orelse return self.fail("attempt to call a non-function value");
                try self.prependCallArgument(thread, resolved, metamethod, callee);
                try self.invokeValue(thread, .{ .base = resolved.base, .arg_count = resolved.arg_count + 1, .return_count = resolved.return_count }, depth + 1);
            },
        }
    }

    fn prependCallArgument(self: *State, thread: *Thread, resolved: bytecode.Call, metamethod: Value, receiver: Value) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const base = frame.base + resolved.base;
        try thread.ensureStack(self.allocator, base + 2 + resolved.arg_count);
        var index: usize = resolved.arg_count;
        while (index > 0) {
            index -= 1;
            thread.stack.items[base + 2 + index] = thread.stack.items[base + 1 + index];
        }
        thread.stack.items[base] = metamethod;
        thread.stack.items[base + 1] = receiver;
    }

    pub fn callOneResult(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!Value {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[frame_count - 1];
        const relative_base: bytecode.Register = frame.proto.max_registers;
        const base = frame.base + @as(usize, relative_base);
        try thread.ensureStack(self.allocator, base + 1 + args.len);
        thread.stack.items[base] = callable;
        for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

        try self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = 1 }, 0);
        try self.runThreadUntil(thread, frame_count);
        return thread.stack.items[base];
    }

    pub fn protectedCall(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!ProtectedCallResult {
        const frame_count = thread.frames.items.len;
        const frame = thread.frames.items[frame_count - 1];
        const relative_base: bytecode.Register = frame.proto.max_registers;
        const base = frame.base + @as(usize, relative_base);
        const old_stack_len = thread.stack.items.len;
        const old_last_result_base = thread.last_result_base;
        const old_last_result_count = thread.last_result_count;
        const old_last_error = self.last_error;
        const old_last_error_value = self.last_error_value;

        try thread.ensureStack(self.allocator, base + 1 + args.len);
        thread.stack.items[base] = callable;
        for (args, 0..) |arg, index| thread.stack.items[base + 1 + index] = arg;

        self.last_error = null;
        self.last_error_value = .nil;
        self.invokeValue(thread, .{ .base = relative_base, .arg_count = @intCast(args.len), .return_count = bytecode.multret_count }, 0) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                const error_value = self.currentErrorValue();
                const failure = try self.restoreProtectedCall(thread, frame_count, old_stack_len, old_last_result_base, old_last_result_count, old_last_error, old_last_error_value, error_value);
                return .{ .failure = failure };
            },
            else => return err,
        };
        self.runThreadUntil(thread, frame_count) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                const error_value = self.currentErrorValue();
                const failure = try self.restoreProtectedCall(thread, frame_count, old_stack_len, old_last_result_base, old_last_result_count, old_last_error, old_last_error_value, error_value);
                return .{ .failure = failure };
            },
            else => return err,
        };

        const values = try self.allocator.alloc(Value, thread.last_result_count);
        for (values, 0..) |*value, index| value.* = thread.stack.items[thread.last_result_base + index];
        _ = try self.restoreProtectedCall(thread, frame_count, old_stack_len, old_last_result_base, old_last_result_count, old_last_error, old_last_error_value, .nil);
        return .{ .success = values };
    }

    fn restoreProtectedCall(
        self: *State,
        thread: *Thread,
        frame_count: usize,
        stack_len: usize,
        last_result_base: usize,
        last_result_count: usize,
        last_error: ?[]const u8,
        last_error_value: Value,
        error_value: Value,
    ) !Value {
        var failure = error_value;
        self.closeFramesTo(thread, frame_count, error_value) catch |err| switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => failure = self.currentErrorValue(),
            else => return err,
        };
        thread.stack.items.len = stack_len;
        thread.last_result_base = last_result_base;
        thread.last_result_count = last_result_count;
        self.last_error = last_error;
        self.last_error_value = last_error_value;
        return failure;
    }

    fn valueToString(self: *State, thread: *Thread, value: Value) anyerror![]const u8 {
        if (try self.getMetamethod(value, "__tostring")) |metamethod| {
            const result = try self.callOneResult(thread, metamethod, &.{value});
            return switch (result) {
                .string => |string| string,
                else => self.fail("'__tostring' must return a string"),
            };
        }

        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);
        try appendValue(self.allocator, &out, value);
        return self.intern(out.items);
    }

    fn getMetatableValue(self: *State, value: Value) !Value {
        const metatable = switch (value) {
            .table => |table| table.metatable orelse return .nil,
            .string => self.string_metatable orelse return .nil,
            else => return .nil,
        };
        const locked = metatable.get(.{ .string = "__metatable" });
        if (locked != .nil) return locked;
        return .{ .table = metatable };
    }

    fn setMetatableValue(self: *State, table_value: Value, metatable_value: Value) !void {
        const table = try self.expectTable(table_value);
        if (table.metatable) |metatable| {
            if (metatable.get(.{ .string = "__metatable" }) != .nil) return self.fail("cannot change a protected metatable");
        }
        table.metatable = switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => return self.fail("nil or table expected"),
        };
        if (table.metatable) |metatable| self.writeBarrier(table.marked, .{ .table = metatable });
    }

    fn getMetamethod(self: *State, value: Value, name: []const u8) !?Value {
        const metatable = switch (value) {
            .table => |table| table.metatable orelse return null,
            .string => self.string_metatable orelse return null,
            else => return null,
        };
        const metamethod = metatable.get(.{ .string = name });
        return if (metamethod == .nil) null else metamethod;
    }

    fn getEitherMetamethod(self: *State, lhs: Value, rhs: Value, name: []const u8) !?Value {
        if (try self.getMetamethod(lhs, name)) |metamethod| return metamethod;
        return self.getMetamethod(rhs, name);
    }

    fn rawLen(self: *State, value: Value) !Value {
        return switch (value) {
            .string => |string| .{ .integer = @intCast(string.len) },
            .table => |table| .{ .integer = table.len() },
            else => self.fail("table or string expected"),
        };
    }

    fn binaryOp(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: BinaryOp) !Value {
        if (op == .concat and luaStringLike(lhs) and luaStringLike(rhs)) return self.concatValues(lhs, rhs);
        const raw = rawBinaryOp(lhs, rhs, op) catch |err| switch (err) {
            error.RuntimeError => if ((op == .idiv or op == .mod) and (toInteger(rhs) orelse 1) == 0) return self.fail("divide by zero") else return err,
        };
        if (raw) |value| return value;
        const metamethod_name = binaryMetamethod(op);
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, metamethod_name)) orelse {
            if (bitwiseIntegerError(lhs, rhs, op)) |message| return self.fail(message);
            return self.fail("attempt to perform operation on unsupported values");
        };
        return self.callOneResult(thread, metamethod, &.{ lhs, rhs });
    }

    fn unaryOp(self: *State, thread: *Thread, value: Value, op: UnaryMetamethodOp) !Value {
        if (rawUnaryOp(value, op)) |result| return result;
        const metamethod = (try self.getMetamethod(value, unaryMetamethod(op))) orelse return self.fail("attempt to perform operation on unsupported value");
        return self.callOneResult(thread, metamethod, &.{value});
    }

    fn equalValues(self: *State, thread: *Thread, lhs: Value, rhs: Value) !bool {
        if (valuesEqual(lhs, rhs)) return true;
        if (lhs != .table or rhs != .table) return false;
        const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__eq")) orelse return false;
        return truthy(try self.callOneResult(thread, metamethod, &.{ lhs, rhs }));
    }

    pub fn compareValues(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: CompareOp) !bool {
        if (rawCompare(lhs, rhs, op)) |result| return result;
        switch (op) {
            .lt => {
                const metamethod = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.fail("attempt to compare unsupported values");
                return truthy(try self.callOneResult(thread, metamethod, &.{ lhs, rhs }));
            },
            .le => {
                if (try self.getEitherMetamethod(lhs, rhs, "__le")) |metamethod| {
                    return truthy(try self.callOneResult(thread, metamethod, &.{ lhs, rhs }));
                }
                const lt = (try self.getEitherMetamethod(lhs, rhs, "__lt")) orelse return self.fail("attempt to compare unsupported values");
                return !truthy(try self.callOneResult(thread, lt, &.{ rhs, lhs }));
            },
        }
    }

    fn callClosure(self: *State, thread: *Thread, op: bytecode.Call, closure: *Closure) !void {
        if (thread.frames.items.len >= max_call_frames) return self.fail("stack overflow");

        const caller = thread.frames.items[thread.frames.items.len - 1];
        const base = caller.base + op.base;
        var frame = try self.prepareClosureFrame(thread, closure, base, base, @intCast(op.arg_count), base, op.return_count);
        errdefer frame.deinit(self.allocator);
        try thread.frames.append(self.allocator, frame);
    }

    fn tailCallValue(self: *State, thread: *Thread, op: bytecode.Call) anyerror!void {
        var resolved = try self.resolveCall(thread, op);
        var depth: usize = 0;
        while (true) {
            const callee = self.get(thread, resolved.base);
            switch (callee) {
                .closure => break,
                .coroutine_wrapper => break,
                else => if (isNativeCallable(callee)) break,
            }

            if (depth > max_metamethod_depth) return self.fail("'__call' chain too long");
            const metamethod = try self.getMetamethod(callee, "__call") orelse break;
            try self.prependCallArgument(thread, resolved, metamethod, callee);
            resolved.arg_count += 1;
            depth += 1;
        }

        const callee = self.get(thread, resolved.base);
        switch (callee) {
            .closure => |closure| {
                try self.closeActiveToBeClosedInTopFrame(thread, .nil);
                const frame = thread.frames.items[thread.frames.items.len - 1];
                self.closeUpvalues(thread, frame.base);
                const new_frame = try self.prepareClosureFrame(thread, closure, frame.base + resolved.base, frame.base, @intCast(resolved.arg_count), frame.return_start, frame.return_count);
                thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
                thread.frames.items[thread.frames.items.len - 1] = new_frame;
            },
            else => {
                const frame = thread.frames.items[thread.frames.items.len - 1];
                const frame_count = thread.frames.items.len;
                self.callValue(thread, .{ .base = resolved.base, .arg_count = resolved.arg_count, .return_count = frame.return_count }) catch |err| switch (err) {
                    error.CoroutineYield => {
                        thread.yield_tail_return = true;
                        thread.yield_tail_base = resolved.base;
                        thread.yield_tail_count = frame.return_count;
                        return err;
                    },
                    else => return err,
                };
                try self.runThreadUntil(thread, frame_count);
                try self.returnFromFrame(thread, resolved.base, frame.return_count);
            },
        }
    }

    fn returnFromFrame(self: *State, thread: *Thread, first: bytecode.Register, count: u16) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const source_start = frame.base + first;
        const source_count = try self.resolveResultCount(thread, source_start, count);
        try self.closeActiveToBeClosedInTopFrame(thread, .nil);
        self.closeUpvalues(thread, frame.base);
        if (thread.frames.items.len == 1) {
            thread.last_result_base = source_start;
            thread.last_result_count = source_count;
            thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
            thread.frames.items.len = 0;
            return;
        }

        const return_start = frame.return_start;
        const return_count = try self.resolveReturnCount(frame.return_count, source_count);
        thread.frames.items[thread.frames.items.len - 1].deinit(self.allocator);
        thread.frames.items.len -= 1;

        try thread.ensureStack(self.allocator, return_start + return_count);
        const copied = @min(return_count, source_count);
        copyStackValues(thread, return_start, source_start, copied);
        for (copied..return_count) |index| thread.stack.items[return_start + index] = .nil;
        thread.last_result_base = return_start;
        thread.last_result_count = return_count;
    }

    pub fn returnValues(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, values: []const Value) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const actual_count = try self.resolveReturnCount(return_count, values.len);
        const absolute_base = frame.base + base;
        try thread.ensureStack(self.allocator, absolute_base + actual_count);
        for (0..actual_count) |index| {
            thread.stack.items[absolute_base + index] = if (index < values.len) values[index] else .nil;
        }
        thread.last_result_base = absolute_base;
        thread.last_result_count = actual_count;
    }

    fn prepareClosureFrame(self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame {
        const register_count = @max(closure.proto.max_registers, 1);
        const param_count = @as(usize, closure.proto.param_count);
        const copied = @min(arg_count, param_count);
        const varargs = try self.captureVarargs(thread, source_base + 1 + param_count, if (closure.proto.is_vararg and arg_count > param_count) arg_count - param_count else 0);
        errdefer if (varargs.len != 0) self.allocator.free(varargs);
        try thread.ensureStack(self.allocator, frame_base + register_count);

        for (0..copied) |index| thread.stack.items[frame_base + index] = thread.stack.items[source_base + 1 + index];
        for (copied..register_count) |index| thread.stack.items[frame_base + index] = .nil;

        if (closure.proto.is_vararg and closure.proto.max_registers > closure.proto.param_count) {
            thread.stack.items[frame_base + param_count] = try self.namedVarargTable(varargs);
        }

        return .{
            .closure = closure,
            .proto = closure.proto,
            .base = frame_base,
            .pc = 0,
            .return_start = return_start,
            .return_count = return_count,
            .varargs = varargs,
            .owns_varargs = varargs.len != 0,
        };
    }

    fn captureVarargs(self: *State, thread: *Thread, source_start: usize, count: usize) ![]const Value {
        if (count == 0) return &.{};
        const values = try self.allocator.alloc(Value, count);
        for (0..count) |index| values[index] = thread.stack.items[source_start + index];
        return values;
    }

    fn namedVarargTable(self: *State, varargs: []const Value) !Value {
        const table_value = try self.newTableWithHints(@intCast(varargs.len), 1);
        const table = table_value.table;
        try table.set(self.allocator, .{ .string = try self.intern("n") }, .{ .integer = @intCast(varargs.len) });
        for (varargs, 0..) |value, index| {
            try table.set(self.allocator, .{ .integer = @intCast(index + 1) }, value);
        }
        return table_value;
    }

    fn resolveCall(self: *State, thread: *Thread, op: bytecode.Call) !bytecode.Call {
        if (op.arg_count != bytecode.multret_count) return op;
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const expected_base = frame.base + op.base + 1;
        if (thread.last_result_base < expected_base) return self.fail("invalid multiple-return call state");
        const end = thread.last_result_base + thread.last_result_count;
        const count = if (end <= expected_base) 0 else end - expected_base;
        return .{ .base = op.base, .arg_count = @intCast(count), .return_count = op.return_count };
    }

    fn resolveResultCount(self: *State, thread: *Thread, source_start: usize, count: u16) !usize {
        if (count != bytecode.multret_count) return count;
        if (thread.last_result_base < source_start) return self.fail("invalid multiple-return result state");
        const end = thread.last_result_base + thread.last_result_count;
        return if (end <= source_start) 0 else end - source_start;
    }

    fn resolveReturnCount(self: *State, count: u16, available: usize) !usize {
        _ = self;
        return if (count == bytecode.multret_count) available else count;
    }

    fn loadVarargs(self: *State, thread: *Thread, op: bytecode.Vararg) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const actual_count = try self.resolveReturnCount(op.count, frame.varargs.len);
        const dest = frame.base + op.dest;
        try thread.ensureStack(self.allocator, dest + actual_count);
        const copied = @min(actual_count, frame.varargs.len);
        for (0..copied) |index| thread.stack.items[dest + index] = frame.varargs[index];
        for (copied..actual_count) |index| thread.stack.items[dest + index] = .nil;
        thread.last_result_base = dest;
        thread.last_result_count = actual_count;
    }

    fn setList(self: *State, thread: *Thread, op: bytecode.SetList) !void {
        const frame = thread.frames.items[thread.frames.items.len - 1];
        const source_start = frame.base + op.first;
        const count = if (op.count == bytecode.multret_count) try self.resolveResultCount(thread, source_start, bytecode.multret_count) else op.count;
        const table_value = self.get(thread, op.table);
        for (0..count) |index| {
            try self.setTable(table_value, .{ .integer = @intCast(op.start_index + index) }, thread.stack.items[source_start + index]);
        }
    }

    fn selectValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.fail("bad argument #1 to 'select'");
        const first = argValue(self, thread, op, 0);
        if (first == .string and std.mem.eql(u8, first.string, "#")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = @intCast(op.arg_count - 1) }});
            return;
        }

        var index = toInteger(first) orelse return self.fail("bad argument #1 to 'select'");
        const count: i64 = @intCast(op.arg_count - 1);
        if (index < 0) index = count + index + 1;
        if (index < 1 or index > count + 1) return self.fail("bad argument #1 to 'select'");

        var values = std.ArrayList(Value).empty;
        defer values.deinit(self.allocator);
        var arg_index: usize = @intCast(index);
        const last_arg: usize = @intCast(count);
        while (arg_index <= last_arg) : (arg_index += 1) {
            try values.append(self.allocator, argValue(self, thread, op, @intCast(arg_index)));
        }
        try self.returnValues(thread, op.base, op.return_count, values.items);
    }

    fn assertValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const condition = argValue(self, thread, op, 0);
        if (!truthy(condition)) {
            const message = if (op.arg_count >= 2) argValue(self, thread, op, 1) else Value{ .string = try self.intern("assertion failed!") };
            return self.throwValue(message);
        }

        const values = try self.allocator.alloc(Value, op.arg_count);
        defer self.allocator.free(values);
        for (values, 0..) |*value, index| value.* = argValue(self, thread, op, @intCast(index));
        try self.returnValues(thread, op.base, op.return_count, values);
    }

    fn errorValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const value = argValue(self, thread, op, 0);
        const level = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse 1 else 1;
        if (level <= 0 or value != .string) return self.throwValue(value);

        const level_index = std.math.cast(usize, level) orelse return self.throwValue(value);
        const line = self.lineForErrorLevel(thread, level_index) orelse return self.throwValue(value);
        const message = try std.fmt.allocPrint(self.allocator, "zlua:{d}: {s}", .{ line, value.string });
        defer self.allocator.free(message);
        return self.throwValue(.{ .string = try self.intern(message) });
    }

    fn pcallValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count == 0) return self.fail("bad argument #1 to 'pcall'");
        const args = try self.collectArgs(thread, op, 1);
        defer self.allocator.free(args);

        const result = try self.protectedCall(thread, argValue(self, thread, op, 0), args);
        defer freeProtectedResult(self.allocator, result);
        try self.returnProtectedResult(thread, op.base, op.return_count, result);
    }

    fn xpcallValues(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (op.arg_count < 2) return self.fail("bad argument #2 to 'xpcall'");
        const args = try self.collectArgs(thread, op, 2);
        defer self.allocator.free(args);

        const result = try self.protectedCall(thread, argValue(self, thread, op, 0), args);
        defer freeProtectedResult(self.allocator, result);
        switch (result) {
            .success => try self.returnProtectedResult(thread, op.base, op.return_count, result),
            .failure => |error_value| {
                const handler_result = try self.protectedCall(thread, argValue(self, thread, op, 1), &.{error_value});
                defer freeProtectedResult(self.allocator, handler_result);
                const handled = switch (handler_result) {
                    .success => |values| if (values.len == 0) Value.nil else values[0],
                    .failure => Value{ .string = try self.intern("error in error handling") },
                };
                try self.returnValues(thread, op.base, op.return_count, &.{ .{ .boolean = false }, handled });
            },
        }
    }

    fn tracebackValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator);

        const message = argValue(self, thread, op, 0);
        if (message != .nil) {
            try appendValue(self.allocator, &out, message);
            try out.append(self.allocator, '\n');
        }
        try out.appendSlice(self.allocator, "stack traceback:");
        const level = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse 1 else 1;
        const skip = if (level <= 0) thread.frames.items.len else std.math.cast(usize, level - 1) orelse thread.frames.items.len;
        var index = if (skip >= thread.frames.items.len) @as(usize, 0) else thread.frames.items.len - skip;
        while (index > 0) {
            index -= 1;
            const frame = thread.frames.items[index];
            const line = lineForFrame(frame) orelse 0;
            try out.appendSlice(self.allocator, "\n\tzlua:");
            try appendFmt(self.allocator, &out, "{d}", .{line});
            try out.appendSlice(self.allocator, ": in function");
        }

        try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(out.items) }});
    }

    fn coroutineCreate(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const closure = switch (argValue(self, thread, op, 0)) {
            .closure => |closure| closure,
            else => return self.fail("function expected"),
        };
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .thread = try self.newCoroutineThread(closure) }});
    }

    fn coroutineResume(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const target = try self.expectThread(argValue(self, thread, op, 0));
        const args = try self.collectArgs(thread, op, 1);
        defer self.allocator.free(args);

        const result = try self.resumeCoroutine(target, args);
        defer freeCoroutineResumeResult(self.allocator, result);
        try self.returnCoroutineResumeResult(thread, op.base, op.return_count, result);
    }

    fn coroutineYield(self: *State, thread: *Thread, op: bytecode.Call) !void {
        if (thread.is_main) return self.fail("attempt to yield from outside a coroutine");
        if (thread.native_call_depth > 1) return self.fail("attempt to yield across a native-call boundary");

        thread.yield_values.clearRetainingCapacity();
        for (0..op.arg_count) |index| {
            try thread.yield_values.append(self.allocator, argValue(self, thread, op, @intCast(index)));
        }
        const frame = thread.frames.items[thread.frames.items.len - 1];
        thread.yield_result_base = frame.base + op.base;
        thread.yield_result_count = op.return_count;
        thread.status = .suspended;
        return error.CoroutineYield;
    }

    fn coroutineStatus(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const target = try self.expectThread(argValue(self, thread, op, 0));
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(threadStatusName(target.status)) }});
    }

    fn coroutineRunning(self: *State, thread: *Thread, op: bytecode.Call) !void {
        try self.returnValues(thread, op.base, op.return_count, &.{ .{ .thread = thread }, .{ .boolean = thread.is_main } });
    }

    fn coroutineWrap(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const closure = switch (argValue(self, thread, op, 0)) {
            .closure => |closure| closure,
            else => return self.fail("function expected"),
        };
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .coroutine_wrapper = try self.newCoroutineThread(closure) }});
    }

    fn callCoroutineWrapper(self: *State, thread: *Thread, op: bytecode.Call, target: *Thread) !void {
        const args = try self.collectArgs(thread, op, 0);
        defer self.allocator.free(args);
        try self.callCoroutineWrapperWithArgs(thread, op.base, op.return_count, target, args);
    }

    fn callCoroutineWrapperWithArgs(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value) !void {
        const result = try self.resumeCoroutine(target, args);
        defer freeCoroutineResumeResult(self.allocator, result);
        switch (result) {
            .success => |values| try self.returnValues(thread, base, return_count, values),
            .failure => |error_value| return self.throwValue(error_value),
        }
    }

    fn newCoroutineThread(self: *State, closure: *Closure) !*Thread {
        const thread = try self.allocator.create(Thread);
        errdefer self.allocator.destroy(thread);
        thread.* = Thread.initCoroutine(closure);
        errdefer thread.deinit(self.allocator);
        try self.thread_allocations.append(self.allocator, thread);
        return thread;
    }

    fn resumeCoroutine(self: *State, target: *Thread, args: []const Value) !CoroutineResumeResult {
        if (target.is_main) return .{ .failure = .{ .string = try self.intern("cannot resume main coroutine") } };
        if (target.status == .dead) return .{ .failure = .{ .string = try self.intern("cannot resume dead coroutine") } };
        if (target.status != .suspended) return .{ .failure = .{ .string = try self.intern("cannot resume non-suspended coroutine") } };

        const parent = self.current_thread;
        if (parent == target) return .{ .failure = .{ .string = try self.intern("cannot resume running coroutine") } };

        if (parent) |parent_thread| {
            if (parent_thread.status == .running) parent_thread.status = .normal;
        }
        const previous_thread = self.current_thread;
        self.current_thread = target;
        target.status = .running;
        defer {
            self.current_thread = previous_thread;
            if (parent) |parent_thread| {
                if (parent_thread.status == .normal) parent_thread.status = .running;
            }
        }

        if (!target.started) {
            try self.startCoroutine(target, args);
        } else {
            try self.setCoroutineResumeValues(target, args);
        }

        self.runThreadUntil(target, 0) catch |err| switch (err) {
            error.CoroutineYield => return .{ .success = try self.copyValues(target.yield_values.items) },
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                var error_value = self.currentErrorValue();
                self.closeFramesTo(target, 0, error_value) catch |close_err| switch (close_err) {
                    error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => error_value = self.currentErrorValue(),
                    else => return close_err,
                };
                target.status = .dead;
                return .{ .failure = error_value };
            },
            else => return err,
        };

        target.status = .dead;
        return .{ .success = try self.copyStackSlice(target, target.last_result_base, target.last_result_count) };
    }

    fn startCoroutine(self: *State, target: *Thread, args: []const Value) !void {
        const closure = target.entry orelse return self.fail("coroutine has no entry function");
        try target.ensureStack(self.allocator, 1 + args.len);
        target.stack.items[0] = .{ .closure = closure };
        for (args, 0..) |arg, index| target.stack.items[1 + index] = arg;
        var frame = try self.prepareClosureFrame(target, closure, 0, 0, args.len, 0, bytecode.multret_count);
        errdefer frame.deinit(self.allocator);
        try target.frames.append(self.allocator, frame);
        target.started = true;
    }

    fn setCoroutineResumeValues(self: *State, target: *Thread, args: []const Value) !void {
        const actual_count = try self.resolveReturnCount(target.yield_result_count, args.len);
        try target.ensureStack(self.allocator, target.yield_result_base + actual_count);
        for (0..actual_count) |index| {
            target.stack.items[target.yield_result_base + index] = if (index < args.len) args[index] else .nil;
        }
        target.last_result_base = target.yield_result_base;
        target.last_result_count = actual_count;
        if (target.yield_tail_return) {
            const tail_base = target.yield_tail_base;
            const tail_count = target.yield_tail_count;
            target.yield_tail_return = false;
            try self.returnFromFrame(target, tail_base, tail_count);
        }
    }

    fn returnCoroutineResumeResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult) !void {
        switch (result) {
            .success => |values| {
                var returns = std.ArrayList(Value).empty;
                defer returns.deinit(self.allocator);
                try returns.append(self.allocator, .{ .boolean = true });
                try returns.appendSlice(self.allocator, values);
                try self.returnValues(thread, base, return_count, returns.items);
            },
            .failure => |error_value| try self.returnValues(thread, base, return_count, &.{ .{ .boolean = false }, error_value }),
        }
    }

    fn copyValues(self: *State, values: []const Value) ![]Value {
        const copied = try self.allocator.alloc(Value, values.len);
        @memcpy(copied, values);
        return copied;
    }

    fn copyStackSlice(self: *State, thread: *Thread, base: usize, count: usize) ![]Value {
        const values = try self.allocator.alloc(Value, count);
        for (values, 0..) |*value, index| value.* = thread.stack.items[base + index];
        return values;
    }

    fn lineForErrorLevel(self: *State, thread: *Thread, level: usize) ?usize {
        _ = self;
        if (level == 0 or level > thread.frames.items.len) return null;
        const frame = thread.frames.items[thread.frames.items.len - level];
        return lineForFrame(frame);
    }

    fn collectArgs(self: *State, thread: *Thread, op: bytecode.Call, first: u16) ![]Value {
        if (op.arg_count <= first) return self.allocator.alloc(Value, 0);
        const args = try self.allocator.alloc(Value, op.arg_count - first);
        for (args, 0..) |*arg, index| arg.* = argValue(self, thread, op, first + @as(u16, @intCast(index)));
        return args;
    }

    fn returnProtectedResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult) !void {
        switch (result) {
            .success => |values| {
                var returns = std.ArrayList(Value).empty;
                defer returns.deinit(self.allocator);
                try returns.append(self.allocator, .{ .boolean = true });
                try returns.appendSlice(self.allocator, values);
                try self.returnValues(thread, base, return_count, returns.items);
            },
            .failure => |error_value| try self.returnValues(thread, base, return_count, &.{ .{ .boolean = false }, error_value }),
        }
    }

    fn rawSet(self: *State, table_value: Value, key_value: Value, value: Value) !void {
        const table = try self.expectTable(table_value);
        const key = try self.writableTableKey(key_value);
        try table.set(self.allocator, key, value);
        self.writeTableBarrier(table, key, value);
    }

    fn nextValues(self: *State, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        const key = try self.readableTableKey(key_value) orelse Value.nil;
        return table.next(key) catch return self.fail("invalid key to 'next'");
    }

    fn ipairsIterValues(self: *State, table_value: Value, key_value: Value) ![2]Value {
        const table = try self.expectTable(table_value);
        const current = toInteger(key_value) orelse return self.fail("invalid index to 'ipairs'");
        if (current == std.math.maxInt(i64)) return .{ .nil, .nil };
        const next_index = current + 1;
        const value = table.get(.{ .integer = next_index });
        if (value == .nil) return .{ .nil, .nil };
        return .{ .{ .integer = next_index }, value };
    }

    fn advanceGenericFor(self: *State, thread: *Thread, op: bytecode.GenericFor) !bool {
        const iterator = self.get(thread, op.base);
        const state = self.get(thread, op.base + 1);
        const control = self.get(thread, op.base + 2);
        var fixed: [2]Value = undefined;
        var owned_values: ?[]Value = null;
        defer if (owned_values) |values| self.allocator.free(values);
        const values: []const Value = switch (iterator) {
            .native_next => blk: {
                fixed = try self.nextValues(state, control);
                break :blk fixed[0..2];
            },
            .native_ipairs_iter => blk: {
                fixed = try self.ipairsIterValues(state, control);
                break :blk fixed[0..2];
            },
            .native => |native| switch (native) {
                .string_gmatch_iter => blk: {
                    fixed = try stdlib.string.gmatchNext(self, state);
                    break :blk fixed[0..2];
                },
                .utf8_codes_iter => blk: {
                    fixed = try stdlib.utf8.codesNext(self, state, control);
                    break :blk fixed[0..2];
                },
                else => blk: {
                    const args = [_]Value{ state, control };
                    owned_values = try self.callCollect(thread, iterator, &args);
                    break :blk owned_values.?;
                },
            },
            else => blk: {
                const args = [_]Value{ state, control };
                owned_values = try self.callCollect(thread, iterator, &args);
                break :blk owned_values.?;
            },
        };
        const first_value = if (values.len > 0) values[0] else Value.nil;
        self.set(thread, op.base + 2, first_value);
        for (0..op.variable_count) |index| {
            const value = if (index < values.len) values[index] else Value.nil;
            self.set(thread, op.base + 3 + @as(bytecode.Register, @intCast(index)), value);
        }
        return first_value != .nil;
    }

    pub fn expectTable(self: *State, value: Value) !*Table {
        return switch (value) {
            .table => |table| table,
            else => self.fail("table expected"),
        };
    }

    pub fn expectString(self: *State, value: Value) ![]const u8 {
        return switch (value) {
            .string => |string| string,
            else => self.fail("string expected"),
        };
    }

    fn expectThread(self: *State, value: Value) !*Thread {
        return switch (value) {
            .thread => |thread| thread,
            else => self.fail("thread expected"),
        };
    }

    fn tableCreateHint(self: *State, value: Value, arg_index: u8) !u32 {
        const integer = toInteger(value) orelse return self.fail("number expected");
        if (integer < 0 or integer > std.math.maxInt(i32)) {
            return self.fail(if (arg_index == 1) "bad argument #1 to 'table.create' (out of range)" else "bad argument #2 to 'table.create' (out of range)");
        }
        return @intCast(integer);
    }

    fn callNative(self: *State, native: NativeFn, thread: *Thread, op: bytecode.Call) !void {
        try stdlib.callNative(self, native, thread, op);
    }

    fn collectGarbageValue(self: *State, thread: *Thread, op: bytecode.Call) !void {
        const option = argValue(self, thread, op, 0);
        if (option == .nil or (option == .string and std.mem.eql(u8, option.string, "collect"))) {
            try self.collectGarbageWithFinalizers(thread);
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "step")) {
            const budget = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse return self.fail("number expected") else 0;
            const complete = try self.collectGarbageStep(thread, budget);
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = complete }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "count")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .number = @as(f64, @floatFromInt(self.allocationStats().total())) / 1024.0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "isrunning")) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = self.gc_running }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "stop")) {
            self.gc_running = false;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "restart")) {
            self.gc_running = true;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "incremental")) {
            const old = self.gc_mode;
            self.gc_mode = .incremental;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(old.name()) }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "generational")) {
            const old = self.gc_mode;
            self.gc_mode = .generational;
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .string = try self.intern(old.name()) }});
            return;
        }
        if (option == .string and std.mem.eql(u8, option.string, "param")) {
            const param_value = argValue(self, thread, op, 1);
            const param = try self.collectGarbageParam(param_value);
            const old = self.gc_params.get(param);
            if (op.arg_count >= 3) {
                const new_value = toInteger(argValue(self, thread, op, 2)) orelse return self.fail("number expected");
                self.gc_params.set(param, new_value);
            }
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = old }});
            return;
        }
        return self.fail("bad argument #1 to 'collectgarbage'");
    }

    fn collectGarbageParam(self: *State, value: Value) !GcParam {
        if (value != .string) return self.fail("bad argument #2 to 'collectgarbage'");
        if (std.mem.eql(u8, value.string, "minormul")) return .minormul;
        if (std.mem.eql(u8, value.string, "majorminor")) return .majorminor;
        if (std.mem.eql(u8, value.string, "minormajor")) return .minormajor;
        if (std.mem.eql(u8, value.string, "pause")) return .pause;
        if (std.mem.eql(u8, value.string, "stepmul")) return .stepmul;
        if (std.mem.eql(u8, value.string, "stepsize")) return .stepsize;
        return self.fail("bad argument #2 to 'collectgarbage'");
    }

    fn collectGarbageStep(self: *State, thread: ?*Thread, budget: i64) !bool {
        _ = budget;
        try self.collectGarbageWithFinalizers(thread);
        return false;
    }

    pub fn collectGarbage(self: *State) !void {
        try self.collectGarbageWithFinalizers(self.current_thread);
    }

    fn collectGarbageConservatively(self: *State, thread: ?*Thread) !void {
        try self.collectGarbageWithFinalizersMode(thread, true);
    }

    fn collectGarbageWithFinalizers(self: *State, thread: ?*Thread) !void {
        try self.collectGarbageWithFinalizersMode(thread, false);
    }

    fn collectGarbageWithFinalizersMode(self: *State, thread: ?*Thread, mark_all_stack_registers: bool) !void {
        if (self.is_collecting) return;
        self.is_collecting = true;
        const previous_mark_all = self.mark_all_stack_registers;
        self.mark_all_stack_registers = mark_all_stack_registers;
        defer {
            self.mark_all_stack_registers = previous_mark_all;
            self.is_collecting = false;
        }

        self.resetMarks();
        self.markRoots();
        self.convergeEphemerons();
        self.clearWeakValues();
        try self.runPendingFinalizers(thread);
        self.clearWeakTables();
        self.sweepThreads();
        self.sweepClosures();
        self.sweepUpvalues();
        self.sweepTables();
        self.resetAutoGcThreshold();
    }

    fn shouldRunAutoGc(self: State) bool {
        return !self.is_collecting and self.allocationStats().total() >= self.gc_next_total;
    }

    fn resetAutoGcThreshold(self: *State) void {
        const total = self.allocationStats().total();
        self.gc_next_total = total + @max(total / 2, 256);
    }

    fn resetMarks(self: *State) void {
        for (self.string_allocations.items) |*allocation| allocation.marked = false;
        for (self.table_allocations.items) |table| table.marked = false;
        for (self.closure_allocations.items) |closure| closure.marked = false;
        for (self.upvalue_allocations.items) |upvalue| upvalue.marked = false;
        for (self.thread_allocations.items) |thread| thread.marked = false;
        if (self.current_thread) |thread| {
            if (!self.isTrackedThread(thread)) thread.marked = false;
        }
    }

    fn markRoots(self: *State) void {
        var globals = self.globals.iterator();
        while (globals.next()) |entry| {
            self.markString(entry.key_ptr.*);
            self.markValue(entry.value_ptr.*);
        }
        if (self.last_error) |message| self.markString(message);
        self.markValue(self.last_error_value);
        if (self.current_thread) |thread| self.markThread(thread);
        if (self.string_metatable) |metatable| if (self.isTrackedTable(metatable)) self.markTable(metatable);
    }

    fn markValue(self: *State, value: Value) void {
        switch (value) {
            .string => |string| self.markString(string),
            .table => |table| if (self.isTrackedTable(table)) self.markTable(table),
            .closure => |closure| if (self.isTrackedClosure(closure)) self.markClosure(closure),
            .thread, .coroutine_wrapper => |thread| if (self.isTrackedThread(thread) or thread == self.current_thread) self.markThread(thread),
            else => {},
        }
    }

    fn markString(self: *State, bytes: []const u8) void {
        if (self.findStringAllocation(bytes)) |index| self.string_allocations.items[index].marked = true;
    }

    fn markTable(self: *State, table: *Table) void {
        if (table.marked) return;
        table.marked = true;
        if (table.metatable) |metatable| self.markTable(metatable);
        const weak = self.weakMode(table);
        if (weak.keys and weak.values) return;
        if (weak.values) {
            for (table.entries.items) |entry| self.markValue(entry.key);
            return;
        }
        if (weak.keys) {
            for (table.array.items) |value| self.markValue(value);
            _ = self.markEphemeronValues(table);
            return;
        }
        for (table.array.items) |value| self.markValue(value);
        for (table.entries.items) |entry| {
            self.markValue(entry.key);
            self.markValue(entry.value);
        }
    }

    fn markClosure(self: *State, closure: *Closure) void {
        if (closure.marked) return;
        closure.marked = true;
        for (closure.upvalues) |upvalue| self.markUpvalue(upvalue);
    }

    fn markUpvalue(self: *State, upvalue: *Upvalue) void {
        if (upvalue.marked) return;
        upvalue.marked = true;
        if (upvalue.is_open) {
            if (upvalue.stack_index < upvalue.owner.stack.items.len) self.markValue(upvalue.owner.stack.items[upvalue.stack_index]);
            self.markThread(upvalue.owner);
        } else {
            self.markValue(upvalue.closed);
        }
    }

    fn markThread(self: *State, thread: *Thread) void {
        if (thread.marked) return;
        thread.marked = true;
        if (thread.entry) |entry| self.markClosure(entry);
        self.markThreadStack(thread);
        for (thread.yield_values.items) |value| self.markValue(value);
        for (thread.frames.items) |frame| {
            self.markClosure(frame.closure);
            for (frame.varargs) |value| self.markValue(value);
        }
        var current = thread.open_upvalues;
        while (current) |upvalue| : (current = upvalue.next) self.markUpvalue(upvalue);
    }

    fn markThreadStack(self: *State, thread: *Thread) void {
        for (thread.frames.items) |frame| {
            if (self.mark_all_stack_registers) {
                const register_count = @max(frame.proto.max_registers, 1);
                self.markStackRange(thread, frame.base, register_count);
            } else {
                for (frame.proto.locals.items) |local| {
                    if (!localActiveAt(local, frame.pc)) continue;
                    self.markStackRange(thread, frame.base + local.register, 1);
                }
            }
        }
        self.markStackRange(thread, thread.last_result_base, thread.last_result_count);
        self.markStackRange(thread, thread.yield_result_base, thread.yield_result_count);
    }

    fn markStackRange(self: *State, thread: *Thread, base: usize, count: usize) void {
        if (base >= thread.stack.items.len) return;
        const end = @min(thread.stack.items.len, base + count);
        for (thread.stack.items[base..end]) |value| self.markValue(value);
    }

    fn weakMode(self: *State, table: *Table) WeakMode {
        _ = self;
        const metatable = table.metatable orelse return .{};
        const mode = metatable.get(.{ .string = "__mode" });
        if (mode != .string) return .{};
        return .{
            .keys = std.mem.indexOfScalar(u8, mode.string, 'k') != null,
            .values = std.mem.indexOfScalar(u8, mode.string, 'v') != null,
        };
    }

    fn markEphemeronValues(self: *State, table: *Table) bool {
        var changed = false;
        for (table.entries.items) |entry| {
            if (self.valueIsWeaklyCleared(entry.key)) continue;
            self.markValue(entry.key);
            if (self.markValueChanged(entry.value)) changed = true;
        }
        return changed;
    }

    fn convergeEphemerons(self: *State) void {
        var changed = true;
        while (changed) {
            changed = false;
            for (self.table_allocations.items) |table| {
                if (!table.marked) continue;
                const weak = self.weakMode(table);
                if (!weak.keys or weak.values) continue;
                if (self.markEphemeronValues(table)) changed = true;
            }
        }
    }

    fn markValueChanged(self: *State, value: Value) bool {
        const was_marked = self.valueIsMarked(value);
        self.markValue(value);
        return !was_marked and self.valueIsMarked(value);
    }

    fn valueIsMarked(self: *State, value: Value) bool {
        return switch (value) {
            .string => |string| if (self.findStringAllocation(string)) |index| self.string_allocations.items[index].marked else true,
            .table => |table| !self.isTrackedTable(table) or table.marked,
            .closure => |closure| !self.isTrackedClosure(closure) or closure.marked,
            .thread, .coroutine_wrapper => |thread| !self.isTrackedThread(thread) or thread.marked,
            else => true,
        };
    }

    fn valueIsWeaklyCleared(self: *State, value: Value) bool {
        return switch (value) {
            .table => |table| self.isTrackedTable(table) and !table.marked,
            .closure => |closure| self.isTrackedClosure(closure) and !closure.marked,
            .thread, .coroutine_wrapper => |thread| self.isTrackedThread(thread) and !thread.marked,
            else => false,
        };
    }

    fn clearWeakValues(self: *State) void {
        for (self.table_allocations.items) |table| {
            if (!table.marked) continue;
            if (!self.weakMode(table).values) continue;
            self.clearWeakTableValues(table);
        }
    }

    fn clearWeakTables(self: *State) void {
        for (self.table_allocations.items) |table| {
            if (!table.marked) continue;
            const weak = self.weakMode(table);
            if (weak.values) self.clearWeakTableValues(table);
            if (weak.keys) self.clearWeakTableKeys(table);
        }
    }

    fn clearWeakTableValues(self: *State, table: *Table) void {
        for (table.array.items) |*value| {
            if (self.valueIsWeaklyCleared(value.*)) value.* = .nil;
        }
        var index: usize = 0;
        while (index < table.entries.items.len) {
            if (self.valueIsWeaklyCleared(table.entries.items[index].value)) {
                _ = table.entries.swapRemove(index);
            } else {
                index += 1;
            }
        }
    }

    fn clearWeakTableKeys(self: *State, table: *Table) void {
        var index: usize = 0;
        while (index < table.entries.items.len) {
            if (self.valueIsWeaklyCleared(table.entries.items[index].key)) {
                _ = table.entries.swapRemove(index);
            } else {
                index += 1;
            }
        }
    }

    fn writeTableBarrier(self: *State, table: *Table, key: Value, value: Value) void {
        if (!self.is_collecting or !table.marked) return;
        const weak = self.weakMode(table);
        if (!weak.keys) self.markValue(key);
        if (!weak.values and (!weak.keys or !self.valueIsWeaklyCleared(key))) self.markValue(value);
    }

    fn writeBarrier(self: *State, parent_marked: bool, child: Value) void {
        if (!self.is_collecting or !parent_marked) return;
        self.markValue(child);
    }

    fn runPendingFinalizers(self: *State, thread: ?*Thread) !void {
        const active_thread = thread orelse return;
        var ran_finalizer = false;
        for (self.table_allocations.items) |table| {
            if (table.marked or table.finalized) continue;
            const metatable = table.metatable orelse continue;
            const finalizer = metatable.get(.{ .string = "__gc" });
            if (finalizer == .nil) continue;
            table.marked = true;
            table.finalized = true;
            _ = try self.callOneResult(active_thread, finalizer, &.{.{ .table = table }});
            try self.runThreadUntil(active_thread, active_thread.frames.items.len);
            ran_finalizer = true;
        }
        if (!ran_finalizer) return;
        self.resetMarks();
        self.markRoots();
        self.convergeEphemerons();
        self.clearWeakValues();
    }

    fn sweepStrings(self: *State) void {
        var index: usize = 0;
        while (index < self.string_allocations.items.len) {
            const allocation = self.string_allocations.items[index];
            if (allocation.marked) {
                index += 1;
                continue;
            }
            _ = self.strings.remove(allocation.bytes);
            self.allocator.free(allocation.bytes);
            _ = self.string_allocations.swapRemove(index);
        }
    }

    fn sweepTables(self: *State) void {
        var index: usize = 0;
        while (index < self.table_allocations.items.len) {
            const table = self.table_allocations.items[index];
            if (table.marked) {
                index += 1;
                continue;
            }
            self.destroyTable(table);
            _ = self.table_allocations.swapRemove(index);
        }
    }

    fn sweepClosures(self: *State) void {
        var index: usize = 0;
        while (index < self.closure_allocations.items.len) {
            const closure = self.closure_allocations.items[index];
            if (closure.marked) {
                index += 1;
                continue;
            }
            self.destroyClosure(closure);
            _ = self.closure_allocations.swapRemove(index);
        }
    }

    fn sweepUpvalues(self: *State) void {
        var index: usize = 0;
        while (index < self.upvalue_allocations.items.len) {
            const upvalue = self.upvalue_allocations.items[index];
            if (upvalue.marked) {
                index += 1;
                continue;
            }
            self.allocator.destroy(upvalue);
            _ = self.upvalue_allocations.swapRemove(index);
        }
    }

    fn sweepThreads(self: *State) void {
        var index: usize = 0;
        while (index < self.thread_allocations.items.len) {
            const thread = self.thread_allocations.items[index];
            if (thread.marked) {
                index += 1;
                continue;
            }
            self.destroyThread(thread);
            _ = self.thread_allocations.swapRemove(index);
        }
    }

    fn findStringAllocation(self: *State, bytes: []const u8) ?usize {
        for (self.string_allocations.items, 0..) |allocation, index| {
            if (std.mem.eql(u8, allocation.bytes, bytes)) return index;
        }
        return null;
    }

    fn isTrackedThread(self: *State, thread: *Thread) bool {
        for (self.thread_allocations.items) |allocation| {
            if (allocation == thread) return true;
        }
        return false;
    }

    fn isTrackedTable(self: *State, table: *Table) bool {
        for (self.table_allocations.items) |allocation| {
            if (allocation == table) return true;
        }
        return false;
    }

    fn isTrackedClosure(self: *State, closure: *Closure) bool {
        for (self.closure_allocations.items) |allocation| {
            if (allocation == closure) return true;
        }
        return false;
    }

    fn destroyTable(self: *State, table: *Table) void {
        table.deinit(self.allocator);
        self.allocator.destroy(table);
    }

    fn destroyClosure(self: *State, closure: *Closure) void {
        if (closure.upvalues.len != 0) self.allocator.free(closure.upvalues);
        self.allocator.destroy(closure);
    }

    fn destroyThread(self: *State, thread: *Thread) void {
        thread.deinit(self.allocator);
        self.allocator.destroy(thread);
    }

    fn allocationStats(self: State) RuntimeAllocationStats {
        var bytes: usize = 0;
        for (self.string_allocations.items) |allocation| bytes += @sizeOf(StringAllocation) + allocation.bytes.len;
        for (self.table_allocations.items) |table| bytes += @sizeOf(Table) + table.array.capacity * @sizeOf(Value) + table.entries.capacity * @sizeOf(TableEntry);
        bytes += self.closure_allocations.items.len * @sizeOf(Closure);
        bytes += self.upvalue_allocations.items.len * @sizeOf(Upvalue);
        bytes += self.thread_allocations.items.len * @sizeOf(Thread);

        return .{
            .strings = self.string_allocations.items.len,
            .tables = self.table_allocations.items.len,
            .closures = self.closure_allocations.items.len,
            .upvalues = self.upvalue_allocations.items.len,
            .threads = self.thread_allocations.items.len,
            .bytes = bytes,
        };
    }

    fn errorDetailAlloc(self: *State, allocator: std.mem.Allocator, err: anyerror) ![]const u8 {
        if (self.last_error_value == .nil) return allocator.dupe(u8, @errorName(err));
        var out = std.ArrayList(u8).empty;
        defer out.deinit(allocator);
        try appendValue(allocator, &out, self.last_error_value);
        return allocator.dupe(u8, out.items);
    }

    pub fn fail(self: *State, message: []const u8) RuntimeError {
        self.last_error = message;
        self.last_error_value = .{ .string = message };
        return error.RuntimeError;
    }

    fn throwValue(self: *State, value: Value) RuntimeError {
        self.last_error = null;
        self.last_error_value = value;
        return error.RuntimeError;
    }

    fn currentErrorValue(self: *State) Value {
        if (self.last_error != null and self.last_error_value == .nil) return .{ .string = self.last_error.? };
        return self.last_error_value;
    }
};

pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    return executeSourceWithOptions(allocator, source, .{});
}

pub fn executeSourceWithOptions(allocator: std.mem.Allocator, source: []const u8, options: ExecuteOptions) !process.ProcessResult {
    var tree = frontend.parse(allocator, source) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua parser rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };
    defer tree.deinit();

    compile.resolver.resolve(allocator, &tree) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua resolver rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };

    var proto = compile.compile(allocator, &tree) catch |err| {
        const message = try std.fmt.allocPrint(allocator, "zlua compiler rejected source: {s}\n", .{@errorName(err)});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };
    defer proto.deinit();

    var state = try State.initWithOptions(allocator, options.state);
    defer state.deinit();
    state.collect_after_instruction = options.collect_after_instruction;
    state.execute(&proto) catch |err| {
        const detail = if (state.last_error) |message|
            message
        else
            try state.errorDetailAlloc(allocator, err);
        defer if (state.last_error == null) allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "zlua runtime error: {s}\n", .{detail});
        defer allocator.free(message);
        return process.ownedResult(allocator, "", message, 1);
    };

    return .{
        .stdout = try allocator.dupe(u8, state.stdout.items),
        .stderr = try allocator.dupe(u8, state.stderr.items),
        .exit_code = 0,
        .signal = null,
        .timed_out = false,
    };
}

const BinaryOp = enum { add, sub, mul, div, idiv, mod, pow, band, bor, bxor, shl, shr, concat };
const UnaryMetamethodOp = enum { unm, bnot };
pub const CompareOp = enum { lt, le };

fn rawBinaryOp(lhs: Value, rhs: Value, op: BinaryOp) !?Value {
    switch (op) {
        .add, .sub, .mul, .idiv, .mod => {
            if (toInteger(lhs)) |left| {
                if (toInteger(rhs)) |right| {
                    return switch (op) {
                        .add => .{ .integer = left +% right },
                        .sub => .{ .integer = left -% right },
                        .mul => .{ .integer = left *% right },
                        .idiv => if (right == 0) error.RuntimeError else .{ .integer = floorDiv(left, right) },
                        .mod => if (right == 0) error.RuntimeError else .{ .integer = floorMod(left, right) },
                        else => unreachable,
                    };
                }
            }
        },
        .band, .bor, .bxor, .shl, .shr => {
            if (toBitwiseInteger(lhs)) |left| {
                if (toBitwiseInteger(rhs)) |right| {
                    return .{ .integer = rawBitwise(left, right, op) };
                }
            }
        },
        .div, .pow, .concat => {},
    }

    if (op == .concat) return null;
    const left = toNumberMaybe(lhs) orelse return null;
    const right = toNumberMaybe(rhs) orelse return null;
    return switch (op) {
        .add => .{ .number = left + right },
        .sub => .{ .number = left - right },
        .mul => .{ .number = left * right },
        .div => .{ .number = left / right },
        .idiv => .{ .number = @floor(left / right) },
        .mod => .{ .number = floorModNumber(left, right) },
        .pow => .{ .number = std.math.pow(f64, left, right) },
        else => null,
    };
}

fn floorModNumber(left: f64, right: f64) f64 {
    var result = @rem(left, right);
    if (result != 0 and ((result < 0) != (right < 0))) result += right;
    return result;
}

fn rawUnaryOp(value: Value, op: UnaryMetamethodOp) ?Value {
    return switch (op) {
        .unm => switch (value) {
            .integer => |integer| .{ .integer = -%integer },
            .number => |number| .{ .number = -number },
            else => if (toNumberMaybe(value)) |number| .{ .number = -number } else null,
        },
        .bnot => if (toBitwiseInteger(value)) |integer| .{ .integer = ~integer } else null,
    };
}

fn toBitwiseInteger(value: Value) ?i64 {
    return switch (value) {
        .integer => |integer| integer,
        .number => |number| floatToInteger(number),
        .string => |string| parseIntegerStrict(string) orelse if (parseLuaNumber(string)) |number| floatToInteger(number) else |_| null,
        else => null,
    };
}

fn rawBitwise(left: i64, right: i64, op: BinaryOp) i64 {
    return switch (op) {
        .band => left & right,
        .bor => left | right,
        .bxor => left ^ right,
        .shl => shiftInteger(left, right),
        .shr => if (right == std.math.minInt(i64)) 0 else shiftInteger(left, -right),
        else => unreachable,
    };
}

fn bitwiseIntegerError(lhs: Value, rhs: Value, op: BinaryOp) ?[]const u8 {
    switch (op) {
        .band, .bor, .bxor, .shl, .shr => {},
        else => return null,
    }
    if (bitwiseValueError(lhs)) |message| return message;
    return bitwiseValueError(rhs);
}

fn bitwiseValueError(value: Value) ?[]const u8 {
    switch (value) {
        .integer => return null,
        .number => |number| {
            if (floatToInteger(number) != null) return null;
            if (std.math.isPositiveInf(number)) return "number (field 'huge') has no integer representation";
            return "number has no integer representation";
        },
        .string => |string| {
            if (toBitwiseInteger(.{ .string = string }) != null) return null;
            if (parseLuaNumber(string)) |number| {
                if (floatToInteger(number) == null) return "number has no integer representation";
            } else |_| {}
            return null;
        },
        else => return null,
    }
}

fn shiftInteger(value: i64, amount: i64) i64 {
    if (amount == 0) return value;
    if (amount >= 64 or amount <= -64) return 0;
    return if (amount > 0)
        value << @intCast(amount)
    else
        @as(i64, @bitCast(@as(u64, @bitCast(value)) >> @intCast(-amount)));
}

fn rawCompare(lhs: Value, rhs: Value, op: CompareOp) ?bool {
    return switch (lhs) {
        .integer => |left| switch (rhs) {
            .integer => |right| switch (op) {
                .lt => left < right,
                .le => left <= right,
            },
            .number => |right| compareIntegerNumber(left, right, op),
            else => null,
        },
        .number => |left| switch (rhs) {
            .integer => |right| compareNumberInteger(left, right, op),
            .number => |right| switch (op) {
                .lt => left < right,
                .le => left <= right,
            },
            else => null,
        },
        .string => |left| switch (rhs) {
            .string => |right| switch (op) {
                .lt => std.mem.lessThan(u8, left, right),
                .le => !std.mem.lessThan(u8, right, left),
            },
            else => null,
        },
        else => null,
    };
}

fn compareIntegerNumber(integer: i64, number: f64, op: CompareOp) bool {
    if (std.math.isNan(number)) return false;
    const min = @as(f64, @floatFromInt(std.math.minInt(i64)));
    const max_exclusive = -min;
    return switch (op) {
        .lt => {
            if (number <= min) return false;
            if (number >= max_exclusive) return true;
            return integer < @as(i64, @intFromFloat(@ceil(number)));
        },
        .le => {
            if (number < min) return false;
            if (number >= max_exclusive) return true;
            return integer <= @as(i64, @intFromFloat(@floor(number)));
        },
    };
}

fn compareNumberInteger(number: f64, integer: i64, op: CompareOp) bool {
    if (std.math.isNan(number)) return false;
    return switch (op) {
        .lt => !compareIntegerNumber(integer, number, .le),
        .le => !compareIntegerNumber(integer, number, .lt),
    };
}

fn binaryMetamethod(op: BinaryOp) []const u8 {
    return switch (op) {
        .add => "__add",
        .sub => "__sub",
        .mul => "__mul",
        .div => "__div",
        .idiv => "__idiv",
        .mod => "__mod",
        .pow => "__pow",
        .band => "__band",
        .bor => "__bor",
        .bxor => "__bxor",
        .shl => "__shl",
        .shr => "__shr",
        .concat => "__concat",
    };
}

fn unaryMetamethod(op: UnaryMetamethodOp) []const u8 {
    return switch (op) {
        .unm => "__unm",
        .bnot => "__bnot",
    };
}

pub fn valuesEqual(lhs: Value, rhs: Value) bool {
    return switch (lhs) {
        .nil => rhs == .nil,
        .boolean => |value| rhs == .boolean and rhs.boolean == value,
        .integer => |value| switch (rhs) {
            .integer => |other| value == other,
            .number => |other| if (floatToInteger(other)) |integer| value == integer else false,
            else => false,
        },
        .number => |value| switch (rhs) {
            .integer => |other| if (floatToInteger(value)) |integer| integer == other else false,
            .number => |other| value == other,
            else => false,
        },
        .string => |value| rhs == .string and std.mem.eql(u8, value, rhs.string),
        .table => |value| rhs == .table and value == rhs.table,
        .closure => |value| rhs == .closure and value == rhs.closure,
        .thread => |value| rhs == .thread and value == rhs.thread,
        .coroutine_wrapper => |value| rhs == .coroutine_wrapper and value == rhs.coroutine_wrapper,
        .native_print => rhs == .native_print,
        .native_tostring => rhs == .native_tostring,
        .native_getmetatable => rhs == .native_getmetatable,
        .native_setmetatable => rhs == .native_setmetatable,
        .native_rawequal => rhs == .native_rawequal,
        .native_rawget => rhs == .native_rawget,
        .native_rawset => rhs == .native_rawset,
        .native_rawlen => rhs == .native_rawlen,
        .native_next => rhs == .native_next,
        .native_pairs => rhs == .native_pairs,
        .native_ipairs => rhs == .native_ipairs,
        .native_ipairs_iter => rhs == .native_ipairs_iter,
        .native_table_create => rhs == .native_table_create,
        .native_select => rhs == .native_select,
        .native_assert => rhs == .native_assert,
        .native_error => rhs == .native_error,
        .native_pcall => rhs == .native_pcall,
        .native_xpcall => rhs == .native_xpcall,
        .native_collectgarbage => rhs == .native_collectgarbage,
        .native_debug_traceback => rhs == .native_debug_traceback,
        .native_coroutine_create => rhs == .native_coroutine_create,
        .native_coroutine_resume => rhs == .native_coroutine_resume,
        .native_coroutine_yield => rhs == .native_coroutine_yield,
        .native_coroutine_status => rhs == .native_coroutine_status,
        .native_coroutine_running => rhs == .native_coroutine_running,
        .native_coroutine_wrap => rhs == .native_coroutine_wrap,
        .native => |native| rhs == .native and rhs.native == native,
    };
}

fn isNativeCallable(value: Value) bool {
    return switch (value) {
        .native_print,
        .native_tostring,
        .native_getmetatable,
        .native_setmetatable,
        .native_rawequal,
        .native_rawget,
        .native_rawset,
        .native_rawlen,
        .native_next,
        .native_pairs,
        .native_ipairs,
        .native_ipairs_iter,
        .native_table_create,
        .native_select,
        .native_assert,
        .native_error,
        .native_pcall,
        .native_xpcall,
        .native_collectgarbage,
        .native_debug_traceback,
        .native_coroutine_create,
        .native_coroutine_resume,
        .native_coroutine_yield,
        .native_coroutine_status,
        .native_coroutine_running,
        .native_coroutine_wrap,
        .native,
        => true,
        else => false,
    };
}

fn threadStatusName(status: ThreadStatus) []const u8 {
    return switch (status) {
        .suspended => "suspended",
        .running => "running",
        .normal => "normal",
        .dead => "dead",
    };
}

fn lessThan(lhs: Value, rhs: Value) !bool {
    return switch (lhs) {
        .integer, .number => (try toNumber(lhs)) < (try toNumber(rhs)),
        .string => |left| switch (rhs) {
            .string => |right| std.mem.lessThan(u8, left, right),
            else => error.RuntimeError,
        },
        else => error.RuntimeError,
    };
}

fn lessEqual(lhs: Value, rhs: Value) !bool {
    return valuesEqual(lhs, rhs) or try lessThan(lhs, rhs);
}

pub fn truthy(value: Value) bool {
    return switch (value) {
        .nil => false,
        .boolean => |boolean| boolean,
        else => true,
    };
}

pub fn toInteger(value: Value) ?i64 {
    return switch (value) {
        .integer => |integer| integer,
        .string => |string| parseIntegerStrict(string),
        else => null,
    };
}

pub fn toNumber(value: Value) !f64 {
    return switch (value) {
        .integer => |integer| @floatFromInt(integer),
        .number => |number| number,
        .string => |string| parseLuaNumber(string),
        else => error.RuntimeError,
    };
}

fn toNumberMaybe(value: Value) ?f64 {
    return toNumber(value) catch null;
}

fn luaStringLike(value: Value) bool {
    return switch (value) {
        .integer, .number, .string => true,
        else => false,
    };
}

fn indexErrorMessage(value: Value) []const u8 {
    return switch (value) {
        .integer, .number => "attempt to index a number value",
        .string => "attempt to index a string value",
        .boolean => "attempt to index a boolean value",
        .nil => "attempt to index a nil value",
        else => "attempt to index a non-table value",
    };
}

pub fn appendLuaString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .integer, .number, .string => try appendValue(allocator, out, value),
        else => return error.RuntimeError,
    }
}

fn floorDiv(left: i64, right: i64) i64 {
    if (left == std.math.minInt(i64) and right == -1) return left;
    return @divFloor(left, right);
}

fn floorMod(left: i64, right: i64) i64 {
    if (left == std.math.minInt(i64) and right == -1) return 0;
    return @mod(left, right);
}

fn jumpTarget(pc: usize, offset: bytecode.JumpOffset) usize {
    return if (offset >= 0) pc + @as(usize, @intCast(offset)) else pc - @as(usize, @intCast(-offset));
}

fn forLoopContinuesInteger(current: i64, limit: i64, step: i64) bool {
    return if (step > 0) current <= limit else current >= limit;
}

fn forLoopContinuesNumber(current: f64, limit: f64, step: f64) bool {
    return if (step > 0) current <= limit else current >= limit;
}

fn localActiveAt(local: proto_mod.LocalDebug, pc: usize) bool {
    return local.start_pc <= pc and (local.end_pc == 0 or pc <= local.end_pc);
}

fn isRuntimeError(err: anyerror) bool {
    return switch (err) {
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => true,
        else => false,
    };
}

fn lineForFrame(frame: CallFrame) ?usize {
    if (frame.proto.line_info.items.len == 0) return null;
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    if (pc >= frame.proto.line_info.items.len) return null;
    return frame.proto.line_info.items[pc].line;
}

fn copyStackValues(thread: *Thread, dest: usize, source: usize, count: usize) void {
    if (count == 0 or dest == source) return;
    if (dest > source and dest < source + count) {
        var index = count;
        while (index > 0) {
            index -= 1;
            thread.stack.items[dest + index] = thread.stack.items[source + index];
        }
    } else {
        for (0..count) |index| thread.stack.items[dest + index] = thread.stack.items[source + index];
    }
}

fn constantString(proto: *const proto_mod.Proto, index: bytecode.ConstantIndex) []const u8 {
    return proto.constants.items[index].string;
}

fn parseIntegerLiteral(lexeme: []const u8) !Value {
    if (isHex(lexeme)) {
        const unsigned = try std.fmt.parseInt(u64, lexeme[2..], 16);
        return .{ .integer = @as(i64, @bitCast(unsigned)) };
    }
    if (std.fmt.parseInt(i64, lexeme, 10)) |integer| {
        return .{ .integer = integer };
    } else |_| {
        return .{ .number = try std.fmt.parseFloat(f64, lexeme) };
    }
}

pub fn parseIntegerStrict(text: []const u8) ?i64 {
    const trimmed = trimAscii(text);
    if (trimmed.len == 0) return null;
    const negative = trimmed[0] == '-';
    const unsigned_text = if (trimmed[0] == '+' or trimmed[0] == '-') trimmed[1..] else trimmed;
    if (unsigned_text.len == 0) return null;
    if (isHex(unsigned_text)) {
        if (unsigned_text.len == 2) return null;
        var unsigned: u64 = 0;
        for (unsigned_text[2..]) |byte| {
            if (!std.ascii.isHex(byte)) return null;
            unsigned = unsigned *% 16 +% hexValue(byte);
        }
        const integer: i64 = @bitCast(unsigned);
        return if (negative) -%integer else integer;
    }
    for (trimmed, 0..) |byte, index| {
        if (index == 0 and (byte == '+' or byte == '-')) continue;
        if (!std.ascii.isDigit(byte)) return null;
    }
    return std.fmt.parseInt(i64, trimmed, 10) catch null;
}

pub fn parseLuaNumber(text: []const u8) !f64 {
    const trimmed = trimAscii(text);
    if (trimmed.len == 0) return error.RuntimeError;
    const negative = trimmed[0] == '-';
    const unsigned_text = if (trimmed[0] == '+' or trimmed[0] == '-') trimmed[1..] else trimmed;
    if (unsigned_text.len == 0) return error.RuntimeError;
    if (isHex(unsigned_text)) {
        const number = try parseHexNumber(unsigned_text);
        return if (negative) -number else number;
    }
    var has_digit = false;
    for (unsigned_text) |byte| {
        if (std.ascii.isDigit(byte)) {
            has_digit = true;
            break;
        }
    }
    if (!has_digit) return error.RuntimeError;
    return std.fmt.parseFloat(f64, trimmed);
}

fn parseHexNumber(text: []const u8) !f64 {
    var index: usize = 2;
    var value: f64 = 0;
    var digits: usize = 0;
    while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
        value = value * 16 + @as(f64, @floatFromInt(hexValue(text[index])));
        digits += 1;
    }
    if (index < text.len and text[index] == '.') {
        index += 1;
        var place: f64 = 1.0 / 16.0;
        while (index < text.len and std.ascii.isHex(text[index])) : (index += 1) {
            value += @as(f64, @floatFromInt(hexValue(text[index]))) * place;
            place /= 16.0;
            digits += 1;
        }
    }
    if (digits == 0) return error.RuntimeError;

    var exponent: i32 = 0;
    if (index < text.len and (text[index] == 'p' or text[index] == 'P')) {
        index += 1;
        var sign: i32 = 1;
        if (index < text.len and (text[index] == '+' or text[index] == '-')) {
            sign = if (text[index] == '-') -1 else 1;
            index += 1;
        }
        const exponent_start = index;
        while (index < text.len and std.ascii.isDigit(text[index])) : (index += 1) {
            exponent = exponent * 10 + @as(i32, @intCast(text[index] - '0'));
        }
        if (index == exponent_start) return error.RuntimeError;
        exponent *= sign;
    }
    if (index != text.len) return error.RuntimeError;
    return value * std.math.pow(f64, 2.0, @floatFromInt(exponent));
}

pub fn floatToInteger(number: f64) ?i64 {
    if (!std.math.isFinite(number) or @floor(number) != number) return null;
    const min = @as(f64, @floatFromInt(std.math.minInt(i64)));
    const max = @as(f64, @floatFromInt(std.math.maxInt(i64)));
    if (number < min or number >= max) return null;
    return @intFromFloat(number);
}

fn isHex(text: []const u8) bool {
    return text.len >= 3 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X');
}

pub fn trimAscii(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\n\r\x0b\x0c");
}

fn arrayIndex(value: Value) ?usize {
    const integer = switch (value) {
        .integer => |integer| integer,
        else => return null,
    };
    if (integer <= 0) return null;
    return std.math.cast(usize, integer);
}

pub fn argValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value {
    if (index >= op.arg_count) return .nil;
    return state.get(thread, op.base + 1 + index);
}

pub fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |boolean| try out.appendSlice(allocator, if (boolean) "true" else "false"),
        .integer => |integer| try appendFmt(allocator, out, "{d}", .{integer}),
        .number => |number| try appendNumber(allocator, out, number),
        .string => |string| try out.appendSlice(allocator, string),
        .table => try out.appendSlice(allocator, "table"),
        .closure => try out.appendSlice(allocator, "function"),
        .thread => try out.appendSlice(allocator, "thread"),
        .coroutine_wrapper => try out.appendSlice(allocator, "function"),
        .native_print => try out.appendSlice(allocator, "function: print"),
        .native_tostring => try out.appendSlice(allocator, "function: tostring"),
        .native_getmetatable => try out.appendSlice(allocator, "function: getmetatable"),
        .native_setmetatable => try out.appendSlice(allocator, "function: setmetatable"),
        .native_rawequal => try out.appendSlice(allocator, "function: rawequal"),
        .native_rawget => try out.appendSlice(allocator, "function: rawget"),
        .native_rawset => try out.appendSlice(allocator, "function: rawset"),
        .native_rawlen => try out.appendSlice(allocator, "function: rawlen"),
        .native_next => try out.appendSlice(allocator, "function: next"),
        .native_pairs => try out.appendSlice(allocator, "function: pairs"),
        .native_ipairs => try out.appendSlice(allocator, "function: ipairs"),
        .native_ipairs_iter => try out.appendSlice(allocator, "function: ipairs iterator"),
        .native_table_create => try out.appendSlice(allocator, "function: table.create"),
        .native_select => try out.appendSlice(allocator, "function: select"),
        .native_assert => try out.appendSlice(allocator, "function: assert"),
        .native_error => try out.appendSlice(allocator, "function: error"),
        .native_pcall => try out.appendSlice(allocator, "function: pcall"),
        .native_xpcall => try out.appendSlice(allocator, "function: xpcall"),
        .native_collectgarbage => try out.appendSlice(allocator, "function: collectgarbage"),
        .native_debug_traceback => try out.appendSlice(allocator, "function: debug.traceback"),
        .native_coroutine_create => try out.appendSlice(allocator, "function: coroutine.create"),
        .native_coroutine_resume => try out.appendSlice(allocator, "function: coroutine.resume"),
        .native_coroutine_yield => try out.appendSlice(allocator, "function: coroutine.yield"),
        .native_coroutine_status => try out.appendSlice(allocator, "function: coroutine.status"),
        .native_coroutine_running => try out.appendSlice(allocator, "function: coroutine.running"),
        .native_coroutine_wrap => try out.appendSlice(allocator, "function: coroutine.wrap"),
        .native => |native| {
            try out.appendSlice(allocator, "function: ");
            try out.appendSlice(allocator, native.name());
        },
    }
}

fn freeProtectedResult(allocator: std.mem.Allocator, result: ProtectedCallResult) void {
    switch (result) {
        .success => |values| allocator.free(values),
        .failure => {},
    }
}

fn freeCoroutineResumeResult(allocator: std.mem.Allocator, result: CoroutineResumeResult) void {
    switch (result) {
        .success => |values| allocator.free(values),
        .failure => {},
    }
}

pub fn appendNumber(allocator: std.mem.Allocator, out: *std.ArrayList(u8), number: f64) !void {
    try appendFmt(allocator, out, "{d}", .{number});
    if (@floor(number) == number and std.math.isFinite(number)) {
        try out.appendSlice(allocator, ".0");
    }
}

pub fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn hexValue(byte: u8) u32 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => 0,
    };
}

const max_lua_utf8_codepoint: u32 = 0x7fffffff;

fn appendUnicodeEscapeDigit(value: u32, digit: u32) u32 {
    if (value > max_lua_utf8_codepoint / 16) return max_lua_utf8_codepoint + 1;
    const next = value * 16 + digit;
    if (next > max_lua_utf8_codepoint) return max_lua_utf8_codepoint + 1;
    return next;
}

fn encodeLuaUtf8(code: u32, out: *[6]u8) ?usize {
    if (code <= 0x7f) {
        out[0] = @intCast(code);
        return 1;
    }
    if (code <= 0x7ff) {
        out[0] = 0xc0 | @as(u8, @intCast(code >> 6));
        out[1] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 2;
    }
    if (code <= 0xffff) {
        out[0] = 0xe0 | @as(u8, @intCast(code >> 12));
        out[1] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 3;
    }
    if (code <= 0x1fffff) {
        out[0] = 0xf0 | @as(u8, @intCast(code >> 18));
        out[1] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 4;
    }
    if (code <= 0x3ffffff) {
        out[0] = 0xf8 | @as(u8, @intCast(code >> 24));
        out[1] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 5;
    }
    if (code <= max_lua_utf8_codepoint) {
        out[0] = 0xfc | @as(u8, @intCast(code >> 30));
        out[1] = 0x80 | @as(u8, @intCast((code >> 24) & 0x3f));
        out[2] = 0x80 | @as(u8, @intCast((code >> 18) & 0x3f));
        out[3] = 0x80 | @as(u8, @intCast((code >> 12) & 0x3f));
        out[4] = 0x80 | @as(u8, @intCast((code >> 6) & 0x3f));
        out[5] = 0x80 | @as(u8, @intCast(code & 0x3f));
        return 6;
    }
    return null;
}

test "executes basic print and arithmetic" {
    var result = try executeSource(std.testing.allocator,
        \\print(1 + 2)
        \\print(9 // 4)
        \\print(2 ^ 8)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "3\n2\n256.0\n"));
}

test "executes if while and repeat jumps" {
    var result = try executeSource(std.testing.allocator,
        \\local x = 0
        \\while x < 3 do
        \\  x = x + 1
        \\end
        \\if x == 3 then print("while") else print("bad") end
        \\repeat
        \\  x = x - 1
        \\until x == 0
        \\print(x)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "while\n0\n"));
}

test "reports stack overflow for unbounded Lua recursion" {
    var result = try executeSource(std.testing.allocator,
        \\function f()
        \\  return 1 + f()
        \\end
        \\f()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack overflow") != null);
}

test "reports calls to non-functions" {
    var result = try executeSource(std.testing.allocator,
        \\local value = 1
        \\value()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "attempt to call a non-function value") != null);
}

test "safe stdlib omits host-facing libraries" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\print(type(io), type(os), type(package), type(debug))
    , .{ .state = .{ .stdlib = .safe } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "nil\tnil\tnil\tnil\n"));
}

test "full stdlib can use memory-backed filesystem and fixed clock" {
    const files = [_]MemoryFile{
        .{ .path = "input.txt", .contents = "alpha\nbeta" },
        .{ .path = "loaded.lua", .contents = "return 'loaded'" },
    };
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file = assert(io.open("input.txt", "r"))
        \\print(file:read("*l"))
        \\print(file:read("*a"))
        \\print(assert(loadfile("loaded.lua"))())
        \\print(os.date("!%Y", 0))
    , .{ .state = .{ .filesystem = .{ .memory = &files }, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "alpha\nbeta\nloaded\n1970\n"));
}

test "disabled capabilities block filesystem and process access" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file, err = io.open("missing.lua", "r")
        \\print(file == nil, type(err))
        \\print(pcall(os.execute, "true"))
    , .{ .state = .{ .filesystem = .disabled, .process = .disabled, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "true\tstring\nfalse\tprocess access disabled\n"));
}

test "collects unreachable runtime allocations" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const before = state.allocationStats();
    _ = try state.intern("transient-gc-string");
    _ = try state.newTableWithHints(4, 4);

    try state.collectGarbage();

    const after = state.allocationStats();
    try std.testing.expect(after.strings >= before.strings);
    try std.testing.expectEqual(before.tables, after.tables);
    try std.testing.expectEqual(before.closures, after.closures);
    try std.testing.expectEqual(before.upvalues, after.upvalues);
    try std.testing.expectEqual(before.threads, after.threads);
}

test "keeps global table graph alive during collection" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const root = try state.newTableWithHints(0, 1);
    const child = try state.newTableWithHints(0, 1);
    const key = try state.intern("child");
    try state.setTable(child, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try state.setTable(root, .{ .string = key }, child);
    try state.globals.put(try state.intern("gc_root"), root);

    try state.collectGarbage();

    const kept_root = state.globals.get("gc_root") orelse Value.nil;
    try std.testing.expect(kept_root == .table);
    const kept_child = kept_root.table.get(.{ .string = key });
    try std.testing.expect(kept_child == .table);
    try std.testing.expect(valuesEqual(kept_child.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}

test "weak value tables clear unreachable values" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("v") });
    try state.setMetatableValue(weak, metatable);
    try state.globals.put(try state.intern("weak_values"), weak);

    const dead = try state.newTableWithHints(0, 0);
    try state.setTable(weak, .{ .string = try state.intern("item") }, dead);

    try state.collectGarbage();

    try std.testing.expect(weak.table.get(.{ .string = "item" }) == .nil);
}

test "weak key tables clear unreachable keys" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    try state.setMetatableValue(weak, metatable);
    try state.globals.put(try state.intern("weak_keys"), weak);

    const dead_key = try state.newTableWithHints(0, 0);
    try state.setTable(weak, dead_key, .{ .integer = 1 });

    try state.collectGarbage();

    try std.testing.expectEqual(@as(usize, 0), weak.table.entries.items.len);
}

test "ephemeron table marks value when key is reachable" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const ephemeron = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try state.setTable(metatable, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    try state.setMetatableValue(ephemeron, metatable);
    try state.globals.put(try state.intern("ephemeron"), ephemeron);

    const key = try state.newTableWithHints(0, 0);
    const value = try state.newTableWithHints(0, 1);
    try state.setTable(value, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try state.setTable(ephemeron, key, value);
    try state.globals.put(try state.intern("live_key"), key);

    try state.collectGarbage();

    const kept_value = ephemeron.table.get(key);
    try std.testing.expect(kept_value == .table);
    try std.testing.expect(valuesEqual(kept_value.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}

test "GC stress preserves live locals during execution" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local keep = { answer = 42 }
        \\local i = 1
        \\while i <= 50 do
        \\  local transient = { i, { i + 1 } }
        \\  collectgarbage("collect")
        \\  i = i + 1
        \\end
        \\collectgarbage("collect")
        \\print(keep.answer)
    , .{ .collect_after_instruction = true });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\n"));
}

test "collectgarbage runs table finalizers before sweeping" {
    var result = try executeSource(std.testing.allocator,
        \\do
        \\  local dead = setmetatable({ name = "dead" }, {
        \\    __gc = function(self)
        \\      print("gc-final", self.name)
        \\    end,
        \\  })
        \\  dead = nil
        \\end
        \\collectgarbage("collect")
        \\collectgarbage("collect")
        \\print("done")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "gc-final\tdead\ndone\n"));
}

test "string.dump reloads Lua closures" {
    var result = try executeSource(std.testing.allocator,
        \\local f = assert(load(string.dump(function() return 42 end)))
        \\local ok, message = pcall(string.dump, print)
        \\print(f(), ok, message ~= nil)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\tfalse\ttrue\n"));
}

test "official closure upvalue edge cases" {
    var result = try executeSource(std.testing.allocator,
        \\local a = {}
        \\local i = 1
        \\repeat
        \\  local x = i
        \\  a[i] = function () i = x + 1; return x end
        \\until i > 10 or a[i]() ~= x
        \\assert(i == 11 and a[1]() == 1 and a[3]() == 3 and i == 4)
        \\
        \\a = {}
        \\for j = 1, 3 do
        \\  if j % 3 == 2 then
        \\    local t
        \\    goto make
        \\    ::assign:: a[j] = t; goto done
        \\    ::make::
        \\    local y = 2
        \\    t = function (x) local old = y; y = x; return old end
        \\    goto assign
        \\    ::done::
        \\  end
        \\end
        \\assert(a[2](20) == 2 and a[2]() == 20)
        \\
        \\local debug = require "debug"
        \\local foo1, foo2
        \\do
        \\  local x, y = 3, 5
        \\  foo1 = function () return x + y end
        \\  foo2 = function () return y + x end
        \\end
        \\assert(debug.upvalueid(foo1, 1) == debug.upvalueid(foo2, 2))
        \\debug.upvaluejoin(foo1, 2, foo2, 2)
        \\assert(foo1() == 6 and foo2() == 8)
        \\print("ok")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "ok\n"));
}
