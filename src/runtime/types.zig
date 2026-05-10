const std = @import("std");
const compile = @import("../compile.zig");
const errors = @import("../errors.zig");
const runtime = @import("../runtime.zig");
const value_mod = @import("value.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;
const State = runtime.State;

pub const RuntimeError = error{
    RuntimeError,
    StackOverflow,
    UnsupportedOpcode,
};

pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: *Table,
    userdata: *Userdata,
    closure: *Closure,
    c_closure: *CClosure,
    thread: *Thread,
    coroutine_wrapper: *Thread,
    gmatch_iterator: *Table,
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
    native_coroutine_isyieldable,
    native_coroutine_close,
    native_coroutine_wrap,
    native: NativeFn,
};

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
    import_module,
    json_read,
    json_write,
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
            .import_module => "import",
            .json_read => "json.read",
            .json_write => "json.write",
            .api_callback_dispatch => "__zlua_api_callback",
        };
    }
};

pub const UserdataFinalizer = *const fn (*anyopaque, ?*const anyopaque) void;
pub const UserdataDeinit = *const fn (std.mem.Allocator, *anyopaque) void;

pub const ProtectedCallResult = union(enum) {
    success: []Value,
    failure: Value,
};

pub const ApiCallbackDispatchFn = *const fn (*ApiCallbackContext) anyerror!void;
pub const CClosureDispatchFn = *const fn (*CClosureContext) anyerror!void;
pub const CClosureResumeDispatchFn = *const fn (*CClosureResumeContext) anyerror!void;
pub const CDebugHookDispatchFn = *const fn (*CDebugHookContext) anyerror!void;

pub const DebugHookEvent = enum {
    call,
    ret,
    line,
    count,
    tail_call,
};

pub const CDebugHookContext = struct {
    state: *State,
    thread: *Thread,
    event: DebugHookEvent,
    currentline: ?usize = null,
    ftransfer: i64 = 0,
    ntransfer: usize = 0,
    user_data: ?*anyopaque,
};

pub const CClosureContext = struct {
    state: *State,
    thread: *Thread,
    op: bytecode.Call,
    closure: *CClosure,
    user_data: ?*anyopaque,
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,

    pub fn deinit(self: *CClosureContext) void {
        self.returns.deinit(self.state.allocator);
    }

    pub fn argCount(self: *CClosureContext) usize {
        return self.op.arg_count;
    }

    pub fn argValue(self: *CClosureContext, index: usize) Value {
        const raw_index = std.math.cast(u16, index) orelse return .nil;
        return value_mod.runtimeArgValue(self.state, self.thread, self.op, raw_index);
    }

    pub fn appendReturn(self: *CClosureContext, value: Value) !void {
        try self.returns.append(self.state.allocator, value);
    }

    pub fn raise(self: *CClosureContext, value: Value) error{LuaError} {
        self.error_value = value;
        return error.LuaError;
    }

    pub fn yieldWithReturns(self: *CClosureContext, values: []const Value) !void {
        self.thread.yield_values.clearRetainingCapacity();
        try self.thread.yield_values.appendSlice(self.state.allocator, values);
        const frame = self.thread.frames.items[self.thread.frames.items.len - 1];
        self.thread.yield_result_base = frame.base + self.op.base;
        self.thread.yield_result_count = self.op.return_count;
        self.thread.pending_c_continuation = true;
        self.thread.status = .suspended;
        return error.CoroutineYield;
    }
};

pub const CClosureResumeContext = struct {
    state: *State,
    thread: *Thread,
    args: []const Value,
    user_data: ?*anyopaque,
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,

    pub fn deinit(self: *CClosureResumeContext) void {
        self.returns.deinit(self.state.allocator);
    }

    pub fn appendReturn(self: *CClosureResumeContext, value: Value) !void {
        try self.returns.append(self.state.allocator, value);
    }

    pub fn raise(self: *CClosureResumeContext, value: Value) error{LuaError} {
        self.error_value = value;
        return error.LuaError;
    }

    pub fn yieldWithReturns(self: *CClosureResumeContext, values: []const Value) !void {
        self.thread.yield_values.clearRetainingCapacity();
        try self.thread.yield_values.appendSlice(self.state.allocator, values);
        self.thread.pending_c_continuation = true;
        self.thread.status = .suspended;
        return error.CoroutineYield;
    }
};

pub const ApiCallbackContext = struct {
    state: *State,
    thread: *Thread,
    op: bytecode.Call,
    callback_id: usize,
    user_data: ?*anyopaque,
    function_name: []const u8 = "host callback",
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,

    pub fn deinit(self: *ApiCallbackContext) void {
        self.returns.deinit(self.state.allocator);
    }

    pub fn argCount(self: *ApiCallbackContext) usize {
        if (self.op.arg_count == 0) return 0;
        return self.op.arg_count - 1;
    }

    pub fn callbackArgValue(self: *ApiCallbackContext, index: usize) Value {
        const raw_index = std.math.cast(u16, index + 1) orelse return .nil;
        return value_mod.argValue(self.state, self.thread, self.op, raw_index);
    }

    pub fn clearReturns(self: *ApiCallbackContext) void {
        self.returns.clearRetainingCapacity();
    }

    pub fn appendReturn(self: *ApiCallbackContext, value: Value) !void {
        try self.returns.append(self.state.allocator, value);
    }

    pub fn fail(self: *ApiCallbackContext, message: []const u8) RuntimeError {
        return self.state.fail(message);
    }

    pub fn failArgumentMessage(self: *ApiCallbackContext, index: usize, message: []const u8) RuntimeError {
        return self.state.failArgumentMessage(self.function_name, argumentIndex(index), message);
    }

    pub fn failArgumentType(self: *ApiCallbackContext, index: usize, expected: []const u8, actual: Value) RuntimeError {
        return self.state.failArgumentType(self.function_name, argumentIndex(index), expected, actual);
    }

    pub fn raise(self: *ApiCallbackContext, value: Value) error{LuaError} {
        self.error_value = value;
        return error.LuaError;
    }

    fn argumentIndex(index: usize) u16 {
        return std.math.cast(u16, index + 1) orelse std.math.maxInt(u16);
    }
};

pub const RuntimeErrorPayload = union(enum) {
    diagnostic: []const u8,
    argument: errors.ArgumentError,
    lua_value: Value,

    pub fn luaValue(self: RuntimeErrorPayload, state: anytype) Value {
        return switch (self) {
            .diagnostic => |message| .{ .string = message },
            .argument => |argument| blk: {
                const rendered = errors.renderArgumentError(state.allocator, argument) catch break :blk .{ .string = "bad argument" };
                defer state.allocator.free(rendered);
                break :blk .{ .string = state.intern(rendered) catch "bad argument" };
            },
            .lua_value => |value| value,
        };
    }
};

pub const ProtectedCallContext = struct {
    frame_count: usize,
    relative_base: bytecode.Register,
    absolute_base: usize,
    stack_len: usize,
    last_result_base: usize,
    last_result_count: usize,
    last_error: ?RuntimeErrorPayload,
};

pub const ProtectedContinuationKind = enum {
    pcall,
    xpcall,
    xpcall_handler,
};

pub const ProtectedContinuation = struct {
    context: ProtectedCallContext,
    base: bytecode.Register,
    return_count: u16,
    kind: ProtectedContinuationKind,
    handler: Value = .nil,
    handler_depth: usize = 0,
};

pub const GenericForContinuation = struct {
    frame_count: usize,
    op: bytecode.GenericFor,
    jump_on_nil: bool,
};

pub const BranchContinuation = struct {
    jump_if_truthy: bool,
    offset: bytecode.JumpOffset,
};

pub const TailCallContinuation = struct {
    frame_count: usize,
    base: bytecode.Register,
    return_count: u16,
};

pub const CallOneContinuationResult = union(enum) {
    value: usize,
    truthy: usize,
    inverted_truthy: usize,
    branch_truthy: BranchContinuation,
    branch_inverted_truthy: BranchContinuation,
    discard,
};

pub const CallOneContinuation = struct {
    frame_count: usize,
    result: CallOneContinuationResult,
};

pub const CoroutineResumeResult = union(enum) {
    success: []Value,
    failure: Value,
};

pub const Closure = struct {
    proto: *const proto_mod.Proto,
    upvalues: []*Upvalue,
    constants: ?[]?Value = null,
    stripped_debug: bool = false,
    marked: bool = false,
};

pub const CClosure = struct {
    function_id: usize,
    upvalues: []*CUpvalue,
    marked: bool = false,
};

pub const CUpvalue = struct {
    value: Value = .nil,
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

pub const TableEntry = struct {
    key: Value,
    value: Value,
};

pub const TableEntryIndex = std.HashMap(Value, usize, ValueHashContext, std.hash_map.default_max_load_percentage);

const ValueHashContext = struct {
    pub fn hash(_: ValueHashContext, key: Value) u64 {
        return value_mod.hashValue(key);
    }

    pub fn eql(_: ValueHashContext, lhs: Value, rhs: Value) bool {
        return value_mod.valuesEqual(lhs, rhs);
    }
};

pub const Table = struct {
    array: std.ArrayList(Value) = .empty,
    entries: std.ArrayList(TableEntry) = .empty,
    entry_index: TableEntryIndex,
    metatable: ?*Table = null,
    metatable_prev: ?*Table = null,
    metatable_next: ?*Table = null,
    counts_for_gc_count: bool = true,
    marked: bool = false,
    finalized: bool = false,

    pub fn init(allocator: std.mem.Allocator, array_hint: u32, hash_hint: u32) !Table {
        var table = Table{ .entry_index = TableEntryIndex.init(allocator) };
        errdefer table.deinit(allocator);
        try table.array.ensureTotalCapacity(allocator, array_hint);
        try table.entries.ensureTotalCapacity(allocator, hash_hint);
        try table.entry_index.ensureTotalCapacity(hash_hint);
        return table;
    }

    pub fn deinit(self: *Table, allocator: std.mem.Allocator) void {
        self.entry_index.deinit();
        self.entries.deinit(allocator);
        self.array.deinit(allocator);
        self.* = undefined;
    }

    pub fn get(self: Table, key: Value) Value {
        if (value_mod.arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.array.items[index - 1];
        }
        if (self.entry_index.get(key)) |index| return self.entries.items[index].value;
        return .nil;
    }

    pub fn set(self: *Table, allocator: std.mem.Allocator, key: Value, value: Value) !void {
        if (value_mod.arrayIndex(key)) |index| {
            if (index <= self.array.items.len) {
                self.array.items[index - 1] = value;
                return;
            }
            if (value != .nil and index == self.array.items.len + 1) {
                try self.array.append(allocator, value);
                self.removeHashKey(key);
                return;
            }
            if (value != .nil and index <= self.array.capacity) {
                const old_len = self.array.items.len;
                try self.array.resize(allocator, index);
                @memset(self.array.items[old_len..], .nil);
                self.array.items[index - 1] = value;
                self.removeHashKey(key);
                return;
            }
        }
        if (self.entry_index.get(key)) |index| {
            if (value == .nil) {
                self.entries.items[index].value = .nil;
            } else {
                self.entries.items[index].value = value;
            }
            return;
        }
        if (value != .nil) {
            try self.entries.append(allocator, .{ .key = key, .value = value });
            errdefer self.entries.items.len -= 1;
            try self.entry_index.put(key, self.entries.items.len - 1);
        }
    }

    pub fn setExistingNonNil(self: *Table, key: Value, value: Value) bool {
        if (value_mod.arrayIndex(key)) |index| {
            if (index <= self.array.items.len and self.array.items[index - 1] != .nil) {
                self.array.items[index - 1] = value;
                return true;
            }
            return false;
        }
        if (self.entry_index.get(key)) |index| {
            if (self.entries.items[index].value == .nil) return false;
            self.entries.items[index].value = value;
            return true;
        }
        return false;
    }

    pub fn len(self: Table) i64 {
        var result = self.array.items.len;
        while (result > 0 and self.array.items[result - 1] == .nil) result -= 1;
        if (self.entries.items.len == 0) return @intCast(result);
        while (result < std.math.maxInt(i64)) {
            const next_index = result + 1;
            if (self.get(.{ .integer = @intCast(next_index) }) == .nil) break;
            result = next_index;
        }
        return @intCast(result);
    }

    pub fn next(self: Table, key: Value) ![2]Value {
        if (key == .nil) return self.firstEntryAfterArray(0);
        if (value_mod.arrayIndex(key)) |index| {
            if (index <= self.array.items.len) return self.firstEntryAfterArray(index);
        }
        if (self.entry_index.get(key)) |index| {
            return self.firstHashEntryFrom(index + 1);
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
        return self.firstHashEntryFrom(0);
    }

    fn firstHashEntryFrom(self: Table, start: usize) [2]Value {
        var index = start;
        while (index < self.entries.items.len) : (index += 1) {
            const entry = self.entries.items[index];
            if (entry.value != .nil) return .{ entry.key, entry.value };
        }
        return .{ .nil, .nil };
    }

    pub fn removeHashKey(self: *Table, key: Value) void {
        if (self.entry_index.get(key)) |index| self.removeEntryAt(index);
    }

    pub fn removeEntryAt(self: *Table, index: usize) void {
        const old_key = self.entries.items[index].key;
        _ = self.entry_index.remove(old_key);
        var next_index = index + 1;
        while (next_index < self.entries.items.len) : (next_index += 1) {
            const shifted_index = next_index - 1;
            self.entries.items[shifted_index] = self.entries.items[next_index];
            self.entry_index.getPtr(self.entries.items[shifted_index].key).?.* = shifted_index;
        }
        self.entries.items.len -= 1;
    }
};

pub const Userdata = struct {
    ptr: *anyopaque,
    type_id: usize,
    type_name: []const u8,
    metatable: ?*Table = null,
    finalizer: ?UserdataFinalizer = null,
    finalizer_data: ?*const anyopaque = null,
    deinit_fn: ?UserdataDeinit = null,
    marked: bool = false,
    finalized: bool = false,
};

pub const Thread = struct {
    stack: std.ArrayList(Value) = .empty,
    frames: std.ArrayList(CallFrame) = .empty,
    yield_values: std.ArrayList(Value) = .empty,
    protected_continuations: std.ArrayList(ProtectedContinuation) = .empty,
    generic_for_continuations: std.ArrayList(GenericForContinuation) = .empty,
    tail_call_continuations: std.ArrayList(TailCallContinuation) = .empty,
    call_one_continuations: std.ArrayList(CallOneContinuation) = .empty,
    open_upvalues: ?*Upvalue = null,
    hook: Value = .nil,
    hook_call: bool = false,
    hook_line: bool = false,
    hook_return: bool = false,
    hook_count: u32 = 0,
    hook_count_remaining: u32 = 0,
    hook_running: bool = false,
    hook_return_name: ?[]const u8 = null,
    hook_level2_func: Value = .nil,
    hook_transfer_index_base: i64 = 0,
    hook_transfer_stack_base: usize = 0,
    hook_transfer_count: usize = 0,
    hook_transfer_values: []const Value = &.{},
    next_call_name: ?[]const u8 = null,
    next_call_namewhat: ?[]const u8 = null,
    pending_yield_hook_return: bool = false,
    last_result_base: usize = 0,
    last_result_count: usize = 0,
    last_transfer_base: usize = 0,
    last_transfer_count: usize = 0,
    yield_result_base: usize = 0,
    yield_result_count: u16 = 0,
    native_call_depth: usize = 0,
    traceback_native_name: ?[]const u8 = null,
    protected_close_depth: usize = 0,
    close_error_value: ?Value = null,
    error_traceback: ?[]const u8 = null,
    pending_unwind_error: ?Value = null,
    pending_unwind_resume_frame_count: usize = 0,
    pending_unwind_target_frame_count: usize = 0,
    pending_c_continuation: bool = false,
    resume_parent: ?*Thread = null,
    entry: Value = .nil,
    marked: bool = false,
    started: bool = false,
    is_main: bool = false,
    closing: bool = false,
    status: ThreadStatus = .suspended,

    pub fn initRoot(allocator: std.mem.Allocator, closure: *Closure, stack_value_limit: usize) !Thread {
        var thread = Thread{};
        thread.entry = .{ .closure = closure };
        thread.started = true;
        thread.is_main = true;
        thread.status = .running;
        errdefer thread.deinit(allocator);
        const proto = closure.proto;
        try thread.ensureStack(allocator, @max(proto.max_registers, 1), stack_value_limit);
        try thread.frames.append(allocator, .{ .closure = closure, .proto = proto, .base = 0, .pc = 0, .return_start = 0, .return_count = 0, .varargs = &.{} });
        return thread;
    }

    pub fn initCoroutine(entry: Value) Thread {
        return .{ .entry = entry, .status = .suspended };
    }

    pub fn deinit(self: *Thread, allocator: std.mem.Allocator) void {
        for (self.frames.items) |*frame| frame.deinit(allocator);
        self.yield_values.deinit(allocator);
        self.protected_continuations.deinit(allocator);
        self.generic_for_continuations.deinit(allocator);
        self.tail_call_continuations.deinit(allocator);
        self.call_one_continuations.deinit(allocator);
        self.frames.deinit(allocator);
        self.stack.deinit(allocator);
        self.* = undefined;
    }

    pub fn ensureStack(self: *Thread, allocator: std.mem.Allocator, size: usize, limit: usize) !void {
        if (size > limit) return error.StackOverflow;
        const old_len = self.stack.items.len;
        if (size <= old_len) return;
        try self.stack.resize(allocator, size);
        @memset(self.stack.items[old_len..], .nil);
    }
};

pub const ThreadStatus = enum {
    suspended,
    running,
    normal,
    dead,
};

pub const CallFrame = struct {
    closure: *Closure,
    proto: *const proto_mod.Proto,
    base: usize,
    pc: usize,
    return_start: usize,
    return_count: u16,
    varargs: []const Value,
    owns_varargs: bool = false,
    vararg_table_local: Value = .nil,
    last_hook_line: ?usize = null,
    debug_name_override: ?[]const u8 = null,
    debug_namewhat_override: ?[]const u8 = null,
    is_tail_call: bool = false,
    pending_returns: ?[]Value = null,

    pub fn deinit(self: *CallFrame, allocator: std.mem.Allocator) void {
        if (self.owns_varargs) allocator.free(self.varargs);
        if (self.pending_returns) |returns| allocator.free(returns);
        self.varargs = &.{};
        self.owns_varargs = false;
        self.pending_returns = null;
    }
};

pub const StringAllocation = struct {
    bytes: []const u8,
    marked: bool = false,
};
pub const PointerAllocationIndex = std.AutoHashMap(usize, usize);

pub const GcMode = enum {
    incremental,
    generational,

    pub fn name(self: GcMode) []const u8 {
        return switch (self) {
            .incremental => "incremental",
            .generational => "generational",
        };
    }
};

pub const GcParam = enum {
    minormul,
    majorminor,
    minormajor,
    pause,
    stepmul,
    stepsize,
};

pub const GcParams = struct {
    minormul: i64 = 20,
    majorminor: i64 = 50,
    minormajor: i64 = 70,
    pause: i64 = 250,
    stepmul: i64 = 200,
    stepsize: i64 = 200,

    pub fn get(self: GcParams, param: GcParam) i64 {
        return switch (param) {
            .minormul => self.minormul,
            .majorminor => self.majorminor,
            .minormajor => self.minormajor,
            .pause => self.pause,
            .stepmul => self.stepmul,
            .stepsize => self.stepsize,
        };
    }

    pub fn set(self: *GcParams, param: GcParam, value: i64) void {
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

pub const WeakMode = struct {
    keys: bool = false,
    values: bool = false,
};

pub const RuntimeAllocationStats = struct {
    strings: usize,
    tables: usize,
    closures: usize,
    upvalues: usize,
    threads: usize,
    bytes: usize,

    pub fn total(self: RuntimeAllocationStats) usize {
        return self.bytes;
    }
};
