const std = @import("std");
const runtime = @import("runtime.zig");
const stdlib = @import("stdlib.zig");

pub const lua_State = opaque {};
const LUA_IDSIZE: usize = 60;

const lua_Debug = extern struct {
    event: c_int,
    name: ?[*:0]const u8,
    namewhat: ?[*:0]const u8,
    what: ?[*:0]const u8,
    source: ?[*]const u8,
    srclen: usize,
    currentline: c_int,
    linedefined: c_int,
    lastlinedefined: c_int,
    nups: u8,
    nparams: u8,
    isvararg: u8,
    extraargs: u8,
    istailcall: u8,
    ftransfer: c_int,
    ntransfer: c_int,
    short_src: [LUA_IDSIZE]u8,
    i_ci: ?*anyopaque,
};
const LuaLBufferInit = extern union {
    n: lua_Number,
    u: f64,
    s: ?*anyopaque,
    i: lua_Integer,
    l: c_long,
    b: [LUAL_BUFFERSIZE]u8,
};
const luaL_Buffer = extern struct {
    b: ?[*]u8,
    size: usize,
    n: usize,
    L: ?*lua_State,
    init: LuaLBufferInit,
};
const luaL_Reg = extern struct {
    name: ?[*:0]const u8,
    func: lua_CFunction,
};

const lua_Number = f64;
const lua_Integer = c_longlong;
const lua_Unsigned = c_ulonglong;
const lua_KContext = isize;
const lua_CFunction = ?*const fn (?*lua_State) callconv(.c) c_int;
const lua_KFunction = ?*const fn (?*lua_State, c_int, lua_KContext) callconv(.c) c_int;
const lua_Reader = ?*const fn (?*lua_State, ?*anyopaque, *usize) callconv(.c) ?[*:0]const u8;
const lua_Writer = ?*const fn (?*lua_State, ?*const anyopaque, usize, ?*anyopaque) callconv(.c) c_int;
const lua_Alloc = ?*const fn (?*anyopaque, ?*anyopaque, usize, usize) callconv(.c) ?*anyopaque;
const lua_WarnFunction = ?*const fn (?*anyopaque, ?[*:0]const u8, c_int) callconv(.c) void;
const lua_Hook = ?*const fn (?*lua_State, ?*lua_Debug) callconv(.c) void;
const VaList = std.builtin.VaList;

pub export const lua_ident: [18:0]u8 = "zlua C API phase 7".*;

const LUA_MULTRET: c_int = -1;
const LUA_OK: c_int = 0;
const LUA_YIELD: c_int = 1;
const LUA_ERRRUN: c_int = 2;
const LUA_ERRSYNTAX: c_int = 3;
const LUA_ERRMEM: c_int = 4;
const LUA_ERRERR: c_int = 5;
const LUA_ERRFILE: c_int = LUA_ERRERR + 1;

const LUA_TNONE: c_int = -1;
const LUA_TNIL: c_int = 0;
const LUA_TBOOLEAN: c_int = 1;
const LUA_TLIGHTUSERDATA: c_int = 2;
const LUA_TNUMBER: c_int = 3;
const LUA_TSTRING: c_int = 4;
const LUA_TTABLE: c_int = 5;
const LUA_TFUNCTION: c_int = 6;
const LUA_TUSERDATA: c_int = 7;
const LUA_TTHREAD: c_int = 8;

const LUA_MINSTACK: usize = 20;
const LUA_RIDX_GLOBALS: lua_Integer = 2;
const LUA_RIDX_MAINTHREAD: lua_Integer = 3;
const LUA_REGISTRYINDEX: c_int = -(std.math.maxInt(c_int) / 2 + 1000);
const LUA_EXTRASPACE: usize = @sizeOf(?*anyopaque);
const LUA_VERSION_NUM: lua_Number = 505;
const LUAL_NUMSIZES: usize = @sizeOf(lua_Integer) * 16 + @sizeOf(lua_Number);
const LUA_NOREF: c_int = -2;
const LUA_REFNIL: c_int = -1;
const LUAL_BUFFERSIZE: usize = 16 * @sizeOf(?*anyopaque) * @sizeOf(lua_Number);
const LUA_GNAME = "_G";
const LUA_LOADED_TABLE = "_LOADED";
const LUA_PRELOAD_TABLE = "_PRELOAD";

const LUA_GLIBK: c_int = 1;
const LUA_LOADLIBK: c_int = LUA_GLIBK << 1;
const LUA_COLIBK: c_int = LUA_LOADLIBK << 1;
const LUA_DBLIBK: c_int = LUA_COLIBK << 1;
const LUA_IOLIBK: c_int = LUA_DBLIBK << 1;
const LUA_MATHLIBK: c_int = LUA_IOLIBK << 1;
const LUA_OSLIBK: c_int = LUA_MATHLIBK << 1;
const LUA_STRLIBK: c_int = LUA_OSLIBK << 1;
const LUA_TABLIBK: c_int = LUA_STRLIBK << 1;
const LUA_UTF8LIBK: c_int = LUA_TABLIBK << 1;

const LUA_OPADD: c_int = 0;
const LUA_OPSUB: c_int = 1;
const LUA_OPMUL: c_int = 2;
const LUA_OPMOD: c_int = 3;
const LUA_OPPOW: c_int = 4;
const LUA_OPDIV: c_int = 5;
const LUA_OPIDIV: c_int = 6;
const LUA_OPBAND: c_int = 7;
const LUA_OPBOR: c_int = 8;
const LUA_OPBXOR: c_int = 9;
const LUA_OPSHL: c_int = 10;
const LUA_OPSHR: c_int = 11;
const LUA_OPUNM: c_int = 12;
const LUA_OPBNOT: c_int = 13;

const LUA_OPEQ: c_int = 0;
const LUA_OPLT: c_int = 1;
const LUA_OPLE: c_int = 2;

const LUA_GCSTOP: c_int = 0;
const LUA_GCRESTART: c_int = 1;
const LUA_GCCOLLECT: c_int = 2;
const LUA_GCCOUNT: c_int = 3;
const LUA_GCCOUNTB: c_int = 4;
const LUA_GCSTEP: c_int = 5;
const LUA_GCISRUNNING: c_int = 6;
const LUA_GCGEN: c_int = 7;
const LUA_GCINC: c_int = 8;
const LUA_GCPARAM: c_int = 9;
const LUA_GCPN: c_int = 6;

const LUA_HOOKCALL: c_int = 0;
const LUA_HOOKRET: c_int = 1;
const LUA_HOOKLINE: c_int = 2;
const LUA_HOOKCOUNT: c_int = 3;
const LUA_HOOKTAILCALL: c_int = 4;

const LUA_MASKCALL: c_int = 1 << LUA_HOOKCALL;
const LUA_MASKRET: c_int = 1 << LUA_HOOKRET;
const LUA_MASKLINE: c_int = 1 << LUA_HOOKLINE;
const LUA_MASKCOUNT: c_int = 1 << LUA_HOOKCOUNT;

const Value = union(enum) {
    nil,
    boolean: bool,
    integer: lua_Integer,
    number: lua_Number,
    string: *CString,
    table: *CTable,
    userdata: *CUserdata,
    thread: *CThread,
    light_userdata: ?*anyopaque,
    lua_closure: *runtime.Closure,
    c_closure: *runtime.CClosure,
    runtime_native: runtime.Value,

    fn typeTag(self: Value) c_int {
        return switch (self) {
            .nil => LUA_TNIL,
            .boolean => LUA_TBOOLEAN,
            .integer, .number => LUA_TNUMBER,
            .string => LUA_TSTRING,
            .table => LUA_TTABLE,
            .userdata => LUA_TUSERDATA,
            .thread => LUA_TTHREAD,
            .light_userdata => LUA_TLIGHTUSERDATA,
            .lua_closure, .c_closure, .runtime_native => LUA_TFUNCTION,
        };
    }
};

const CString = struct {
    bytes: [:0]const u8,
    external: bool = false,
    external_alloc_f: lua_Alloc = null,
    external_ud: ?*anyopaque = null,
    marked: bool = false,

    fn deinit(self: *CString, allocator: std.mem.Allocator) void {
        if (self.external) {
            if (self.external_alloc_f) |alloc_f| {
                _ = alloc_f(self.external_ud, @constCast(self.bytes.ptr), self.bytes.len + 1, 0);
            }
        } else {
            allocator.free(self.bytes);
        }
        allocator.destroy(self);
    }
};

const TableEntry = struct {
    key: Value,
    value: Value,
};

const CTable = struct {
    entries: std.ArrayList(TableEntry) = .empty,
    metatable: ?*CTable = null,
    marked: bool = false,

    fn create(allocator: std.mem.Allocator, array_hint: c_int, record_hint: c_int) !*CTable {
        const table = try allocator.create(CTable);
        table.* = .{};
        errdefer allocator.destroy(table);
        const capacity = @as(usize, @intCast(@max(array_hint, 0))) + @as(usize, @intCast(@max(record_hint, 0)));
        try table.entries.ensureTotalCapacity(allocator, capacity);
        return table;
    }

    fn deinit(self: *CTable, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        allocator.destroy(self);
    }

    fn get(self: *CTable, key: Value) Value {
        const normalized = normalizeKey(key) orelse return .nil;
        for (self.entries.items) |entry| {
            if (entry.value != .nil and valuesEqual(entry.key, normalized)) return entry.value;
        }
        return .nil;
    }

    fn set(self: *CTable, allocator: std.mem.Allocator, key: Value, value: Value) !void {
        const normalized = normalizeKey(key) orelse return;
        for (self.entries.items, 0..) |entry, index| {
            if (valuesEqual(entry.key, normalized)) {
                if (value == .nil) {
                    _ = self.entries.orderedRemove(index);
                } else {
                    self.entries.items[index].value = value;
                }
                return;
            }
        }
        if (value != .nil) try self.entries.append(allocator, .{ .key = normalized, .value = value });
    }

    fn len(self: *CTable) lua_Integer {
        var result: lua_Integer = 0;
        while (true) {
            const next_index = result + 1;
            if (self.get(.{ .integer = next_index }) == .nil) return result;
            result = next_index;
        }
    }

    fn next(self: *CTable, key: Value) ?TableEntry {
        var start: usize = 0;
        if (key != .nil) {
            const normalized = normalizeKey(key) orelse return null;
            for (self.entries.items, 0..) |entry, index| {
                if (entry.value != .nil and valuesEqual(entry.key, normalized)) {
                    start = index + 1;
                    break;
                }
            } else return null;
        }
        for (self.entries.items[start..]) |entry| {
            if (entry.value != .nil) return entry;
        }
        return null;
    }
};

const CUserdata = struct {
    bytes: []u8,
    size: usize,
    uservalues: []Value,
    metatable: ?*CTable = null,
    finalized: bool = false,
    marked: bool = false,

    fn create(allocator: std.mem.Allocator, size: usize, uservalue_count: usize) !*CUserdata {
        const userdata = try allocator.create(CUserdata);
        errdefer allocator.destroy(userdata);
        const bytes = try allocator.alloc(u8, @max(size, 1));
        errdefer allocator.free(bytes);
        const uservalues = try allocator.alloc(Value, uservalue_count);
        errdefer allocator.free(uservalues);
        for (uservalues) |*value| value.* = .nil;
        userdata.* = .{
            .bytes = bytes,
            .size = size,
            .uservalues = uservalues,
        };
        return userdata;
    }

    fn deinit(self: *CUserdata, allocator: std.mem.Allocator) void {
        allocator.free(self.uservalues);
        allocator.free(self.bytes);
        allocator.destroy(self);
    }
};

const LuaStateHeader = extern struct {
    thread: *CThread,
};

const CThread = struct {
    owner: *CState,
    public_state: *LuaStateHeader,
    owned_block: ?*StateBlock = null,
    runtime_thread: ?*runtime.Thread = null,
    stack: std.ArrayList(Value) = .empty,
    to_close_slots: std.ArrayList(usize) = .empty,
    status: c_int = 0,
    started: bool = false,
    running: bool = false,
    dead: bool = false,
    resume_result_count: usize = 0,
    pending_error: ?Value = null,
    pending_yield: ?PendingYield = null,
    continuation: ?CContinuation = null,
    current_c_closure: ?*runtime.CClosure = null,
    c_call_depth: usize = 0,
    yieldable_call_depth: usize = 0,
    c_frames: std.ArrayList(CCallFrame) = .empty,
    debug_hook: lua_Hook = null,
    debug_hook_mask: c_int = 0,
    debug_hook_count: c_int = 0,
    debug_event: DebugEvent = .{},

    fn deinit(self: *CThread) void {
        self.c_frames.deinit(self.owner.allocator());
        self.to_close_slots.deinit(self.owner.allocator());
        self.stack.deinit(self.owner.allocator());
    }
};

const CCallFrame = struct {
    closure: *runtime.CClosure,
    base: usize,
    arg_count: usize,
};

const DebugEvent = struct {
    event: c_int = LUA_HOOKCALL,
    currentline: c_int = -1,
    ftransfer: c_int = 0,
    ntransfer: c_int = 0,
};

const PendingYield = struct {
    values: []Value,
    result_count: usize,
    ctx: lua_KContext,
    k: lua_KFunction,
};

const CContinuation = struct {
    ctx: lua_KContext,
    k: *const fn (?*lua_State, c_int, lua_KContext) callconv(.c) c_int,
};

const StateBlock = extern struct {
    extraspace: [LUA_EXTRASPACE]u8 = .{0} ** LUA_EXTRASPACE,
    header: LuaStateHeader,
};

comptime {
    std.debug.assert(@offsetOf(StateBlock, "header") == LUA_EXTRASPACE);
}

const CState = struct {
    alloc_f: lua_Alloc,
    alloc_ud: ?*anyopaque,
    block: *StateBlock,
    runtime_state: runtime.State,
    main_thread: CThread,
    registry_table: *CTable,
    global_table: *CTable,
    strings: std.ArrayList(*CString) = .empty,
    tables: std.ArrayList(*CTable) = .empty,
    userdata: std.ArrayList(*CUserdata) = .empty,
    threads: std.ArrayList(*CThread) = .empty,
    panicf: lua_CFunction = null,
    warnf: lua_WarnFunction = null,
    warn_ud: ?*anyopaque = null,

    fn allocator(self: *CState) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &lua_allocator_vtable };
    }

    fn deinitOwnedObjects(self: *CState) void {
        const alloc = self.allocator();
        for (self.tables.items) |table| table.deinit(alloc);
        for (self.userdata.items) |userdata| userdata.deinit(alloc);
        for (self.strings.items) |string| string.deinit(alloc);
        self.tables.deinit(alloc);
        self.userdata.deinit(alloc);
        self.strings.deinit(alloc);
        self.threads.deinit(alloc);
    }
};

const lua_allocator_vtable = std.mem.Allocator.VTable{
    .alloc = luaAllocatorAlloc,
    .resize = luaAllocatorResize,
    .remap = luaAllocatorRemap,
    .free = luaAllocatorFree,
};

fn luaAllocatorAlloc(ctx: *anyopaque, len: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
    const state: *CState = @ptrCast(@alignCast(ctx));
    const alloc_f = state.alloc_f orelse return null;
    const ptr = alloc_f(state.alloc_ud, null, 0, len) orelse return null;
    return @ptrCast(ptr);
}

fn luaAllocatorResize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
    return false;
}

fn luaAllocatorRemap(ctx: *anyopaque, memory: []u8, _: std.mem.Alignment, new_len: usize, _: usize) ?[*]u8 {
    const state: *CState = @ptrCast(@alignCast(ctx));
    const alloc_f = state.alloc_f orelse return null;
    const ptr = alloc_f(state.alloc_ud, memory.ptr, memory.len, new_len) orelse return null;
    return @ptrCast(ptr);
}

fn luaAllocatorFree(ctx: *anyopaque, memory: []u8, _: std.mem.Alignment, _: usize) void {
    const state: *CState = @ptrCast(@alignCast(ctx));
    const alloc_f = state.alloc_f orelse return;
    _ = alloc_f(state.alloc_ud, memory.ptr, memory.len, 0);
}

fn zstr(comptime value: [:0]const u8) [*:0]const u8 {
    return value.ptr;
}

fn threadFromState(L: ?*lua_State) ?*CThread {
    const raw = L orelse return null;
    const header: *LuaStateHeader = @ptrCast(@alignCast(raw));
    return header.thread;
}

fn stateFromThread(L: ?*lua_State) ?*CState {
    const thread = threadFromState(L) orelse return null;
    return thread.owner;
}

fn allocateHost(comptime T: type, alloc_f: lua_Alloc, ud: ?*anyopaque) ?*T {
    const f = alloc_f orelse return null;
    const raw = f(ud, null, 0, @sizeOf(T)) orelse return null;
    return @ptrCast(@alignCast(raw));
}

fn freeHost(comptime T: type, alloc_f: lua_Alloc, ud: ?*anyopaque, ptr: *T) void {
    const f = alloc_f orelse return;
    _ = f(ud, ptr, @sizeOf(T), 0);
}

fn pushValue(thread: *CThread, value: Value) bool {
    thread.stack.append(thread.owner.allocator(), value) catch return false;
    return true;
}

fn ensureStack(thread: *CThread, extra: usize) bool {
    thread.stack.ensureUnusedCapacity(thread.owner.allocator(), extra) catch return false;
    return true;
}

fn stackAbsIndex(thread: *CThread, idx: c_int) ?usize {
    if (idx > 0) {
        const index: usize = @intCast(idx - 1);
        return if (index < thread.stack.items.len) index else null;
    }
    if (idx < 0 and idx > LUA_REGISTRYINDEX) {
        const top: isize = @intCast(thread.stack.items.len);
        const absolute = top + @as(isize, @intCast(idx));
        if (absolute < 0) return null;
        const index: usize = @intCast(absolute);
        return if (index < thread.stack.items.len) index else null;
    }
    return null;
}

fn stackSlot(thread: *CThread, idx: c_int) ?*Value {
    const index = stackAbsIndex(thread, idx) orelse return null;
    return &thread.stack.items[index];
}

fn valueAt(thread: *CThread, idx: c_int) ?Value {
    if (idx == LUA_REGISTRYINDEX) return .{ .table = thread.owner.registry_table };
    if (upvaluePseudoIndex(idx)) |upvalue_index| {
        const closure = thread.current_c_closure orelse return null;
        if (upvalue_index >= closure.upvalues.len) return null;
        return runtimeToCValue(thread.owner, closure.upvalues[upvalue_index].value, 0) catch null;
    }
    return if (stackSlot(thread, idx)) |slot| slot.* else null;
}

const DebugFrameKind = enum(u8) {
    runtime = 1,
    c = 2,
};

const DebugFrameRef = struct {
    kind: DebugFrameKind,
    index: usize,
};

fn debugFrameHandle(frame: DebugFrameRef) ?*anyopaque {
    const kind_part = @as(usize, @intFromEnum(frame.kind)) << (@bitSizeOf(usize) - 8);
    return @ptrFromInt(kind_part | (frame.index + 1));
}

fn debugFrameFromHandle(handle: ?*anyopaque) ?DebugFrameRef {
    const raw = @intFromPtr(handle orelse return null);
    if (raw == 0) return null;
    const kind_raw = raw >> (@bitSizeOf(usize) - 8);
    const kind: DebugFrameKind = switch (kind_raw) {
        1 => .runtime,
        2 => .c,
        else => return null,
    };
    const mask = (@as(usize, 1) << (@bitSizeOf(usize) - 8)) - 1;
    const encoded_index = raw & mask;
    if (encoded_index == 0) return null;
    return .{ .kind = kind, .index = encoded_index - 1 };
}

fn typeAt(thread: *CThread, idx: c_int) c_int {
    return if (valueAt(thread, idx)) |value| value.typeTag() else LUA_TNONE;
}

fn setTop(thread: *CThread, idx: c_int) void {
    const current = thread.stack.items.len;
    const new_top: usize = if (idx >= 0) @intCast(idx) else blk: {
        const relative = @as(isize, @intCast(current)) + @as(isize, @intCast(idx)) + 1;
        break :blk if (relative <= 0) 0 else @intCast(relative);
    };

    if (new_top <= current) {
        closeToCloseSlots(thread, new_top, current);
        thread.stack.items.len = new_top;
        return;
    }

    const extra = new_top - current;
    if (!ensureStack(thread, extra)) return;
    for (0..extra) |_| thread.stack.appendAssumeCapacity(.nil);
}

fn createString(state: *CState, bytes: []const u8) ?*CString {
    const allocator = state.allocator();
    const storage = allocator.allocSentinel(u8, bytes.len, 0) catch return null;
    @memcpy(storage[0..bytes.len], bytes);
    const string = allocator.create(CString) catch {
        allocator.free(storage);
        return null;
    };
    string.* = .{ .bytes = storage };
    state.strings.append(allocator, string) catch {
        string.deinit(allocator);
        return null;
    };
    return string;
}

fn createExternalString(state: *CState, bytes: [:0]const u8, alloc_f: lua_Alloc, ud: ?*anyopaque) ?*CString {
    const allocator = state.allocator();
    const string = allocator.create(CString) catch return null;
    string.* = .{ .bytes = bytes, .external = true, .external_alloc_f = alloc_f, .external_ud = ud };
    state.strings.append(allocator, string) catch {
        allocator.destroy(string);
        return null;
    };
    return string;
}

fn destroyCString(state: *CState, string: *CString) void {
    const allocator = state.allocator();
    for (state.strings.items, 0..) |candidate, index| {
        if (candidate == string) {
            _ = state.strings.orderedRemove(index);
            break;
        }
    }
    string.deinit(allocator);
}

fn pushStringBytes(thread: *CThread, bytes: []const u8) ?*CString {
    const string = createString(thread.owner, bytes) orelse return null;
    if (!pushValue(thread, .{ .string = string })) return null;
    return string;
}

fn debugString(state: *CState, bytes: []const u8) ?[*:0]const u8 {
    return (createString(state, bytes) orelse return null).bytes.ptr;
}

fn emptyDebug() lua_Debug {
    return .{
        .event = LUA_HOOKCALL,
        .name = null,
        .namewhat = zstr(""),
        .what = zstr(""),
        .source = null,
        .srclen = 0,
        .currentline = -1,
        .linedefined = -1,
        .lastlinedefined = -1,
        .nups = 0,
        .nparams = 0,
        .isvararg = 0,
        .extraargs = 0,
        .istailcall = 0,
        .ftransfer = 0,
        .ntransfer = 0,
        .short_src = .{0} ** LUA_IDSIZE,
        .i_ci = null,
    };
}

fn setShortSource(ar: *lua_Debug, source: []const u8) void {
    @memset(&ar.short_src, 0);
    if (source.len == 0) return;
    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.heap.page_allocator);
    if (source[0] == '=') {
        out.appendSlice(std.heap.page_allocator, source[1..@min(source.len, LUA_IDSIZE)]) catch return;
    } else if (source[0] == '@') {
        const path = source[1..];
        if (source.len <= LUA_IDSIZE) {
            out.appendSlice(std.heap.page_allocator, path) catch return;
        } else {
            out.appendSlice(std.heap.page_allocator, "...") catch return;
            out.appendSlice(std.heap.page_allocator, path[path.len - (LUA_IDSIZE - 3) ..]) catch return;
        }
    } else {
        const prefix = "[string \"";
        const suffix = "\"]";
        const room = LUA_IDSIZE - prefix.len - suffix.len - 1;
        const newline = std.mem.indexOfScalar(u8, source, '\n');
        var end = @min(newline orelse source.len, room);
        if (source.len >= room or newline != null) end = @min(end, room - 3);
        out.appendSlice(std.heap.page_allocator, prefix) catch return;
        out.appendSlice(std.heap.page_allocator, source[0..end]) catch return;
        if (source.len >= room or newline != null) out.appendSlice(std.heap.page_allocator, "...") catch return;
        out.appendSlice(std.heap.page_allocator, suffix) catch return;
    }
    const len = @min(out.items.len, LUA_IDSIZE - 1);
    @memcpy(ar.short_src[0..len], out.items[0..len]);
}

fn createTable(state: *CState, array_hint: c_int, record_hint: c_int) ?*CTable {
    const allocator = state.allocator();
    const table = CTable.create(allocator, array_hint, record_hint) catch return null;
    state.tables.append(allocator, table) catch {
        table.deinit(allocator);
        return null;
    };
    return table;
}

fn createUserdata(state: *CState, size: usize, uservalue_count: usize) ?*CUserdata {
    const allocator = state.allocator();
    const userdata = CUserdata.create(allocator, size, uservalue_count) catch return null;
    state.userdata.append(allocator, userdata) catch {
        userdata.deinit(allocator);
        return null;
    };
    return userdata;
}

fn createThread(parent: *CThread) ?*CThread {
    const state = parent.owner;
    const allocator = state.allocator();
    const block = allocator.create(StateBlock) catch return null;
    const thread = allocator.create(CThread) catch {
        allocator.destroy(block);
        return null;
    };
    block.* = .{ .header = .{ .thread = thread } };
    thread.* = .{ .owner = state, .public_state = &block.header, .owned_block = block };
    if (!ensureStack(thread, LUA_MINSTACK)) {
        thread.deinit();
        allocator.destroy(thread);
        allocator.destroy(block);
        return null;
    }
    state.threads.append(allocator, thread) catch {
        thread.deinit();
        allocator.destroy(thread);
        allocator.destroy(block);
        return null;
    };
    return thread;
}

fn destroyThread(state: *CState, thread: *CThread) void {
    const allocator = state.allocator();
    if (thread.pending_yield) |pending| allocator.free(pending.values);
    thread.deinit();
    if (thread.owned_block) |block| allocator.destroy(block);
    allocator.destroy(thread);
}

fn collectTopValues(thread: *CThread, count: usize) ?[]Value {
    if (count > thread.stack.items.len) return null;
    const start = thread.stack.items.len - count;
    const values = thread.owner.allocator().dupe(Value, thread.stack.items[start..]) catch return null;
    thread.stack.items.len = start;
    return values;
}

fn topValueSlice(thread: *CThread, count: usize) []Value {
    if (count > thread.stack.items.len) return thread.stack.items;
    return thread.stack.items[thread.stack.items.len - count ..];
}

fn replaceStack(thread: *CThread, values: []const Value) bool {
    thread.stack.clearRetainingCapacity();
    thread.stack.appendSlice(thread.owner.allocator(), values) catch return false;
    return true;
}

fn canYield(thread: *CThread) bool {
    return thread != &thread.owner.main_thread and thread.running and (thread.c_call_depth == 1 or thread.yieldable_call_depth != 0);
}

fn installYieldContinuation(thread: *CThread, ctx: lua_KContext, k: lua_KFunction) bool {
    const result_count = thread.resume_result_count;
    const values = thread.owner.allocator().dupe(Value, topValueSlice(thread, result_count)) catch return false;
    thread.pending_yield = .{ .values = values, .result_count = result_count, .ctx = ctx, .k = k };
    return true;
}

fn findThreadForRuntime(state: *CState, target: *runtime.Thread) ?*CThread {
    if (state.main_thread.runtime_thread == target) return &state.main_thread;
    for (state.threads.items) |thread| {
        if (thread.runtime_thread == target) return thread;
    }
    return null;
}

fn findUserdataByPtr(state: *CState, ptr: *anyopaque) ?*CUserdata {
    for (state.userdata.items) |userdata| {
        if (userdata.bytes.ptr == @as([*]u8, @ptrCast(ptr))) return userdata;
    }
    return null;
}

fn applyDebugHook(thread: *CThread, target: *runtime.Thread) void {
    if (thread.debug_hook == null or thread.debug_hook_mask == 0) {
        thread.owner.runtime_state.setThreadHook(target, .nil, "", 0);
        return;
    }
    thread.owner.runtime_state.setThreadHook(target, .{ .boolean = true }, maskString(thread.debug_hook_mask), @intCast(@max(thread.debug_hook_count, 0)));
}

fn maskString(mask: c_int) []const u8 {
    if ((mask & LUA_MASKCALL) != 0 and (mask & LUA_MASKRET) != 0 and (mask & LUA_MASKLINE) != 0) return "crl";
    if ((mask & LUA_MASKCALL) != 0 and (mask & LUA_MASKRET) != 0) return "cr";
    if ((mask & LUA_MASKCALL) != 0 and (mask & LUA_MASKLINE) != 0) return "cl";
    if ((mask & LUA_MASKRET) != 0 and (mask & LUA_MASKLINE) != 0) return "rl";
    if ((mask & LUA_MASKCALL) != 0) return "c";
    if ((mask & LUA_MASKRET) != 0) return "r";
    if ((mask & LUA_MASKLINE) != 0) return "l";
    return "";
}

fn normalizeKey(value: Value) ?Value {
    return switch (value) {
        .nil => null,
        .number => |number| if (floatToInteger(number)) |integer| .{ .integer = integer } else value,
        else => value,
    };
}

fn valuesEqual(lhs: Value, rhs: Value) bool {
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
        .string => |value| rhs == .string and std.mem.eql(u8, value.bytes, rhs.string.bytes),
        .table => |value| rhs == .table and value == rhs.table,
        .userdata => |value| rhs == .userdata and value == rhs.userdata,
        .thread => |value| rhs == .thread and value == rhs.thread,
        .light_userdata => |value| rhs == .light_userdata and value == rhs.light_userdata,
        .lua_closure => |value| rhs == .lua_closure and value == rhs.lua_closure,
        .c_closure => |value| rhs == .c_closure and value == rhs.c_closure,
        .runtime_native => |value| rhs == .runtime_native and runtime.valuesEqual(value, rhs.runtime_native),
    };
}

fn cStringSlice(s: ?[*:0]const u8) []const u8 {
    const ptr = s orelse return &.{};
    return std.mem.span(ptr);
}

fn initBufferPtr(B: *luaL_Buffer) [*]u8 {
    return @ptrCast(&B.init.b);
}

fn functionId(function: lua_CFunction) usize {
    return if (function) |ptr| @intFromPtr(ptr) else 0;
}

fn functionFromId(id: usize) lua_CFunction {
    return if (id == 0) null else @ptrFromInt(id);
}

fn upvaluePseudoIndex(idx: c_int) ?usize {
    if (idx >= LUA_REGISTRYINDEX) return null;
    const raw = LUA_REGISTRYINDEX - idx;
    if (raw <= 0) return null;
    return @intCast(raw - 1);
}

fn readRuntimeUpvalue(upvalue: *runtime.Upvalue) runtime.Value {
    return if (upvalue.is_open) upvalue.owner.stack.items[upvalue.stack_index] else upvalue.closed;
}

fn writeRuntimeUpvalue(upvalue: *runtime.Upvalue, value: runtime.Value) void {
    if (upvalue.is_open) {
        upvalue.owner.stack.items[upvalue.stack_index] = value;
    } else {
        upvalue.closed = value;
    }
}

fn stringLikeBytes(thread: *CThread, value: Value) ?[]const u8 {
    switch (value) {
        .string => |string| return string.bytes,
        .integer, .number => {
            var out = std.ArrayList(u8).empty;
            defer out.deinit(thread.owner.allocator());
            appendValueString(thread.owner.allocator(), &out, value) catch return null;
            const string = createString(thread.owner, out.items) orelse return null;
            return string.bytes;
        },
        else => return null,
    }
}

fn appendValueString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void {
    switch (value) {
        .string => |string| try out.appendSlice(allocator, string.bytes),
        .integer => |integer| try appendFmt(out, allocator, "{d}", .{integer}),
        .number => |number| {
            try appendFmt(out, allocator, "{d}", .{number});
            if (@floor(number) == number and std.math.isFinite(number)) try out.appendSlice(allocator, ".0");
        },
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |boolean| try out.appendSlice(allocator, if (boolean) "true" else "false"),
        .table => |table| try appendFmt(out, allocator, "table: 0x{x}", .{@intFromPtr(table)}),
        .userdata => |userdata| try appendFmt(out, allocator, "userdata: 0x{x}", .{@intFromPtr(userdata.bytes.ptr)}),
        .thread => |target| try appendFmt(out, allocator, "thread: 0x{x}", .{@intFromPtr(target)}),
        .light_userdata => |ptr| try appendFmt(out, allocator, "userdata: 0x{x}", .{@intFromPtr(ptr)}),
        .lua_closure, .c_closure, .runtime_native => try out.appendSlice(allocator, "function"),
    }
}

fn appendCNumberString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !bool {
    switch (value) {
        .integer => |integer| {
            try appendFmt(out, allocator, "{d}", .{integer});
            return true;
        },
        .number => |number| {
            try appendFmt(out, allocator, "{d}", .{number});
            if (@floor(number) == number and std.math.isFinite(number)) try out.appendSlice(allocator, ".0");
            return true;
        },
        else => return false,
    }
}

fn appendFmt(out: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

fn toNumberValue(value: Value) ?lua_Number {
    return switch (value) {
        .integer => |integer| @floatFromInt(integer),
        .number => |number| number,
        .string => |string| parseLuaNumber(string.bytes).number,
        else => null,
    };
}

fn toIntegerValue(value: Value) ?lua_Integer {
    return switch (value) {
        .integer => |integer| integer,
        .number => |number| floatToInteger(number),
        .string => |string| blk: {
            const parsed = parseLuaNumber(string.bytes);
            if (parsed.integer) |integer| break :blk integer;
            break :blk if (parsed.number) |number| floatToInteger(number) else null;
        },
        else => null,
    };
}

const ParsedLuaNumber = struct {
    consumed: usize = 0,
    integer: ?lua_Integer = null,
    number: ?lua_Number = null,
};

fn parseLuaNumber(text: []const u8) ParsedLuaNumber {
    const leading = trimLeftAscii(text, " \t\n\r\x0b\x0c");
    if (leading.len == 0) return .{};
    const numeral = trimRightAscii(leading, " \t\n\r\x0b\x0c");
    if (numeral.len == 0) return .{};

    if (parseLuaInteger(numeral)) |integer| {
        return .{ .consumed = text.len + 1, .integer = integer, .number = @floatFromInt(integer) };
    }
    if (parseLuaFloat(numeral)) |number| {
        return .{ .consumed = text.len + 1, .number = number };
    }
    return .{};
}

fn parseLuaInteger(numeral: []const u8) ?lua_Integer {
    if (numeral.len == 0) return null;
    var index: usize = 0;
    var negative = false;
    if (numeral[index] == '+' or numeral[index] == '-') {
        negative = numeral[index] == '-';
        index += 1;
        if (index == numeral.len) return null;
    }

    const rest = numeral[index..];
    if (rest.len >= 2 and rest[0] == '0' and (rest[1] == 'x' or rest[1] == 'X')) {
        if (rest.len == 2) return null;
        const magnitude = std.fmt.parseInt(lua_Unsigned, rest[2..], 16) catch return null;
        return unsignedMagnitudeToInteger(magnitude, negative);
    }
    return std.fmt.parseInt(lua_Integer, numeral, 10) catch null;
}

fn unsignedMagnitudeToInteger(magnitude: lua_Unsigned, negative: bool) ?lua_Integer {
    const positive_max: lua_Unsigned = @intCast(std.math.maxInt(lua_Integer));
    if (!negative) {
        if (magnitude > positive_max) return null;
        return @intCast(magnitude);
    }
    const negative_limit = positive_max + 1;
    if (magnitude > negative_limit) return null;
    if (magnitude == negative_limit) return std.math.minInt(lua_Integer);
    return -@as(lua_Integer, @intCast(magnitude));
}

fn parseLuaFloat(numeral: []const u8) ?lua_Number {
    if (std.mem.indexOfAny(u8, numeral, "nN") != null) return null;
    if (isHexFloat(numeral)) return parseHexFloat(numeral);
    return std.fmt.parseFloat(lua_Number, numeral) catch null;
}

fn isHexFloat(numeral: []const u8) bool {
    var index: usize = 0;
    if (index < numeral.len and (numeral[index] == '+' or numeral[index] == '-')) index += 1;
    return index + 1 < numeral.len and numeral[index] == '0' and (numeral[index + 1] == 'x' or numeral[index + 1] == 'X');
}

fn parseHexFloat(numeral: []const u8) ?lua_Number {
    var index: usize = 0;
    var negative = false;
    if (numeral[index] == '+' or numeral[index] == '-') {
        negative = numeral[index] == '-';
        index += 1;
    }
    if (index + 1 >= numeral.len or numeral[index] != '0' or (numeral[index + 1] != 'x' and numeral[index + 1] != 'X')) return null;
    index += 2;

    var value: lua_Number = 0;
    var hex_exponent: i32 = 0;
    var significant_digits: usize = 0;
    var leading_zeroes: usize = 0;
    var seen_dot = false;
    while (index < numeral.len) : (index += 1) {
        const byte = numeral[index];
        if (byte == '.') {
            if (seen_dot) return null;
            seen_dot = true;
            continue;
        }
        const digit = hexDigitValue(byte) orelse break;
        if (significant_digits == 0 and digit == 0) {
            leading_zeroes += 1;
        } else {
            significant_digits += 1;
            if (significant_digits <= 30) {
                value = value * 16 + @as(lua_Number, @floatFromInt(digit));
            } else if (!seen_dot) {
                hex_exponent += 1;
            }
        }
        if (seen_dot) hex_exponent -= 1;
    }
    if (leading_zeroes + significant_digits == 0) return null;

    var exponent = hex_exponent * 4;
    if (index < numeral.len and (numeral[index] == 'p' or numeral[index] == 'P')) {
        index += 1;
        if (index >= numeral.len) return null;
        var exponent_negative = false;
        if (numeral[index] == '+' or numeral[index] == '-') {
            exponent_negative = numeral[index] == '-';
            index += 1;
            if (index >= numeral.len) return null;
        }
        const exponent_start = index;
        var parsed_exponent: i32 = 0;
        while (index < numeral.len) : (index += 1) {
            const digit = decimalDigitValue(numeral[index]) orelse break;
            parsed_exponent = std.math.add(i32, std.math.mul(i32, parsed_exponent, 10) catch return null, digit) catch return null;
        }
        if (index == exponent_start) return null;
        exponent = std.math.add(i32, exponent, if (exponent_negative) -parsed_exponent else parsed_exponent) catch return null;
    }
    if (index != numeral.len) return null;
    const result = std.math.ldexp(value, exponent);
    return if (negative) -result else result;
}

fn hexDigitValue(byte: u8) ?u8 {
    if (byte >= '0' and byte <= '9') return byte - '0';
    if (byte >= 'a' and byte <= 'f') return byte - 'a' + 10;
    if (byte >= 'A' and byte <= 'F') return byte - 'A' + 10;
    return null;
}

fn decimalDigitValue(byte: u8) ?i32 {
    if (byte >= '0' and byte <= '9') return byte - '0';
    return null;
}

fn floatToInteger(number: f64) ?lua_Integer {
    if (!std.math.isFinite(number) or @floor(number) != number) return null;
    const min = @as(f64, @floatFromInt(std.math.minInt(lua_Integer)));
    const max = @as(f64, @floatFromInt(std.math.maxInt(lua_Integer)));
    if (number < min or number >= max) return null;
    return @intFromFloat(number);
}

fn tableMetafield(table: *CTable, name: []const u8) Value {
    const metatable = table.metatable orelse return .nil;
    for (metatable.entries.items) |entry| {
        if (entry.key == .string and std.mem.eql(u8, entry.key.string.bytes, name)) return entry.value;
    }
    return .nil;
}

fn metatableField(value: Value, name: []const u8) Value {
    const metatable = switch (value) {
        .table => |table| table.metatable,
        .userdata => |userdata| userdata.metatable,
        else => null,
    } orelse return .nil;
    for (metatable.entries.items) |entry| {
        if (entry.key == .string and std.mem.eql(u8, entry.key.string.bytes, name)) return entry.value;
    }
    return .nil;
}

fn cValueMetatable(value: Value) ?*CTable {
    return switch (value) {
        .table => |table| table.metatable,
        .userdata => |userdata| userdata.metatable,
        else => null,
    };
}

fn rawTableGetString(state: *CState, table: *CTable, key: []const u8) Value {
    const key_string = createString(state, key) orelse return .nil;
    return table.get(.{ .string = key_string });
}

fn rawTableSetString(state: *CState, table: *CTable, key: []const u8, value: Value) bool {
    const key_string = createString(state, key) orelse return false;
    table.set(state.allocator(), .{ .string = key_string }, value) catch return false;
    return true;
}

fn valueToStringBytes(thread: *CThread, value: Value) ?[]const u8 {
    switch (value) {
        .string => |string| return string.bytes,
        .integer, .number => {
            var out = std.ArrayList(u8).empty;
            defer out.deinit(thread.owner.allocator());
            appendValueString(thread.owner.allocator(), &out, value) catch return null;
            const string = createString(thread.owner, out.items) orelse return null;
            return string.bytes;
        },
        .boolean => |boolean| return if (boolean) "true" else "false",
        .nil => return "nil",
        .light_userdata => return "light userdata",
        .table => return "table",
        .userdata => return "userdata",
        .thread => return "thread",
        .lua_closure, .c_closure, .runtime_native => return "function",
    }
}

fn auxTypeName(thread: *CThread, idx: c_int) []const u8 {
    const value = valueAt(thread, idx) orelse return "no value";
    if (value == .light_userdata) return "light userdata";
    const name_value = metatableField(value, "__name");
    if (name_value == .string) return name_value.string.bytes;
    return std.mem.span(lua_typename(@ptrCast(thread.public_state), value.typeTag()));
}

fn getTable(thread: *CThread, table: *CTable, key: Value, depth: usize) Value {
    const value = table.get(key);
    if (value != .nil) return value;
    if (depth >= 15) return .nil;
    return switch (tableMetafield(table, "__index")) {
        .table => |index_table| getTable(thread, index_table, key, depth + 1),
        else => .nil,
    };
}

fn setTable(thread: *CThread, table: *CTable, key: Value, value: Value, depth: usize) void {
    const allocator = thread.owner.allocator();
    if (table.get(key) != .nil or depth >= 15) {
        table.set(allocator, key, value) catch return;
        return;
    }
    switch (tableMetafield(table, "__newindex")) {
        .table => |newindex_table| setTable(thread, newindex_table, key, value, depth + 1),
        else => table.set(allocator, key, value) catch return,
    }
}

fn cToRuntimeValue(state: *CState, value: Value, depth: usize) !runtime.Value {
    if (depth > 16) return .nil;
    return switch (value) {
        .nil => .nil,
        .boolean => |boolean| .{ .boolean = boolean },
        .integer => |integer| .{ .integer = @intCast(integer) },
        .number => |number| .{ .number = number },
        .string => |string| .{ .string = try state.runtime_state.intern(string.bytes) },
        .lua_closure => |closure| .{ .closure = closure },
        .table => |table| blk: {
            const runtime_table = (try state.runtime_state.newTableWithHints(0, @intCast(table.entries.items.len))).table;
            for (table.entries.items) |entry| {
                const key = try cToRuntimeValue(state, entry.key, depth + 1);
                const item = try cToRuntimeValue(state, entry.value, depth + 1);
                try runtime_table.set(state.runtime_state.allocator, key, item);
            }
            break :blk .{ .table = runtime_table };
        },
        .userdata => |userdata| blk: {
            const runtime_value = try state.runtime_state.newUserdata(@ptrCast(userdata.bytes.ptr), 0, "userdata", null, null, null);
            break :blk runtime_value;
        },
        .c_closure => |closure| .{ .c_closure = closure },
        .runtime_native => |native| native,
        .thread, .light_userdata => .nil,
    };
}

fn runtimeToCValue(state: *CState, value: runtime.Value, depth: usize) !Value {
    if (depth > 16) return .nil;
    return switch (value) {
        .nil => .nil,
        .boolean => |boolean| .{ .boolean = boolean },
        .integer => |integer| .{ .integer = @intCast(integer) },
        .number => |number| .{ .number = number },
        .string => |string| .{ .string = createString(state, string) orelse return error.OutOfMemory },
        .closure => |closure| .{ .lua_closure = closure },
        .c_closure => |closure| .{ .c_closure = closure },
        .table => |table| blk: {
            const c_table = createTable(state, @intCast(table.array.items.len), @intCast(table.entries.items.len)) orelse return error.OutOfMemory;
            for (table.array.items, 0..) |item, index| {
                if (item == .nil) continue;
                try c_table.set(state.allocator(), .{ .integer = @intCast(index + 1) }, try runtimeToCValue(state, item, depth + 1));
            }
            for (table.entries.items) |entry| {
                if (entry.value == .nil) continue;
                try c_table.set(
                    state.allocator(),
                    try runtimeToCValue(state, entry.key, depth + 1),
                    try runtimeToCValue(state, entry.value, depth + 1),
                );
            }
            break :blk .{ .table = c_table };
        },
        .thread => .nil,
        .userdata => |userdata| if (findUserdataByPtr(state, userdata.ptr)) |c_userdata| .{ .userdata = c_userdata } else .nil,
        .coroutine_wrapper => .nil,
        .gmatch_iterator => .nil,
        else => .{ .runtime_native = value },
    };
}

fn pushRuntimeError(thread: *CThread) void {
    const value = runtimeToCValue(thread.owner, thread.owner.runtime_state.currentErrorValue(), 0) catch .nil;
    _ = pushValue(thread, value);
}

fn syncRuntimeGlobalsToC(state: *CState) void {
    var globals = state.runtime_state.globals.iterator();
    while (globals.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "_G")) continue;
        const key = createString(state, entry.key_ptr.*) orelse continue;
        const value = runtimeToCValue(state, entry.value_ptr.*, 0) catch continue;
        state.global_table.set(state.allocator(), .{ .string = key }, value) catch continue;
    }
    const runtime_globals = state.runtime_state.global_table orelse return;
    for (runtime_globals.entries.items) |entry| {
        if (entry.key != .string or std.mem.eql(u8, entry.key.string, "_G")) continue;
        const key = createString(state, entry.key.string) orelse continue;
        const value = runtimeToCValue(state, entry.value, 0) catch continue;
        state.global_table.set(state.allocator(), .{ .string = key }, value) catch continue;
    }
}

fn syncCGlobalToRuntime(state: *CState, name: []const u8, value: Value) void {
    const key = state.runtime_state.intern(name) catch return;
    const runtime_value = cToRuntimeValue(state, value, 0) catch return;
    state.runtime_state.putGlobal(key, runtime_value) catch return;
}

fn loadBuffer(thread: *CThread, source: []const u8, source_name: ?[]const u8, mode: ?[]const u8) c_int {
    const accepts_binary = mode == null or std.mem.indexOfScalar(u8, mode.?, 'b') != null;
    const accepts_text = mode == null or std.mem.indexOfScalar(u8, mode.?, 't') != null;
    const is_binary = std.mem.startsWith(u8, source, runtime.binary_chunk_signature);
    if ((is_binary and !accepts_binary) or (!is_binary and !accepts_text)) {
        _ = pushStringBytes(thread, if (is_binary) "attempt to load a binary chunk" else "attempt to load a text chunk");
        return LUA_ERRSYNTAX;
    }

    const value = (if (is_binary)
        thread.owner.runtime_state.loadBinaryDump(source, thread.owner.runtime_state.getGlobal("_G"))
    else
        thread.owner.runtime_state.loadSourceAsClosureNamed(source, source_name)) catch |err| switch (err) {
        error.OutOfMemory => {
            pushRuntimeError(thread);
            return LUA_ERRMEM;
        },
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
            pushRuntimeError(thread);
            return LUA_ERRSYNTAX;
        },
    };
    const c_value = runtimeToCValue(thread.owner, value, 0) catch {
        _ = pushStringBytes(thread, "not enough memory");
        return LUA_ERRMEM;
    };
    _ = pushValue(thread, c_value);
    return LUA_OK;
}

fn finishCallResults(thread: *CThread, base: usize, results: []const Value, nresults: c_int) void {
    thread.stack.items.len = base;
    const wanted: usize = if (nresults == LUA_MULTRET) results.len else @intCast(@max(nresults, 0));
    for (0..wanted) |index| {
        _ = pushValue(thread, if (index < results.len) results[index] else .nil);
    }
}

const CCallbackResult = union(enum) {
    success: []Value,
    failure: Value,
    yielded,
    memory_error,
};

fn runCClosure(thread: *CThread, closure: *runtime.CClosure, args: []const Value, protected: bool) CCallbackResult {
    const allocator = thread.owner.allocator();
    const saved = allocator.dupe(Value, thread.stack.items) catch return .memory_error;
    defer allocator.free(saved);
    const call_args = allocator.dupe(Value, args) catch return .memory_error;
    defer allocator.free(call_args);

    thread.stack.clearRetainingCapacity();
    thread.stack.appendSlice(allocator, call_args) catch return .memory_error;
    thread.pending_error = null;
    const previous_closure = thread.current_c_closure;
    thread.current_c_closure = closure;
    const frame_index = thread.c_frames.items.len;
    thread.c_frames.append(allocator, .{ .closure = closure, .base = 0, .arg_count = call_args.len }) catch return .memory_error;
    thread.c_call_depth += 1;
    defer {
        thread.c_call_depth -= 1;
        _ = thread.c_frames.pop();
        thread.current_c_closure = previous_closure;
    }
    callCDebugHook(thread, .{ .event = LUA_HOOKCALL, .ftransfer = 1, .ntransfer = @intCast(call_args.len) }, frame_index);
    const function = functionFromId(closure.function_id);
    const returned = if (function) |func| func(@ptrCast(thread.public_state)) else 0;
    if (thread.pending_yield) |pending| {
        thread.pending_yield = null;
        const yield_stack = allocator.dupe(Value, thread.stack.items) catch {
            allocator.free(pending.values);
            thread.stack.clearRetainingCapacity();
            thread.stack.appendSlice(allocator, saved) catch {};
            return .memory_error;
        };
        defer allocator.free(yield_stack);
        thread.stack.clearRetainingCapacity();
        thread.stack.appendSlice(allocator, yield_stack) catch {
            allocator.free(pending.values);
            thread.stack.appendSlice(allocator, saved) catch {};
            return .memory_error;
        };
        allocator.free(pending.values);
        thread.resume_result_count = pending.result_count;
        thread.continuation = if (pending.k) |k| .{ .ctx = pending.ctx, .k = k } else null;
        thread.status = LUA_YIELD;
        thread.running = false;
        return .yielded;
    }
    const pending = thread.pending_error;
    thread.pending_error = null;

    if (pending) |err_value| {
        thread.stack.clearRetainingCapacity();
        thread.stack.appendSlice(allocator, saved) catch return .memory_error;
        if (protected) return .{ .failure = err_value };
        _ = pushValue(thread, err_value);
        raiseUnprotected(thread);
    }

    const raw_count = @max(returned, 0);
    const count: usize = @min(@as(usize, @intCast(raw_count)), thread.stack.items.len);
    const start = thread.stack.items.len - count;
    const results = allocator.dupe(Value, thread.stack.items[start..]) catch return .memory_error;
    callCDebugHook(thread, .{ .event = LUA_HOOKRET, .ftransfer = @intCast(start + 1), .ntransfer = @intCast(results.len) }, frame_index);
    thread.stack.clearRetainingCapacity();
    thread.stack.appendSlice(allocator, saved) catch {
        allocator.free(results);
        return .memory_error;
    };
    return .{ .success = results };
}

fn callCClosure(thread: *CThread, closure: *runtime.CClosure, args: []const Value, nresults: c_int, protected: bool) c_int {
    const base = thread.stack.items.len - args.len - 1;
    const allocator = thread.owner.allocator();
    switch (runCClosure(thread, closure, args, protected)) {
        .success => |results| {
            defer allocator.free(results);
            finishCallResults(thread, base, results, nresults);
            return LUA_OK;
        },
        .failure => |err_value| {
            thread.stack.items.len = base;
            _ = pushValue(thread, err_value);
            return LUA_ERRRUN;
        },
        .yielded => return LUA_YIELD,
        .memory_error => return LUA_ERRMEM,
    }
}

fn cClosureDispatch(context: *runtime.CClosureContext) anyerror!void {
    const state: *CState = @ptrCast(@alignCast(context.user_data orelse return error.RuntimeError));
    const thread = findThreadForRuntime(state, context.thread) orelse &state.main_thread;
    const allocator = state.allocator();
    const args = try allocator.alloc(Value, context.argCount());
    defer allocator.free(args);
    for (args, 0..) |*arg, index| arg.* = try runtimeToCValue(state, context.argValue(index), 0);

    const previous_runtime_thread = thread.runtime_thread;
    thread.runtime_thread = context.thread;
    defer thread.runtime_thread = previous_runtime_thread;

    switch (runCClosure(thread, context.closure, args, true)) {
        .success => |results| {
            defer allocator.free(results);
            for (results) |result| try context.appendReturn(try cToRuntimeValue(state, result, 0));
        },
        .failure => |err_value| return context.raise(try cToRuntimeValue(state, err_value, 0)),
        .yielded => {
            const yielded = topValueSlice(thread, thread.resume_result_count);
            const values = try allocator.alloc(runtime.Value, yielded.len);
            defer allocator.free(values);
            for (values, 0..) |*value, index| value.* = try cToRuntimeValue(state, yielded[index], 0);
            try context.yieldWithReturns(values);
        },
        .memory_error => return error.OutOfMemory,
    }
}

fn cClosureResumeDispatch(context: *runtime.CClosureResumeContext) anyerror!void {
    const state: *CState = @ptrCast(@alignCast(context.user_data orelse return error.RuntimeError));
    const thread = findThreadForRuntime(state, context.thread) orelse return error.RuntimeError;
    const allocator = state.allocator();
    const c_args = try allocator.alloc(Value, context.args.len);
    defer allocator.free(c_args);
    for (c_args, 0..) |*arg, index| arg.* = try runtimeToCValue(state, context.args[index], 0);
    if (!replaceStack(thread, c_args)) return error.OutOfMemory;

    switch (runContinuation(thread, @intCast(c_args.len))) {
        LUA_OK => {
            for (thread.stack.items) |value| try context.appendReturn(try cToRuntimeValue(state, value, 0));
        },
        LUA_YIELD => {
            const yielded = topValueSlice(thread, thread.resume_result_count);
            const values = try allocator.alloc(runtime.Value, yielded.len);
            defer allocator.free(values);
            for (values, 0..) |*value, index| value.* = try cToRuntimeValue(state, yielded[index], 0);
            try context.yieldWithReturns(values);
        },
        else => {
            const err_value = if (thread.stack.items.len == 0) Value.nil else thread.stack.items[thread.stack.items.len - 1];
            return context.raise(try cToRuntimeValue(state, err_value, 0));
        },
    }
}

fn cDebugHookDispatch(context: *runtime.CDebugHookContext) anyerror!void {
    const state: *CState = @ptrCast(@alignCast(context.user_data orelse return));
    const thread = findThreadForRuntime(state, context.thread) orelse return;
    const hook = thread.debug_hook orelse return;
    thread.debug_event = .{
        .event = switch (context.event) {
            .call => LUA_HOOKCALL,
            .ret => LUA_HOOKRET,
            .line => LUA_HOOKLINE,
            .count => LUA_HOOKCOUNT,
            .tail_call => LUA_HOOKTAILCALL,
        },
        .currentline = if (context.currentline) |line| @intCast(line) else -1,
        .ftransfer = @intCast(context.ftransfer),
        .ntransfer = @intCast(context.ntransfer),
    };
    var ar = emptyDebug();
    ar.event = thread.debug_event.event;
    ar.currentline = thread.debug_event.currentline;
    ar.ftransfer = thread.debug_event.ftransfer;
    ar.ntransfer = thread.debug_event.ntransfer;
    ar.i_ci = debugFrameHandle(.{ .kind = .runtime, .index = if (context.thread.frames.items.len == 0) 0 else context.thread.frames.items.len - 1 });
    hook(@ptrCast(thread.public_state), &ar);
}

fn callCDebugHook(thread: *CThread, event: DebugEvent, frame_index: usize) void {
    const hook = thread.debug_hook orelse return;
    if (event.event == LUA_HOOKCALL and (thread.debug_hook_mask & LUA_MASKCALL) == 0) return;
    if (event.event == LUA_HOOKRET and (thread.debug_hook_mask & LUA_MASKRET) == 0) return;
    const previous = thread.debug_event;
    thread.debug_event = event;
    defer thread.debug_event = previous;
    var ar = emptyDebug();
    ar.event = event.event;
    ar.currentline = event.currentline;
    ar.ftransfer = event.ftransfer;
    ar.ntransfer = event.ntransfer;
    ar.i_ci = debugFrameHandle(.{ .kind = .c, .index = frame_index });
    hook(@ptrCast(thread.public_state), &ar);
}

fn callLuaClosure(thread: *CThread, closure: *runtime.Closure, args: []const Value, nresults: c_int, protected: bool) c_int {
    const base = thread.stack.items.len - args.len - 1;
    const allocator = thread.owner.allocator();
    const runtime_args = allocator.alloc(runtime.Value, args.len) catch return LUA_ERRMEM;
    defer allocator.free(runtime_args);
    for (args, 0..) |arg, index| runtime_args[index] = cToRuntimeValue(thread.owner, arg, 0) catch return LUA_ERRMEM;

    const runtime_thread = thread.owner.runtime_state.newCoroutine(.{ .closure = closure }) catch return LUA_ERRMEM;
    const previous_runtime_thread = thread.runtime_thread;
    thread.runtime_thread = runtime_thread;
    defer thread.runtime_thread = previous_runtime_thread;
    applyDebugHook(thread, runtime_thread);

    if (protected) {
        const result = thread.owner.runtime_state.resumeThread(runtime_thread, runtime_args) catch |err| switch (err) {
            error.OutOfMemory => return LUA_ERRMEM,
            else => {
                _ = pushStringBytes(thread, @errorName(err));
                return LUA_ERRRUN;
            },
        };
        switch (result) {
            .success => |runtime_results| {
                defer thread.owner.runtime_state.allocator.free(runtime_results);
                const c_results = allocator.alloc(Value, runtime_results.len) catch return LUA_ERRMEM;
                defer allocator.free(c_results);
                for (runtime_results, 0..) |value, index| c_results[index] = runtimeToCValue(thread.owner, value, 0) catch return LUA_ERRMEM;
                finishCallResults(thread, base, c_results, nresults);
                syncRuntimeGlobalsToC(thread.owner);
                return LUA_OK;
            },
            .failure => |failure| {
                thread.stack.items.len = base;
                _ = pushValue(thread, runtimeToCValue(thread.owner, failure, 0) catch .nil);
                return LUA_ERRRUN;
            },
        }
    }

    const result = thread.owner.runtime_state.resumeThread(runtime_thread, runtime_args) catch |err| switch (err) {
        error.OutOfMemory => {
            thread.stack.items.len = base;
            _ = pushStringBytes(thread, "not enough memory");
            raiseUnprotected(thread);
            return LUA_ERRMEM;
        },
        error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
            thread.stack.items.len = base;
            pushRuntimeError(thread);
            raiseUnprotected(thread);
            return LUA_ERRRUN;
        },
        else => {
            thread.stack.items.len = base;
            _ = pushStringBytes(thread, @errorName(err));
            raiseUnprotected(thread);
            return LUA_ERRRUN;
        },
    };
    const runtime_results = switch (result) {
        .success => |values| values,
        .failure => |failure| {
            thread.stack.items.len = base;
            _ = pushValue(thread, runtimeToCValue(thread.owner, failure, 0) catch .nil);
            raiseUnprotected(thread);
            return LUA_ERRRUN;
        },
    };
    defer thread.owner.runtime_state.allocator.free(runtime_results);
    const c_results = allocator.alloc(Value, runtime_results.len) catch return LUA_ERRMEM;
    defer allocator.free(c_results);
    for (runtime_results, 0..) |value, index| c_results[index] = runtimeToCValue(thread.owner, value, 0) catch return LUA_ERRMEM;
    finishCallResults(thread, base, c_results, nresults);
    syncRuntimeGlobalsToC(thread.owner);
    return LUA_OK;
}

fn callStackFunction(thread: *CThread, nargs: c_int, nresults: c_int, protected: bool) c_int {
    if (nargs < 0) return LUA_ERRRUN;
    const arg_count: usize = @intCast(nargs);
    if (thread.stack.items.len < arg_count + 1) return LUA_ERRRUN;
    const base = thread.stack.items.len - arg_count - 1;
    const callable = thread.stack.items[base];
    const args = thread.stack.items[base + 1 ..];
    return switch (callable) {
        .lua_closure => |closure| callLuaClosure(thread, closure, args, nresults, protected),
        .c_closure => |closure| callCClosure(thread, closure, args, nresults, protected),
        .runtime_native => |native| callRuntimeCallable(thread, native, args, nresults, protected),
        else => blk: {
            thread.stack.items.len = base;
            _ = pushStringBytes(thread, "attempt to call a non-function value");
            if (!protected) raiseUnprotected(thread);
            break :blk LUA_ERRRUN;
        },
    };
}

fn callRuntimeCallable(thread: *CThread, callable: runtime.Value, args: []const Value, nresults: c_int, protected: bool) c_int {
    const base = thread.stack.items.len - args.len - 1;
    const allocator = thread.owner.allocator();
    const runtime_args = allocator.alloc(runtime.Value, args.len) catch return LUA_ERRMEM;
    defer allocator.free(runtime_args);
    for (args, 0..) |arg, index| runtime_args[index] = cToRuntimeValue(thread.owner, arg, 0) catch return LUA_ERRMEM;

    const runtime_thread = thread.owner.runtime_state.newCoroutine(callable) catch return LUA_ERRMEM;
    const result = thread.owner.runtime_state.resumeThread(runtime_thread, runtime_args) catch |err| switch (err) {
        error.OutOfMemory => return LUA_ERRMEM,
        else => return LUA_ERRRUN,
    };
    if (!protected and result == .failure) {
        thread.stack.items.len = base;
        _ = pushValue(thread, runtimeToCValue(thread.owner, result.failure, 0) catch .nil);
        raiseUnprotected(thread);
    }

    switch (result) {
        .success => |runtime_results| {
            defer thread.owner.runtime_state.allocator.free(runtime_results);
            const c_results = allocator.alloc(Value, runtime_results.len) catch return LUA_ERRMEM;
            defer allocator.free(c_results);
            for (runtime_results, 0..) |value, index| c_results[index] = runtimeToCValue(thread.owner, value, 0) catch return LUA_ERRMEM;
            finishCallResults(thread, base, c_results, nresults);
            syncRuntimeGlobalsToC(thread.owner);
            return LUA_OK;
        },
        .failure => |failure| {
            thread.stack.items.len = base;
            _ = pushValue(thread, runtimeToCValue(thread.owner, failure, 0) catch .nil);
            return LUA_ERRRUN;
        },
    }
}

fn runtimeArgsFromTop(thread: *CThread, narg: c_int) ?[]runtime.Value {
    if (narg < 0) return null;
    const arg_count: usize = @intCast(narg);
    if (arg_count > thread.stack.items.len) return null;
    const start = thread.stack.items.len - arg_count;
    const args = thread.owner.allocator().alloc(runtime.Value, arg_count) catch return null;
    for (args, 0..) |*arg, index| arg.* = cToRuntimeValue(thread.owner, thread.stack.items[start + index], 0) catch .nil;
    return args;
}

fn finishRuntimeResume(thread: *CThread, result: runtime.ProtectedCallResult) c_int {
    const allocator = thread.owner.allocator();
    switch (result) {
        .success => |values| {
            defer thread.owner.runtime_state.allocator.free(values);
            if (thread.runtime_thread) |target| {
                if (thread.owner.runtime_state.threadWasYielded(target)) {
                    if (thread.continuation == null) {
                        const c_values = allocator.alloc(Value, values.len) catch return LUA_ERRMEM;
                        defer allocator.free(c_values);
                        for (values, 0..) |value, index| c_values[index] = runtimeToCValue(thread.owner, value, 0) catch return LUA_ERRMEM;
                        if (!replaceStack(thread, c_values)) return LUA_ERRMEM;
                        thread.resume_result_count = c_values.len;
                    }
                    thread.status = LUA_YIELD;
                    thread.running = false;
                    return LUA_YIELD;
                }
            }
            const c_values = allocator.alloc(Value, values.len) catch return LUA_ERRMEM;
            defer allocator.free(c_values);
            for (values, 0..) |value, index| c_values[index] = runtimeToCValue(thread.owner, value, 0) catch return LUA_ERRMEM;
            if (!replaceStack(thread, c_values)) return LUA_ERRMEM;
            thread.status = LUA_OK;
            thread.running = false;
            thread.dead = true;
            return LUA_OK;
        },
        .failure => |failure| {
            thread.stack.clearRetainingCapacity();
            _ = pushValue(thread, runtimeToCValue(thread.owner, failure, 0) catch .nil);
            thread.status = LUA_ERRRUN;
            thread.running = false;
            thread.dead = true;
            return LUA_ERRRUN;
        },
    }
}

fn resumeRuntimeThread(thread: *CThread, narg: c_int) c_int {
    const args = runtimeArgsFromTop(thread, narg) orelse return LUA_ERRRUN;
    defer thread.owner.allocator().free(args);
    const target = thread.runtime_thread orelse blk: {
        if (narg < 0) return LUA_ERRRUN;
        const arg_count: usize = @intCast(narg);
        if (thread.stack.items.len < arg_count + 1) return LUA_ERRRUN;
        const base = thread.stack.items.len - arg_count - 1;
        const entry = cToRuntimeValue(thread.owner, thread.stack.items[base], 0) catch return LUA_ERRMEM;
        thread.stack.items.len = base;
        const created = thread.owner.runtime_state.newCoroutine(entry) catch return LUA_ERRMEM;
        thread.runtime_thread = created;
        break :blk created;
    };
    applyDebugHook(thread, target);
    thread.started = true;
    thread.running = true;
    thread.dead = false;
    const result = thread.owner.runtime_state.resumeThread(target, args) catch |err| switch (err) {
        error.OutOfMemory => return LUA_ERRMEM,
        else => {
            thread.stack.clearRetainingCapacity();
            _ = pushStringBytes(thread, @errorName(err));
            return LUA_ERRRUN;
        },
    };
    syncRuntimeGlobalsToC(thread.owner);
    return finishRuntimeResume(thread, result);
}

fn runContinuation(thread: *CThread, narg: c_int) c_int {
    const continuation = thread.continuation orelse {
        const values = collectTopValues(thread, @intCast(@max(narg, 0))) orelse return LUA_ERRRUN;
        defer thread.owner.allocator().free(values);
        if (!replaceStack(thread, values)) return LUA_ERRMEM;
        thread.status = LUA_OK;
        thread.dead = true;
        return LUA_OK;
    };
    thread.continuation = null;
    const values = collectTopValues(thread, @intCast(@max(narg, 0))) orelse return LUA_ERRRUN;
    defer thread.owner.allocator().free(values);
    if (!replaceStack(thread, values)) return LUA_ERRMEM;

    thread.running = true;
    thread.status = LUA_OK;
    thread.c_call_depth += 1;
    const returned = continuation.k(@ptrCast(thread.public_state), LUA_YIELD, continuation.ctx);
    thread.c_call_depth -= 1;

    if (thread.pending_yield) |pending| {
        thread.pending_yield = null;
        const yield_stack = thread.owner.allocator().dupe(Value, thread.stack.items) catch {
            thread.owner.allocator().free(pending.values);
            return LUA_ERRMEM;
        };
        defer thread.owner.allocator().free(yield_stack);
        thread.stack.clearRetainingCapacity();
        thread.stack.appendSlice(thread.owner.allocator(), yield_stack) catch {
            thread.owner.allocator().free(pending.values);
            return LUA_ERRMEM;
        };
        thread.owner.allocator().free(pending.values);
        thread.resume_result_count = pending.result_count;
        thread.continuation = if (pending.k) |k| .{ .ctx = pending.ctx, .k = k } else null;
        thread.status = LUA_YIELD;
        thread.running = false;
        return LUA_YIELD;
    }
    if (thread.pending_error) |err_value| {
        thread.pending_error = null;
        thread.stack.clearRetainingCapacity();
        _ = pushValue(thread, err_value);
        thread.status = LUA_ERRRUN;
        thread.running = false;
        thread.dead = true;
        return LUA_ERRRUN;
    }

    const result_count: usize = @min(@as(usize, @intCast(@max(returned, 0))), thread.stack.items.len);
    const start = thread.stack.items.len - result_count;
    const results = thread.owner.allocator().dupe(Value, thread.stack.items[start..]) catch return LUA_ERRMEM;
    defer thread.owner.allocator().free(results);
    if (!replaceStack(thread, results)) return LUA_ERRMEM;
    thread.status = LUA_OK;
    thread.running = false;
    thread.dead = true;
    return LUA_OK;
}

fn resumeCThread(thread: *CThread, narg: c_int) c_int {
    if (thread.status == LUA_YIELD) return runContinuation(thread, narg);
    thread.started = true;
    thread.running = true;
    thread.dead = false;
    const status = callStackFunction(thread, narg, LUA_MULTRET, true);
    thread.running = false;
    switch (status) {
        LUA_OK => {
            thread.status = LUA_OK;
            thread.dead = true;
        },
        LUA_YIELD => {},
        else => {
            thread.status = status;
            thread.dead = true;
        },
    }
    return status;
}

fn applyMessageHandler(thread: *CThread, handler: Value, error_value: Value) ?Value {
    _ = pushValue(thread, handler);
    _ = pushValue(thread, error_value);
    if (callStackFunction(thread, 1, 1, true) != LUA_OK) {
        _ = thread.stack.pop();
        return null;
    }
    return thread.stack.pop();
}

fn callMetamethod(thread: *CThread, function: Value, args: []const Value) bool {
    switch (function) {
        .c_closure => |closure| {
            switch (runCClosure(thread, closure, args, true)) {
                .success => |results| {
                    thread.owner.allocator().free(results);
                    return true;
                },
                .failure => return false,
                .yielded => return false,
                .memory_error => return false,
            }
        },
        .lua_closure => {
            const saved_top = thread.stack.items.len;
            _ = pushValue(thread, function);
            for (args) |arg| _ = pushValue(thread, arg);
            const status = callStackFunction(thread, @intCast(args.len), 0, true);
            if (status != LUA_OK) {
                thread.stack.items.len = saved_top;
                return false;
            }
            return true;
        },
        else => return false,
    }
}

fn resetCMarks(state: *CState) void {
    for (state.strings.items) |string| string.marked = false;
    for (state.tables.items) |table| table.marked = false;
    for (state.userdata.items) |userdata| userdata.marked = false;
}

fn markCValue(state: *CState, value: Value) void {
    switch (value) {
        .string => |string| markCString(string),
        .table => |table| markCTable(state, table),
        .userdata => |userdata| markCUserdata(state, userdata),
        else => {},
    }
}

fn markCString(string: *CString) void {
    string.marked = true;
}

fn markCTable(state: *CState, table: *CTable) void {
    if (table.marked) return;
    table.marked = true;
    if (table.metatable) |metatable| markCTable(state, metatable);
    for (table.entries.items) |entry| {
        if (entry.value == .nil) continue;
        markCValue(state, entry.key);
        markCValue(state, entry.value);
    }
}

fn markCUserdata(state: *CState, userdata: *CUserdata) void {
    if (userdata.marked) return;
    userdata.marked = true;
    if (userdata.metatable) |metatable| markCTable(state, metatable);
    for (userdata.uservalues) |value| markCValue(state, value);
}

fn markCRoots(thread: *CThread) void {
    const state = thread.owner;
    for (state.main_thread.stack.items) |value| markCValue(state, value);
    for (state.threads.items) |child| {
        for (child.stack.items) |value| markCValue(state, value);
    }
    markCTable(state, state.registry_table);
    markCTable(state, state.global_table);
}

fn finalizeCUserdata(thread: *CThread, userdata: *CUserdata) void {
    if (userdata.finalized) return;
    const finalizer = metatableField(.{ .userdata = userdata }, "__gc");
    if (finalizer != .nil) {
        const args = [_]Value{.{ .userdata = userdata }};
        _ = callMetamethod(thread, finalizer, &args);
    }
    userdata.finalized = true;
}

fn collectCUserdata(thread: *CThread) void {
    const state = thread.owner;
    resetCMarks(state);
    markCRoots(thread);
    for (state.userdata.items) |userdata| {
        if (!userdata.marked) finalizeCUserdata(thread, userdata);
    }
    sweepCStrings(state);
}

fn sweepCStrings(state: *CState) void {
    var index: usize = 0;
    while (index < state.strings.items.len) {
        const string = state.strings.items[index];
        if (string.marked) {
            index += 1;
        } else {
            string.deinit(state.allocator());
            _ = state.strings.orderedRemove(index);
        }
    }
}

fn closeSlotAt(thread: *CThread, index: usize) void {
    if (index >= thread.stack.items.len) return;
    const value = thread.stack.items[index];
    const close_method = metatableField(value, "__close");
    if (close_method != .nil) {
        const args = [_]Value{value};
        _ = callMetamethod(thread, close_method, &args);
    }
    if (index < thread.stack.items.len) thread.stack.items[index] = .nil;
}

fn removeToCloseSlot(thread: *CThread, slot: usize) void {
    var index: usize = 0;
    while (index < thread.to_close_slots.items.len) {
        if (thread.to_close_slots.items[index] == slot) {
            _ = thread.to_close_slots.orderedRemove(index);
        } else {
            index += 1;
        }
    }
}

fn closeToCloseSlots(thread: *CThread, new_top: usize, current_top: usize) void {
    var index = thread.to_close_slots.items.len;
    while (index > 0) {
        index -= 1;
        const slot = thread.to_close_slots.items[index];
        if (slot >= new_top and slot < current_top) {
            closeSlotAt(thread, slot);
            _ = thread.to_close_slots.orderedRemove(index);
        } else if (slot >= current_top) {
            _ = thread.to_close_slots.orderedRemove(index);
        }
    }
}

fn raiseUnprotected(thread: *CThread) noreturn {
    if (thread.owner.panicf) |panicf| {
        _ = panicf(@ptrCast(thread.public_state));
    }
    std.process.exit(1);
}

pub export fn lua_newstate(alloc_f: lua_Alloc, ud: ?*anyopaque, _: c_uint) callconv(.c) ?*lua_State {
    const f = alloc_f orelse return null;

    const state = allocateHost(CState, f, ud) orelse return null;
    const block = allocateHost(StateBlock, f, ud) orelse {
        freeHost(CState, f, ud, state);
        return null;
    };

    state.* = .{
        .alloc_f = f,
        .alloc_ud = ud,
        .block = block,
        .runtime_state = undefined,
        .main_thread = undefined,
        .registry_table = undefined,
        .global_table = undefined,
    };

    block.* = .{
        .header = .{ .thread = &state.main_thread },
    };
    state.main_thread = .{ .owner = state, .public_state = &block.header };

    const allocator = state.allocator();
    state.runtime_state = runtime.State.initWithOptions(allocator, .{ .stdlib = .none }) catch {
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };
    _ = state.runtime_state.switchGcMode(.incremental);
    state.runtime_state.setCClosureDispatch(cClosureDispatch, state);
    state.runtime_state.setCClosureResumeDispatch(cClosureResumeDispatch);
    state.runtime_state.setCDebugHookDispatch(cDebugHookDispatch);
    const runtime_globals = state.runtime_state.newTableWithHints(0, 1) catch {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };
    state.runtime_state.global_table = runtime_globals.table;
    const runtime_global_name = state.runtime_state.intern("_G") catch {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };
    state.runtime_state.putGlobal(runtime_global_name, runtime_globals) catch {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };

    state.registry_table = createTable(state, 0, 3) orelse {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };

    state.global_table = createTable(state, 0, 0) orelse {
        state.deinitOwnedObjects();
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };

    state.registry_table.set(allocator, .{ .integer = 1 }, .{ .boolean = false }) catch {
        state.deinitOwnedObjects();
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };
    state.registry_table.set(allocator, .{ .integer = LUA_RIDX_GLOBALS }, .{ .table = state.global_table }) catch {
        state.deinitOwnedObjects();
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };
    state.registry_table.set(allocator, .{ .integer = LUA_RIDX_MAINTHREAD }, .{ .thread = &state.main_thread }) catch {
        state.deinitOwnedObjects();
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    };

    if (!ensureStack(&state.main_thread, LUA_MINSTACK)) {
        state.deinitOwnedObjects();
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    }
    return @ptrCast(&block.header);
}

pub export fn lua_close(L: ?*lua_State) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const state = thread.owner;
    const alloc_f = state.alloc_f;
    const alloc_ud = state.alloc_ud;
    const block = state.block;

    for (state.userdata.items) |userdata| finalizeCUserdata(thread, userdata);
    for (state.threads.items) |child| destroyThread(state, child);
    state.threads.clearRetainingCapacity();
    thread.deinit();
    state.deinitOwnedObjects();
    state.runtime_state.deinit();
    freeHost(StateBlock, alloc_f, alloc_ud, block);
    freeHost(CState, alloc_f, alloc_ud, state);
}

pub export fn lua_newthread(L: ?*lua_State) callconv(.c) ?*lua_State {
    const parent = threadFromState(L) orelse return null;
    const child = createThread(parent) orelse return null;
    _ = pushValue(parent, .{ .thread = child });
    return @ptrCast(child.public_state);
}

pub export fn lua_closethread(L: ?*lua_State, _: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_OK;
    if (thread == &thread.owner.main_thread) return LUA_OK;
    if (thread.runtime_thread) |target| {
        if (thread.owner.runtime_state.closeThread(target) catch null) |error_value| {
            thread.stack.clearRetainingCapacity();
            _ = pushValue(thread, runtimeToCValue(thread.owner, error_value, 0) catch .nil);
            thread.status = LUA_ERRRUN;
            thread.running = false;
            thread.dead = true;
            return LUA_ERRRUN;
        }
    }
    closeToCloseSlots(thread, 0, thread.stack.items.len);
    thread.stack.clearRetainingCapacity();
    thread.pending_error = null;
    if (thread.pending_yield) |pending| thread.owner.allocator().free(pending.values);
    thread.pending_yield = null;
    thread.continuation = null;
    thread.status = LUA_OK;
    thread.running = false;
    thread.dead = true;
    return LUA_OK;
}

pub export fn lua_atpanic(L: ?*lua_State, panicf: lua_CFunction) callconv(.c) lua_CFunction {
    const state = stateFromThread(L) orelse return null;
    const old = state.panicf;
    state.panicf = panicf;
    return old;
}

pub export fn lua_version(_: ?*lua_State) callconv(.c) lua_Number {
    return 505;
}

pub export fn lua_absindex(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return idx;
    if (idx > 0 or idx <= LUA_REGISTRYINDEX) return idx;
    return @as(c_int, @intCast(thread.stack.items.len)) + idx + 1;
}

pub export fn lua_gettop(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    return @intCast(thread.stack.items.len);
}

pub export fn lua_settop(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    setTop(thread, idx);
}

pub export fn lua_pushvalue(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const value = valueAt(thread, idx) orelse .nil;
    _ = pushValue(thread, value);
}

pub export fn lua_rotate(L: ?*lua_State, idx: c_int, n: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const start = stackAbsIndex(thread, idx) orelse return;
    const len = thread.stack.items.len - start;
    if (len == 0) return;

    const len_i: c_int = @intCast(len);
    var shift = @mod(n, len_i);
    if (shift < 0) shift += len_i;
    if (shift == 0) return;

    const allocator = thread.owner.allocator();
    const temp = allocator.alloc(Value, len) catch return;
    defer allocator.free(temp);
    @memcpy(temp, thread.stack.items[start..]);
    for (temp, 0..) |value, source_index| {
        const dest = (@as(usize, @intCast(shift)) + source_index) % len;
        thread.stack.items[start + dest] = value;
    }
}

pub export fn lua_copy(L: ?*lua_State, fromidx: c_int, toidx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const value = valueAt(thread, fromidx) orelse .nil;
    if (stackSlot(thread, toidx)) |slot| slot.* = value;
}

pub export fn lua_checkstack(L: ?*lua_State, n: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (n < 0) return 0;
    return if (ensureStack(thread, @intCast(n))) 1 else 0;
}

pub export fn lua_xmove(from: ?*lua_State, to: ?*lua_State, n: c_int) callconv(.c) void {
    const source = threadFromState(from) orelse return;
    const dest = threadFromState(to) orelse return;
    if (source.owner != dest.owner or n <= 0) return;
    const count: usize = @intCast(n);
    if (count > source.stack.items.len) return;
    if (!ensureStack(dest, count)) return;
    const start = source.stack.items.len - count;
    dest.stack.appendSliceAssumeCapacity(source.stack.items[start..]);
    source.stack.items.len = start;
}

pub export fn lua_isnumber(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return if (toNumberValue(value) != null) 1 else 0;
}

pub export fn lua_isstring(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .integer, .number, .string => 1,
        else => 0,
    };
}

pub export fn lua_iscfunction(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .c_closure => 1,
        else => 0,
    };
}

pub export fn lua_isinteger(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .integer => 1,
        else => 0,
    };
}

pub export fn lua_isuserdata(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .light_userdata, .userdata => 1,
        else => 0,
    };
}

pub export fn lua_type(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    return typeAt(thread, idx);
}

pub export fn lua_typename(_: ?*lua_State, tp: c_int) callconv(.c) [*:0]const u8 {
    return switch (tp) {
        -1 => zstr("no value"),
        0 => zstr("nil"),
        1 => zstr("boolean"),
        2 => zstr("userdata"),
        3 => zstr("number"),
        4 => zstr("string"),
        5 => zstr("table"),
        6 => zstr("function"),
        7 => zstr("userdata"),
        8 => zstr("thread"),
        else => zstr("invalid"),
    };
}

pub export fn lua_tonumberx(L: ?*lua_State, idx: c_int, isnum: ?*c_int) callconv(.c) lua_Number {
    const thread = threadFromState(L) orelse {
        if (isnum) |ptr| ptr.* = 0;
        return 0;
    };
    const value = valueAt(thread, idx) orelse {
        if (isnum) |ptr| ptr.* = 0;
        return 0;
    };
    return switch (value) {
        .integer => |integer| blk: {
            if (isnum) |ptr| ptr.* = 1;
            break :blk @floatFromInt(integer);
        },
        .number => |number| blk: {
            if (isnum) |ptr| ptr.* = 1;
            break :blk number;
        },
        .string => |string| blk: {
            const parsed = parseLuaNumber(string.bytes);
            if (parsed.number) |number| {
                if (isnum) |ptr| ptr.* = 1;
                break :blk number;
            }
            if (isnum) |ptr| ptr.* = 0;
            break :blk 0;
        },
        else => blk: {
            if (isnum) |ptr| ptr.* = 0;
            break :blk 0;
        },
    };
}

pub export fn lua_tointegerx(L: ?*lua_State, idx: c_int, isnum: ?*c_int) callconv(.c) lua_Integer {
    const thread = threadFromState(L) orelse {
        if (isnum) |ptr| ptr.* = 0;
        return 0;
    };
    const value = valueAt(thread, idx) orelse {
        if (isnum) |ptr| ptr.* = 0;
        return 0;
    };
    return switch (value) {
        .integer => |integer| blk: {
            if (isnum) |ptr| ptr.* = 1;
            break :blk integer;
        },
        .number, .string => blk: {
            if (toIntegerValue(value)) |integer| {
                if (isnum) |ptr| ptr.* = 1;
                break :blk integer;
            }
            if (isnum) |ptr| ptr.* = 0;
            break :blk 0;
        },
        else => blk: {
            if (isnum) |ptr| ptr.* = 0;
            break :blk 0;
        },
    };
}

pub export fn lua_toboolean(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .nil => 0,
        .boolean => |boolean| if (boolean) 1 else 0,
        else => 1,
    };
}

pub export fn lua_tolstring(L: ?*lua_State, idx: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse {
        if (len) |ptr| ptr.* = 0;
        return null;
    };
    const slot = stackSlot(thread, idx);
    const value = if (slot) |ptr| ptr.* else valueAt(thread, idx) orelse {
        if (len) |ptr| ptr.* = 0;
        return null;
    };
    const string = switch (value) {
        .string => |string| string,
        .integer, .number => blk: {
            var out = std.ArrayList(u8).empty;
            defer out.deinit(thread.owner.allocator());
            appendValueString(thread.owner.allocator(), &out, value) catch {
                if (len) |ptr| ptr.* = 0;
                return null;
            };
            const converted = createString(thread.owner, out.items) orelse {
                if (len) |ptr| ptr.* = 0;
                return null;
            };
            if (slot) |ptr| ptr.* = .{ .string = converted };
            break :blk converted;
        },
        else => {
            if (len) |ptr| ptr.* = 0;
            return null;
        },
    };
    if (len) |ptr| ptr.* = string.bytes.len;
    return string.bytes.ptr;
}

pub export fn lua_rawlen(L: ?*lua_State, idx: c_int) callconv(.c) lua_Unsigned {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .string => |string| @intCast(string.bytes.len),
        .table => |table| @intCast(table.len()),
        .userdata => |userdata| @intCast(userdata.size),
        else => 0,
    };
}

pub export fn lua_tocfunction(L: ?*lua_State, idx: c_int) callconv(.c) lua_CFunction {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .c_closure => |closure| functionFromId(closure.function_id),
        else => null,
    };
}

pub export fn lua_touserdata(L: ?*lua_State, idx: c_int) callconv(.c) ?*anyopaque {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .light_userdata => |ptr| ptr,
        .userdata => |userdata| userdata.bytes.ptr,
        else => null,
    };
}

pub export fn lua_tothread(L: ?*lua_State, idx: c_int) callconv(.c) ?*lua_State {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .thread => |target| @ptrCast(target.public_state),
        else => null,
    };
}

pub export fn lua_topointer(L: ?*lua_State, idx: c_int) callconv(.c) ?*const anyopaque {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .string => |string| string.bytes.ptr,
        .table => |table| table,
        .userdata => |userdata| userdata.bytes.ptr,
        .thread => |target| target.public_state,
        .light_userdata => |ptr| ptr,
        .lua_closure => |closure| closure,
        .c_closure => |closure| closure,
        .runtime_native => |native| switch (native) {
            .table => |table| table,
            .closure => |closure| closure,
            .c_closure => |closure| closure,
            .userdata => |userdata| userdata.ptr,
            .string => |string| string.ptr,
            .thread => |target| target,
            else => null,
        },
        else => null,
    };
}

pub export fn lua_arith(L: ?*lua_State, op: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const unary = op == LUA_OPUNM or op == LUA_OPBNOT;
    const required: usize = if (unary) 1 else 2;
    if (thread.stack.items.len < required) return;
    const rhs = thread.stack.pop().?;
    const lhs = if (unary) rhs else thread.stack.pop().?;

    const result: Value = switch (op) {
        LUA_OPADD => arithmeticBinary(lhs, rhs, .add) orelse .nil,
        LUA_OPSUB => arithmeticBinary(lhs, rhs, .sub) orelse .nil,
        LUA_OPMUL => arithmeticBinary(lhs, rhs, .mul) orelse .nil,
        LUA_OPMOD => arithmeticBinary(lhs, rhs, .mod) orelse .nil,
        LUA_OPPOW => .{ .number = std.math.pow(lua_Number, toNumberValue(lhs) orelse 0, toNumberValue(rhs) orelse 0) },
        LUA_OPDIV => .{ .number = (toNumberValue(lhs) orelse 0) / (toNumberValue(rhs) orelse 1) },
        LUA_OPIDIV => arithmeticBinary(lhs, rhs, .idiv) orelse .nil,
        LUA_OPBAND => bitwiseBinary(lhs, rhs, .band) orelse .nil,
        LUA_OPBOR => bitwiseBinary(lhs, rhs, .bor) orelse .nil,
        LUA_OPBXOR => bitwiseBinary(lhs, rhs, .bxor) orelse .nil,
        LUA_OPSHL => bitwiseBinary(lhs, rhs, .shl) orelse .nil,
        LUA_OPSHR => bitwiseBinary(lhs, rhs, .shr) orelse .nil,
        LUA_OPUNM => switch (rhs) {
            .integer => |integer| .{ .integer = -%integer },
            else => .{ .number = -(toNumberValue(rhs) orelse 0) },
        },
        LUA_OPBNOT => if (toIntegerValue(rhs)) |integer| .{ .integer = ~integer } else .nil,
        else => .nil,
    };
    _ = pushValue(thread, result);
}

const ArithmeticKind = enum { add, sub, mul, mod, idiv };
const BitwiseKind = enum { band, bor, bxor, shl, shr };

fn arithmeticBinary(lhs: Value, rhs: Value, kind: ArithmeticKind) ?Value {
    if (toIntegerValue(lhs)) |left| {
        if (toIntegerValue(rhs)) |right| {
            return switch (kind) {
                .add => .{ .integer = left +% right },
                .sub => .{ .integer = left -% right },
                .mul => .{ .integer = left *% right },
                .mod => .{ .integer = floorModInteger(left, right) },
                .idiv => .{ .integer = floorDivInteger(left, right) },
            };
        }
    }
    const left = toNumberValue(lhs) orelse return null;
    const right = toNumberValue(rhs) orelse return null;
    return switch (kind) {
        .add => .{ .number = left + right },
        .sub => .{ .number = left - right },
        .mul => .{ .number = left * right },
        .mod => .{ .number = floorModNumber(left, right) },
        .idiv => .{ .number = @floor(left / right) },
    };
}

fn bitwiseBinary(lhs: Value, rhs: Value, kind: BitwiseKind) ?Value {
    const left = toIntegerValue(lhs) orelse return null;
    const right = toIntegerValue(rhs) orelse return null;
    return .{ .integer = switch (kind) {
        .band => left & right,
        .bor => left | right,
        .bxor => left ^ right,
        .shl => shiftInteger(left, right),
        .shr => if (right == std.math.minInt(lua_Integer)) 0 else shiftInteger(left, -right),
    } };
}

fn floorDivInteger(left: lua_Integer, right: lua_Integer) lua_Integer {
    var quotient = @divTrunc(left, right);
    const remainder = @rem(left, right);
    if (remainder != 0 and ((remainder < 0) != (right < 0))) quotient -= 1;
    return quotient;
}

fn floorModInteger(left: lua_Integer, right: lua_Integer) lua_Integer {
    return left - floorDivInteger(left, right) *% right;
}

fn floorModNumber(left: lua_Number, right: lua_Number) lua_Number {
    var result = @rem(left, right);
    if (result != 0 and ((result < 0) != (right < 0))) result += right;
    return result;
}

fn shiftInteger(value: lua_Integer, amount: lua_Integer) lua_Integer {
    if (amount == 0) return value;
    if (amount >= 64 or amount <= -64) return 0;
    return if (amount > 0)
        value << @intCast(amount)
    else
        @as(lua_Integer, @bitCast(@as(lua_Unsigned, @bitCast(value)) >> @intCast(-amount)));
}

pub export fn lua_rawequal(L: ?*lua_State, idx1: c_int, idx2: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const lhs = valueAt(thread, idx1) orelse return 0;
    const rhs = valueAt(thread, idx2) orelse return 0;
    return if (valuesEqual(lhs, rhs)) 1 else 0;
}

pub export fn lua_compare(L: ?*lua_State, idx1: c_int, idx2: c_int, op: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const lhs = valueAt(thread, idx1) orelse return 0;
    const rhs = valueAt(thread, idx2) orelse return 0;
    const result = switch (op) {
        LUA_OPEQ => valuesEqual(lhs, rhs),
        LUA_OPLT => compareLess(lhs, rhs) orelse false,
        LUA_OPLE => compareLessEqual(lhs, rhs) orelse false,
        else => false,
    };
    return if (result) 1 else 0;
}

fn compareLess(lhs: Value, rhs: Value) ?bool {
    if (toNumberValue(lhs)) |left| if (toNumberValue(rhs)) |right| return left < right;
    if (lhs == .string and rhs == .string) return std.mem.lessThan(u8, lhs.string.bytes, rhs.string.bytes);
    return null;
}

fn compareLessEqual(lhs: Value, rhs: Value) ?bool {
    if (toNumberValue(lhs)) |left| if (toNumberValue(rhs)) |right| return left <= right;
    if (lhs == .string and rhs == .string) return !std.mem.lessThan(u8, rhs.string.bytes, lhs.string.bytes);
    return null;
}

pub export fn lua_pushnil(L: ?*lua_State) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .nil);
}

pub export fn lua_pushnumber(L: ?*lua_State, n: lua_Number) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .{ .number = n });
}

pub export fn lua_pushinteger(L: ?*lua_State, n: lua_Integer) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .{ .integer = n });
}

pub export fn lua_pushlstring(L: ?*lua_State, s: ?[*]const u8, len: usize) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    const source = if (s) |ptr| ptr[0..len] else &.{};
    const string = pushStringBytes(thread, source) orelse return null;
    return string.bytes.ptr;
}

pub export fn lua_pushexternalstring(L: ?*lua_State, s: ?[*]const u8, len: usize, alloc_f: lua_Alloc, ud: ?*anyopaque) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    const ptr = s orelse return lua_pushlstring(L, null, 0);
    const bytes: [:0]const u8 = ptr[0..len :0];
    const string = createExternalString(thread.owner, bytes, alloc_f, ud) orelse return null;
    if (!pushValue(thread, .{ .string = string })) return null;
    return string.bytes.ptr;
}

pub export fn lua_pushstring(L: ?*lua_State, s: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    if (s == null) {
        lua_pushnil(L);
        return null;
    }
    return lua_pushlstring(L, s, std.mem.len(s.?));
}

pub export fn lua_pushvfstring(L: ?*lua_State, fmt: ?[*:0]const u8, args: *VaList) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    return pushFormattedString(thread, fmt, args);
}

pub export fn lua_pushfstring(L: ?*lua_State, fmt: ?[*:0]const u8, ...) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    var args = @cVaStart();
    defer @cVaEnd(&args);

    return pushFormattedString(thread, fmt, &args);
}

extern fn snprintf(?[*]u8, usize, ?[*:0]const u8, ...) c_int;

fn pushFormattedString(thread: *CThread, fmt: ?[*:0]const u8, args: *VaList) callconv(.c) ?[*:0]const u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(thread.owner.allocator());
    const format = cStringSlice(fmt);
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        if (format[index] != '%' or index + 1 >= format.len) {
            out.append(thread.owner.allocator(), format[index]) catch return null;
            continue;
        }
        index += 1;
        switch (format[index]) {
            '%' => out.append(thread.owner.allocator(), '%') catch return null,
            's' => {
                const value = @cVaArg(args, ?[*:0]const u8);
                out.appendSlice(thread.owner.allocator(), if (value) |ptr| std.mem.span(ptr) else "(null)") catch return null;
            },
            'd' => {
                const value = @cVaArg(args, c_int);
                appendFmt(&out, thread.owner.allocator(), "{d}", .{value}) catch return null;
            },
            'I' => {
                const value = @cVaArg(args, lua_Integer);
                appendFmt(&out, thread.owner.allocator(), "{d}", .{value}) catch return null;
            },
            'f' => {
                const value = @cVaArg(args, f64);
                appendValueString(thread.owner.allocator(), &out, .{ .number = value }) catch return null;
            },
            'p' => {
                const value = @cVaArg(args, ?*anyopaque);
                var buffer: [64]u8 = undefined;
                const written = snprintf(&buffer, buffer.len, zstr("%p"), value);
                if (written < 0) return null;
                const len: usize = @min(@as(usize, @intCast(written)), buffer.len - 1);
                out.appendSlice(thread.owner.allocator(), buffer[0..len]) catch return null;
            },
            'U' => {
                const value: u32 = @truncate(@cVaArg(args, c_ulong));
                var buffer: [6]u8 = undefined;
                const len = encodeLuaUtf8(value, &buffer) orelse return null;
                out.appendSlice(thread.owner.allocator(), buffer[0..len]) catch return null;
            },
            'c' => {
                const value = @cVaArg(args, c_int);
                out.append(thread.owner.allocator(), @intCast(value)) catch return null;
            },
            else => {
                out.append(thread.owner.allocator(), '%') catch return null;
                out.append(thread.owner.allocator(), format[index]) catch return null;
            },
        }
    }
    const string = pushStringBytes(thread, out.items) orelse return null;
    return string.bytes.ptr;
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
    if (code <= 0x7fffffff) {
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

pub export fn lua_pushcclosure(L: ?*lua_State, function: lua_CFunction, n: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const capture_count: usize = @intCast(@max(n, 0));
    if (capture_count > thread.stack.items.len) return;
    const allocator = thread.owner.allocator();
    const upvalues = allocator.alloc(runtime.Value, capture_count) catch return;
    defer allocator.free(upvalues);
    const start = thread.stack.items.len - capture_count;
    for (upvalues, 0..) |*upvalue, index| upvalue.* = cToRuntimeValue(thread.owner, thread.stack.items[start + index], 0) catch .nil;
    thread.stack.items.len = start;
    const closure = thread.owner.runtime_state.newCClosure(functionId(function), upvalues) catch return;
    _ = pushValue(thread, .{ .c_closure = closure });
}

pub export fn lua_pushboolean(L: ?*lua_State, b: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .{ .boolean = b != 0 });
}

pub export fn lua_pushlightuserdata(L: ?*lua_State, ptr: ?*anyopaque) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .{ .light_userdata = ptr });
}

pub export fn lua_pushthread(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    _ = pushValue(thread, .{ .thread = thread });
    return if (thread == &thread.owner.main_thread) 1 else 0;
}

pub export fn lua_getglobal(L: ?*lua_State, name: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    const key = createString(thread.owner, cStringSlice(name)) orelse return LUA_TNIL;
    const value = thread.owner.global_table.get(.{ .string = key });
    _ = pushValue(thread, value);
    return value.typeTag();
}

fn pushGlobalValue(thread: *CThread, name: []const u8) bool {
    const key = createString(thread.owner, name) orelse return false;
    _ = pushValue(thread, thread.owner.global_table.get(.{ .string = key }));
    return true;
}

fn setGlobalValue(thread: *CThread, name: []const u8, value: Value) bool {
    const key = createString(thread.owner, name) orelse return false;
    thread.owner.global_table.set(thread.owner.allocator(), .{ .string = key }, value) catch return false;
    syncCGlobalToRuntime(thread.owner, name, value);
    return true;
}

pub export fn lua_gettable(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    if (thread.stack.items.len == 0) return LUA_TNONE;
    const table_value = valueAt(thread, idx) orelse .nil;
    const key = thread.stack.pop().?;
    const value = switch (table_value) {
        .table => |table| getTable(thread, table, key, 0),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_getfield(L: ?*lua_State, idx: c_int, key: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    const string = createString(thread.owner, cStringSlice(key)) orelse return LUA_TNIL;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = switch (table_value) {
        .table => |table| getTable(thread, table, .{ .string = string }, 0),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_geti(L: ?*lua_State, idx: c_int, n: lua_Integer) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = switch (table_value) {
        .table => |table| getTable(thread, table, .{ .integer = n }, 0),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_rawget(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    if (thread.stack.items.len == 0) return LUA_TNONE;
    const table_value = valueAt(thread, idx) orelse .nil;
    const key = thread.stack.pop().?;
    const value = switch (table_value) {
        .table => |table| table.get(key),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_rawgeti(L: ?*lua_State, idx: c_int, n: lua_Integer) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    if (idx == LUA_REGISTRYINDEX) {
        var value = thread.owner.registry_table.get(.{ .integer = n });
        if (value == .nil) value = switch (n) {
            1 => .{ .boolean = false },
            LUA_RIDX_GLOBALS => .{ .table = thread.owner.global_table },
            LUA_RIDX_MAINTHREAD => .{ .thread = &thread.owner.main_thread },
            else => .nil,
        };
        _ = pushValue(thread, value);
        return value.typeTag();
    }
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = switch (table_value) {
        .table => |table| table.get(.{ .integer = n }),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_rawgetp(L: ?*lua_State, idx: c_int, ptr: ?*const anyopaque) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = switch (table_value) {
        .table => |table| table.get(.{ .light_userdata = @constCast(ptr) }),
        else => .nil,
    };
    _ = pushValue(thread, value);
    return value.typeTag();
}

pub export fn lua_createtable(L: ?*lua_State, narr: c_int, nrec: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const table = createTable(thread.owner, narr, nrec) orelse return;
    _ = pushValue(thread, .{ .table = table });
}

pub export fn lua_newuserdatauv(L: ?*lua_State, size: usize, nuvalue: c_int) callconv(.c) ?*anyopaque {
    const thread = threadFromState(L) orelse return null;
    if (nuvalue < 0) return null;
    const userdata = createUserdata(thread.owner, size, @intCast(nuvalue)) orelse return null;
    if (!pushValue(thread, .{ .userdata = userdata })) return null;
    return userdata.bytes.ptr;
}

pub export fn lua_getmetatable(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    const metatable = switch (value) {
        .table => |table| table.metatable,
        .userdata => |userdata| userdata.metatable,
        else => null,
    } orelse return 0;
    _ = pushValue(thread, .{ .table = metatable });
    return 1;
}

pub export fn lua_getiuservalue(L: ?*lua_State, idx: c_int, n: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    const value = valueAt(thread, idx) orelse .nil;
    if (value != .userdata or n <= 0) {
        _ = pushValue(thread, .nil);
        return LUA_TNONE;
    }
    const index: usize = @intCast(n - 1);
    if (index >= value.userdata.uservalues.len) {
        _ = pushValue(thread, .nil);
        return LUA_TNONE;
    }
    const uservalue = value.userdata.uservalues[index];
    _ = pushValue(thread, uservalue);
    return uservalue.typeTag();
}

pub export fn lua_setglobal(L: ?*lua_State, name: ?[*:0]const u8) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len == 0) return;
    const value = thread.stack.pop().?;
    const name_bytes = cStringSlice(name);
    const key = createString(thread.owner, name_bytes) orelse return;
    thread.owner.global_table.set(thread.owner.allocator(), .{ .string = key }, value) catch return;
    syncCGlobalToRuntime(thread.owner, name_bytes, value);
}

fn rawSetRegistryInteger(thread: *CThread, index: lua_Integer, value: Value) bool {
    thread.owner.registry_table.set(thread.owner.allocator(), .{ .integer = index }, value) catch return false;
    return true;
}

fn rawSetRegistryString(thread: *CThread, key: []const u8, value: Value) bool {
    return rawTableSetString(thread.owner, thread.owner.registry_table, key, value);
}

pub export fn lua_settable(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len < 2) return;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    const key = thread.stack.pop().?;
    if (table_value == .table) setTable(thread, table_value.table, key, value, 0);
}

pub export fn lua_setfield(L: ?*lua_State, idx: c_int, key: ?[*:0]const u8) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len == 0) return;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    const string = createString(thread.owner, cStringSlice(key)) orelse return;
    if (table_value == .table) setTable(thread, table_value.table, .{ .string = string }, value, 0);
}

pub export fn lua_seti(L: ?*lua_State, idx: c_int, n: lua_Integer) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len == 0) return;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    if (table_value == .table) setTable(thread, table_value.table, .{ .integer = n }, value, 0);
}

pub export fn lua_rawset(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len < 2) return;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    const key = thread.stack.pop().?;
    if (table_value == .table) table_value.table.set(thread.owner.allocator(), key, value) catch return;
}

pub export fn lua_rawseti(L: ?*lua_State, idx: c_int, n: lua_Integer) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len == 0) return;
    if (idx == LUA_REGISTRYINDEX) {
        const value = thread.stack.pop().?;
        _ = rawSetRegistryInteger(thread, n, value);
        return;
    }
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    if (table_value == .table) table_value.table.set(thread.owner.allocator(), .{ .integer = n }, value) catch return;
}

pub export fn lua_rawsetp(L: ?*lua_State, idx: c_int, ptr: ?*const anyopaque) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (thread.stack.items.len == 0) return;
    const table_value = valueAt(thread, idx) orelse .nil;
    const value = thread.stack.pop().?;
    if (table_value == .table) table_value.table.set(thread.owner.allocator(), .{ .light_userdata = @constCast(ptr) }, value) catch return;
}

pub export fn lua_setmetatable(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (thread.stack.items.len == 0) return 0;
    const target = valueAt(thread, idx) orelse return 0;
    const metatable_value = thread.stack.pop().?;
    switch (target) {
        .table => |table| thread.owner.runtime_state.setTableMetatableRaw(table, switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => table.metatable,
        }),
        .userdata => |userdata| userdata.metatable = switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => userdata.metatable,
        },
        else => {},
    }
    return 1;
}

pub export fn lua_setiuservalue(L: ?*lua_State, idx: c_int, n: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (thread.stack.items.len == 0) return 0;
    const value = valueAt(thread, idx) orelse .nil;
    const new_value = thread.stack.pop().?;
    if (value != .userdata or n <= 0) return 0;
    const index: usize = @intCast(n - 1);
    if (index >= value.userdata.uservalues.len) return 0;
    value.userdata.uservalues[index] = new_value;
    return 1;
}

pub export fn lua_callk(L: ?*lua_State, nargs: c_int, nresults: c_int, ctx: lua_KContext, k: lua_KFunction) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (k != null) thread.yieldable_call_depth += 1;
    const status = callStackFunction(thread, nargs, nresults, false);
    if (k != null) thread.yieldable_call_depth -= 1;
    if (status == LUA_YIELD and k != null) _ = installYieldContinuation(thread, ctx, k);
}

pub export fn lua_pcallk(L: ?*lua_State, nargs: c_int, nresults: c_int, msgh: c_int, ctx: lua_KContext, k: lua_KFunction) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const handler_abs = if (msgh == 0) 0 else lua_absindex(L, msgh);
    const handler = if (handler_abs == 0) null else valueAt(thread, handler_abs);
    if (k != null) thread.yieldable_call_depth += 1;
    const status = callStackFunction(thread, nargs, nresults, true);
    if (k != null) thread.yieldable_call_depth -= 1;
    if (status == LUA_YIELD and k != null) {
        if (!installYieldContinuation(thread, ctx, k)) return LUA_ERRMEM;
        return LUA_YIELD;
    }
    if (status == LUA_OK) return LUA_OK;
    if (status == LUA_ERRRUN) {
        if (handler) |handler_value| {
            const error_value = thread.stack.pop() orelse .nil;
            if (applyMessageHandler(thread, handler_value, error_value)) |handled| {
                _ = pushValue(thread, handled);
            } else {
                _ = pushValue(thread, error_value);
                return LUA_ERRERR;
            }
        }
    }
    return status;
}

pub export fn lua_load(L: ?*lua_State, reader: lua_Reader, data: ?*anyopaque, name: ?[*:0]const u8, mode: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const read_fn = reader orelse return LUA_ERRSYNTAX;
    var source = std.ArrayList(u8).empty;
    defer source.deinit(thread.owner.allocator());
    while (true) {
        var len: usize = 0;
        const ptr = read_fn(L, data, &len) orelse break;
        if (len == 0) break;
        source.appendSlice(thread.owner.allocator(), ptr[0..len]) catch {
            _ = pushStringBytes(thread, "not enough memory");
            return LUA_ERRMEM;
        };
    }
    return loadBuffer(thread, source.items, cStringSlice(name), if (mode) |ptr| std.mem.span(ptr) else null);
}

pub export fn lua_dump(L: ?*lua_State, writer: lua_Writer, data: ?*anyopaque, strip: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 1;
    const write_fn = writer orelse return 1;
    const value = valueAt(thread, -1) orelse return 1;
    if (value != .lua_closure) return 1;

    var out = std.ArrayList(u8).empty;
    defer out.deinit(thread.owner.allocator());
    runtime.dumpClosureBinary(thread.owner.allocator(), &out, value.lua_closure, strip != 0) catch return 1;
    return write_fn(L, out.items.ptr, out.items.len, data);
}

pub export fn lua_yieldk(L: ?*lua_State, nresults: c_int, ctx: lua_KContext, k: lua_KFunction) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (nresults < 0 or @as(usize, @intCast(nresults)) > thread.stack.items.len) {
        thread.pending_error = .{ .string = createString(thread.owner, "attempt to yield with too many results") orelse return 0 };
        return 0;
    }
    if (!canYield(thread)) {
        const message = if (thread == &thread.owner.main_thread or !thread.running)
            "attempt to yield from outside a coroutine"
        else
            "attempt to yield across a C-call boundary";
        thread.pending_error = .{ .string = createString(thread.owner, message) orelse return 0 };
        return 0;
    }
    const count: usize = @intCast(nresults);
    const start = thread.stack.items.len - count;
    const values = thread.owner.allocator().dupe(Value, thread.stack.items[start..]) catch {
        thread.pending_error = .{ .string = createString(thread.owner, "not enough memory") orelse return 0 };
        return 0;
    };
    thread.pending_yield = .{ .values = values, .result_count = count, .ctx = ctx, .k = k };
    return 0;
}

pub export fn lua_resume(L: ?*lua_State, _: ?*lua_State, narg: c_int, nres: ?*c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse {
        if (nres) |ptr| ptr.* = 0;
        return LUA_ERRRUN;
    };
    if (thread == &thread.owner.main_thread) {
        _ = pushStringBytes(thread, "cannot resume main coroutine");
        if (nres) |ptr| ptr.* = 1;
        return LUA_ERRRUN;
    }
    if (thread.dead and thread.status != LUA_YIELD) {
        _ = pushStringBytes(thread, "cannot resume dead coroutine");
        if (nres) |ptr| ptr.* = 1;
        return LUA_ERRRUN;
    }
    if (thread.running) {
        _ = pushStringBytes(thread, "cannot resume non-suspended coroutine");
        if (nres) |ptr| ptr.* = 1;
        return LUA_ERRRUN;
    }

    const status = if (thread.runtime_thread != null)
        resumeRuntimeThread(thread, narg)
    else blk: {
        if (thread.status == LUA_YIELD) break :blk resumeCThread(thread, narg);
        if (narg < 0 or thread.stack.items.len < @as(usize, @intCast(narg)) + 1) break :blk LUA_ERRRUN;
        const base = thread.stack.items.len - @as(usize, @intCast(narg)) - 1;
        break :blk switch (thread.stack.items[base]) {
            .lua_closure => resumeRuntimeThread(thread, narg),
            .c_closure => resumeCThread(thread, narg),
            else => err_blk: {
                thread.stack.items.len = base;
                _ = pushStringBytes(thread, "attempt to call a non-function value");
                break :err_blk LUA_ERRRUN;
            },
        };
    };
    if (status != LUA_OK and status != LUA_YIELD) {
        thread.status = status;
        thread.running = false;
        thread.dead = true;
    }
    if (nres) |ptr| ptr.* = @intCast(if (status == LUA_YIELD) thread.resume_result_count else thread.stack.items.len);
    return status;
}

pub export fn lua_status(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_OK;
    return thread.status;
}

pub export fn lua_isyieldable(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    return if (thread != &thread.owner.main_thread and !thread.dead) 1 else 0;
}

pub export fn lua_setwarnf(L: ?*lua_State, warnf: lua_WarnFunction, ud: ?*anyopaque) callconv(.c) void {
    const state = stateFromThread(L) orelse return;
    state.warnf = warnf;
    state.warn_ud = ud;
}

pub export fn lua_warning(L: ?*lua_State, msg: ?[*:0]const u8, tocont: c_int) callconv(.c) void {
    const state = stateFromThread(L) orelse return;
    const warnf = state.warnf orelse return;
    warnf(state.warn_ud, msg, tocont);
}

pub export fn lua_gc(L: ?*lua_State, what: c_int, ...) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    var args = @cVaStart();
    defer @cVaEnd(&args);
    switch (what) {
        LUA_GCSTOP => {
            thread.owner.runtime_state.stopGc();
            return 0;
        },
        LUA_GCRESTART => {
            thread.owner.runtime_state.restartGc();
            return 0;
        },
        LUA_GCCOLLECT => {
            collectCUserdata(thread);
            thread.owner.runtime_state.collectGarbage() catch {};
            return 0;
        },
        LUA_GCCOUNT => return @intCast(thread.owner.runtime_state.allocationByteCount() >> 10),
        LUA_GCCOUNTB => return @intCast(thread.owner.runtime_state.allocationByteCount() & 0x3ff),
        LUA_GCSTEP => {
            const budget: i64 = @intCast(@cVaArg(&args, usize));
            const complete = thread.owner.runtime_state.collectGarbageStepPublic(budget) catch false;
            collectCUserdata(thread);
            return if (complete) 1 else 0;
        },
        LUA_GCISRUNNING => return if (thread.owner.runtime_state.gcIsRunning()) 1 else 0,
        LUA_GCGEN => return switch (thread.owner.runtime_state.switchGcMode(.generational)) {
            .incremental => LUA_GCINC,
            .generational => LUA_GCGEN,
        },
        LUA_GCINC => return switch (thread.owner.runtime_state.switchGcMode(.incremental)) {
            .incremental => LUA_GCINC,
            .generational => LUA_GCGEN,
        },
        LUA_GCPARAM => {
            const param_raw = @cVaArg(&args, c_int);
            const value = @cVaArg(&args, c_int);
            const param = gcParamFromInt(param_raw) orelse return -1;
            const old = thread.owner.runtime_state.gcParam(param);
            if (value >= 0) thread.owner.runtime_state.setGcParam(param, value);
            return @intCast(old);
        },
        else => return -1,
    }
}

fn gcParamFromInt(param: c_int) ?runtime.GcParam {
    if (param < 0 or param >= LUA_GCPN) return null;
    return switch (param) {
        0 => .minormul,
        1 => .majorminor,
        2 => .minormajor,
        3 => .pause,
        4 => .stepmul,
        5 => .stepsize,
        else => null,
    };
}

pub export fn lua_error(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    thread.pending_error = if (thread.stack.items.len == 0) .nil else thread.stack.items[thread.stack.items.len - 1];
    if (thread.c_call_depth == 0) raiseUnprotected(thread);
    return 0;
}

pub export fn lua_next(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (thread.stack.items.len == 0) return 0;
    const table_value = valueAt(thread, idx) orelse .nil;
    if (table_value != .table) return 0;
    const key = thread.stack.pop().?;
    const entry = table_value.table.next(key) orelse return 0;
    _ = pushValue(thread, entry.key);
    _ = pushValue(thread, entry.value);
    return 1;
}

pub export fn lua_concat(L: ?*lua_State, n: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (n <= 0) {
        _ = pushStringBytes(thread, &.{});
        return;
    }
    const count: usize = @intCast(n);
    if (count == 1 or count > thread.stack.items.len) return;
    const start = thread.stack.items.len - count;
    var out = std.ArrayList(u8).empty;
    defer out.deinit(thread.owner.allocator());
    for (thread.stack.items[start..]) |value| {
        const bytes = stringLikeBytes(thread, value) orelse return;
        out.appendSlice(thread.owner.allocator(), bytes) catch return;
    }
    thread.stack.items.len = start;
    _ = pushStringBytes(thread, out.items);
}

pub export fn lua_len(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const value = valueAt(thread, idx) orelse .nil;
    const result: Value = switch (value) {
        .string => |string| .{ .integer = @intCast(string.bytes.len) },
        .table => |table| .{ .integer = table.len() },
        else => .nil,
    };
    _ = pushValue(thread, result);
}

pub export fn lua_numbertocstring(L: ?*lua_State, idx: c_int, buff: ?[*]u8) callconv(.c) c_uint {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    switch (value) {
        .integer, .number => {},
        else => return 0,
    }
    var out = std.ArrayList(u8).empty;
    defer out.deinit(thread.owner.allocator());
    if (!(appendCNumberString(thread.owner.allocator(), &out, value) catch return 0)) return 0;
    if (buff) |ptr| {
        @memcpy(ptr[0..out.items.len], out.items);
        ptr[out.items.len] = 0;
    }
    return @intCast(out.items.len + 1);
}

pub export fn lua_stringtonumber(L: ?*lua_State, s: ?[*:0]const u8) callconv(.c) usize {
    const thread = threadFromState(L) orelse return 0;
    const text = cStringSlice(s);
    const parsed = parseLuaNumber(text);
    if (parsed.consumed == 0) return 0;
    if (parsed.integer) |integer| {
        _ = pushValue(thread, .{ .integer = integer });
        return parsed.consumed;
    }
    if (parsed.number) |number| {
        _ = pushValue(thread, .{ .number = number });
        return parsed.consumed;
    }
    return 0;
}

fn trimLeftAscii(value: []const u8, values_to_strip: []const u8) []const u8 {
    var start: usize = 0;
    while (start < value.len and std.mem.indexOfScalar(u8, values_to_strip, value[start]) != null) start += 1;
    return value[start..];
}

fn trimRightAscii(value: []const u8, values_to_strip: []const u8) []const u8 {
    var end = value.len;
    while (end > 0 and std.mem.indexOfScalar(u8, values_to_strip, value[end - 1]) != null) end -= 1;
    return value[0..end];
}

pub export fn lua_getallocf(L: ?*lua_State, ud: ?*?*anyopaque) callconv(.c) lua_Alloc {
    const state = stateFromThread(L) orelse {
        if (ud) |ptr| ptr.* = null;
        return null;
    };
    if (ud) |ptr| ptr.* = state.alloc_ud;
    return state.alloc_f;
}

pub export fn lua_setallocf(L: ?*lua_State, alloc_f: lua_Alloc, ud: ?*anyopaque) callconv(.c) void {
    const state = stateFromThread(L) orelse return;
    _ = alloc_f orelse return;
    state.alloc_f = alloc_f;
    state.alloc_ud = ud;
}
pub export fn lua_toclose(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const slot = stackAbsIndex(thread, idx) orelse return;
    for (thread.to_close_slots.items) |existing| if (existing == slot) return;
    thread.to_close_slots.append(thread.owner.allocator(), slot) catch return;
}

pub export fn lua_closeslot(L: ?*lua_State, idx: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const slot = stackAbsIndex(thread, idx) orelse return;
    closeSlotAt(thread, slot);
    removeToCloseSlot(thread, slot);
}

fn runtimeCurrentLine(frame: anytype) c_int {
    if (frame.proto.line_info.items.len == 0) return -1;
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    if (pc >= frame.proto.line_info.items.len) return -1;
    const line = frame.proto.line_info.items[pc].line;
    return if (line == 0) -1 else @intCast(line);
}

fn runtimeLineRange(closure: *runtime.Closure) struct { first: c_int, last: c_int } {
    const proto = closure.proto;
    if (proto.defined_line == 0) return .{ .first = 0, .last = 0 };
    if (closure.stripped_debug) return .{ .first = @intCast(proto.defined_line), .last = @intCast(proto.defined_line) };
    const last = if (proto.last_defined_line != 0) proto.last_defined_line else proto.defined_line;
    return .{ .first = @intCast(proto.defined_line), .last = @intCast(last) };
}

fn fillDebugSource(state: *CState, ar: *lua_Debug, value: Value, active_frame: ?DebugFrameRef) void {
    switch (value) {
        .lua_closure => |closure| {
            const source = if (closure.stripped_debug) "=?" else closure.proto.source_name;
            ar.source = debugString(state, source);
            ar.srclen = source.len;
            const range = runtimeLineRange(closure);
            ar.linedefined = range.first;
            ar.lastlinedefined = range.last;
            ar.what = if (closure.proto.defined_line == 0) zstr("main") else zstr("Lua");
            setShortSource(ar, source);
        },
        else => {
            const source = "=[C]";
            ar.source = debugString(state, source);
            ar.srclen = source.len;
            ar.linedefined = -1;
            ar.lastlinedefined = -1;
            ar.what = zstr("C");
            setShortSource(ar, source);
        },
    }
    if (active_frame) |frame| if (frame.kind == .runtime) {
        const runtime_thread = state.main_thread.runtime_thread orelse return;
        if (frame.index < runtime_thread.frames.items.len and runtime_thread.frames.items[frame.index].is_tail_call) ar.what = zstr("tail");
    };
}

fn fillDebugCurrentLine(thread: *CThread, ar: *lua_Debug, frame_ref: ?DebugFrameRef) void {
    ar.currentline = -1;
    const frame = frame_ref orelse return;
    switch (frame.kind) {
        .runtime => {
            const runtime_thread = thread.runtime_thread orelse return;
            if (frame.index >= runtime_thread.frames.items.len) return;
            ar.currentline = runtimeCurrentLine(runtime_thread.frames.items[frame.index]);
        },
        .c => {},
    }
}

fn fillDebugUpvalues(ar: *lua_Debug, value: Value) void {
    switch (value) {
        .lua_closure => |closure| {
            ar.nups = @intCast(@min(closure.upvalues.len, std.math.maxInt(u8)));
            ar.nparams = @intCast(@min(closure.proto.param_count, std.math.maxInt(u8)));
            ar.isvararg = if (closure.proto.is_vararg) 1 else 0;
        },
        .c_closure => |closure| {
            ar.nups = @intCast(@min(closure.upvalues.len, std.math.maxInt(u8)));
            ar.nparams = 0;
            ar.isvararg = 1;
        },
        else => {
            ar.nups = 0;
            ar.nparams = 0;
            ar.isvararg = 1;
        },
    }
}

fn fillDebugTailAndTransfers(thread: *CThread, ar: *lua_Debug, frame_ref: ?DebugFrameRef) void {
    ar.istailcall = 0;
    ar.extraargs = 0;
    ar.ftransfer = 0;
    ar.ntransfer = 0;
    const frame = frame_ref orelse return;
    switch (frame.kind) {
        .runtime => {
            const runtime_thread = thread.runtime_thread orelse return;
            if (frame.index >= runtime_thread.frames.items.len) return;
            const runtime_frame = runtime_thread.frames.items[frame.index];
            ar.istailcall = if (runtime_frame.is_tail_call) 1 else 0;
            ar.extraargs = @intCast(@min(runtime_frame.varargs.len, std.math.maxInt(u8)));
            if (runtime_thread.hook_running) {
                ar.ftransfer = thread.debug_event.ftransfer;
                ar.ntransfer = thread.debug_event.ntransfer;
            }
        },
        .c => {},
    }
}

fn fillDebugName(thread: *CThread, ar: *lua_Debug, frame_ref: ?DebugFrameRef) void {
    ar.name = null;
    ar.namewhat = zstr("");
    const frame = frame_ref orelse return;
    if (frame.kind != .runtime) return;
    const runtime_thread = thread.runtime_thread orelse return;
    if (frame.index >= runtime_thread.frames.items.len) return;
    const level: i64 = @intCast(runtime_thread.frames.items.len - frame.index);
    if (thread.owner.runtime_state.currentFunctionName(runtime_thread, level)) |name| {
        ar.name = debugString(thread.owner, name);
        ar.namewhat = debugString(thread.owner, thread.owner.runtime_state.currentFunctionNameWhat(runtime_thread, level) orelse "local");
    }
}

fn debugFrameValue(thread: *CThread, frame_ref: ?DebugFrameRef) Value {
    const frame = frame_ref orelse return .nil;
    return switch (frame.kind) {
        .runtime => blk: {
            const runtime_thread = thread.runtime_thread orelse break :blk .nil;
            if (frame.index >= runtime_thread.frames.items.len) break :blk .nil;
            break :blk .{ .lua_closure = runtime_thread.frames.items[frame.index].closure };
        },
        .c => blk: {
            if (frame.index >= thread.c_frames.items.len) break :blk .nil;
            break :blk .{ .c_closure = thread.c_frames.items[frame.index].closure };
        },
    };
}

fn activeRuntimeThread(thread: *CThread) ?*runtime.Thread {
    return thread.runtime_thread orelse thread.owner.runtime_state.current_thread;
}

pub export fn lua_getstack(L: ?*lua_State, level: c_int, ar: ?*lua_Debug) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    if (level < 0) return 0;
    const out = ar orelse return 0;
    out.* = emptyDebug();
    var depth: usize = @intCast(level);
    if (thread.c_frames.items.len != 0) {
        if (depth == 0) {
            out.i_ci = debugFrameHandle(.{ .kind = .c, .index = thread.c_frames.items.len - 1 });
            return 1;
        }
        depth -= 1;
    }
    const runtime_thread = activeRuntimeThread(thread) orelse return 0;
    if (depth >= runtime_thread.frames.items.len) return 0;
    out.i_ci = debugFrameHandle(.{ .kind = .runtime, .index = runtime_thread.frames.items.len - depth - 1 });
    thread.runtime_thread = runtime_thread;
    return 1;
}

pub export fn lua_getinfo(L: ?*lua_State, what: ?[*:0]const u8, ar: ?*lua_Debug) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const out = ar orelse return 0;
    const options = cStringSlice(what);
    var option_start: usize = 0;
    var frame_ref = debugFrameFromHandle(out.i_ci);
    var function_value = debugFrameValue(thread, frame_ref);
    if (options.len != 0 and options[0] == '>') {
        option_start = 1;
        function_value = if (thread.stack.items.len == 0) .nil else thread.stack.pop().?;
        frame_ref = null;
    }
    out.* = emptyDebug();
    out.i_ci = if (frame_ref) |frame| debugFrameHandle(frame) else null;
    out.event = thread.debug_event.event;
    for (options[option_start..]) |option| switch (option) {
        'S' => fillDebugSource(thread.owner, out, function_value, frame_ref),
        'l' => fillDebugCurrentLine(thread, out, frame_ref),
        'u' => fillDebugUpvalues(out, function_value),
        't' => fillDebugTailAndTransfers(thread, out, frame_ref),
        'n' => fillDebugName(thread, out, frame_ref),
        'r' => {
            out.ftransfer = thread.debug_event.ftransfer;
            out.ntransfer = thread.debug_event.ntransfer;
        },
        'f' => _ = pushValue(thread, function_value),
        'L' => {
            const table = createTable(thread.owner, 0, 0) orelse return 0;
            if (function_value == .lua_closure and !function_value.lua_closure.stripped_debug) {
                for (function_value.lua_closure.proto.line_info.items) |info| {
                    if (info.line != 0) table.set(thread.owner.allocator(), .{ .integer = @intCast(info.line) }, .{ .boolean = true }) catch return 0;
                }
            }
            _ = pushValue(thread, .{ .table = table });
        },
        '>' => {},
        else => return 0,
    };
    return 1;
}

fn runtimeLocalAtIndex(target: *runtime.Thread, frame_index: usize, n: c_int) ?struct { name: []const u8, stack_index: usize } {
    if (n <= 0 or frame_index >= target.frames.items.len) return null;
    const frame = target.frames.items[frame_index];
    const pc = if (frame.pc == 0) 0 else frame.pc - 1;
    var seen: c_int = 0;
    for (frame.proto.locals.items) |local| {
        if (std.mem.eql(u8, local.name, "_ENV")) continue;
        if (!runtime.localActiveAt(local, pc)) continue;
        seen += 1;
        if (seen == n) return .{ .name = local.name, .stack_index = frame.base + local.register };
    }
    return null;
}

fn functionLocalName(value: Value, n: c_int) ?[]const u8 {
    if (n <= 0 or value != .lua_closure) return null;
    var seen: c_int = 0;
    for (value.lua_closure.proto.locals.items) |local| {
        if (local.register >= value.lua_closure.proto.param_count) continue;
        seen += 1;
        if (seen == n) return local.name;
    }
    return null;
}

pub export fn lua_getlocal(L: ?*lua_State, ar: ?*const lua_Debug, n: c_int) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    if (ar == null) {
        const value = if (thread.stack.items.len == 0) .nil else thread.stack.items[thread.stack.items.len - 1];
        const name = functionLocalName(value, n) orelse return null;
        return debugString(thread.owner, name);
    }
    const frame = debugFrameFromHandle(ar.?.i_ci) orelse return null;
    switch (frame.kind) {
        .runtime => {
            const target = activeRuntimeThread(thread) orelse return null;
            if (n < 0 and frame.index < target.frames.items.len) {
                const runtime_frame = target.frames.items[frame.index];
                const vararg_index: usize = @intCast(-n - 1);
                if (vararg_index >= runtime_frame.varargs.len) return null;
                _ = pushValue(thread, runtimeToCValue(thread.owner, runtime_frame.varargs[vararg_index], 0) catch .nil);
                return zstr("(vararg)");
            }
            const local = runtimeLocalAtIndex(target, frame.index, n) orelse return null;
            _ = pushValue(thread, runtimeToCValue(thread.owner, target.stack.items[local.stack_index], 0) catch .nil);
            return debugString(thread.owner, local.name);
        },
        .c => {
            if (frame.index >= thread.c_frames.items.len or n <= 0) return null;
            const c_frame = thread.c_frames.items[frame.index];
            const offset: usize = @intCast(n - 1);
            if (offset >= c_frame.arg_count or c_frame.base + offset >= thread.stack.items.len) return null;
            _ = pushValue(thread, thread.stack.items[c_frame.base + offset]);
            return zstr("(C temporary)");
        },
    }
}

pub export fn lua_setlocal(L: ?*lua_State, ar: ?*const lua_Debug, n: c_int) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    if (thread.stack.items.len == 0) return null;
    const frame = debugFrameFromHandle((ar orelse return null).i_ci) orelse return null;
    const value = thread.stack.pop().?;
    switch (frame.kind) {
        .runtime => {
            const target = activeRuntimeThread(thread) orelse return null;
            if (n < 0 and frame.index < target.frames.items.len) {
                const runtime_frame = &target.frames.items[frame.index];
                const vararg_index: usize = @intCast(-n - 1);
                if (vararg_index >= runtime_frame.varargs.len or !runtime_frame.owns_varargs) return null;
                @constCast(runtime_frame.varargs.ptr)[vararg_index] = cToRuntimeValue(thread.owner, value, 0) catch .nil;
                return zstr("(vararg)");
            }
            const local = runtimeLocalAtIndex(target, frame.index, n) orelse return null;
            target.stack.items[local.stack_index] = cToRuntimeValue(thread.owner, value, 0) catch .nil;
            return debugString(thread.owner, local.name);
        },
        .c => {
            if (frame.index >= thread.c_frames.items.len or n <= 0) return null;
            const c_frame = thread.c_frames.items[frame.index];
            const offset: usize = @intCast(n - 1);
            if (offset >= c_frame.arg_count or c_frame.base + offset >= thread.stack.items.len) return null;
            thread.stack.items[c_frame.base + offset] = value;
            return zstr("(C temporary)");
        },
    }
}

pub export fn lua_getupvalue(L: ?*lua_State, funcindex: c_int, n: c_int) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    if (n <= 0) return null;
    const upvalue_index: usize = @intCast(n - 1);
    const function = valueAt(thread, funcindex) orelse return null;
    switch (function) {
        .c_closure => |closure| {
            if (upvalue_index >= closure.upvalues.len) return null;
            _ = pushValue(thread, runtimeToCValue(thread.owner, closure.upvalues[upvalue_index].value, 0) catch .nil);
            return zstr("");
        },
        .lua_closure => |closure| {
            if (upvalue_index >= closure.upvalues.len) return null;
            _ = pushValue(thread, runtimeToCValue(thread.owner, readRuntimeUpvalue(closure.upvalues[upvalue_index]), 0) catch .nil);
            const name = if (upvalue_index < closure.proto.upvalues.items.len) closure.proto.upvalues.items[upvalue_index].name else "";
            return (createString(thread.owner, name) orelse return zstr("")).bytes.ptr;
        },
        else => return null,
    }
}

pub export fn lua_setupvalue(L: ?*lua_State, funcindex: c_int, n: c_int) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    if (n <= 0 or thread.stack.items.len == 0) return null;
    const upvalue_index: usize = @intCast(n - 1);
    const function = valueAt(thread, funcindex) orelse return null;
    const value = thread.stack.pop().?;
    switch (function) {
        .c_closure => |closure| {
            if (upvalue_index >= closure.upvalues.len) return null;
            closure.upvalues[upvalue_index].value = cToRuntimeValue(thread.owner, value, 0) catch .nil;
            return zstr("");
        },
        .lua_closure => |closure| {
            if (upvalue_index >= closure.upvalues.len) return null;
            writeRuntimeUpvalue(closure.upvalues[upvalue_index], cToRuntimeValue(thread.owner, value, 0) catch .nil);
            const name = if (upvalue_index < closure.proto.upvalues.items.len) closure.proto.upvalues.items[upvalue_index].name else "";
            return (createString(thread.owner, name) orelse return zstr("")).bytes.ptr;
        },
        else => return null,
    }
}

pub export fn lua_upvalueid(L: ?*lua_State, funcindex: c_int, n: c_int) callconv(.c) ?*anyopaque {
    const thread = threadFromState(L) orelse return null;
    if (n <= 0) return null;
    const upvalue_index: usize = @intCast(n - 1);
    const function = valueAt(thread, funcindex) orelse return null;
    return switch (function) {
        .c_closure => |closure| if (upvalue_index < closure.upvalues.len) closure.upvalues[upvalue_index] else null,
        .lua_closure => |closure| if (upvalue_index < closure.upvalues.len) closure.upvalues[upvalue_index] else null,
        else => null,
    };
}

pub export fn lua_upvaluejoin(L: ?*lua_State, fidx1: c_int, n1: c_int, fidx2: c_int, n2: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (n1 <= 0 or n2 <= 0) return;
    const left_index: usize = @intCast(n1 - 1);
    const right_index: usize = @intCast(n2 - 1);
    const left = valueAt(thread, fidx1) orelse return;
    const right = valueAt(thread, fidx2) orelse return;
    switch (left) {
        .c_closure => |left_closure| {
            if (right != .c_closure or left_index >= left_closure.upvalues.len or right_index >= right.c_closure.upvalues.len) return;
            left_closure.upvalues[left_index] = right.c_closure.upvalues[right_index];
        },
        .lua_closure => |left_closure| {
            if (right != .lua_closure or left_index >= left_closure.upvalues.len or right_index >= right.lua_closure.upvalues.len) return;
            left_closure.upvalues[left_index] = right.lua_closure.upvalues[right_index];
        },
        else => {},
    }
}
pub export fn lua_sethook(L: ?*lua_State, hook: lua_Hook, mask: c_int, count: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (hook == null or mask == 0) {
        thread.debug_hook = null;
        thread.debug_hook_mask = 0;
        thread.debug_hook_count = 0;
    } else {
        thread.debug_hook = hook;
        thread.debug_hook_mask = mask;
        thread.debug_hook_count = count;
    }
    if (thread.runtime_thread) |target| applyDebugHook(thread, target);
}

pub export fn lua_gethook(L: ?*lua_State) callconv(.c) lua_Hook {
    const thread = threadFromState(L) orelse return null;
    return thread.debug_hook;
}

pub export fn lua_gethookmask(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    return thread.debug_hook_mask;
}

pub export fn lua_gethookcount(L: ?*lua_State) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    return thread.debug_hook_count;
}

pub export fn luaL_checkversion_(L: ?*lua_State, version: lua_Number, sizes: usize) callconv(.c) void {
    if (version != LUA_VERSION_NUM or sizes != LUAL_NUMSIZES) {
        _ = luaL_error(L, zstr("core and library have incompatible numeric types"));
    }
}

pub export fn luaL_getmetafield(L: ?*lua_State, idx: c_int, field: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNIL;
    const value = valueAt(thread, idx) orelse return LUA_TNIL;
    const metatable = cValueMetatable(value) orelse return LUA_TNIL;
    const result = rawTableGetString(thread.owner, metatable, cStringSlice(field));
    if (result == .nil) return LUA_TNIL;
    _ = pushValue(thread, result);
    return result.typeTag();
}

pub export fn luaL_callmeta(L: ?*lua_State, idx: c_int, field: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const abs = lua_absindex(L, idx);
    if (luaL_getmetafield(L, abs, field) == LUA_TNIL) return 0;
    _ = pushValue(thread, valueAt(thread, abs) orelse .nil);
    lua_callk(L, 1, 1, 0, null);
    return 1;
}

pub export fn luaL_tolstring(L: ?*lua_State, idx: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse {
        if (len) |ptr| ptr.* = 0;
        return null;
    };
    const abs = lua_absindex(L, idx);
    if (luaL_callmeta(L, abs, zstr("__tostring")) != 0) {
        if (lua_type(L, -1) != LUA_TSTRING and lua_type(L, -1) != LUA_TNUMBER) {
            _ = luaL_error(L, zstr("'__tostring' must return a string"));
            return null;
        }
        return lua_tolstring(L, -1, len);
    }
    const value = valueAt(thread, abs) orelse .nil;
    switch (value) {
        .integer, .number, .string => _ = pushValue(thread, value),
        .boolean => |boolean| _ = pushStringBytes(thread, if (boolean) "true" else "false"),
        .nil => _ = pushStringBytes(thread, "nil"),
        else => {
            var out = std.ArrayList(u8).empty;
            defer out.deinit(thread.owner.allocator());
            const name_value = metatableField(value, "__name");
            const kind = if (name_value == .string) name_value.string.bytes else auxTypeName(thread, abs);
            appendFmt(&out, thread.owner.allocator(), "{s}: 0x{x}", .{ kind, if (lua_topointer(L, abs)) |ptr| @intFromPtr(ptr) else 0 }) catch return null;
            _ = pushStringBytes(thread, out.items);
        },
    }
    return lua_tolstring(L, -1, len);
}

pub export fn luaL_argerror(L: ?*lua_State, arg: c_int, extramsg: ?[*:0]const u8) callconv(.c) c_int {
    return luaL_error(L, zstr("bad argument #%d (%s)"), arg, extramsg);
}

pub export fn luaL_typeerror(L: ?*lua_State, arg: c_int, tname: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    var message = std.ArrayList(u8).empty;
    defer message.deinit(thread.owner.allocator());
    appendFmt(&message, thread.owner.allocator(), "{s} expected, got {s}", .{ cStringSlice(tname), auxTypeName(thread, arg) }) catch return 0;
    const string = createString(thread.owner, message.items) orelse return 0;
    return luaL_argerror(L, arg, string.bytes.ptr);
}

pub export fn luaL_checklstring(L: ?*lua_State, arg: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    const value = lua_tolstring(L, arg, len) orelse {
        _ = luaL_typeerror(L, arg, zstr("string"));
        return null;
    };
    return value;
}

pub export fn luaL_optlstring(L: ?*lua_State, arg: c_int, def: ?[*:0]const u8, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    const tp = lua_type(L, arg);
    if (tp == LUA_TNONE or tp == LUA_TNIL) {
        if (len) |ptr| ptr.* = cStringSlice(def).len;
        return def;
    }
    return luaL_checklstring(L, arg, len);
}

pub export fn luaL_checknumber(L: ?*lua_State, arg: c_int) callconv(.c) lua_Number {
    var isnum: c_int = 0;
    const value = lua_tonumberx(L, arg, &isnum);
    if (isnum == 0) _ = luaL_typeerror(L, arg, zstr("number"));
    return value;
}

pub export fn luaL_optnumber(L: ?*lua_State, arg: c_int, def: lua_Number) callconv(.c) lua_Number {
    const tp = lua_type(L, arg);
    return if (tp == LUA_TNONE or tp == LUA_TNIL) def else luaL_checknumber(L, arg);
}

pub export fn luaL_checkinteger(L: ?*lua_State, arg: c_int) callconv(.c) lua_Integer {
    var isnum: c_int = 0;
    const value = lua_tointegerx(L, arg, &isnum);
    if (isnum == 0) {
        if (lua_isnumber(L, arg) != 0) {
            _ = luaL_argerror(L, arg, zstr("number has no integer representation"));
        } else {
            _ = luaL_typeerror(L, arg, zstr("number"));
        }
    }
    return value;
}

pub export fn luaL_optinteger(L: ?*lua_State, arg: c_int, def: lua_Integer) callconv(.c) lua_Integer {
    const tp = lua_type(L, arg);
    return if (tp == LUA_TNONE or tp == LUA_TNIL) def else luaL_checkinteger(L, arg);
}

pub export fn luaL_checkstack(L: ?*lua_State, size: c_int, msg: ?[*:0]const u8) callconv(.c) void {
    if (lua_checkstack(L, size) == 0) {
        if (msg) |_| {
            _ = luaL_error(L, zstr("stack overflow (%s)"), msg);
        } else {
            _ = luaL_error(L, zstr("stack overflow"));
        }
    }
}

pub export fn luaL_checktype(L: ?*lua_State, arg: c_int, tag: c_int) callconv(.c) void {
    if (lua_type(L, arg) != tag) _ = luaL_typeerror(L, arg, lua_typename(L, tag));
}

pub export fn luaL_checkany(L: ?*lua_State, arg: c_int) callconv(.c) void {
    if (lua_type(L, arg) == LUA_TNONE) _ = luaL_argerror(L, arg, zstr("value expected"));
}

pub export fn luaL_newmetatable(L: ?*lua_State, tname: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const name = cStringSlice(tname);
    const key = createString(thread.owner, name) orelse return 0;
    const existing = thread.owner.registry_table.get(.{ .string = key });
    if (existing != .nil) {
        _ = pushValue(thread, existing);
        return 0;
    }
    const metatable = createTable(thread.owner, 0, 2) orelse return 0;
    const name_string = createString(thread.owner, name) orelse return 0;
    metatable.set(thread.owner.allocator(), .{ .string = createString(thread.owner, "__name") orelse return 0 }, .{ .string = name_string }) catch return 0;
    thread.owner.registry_table.set(thread.owner.allocator(), .{ .string = key }, .{ .table = metatable }) catch return 0;
    _ = pushValue(thread, .{ .table = metatable });
    return 1;
}

pub export fn luaL_setmetatable(L: ?*lua_State, tname: ?[*:0]const u8) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const key = createString(thread.owner, cStringSlice(tname)) orelse return;
    _ = pushValue(thread, thread.owner.registry_table.get(.{ .string = key }));
    _ = lua_setmetatable(L, -2);
}

pub export fn luaL_testudata(L: ?*lua_State, ud: c_int, tname: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, ud) orelse return null;
    if (value != .userdata) return null;
    const actual = value.userdata.metatable orelse return null;
    const key = createString(thread.owner, cStringSlice(tname)) orelse return null;
    const expected = thread.owner.registry_table.get(.{ .string = key });
    if (expected != .table or expected.table != actual) return null;
    return value.userdata.bytes.ptr;
}

pub export fn luaL_checkudata(L: ?*lua_State, ud: c_int, tname: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return luaL_testudata(L, ud, tname) orelse {
        _ = luaL_typeerror(L, ud, tname);
        return null;
    };
}

pub export fn luaL_where(L: ?*lua_State, _: c_int) callconv(.c) void {
    _ = lua_pushstring(L, zstr(""));
}

pub export fn luaL_error(L: ?*lua_State, fmt: ?[*:0]const u8, ...) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    var args = @cVaStart();
    defer @cVaEnd(&args);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(thread.owner.allocator());
    const format = cStringSlice(fmt);
    var index: usize = 0;
    while (index < format.len) : (index += 1) {
        if (format[index] != '%' or index + 1 >= format.len) {
            out.append(thread.owner.allocator(), format[index]) catch return 0;
            continue;
        }
        index += 1;
        switch (format[index]) {
            '%' => out.append(thread.owner.allocator(), '%') catch return 0,
            's' => out.appendSlice(thread.owner.allocator(), cStringSlice(@cVaArg(&args, ?[*:0]const u8))) catch return 0,
            'd' => appendFmt(&out, thread.owner.allocator(), "{d}", .{@cVaArg(&args, c_int)}) catch return 0,
            'I' => appendFmt(&out, thread.owner.allocator(), "{d}", .{@cVaArg(&args, lua_Integer)}) catch return 0,
            'f' => appendFmt(&out, thread.owner.allocator(), "{d}", .{@cVaArg(&args, f64)}) catch return 0,
            'c' => out.append(thread.owner.allocator(), @intCast(@cVaArg(&args, c_int))) catch return 0,
            else => {
                out.append(thread.owner.allocator(), '%') catch return 0;
                out.append(thread.owner.allocator(), format[index]) catch return 0;
            },
        }
    }
    _ = pushStringBytes(thread, out.items);
    return lua_error(L);
}

pub export fn luaL_checkoption(L: ?*lua_State, arg: c_int, def: ?[*:0]const u8, list: [*]const ?[*:0]const u8) callconv(.c) c_int {
    const name = luaL_optlstring(L, arg, def, null) orelse zstr("");
    var index: c_int = 0;
    while (list[@intCast(index)]) |entry| : (index += 1) {
        if (std.mem.eql(u8, std.mem.span(entry), std.mem.span(name))) return index;
    }
    const message = lua_pushfstring(L, zstr("invalid option '%s'"), name);
    return luaL_argerror(L, arg, message);
}

pub export fn luaL_fileresult(L: ?*lua_State, stat: c_int, fname: ?[*:0]const u8) callconv(.c) c_int {
    if (stat != 0) {
        lua_pushboolean(L, 1);
        return 1;
    }
    const err = currentErrno();
    lua_pushnil(L);
    const message = cStringSlice(strerror(err));
    if (fname) |name| {
        _ = lua_pushfstring(L, zstr("%s: %s"), name, if (message.len == 0) zstr("(no extra info)") else (strerror(err) orelse zstr("(no extra info)")));
    } else {
        _ = lua_pushstring(L, if (message.len == 0) zstr("(no extra info)") else (strerror(err) orelse zstr("(no extra info)")));
    }
    lua_pushinteger(L, err);
    return 3;
}

pub export fn luaL_execresult(L: ?*lua_State, stat: c_int) callconv(.c) c_int {
    if (stat != 0 and currentErrno() != 0) return luaL_fileresult(L, 0, null);
    var code = stat;
    var what = zstr("exit");
    if ((stat & 0x7f) == 0) {
        code = (stat >> 8) & 0xff;
    } else if (((stat & 0x7f) + 1) >= 2) {
        code = stat & 0x7f;
        what = zstr("signal");
    }
    if (std.mem.eql(u8, std.mem.span(what), "exit") and code == 0) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushnil(L);
    }
    _ = lua_pushstring(L, what);
    lua_pushinteger(L, code);
    return 3;
}

extern fn malloc(usize) ?*anyopaque;
extern fn realloc(?*anyopaque, usize) ?*anyopaque;
extern fn free(?*anyopaque) void;
extern fn strerror(c_int) ?[*:0]const u8;
extern fn __errno_location() *c_int;
extern fn fopen(?[*:0]const u8, ?[*:0]const u8) ?*anyopaque;
extern fn fseek(?*anyopaque, c_long, c_int) c_int;
extern fn ftell(?*anyopaque) c_long;
extern fn rewind(?*anyopaque) void;
extern fn fread(?*anyopaque, usize, usize, ?*anyopaque) usize;
extern fn fclose(?*anyopaque) c_int;
extern fn write(c_int, ?*const anyopaque, usize) isize;

fn currentErrno() c_int {
    return __errno_location().*;
}

pub export fn luaL_alloc(_: ?*anyopaque, ptr: ?*anyopaque, _: usize, nsize: usize) callconv(.c) ?*anyopaque {
    if (nsize == 0) {
        free(ptr);
        return null;
    }
    if (ptr == null) return malloc(nsize);
    return realloc(ptr, nsize);
}

pub export fn luaL_ref(L: ?*lua_State, t: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_NOREF;
    if (thread.stack.items.len == 0) return LUA_NOREF;
    if (thread.stack.items[thread.stack.items.len - 1] == .nil) {
        _ = thread.stack.pop();
        return LUA_REFNIL;
    }
    const table_value = valueAt(thread, t) orelse return LUA_NOREF;
    if (table_value != .table) return LUA_NOREF;
    const table = table_value.table;

    var ref: c_int = 0;
    const freelist = table.get(.{ .integer = 1 });
    if (freelist == .integer) ref = @intCast(freelist.integer);
    if (ref != 0) {
        const next = table.get(.{ .integer = ref });
        table.set(thread.owner.allocator(), .{ .integer = 1 }, next) catch return LUA_NOREF;
    } else {
        const length = table.len();
        if (length == 0) table.set(thread.owner.allocator(), .{ .integer = 1 }, .{ .integer = 0 }) catch return LUA_NOREF;
        ref = @intCast(@max(length, 1) + 1);
    }
    const value = thread.stack.pop().?;
    table.set(thread.owner.allocator(), .{ .integer = ref }, value) catch return LUA_NOREF;
    return ref;
}

pub export fn luaL_unref(L: ?*lua_State, t: c_int, ref: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    if (ref < 0) return;
    const table_value = valueAt(thread, t) orelse return;
    if (table_value != .table) return;
    const table = table_value.table;
    const head = table.get(.{ .integer = 1 });
    table.set(thread.owner.allocator(), .{ .integer = ref }, if (head == .nil) .{ .integer = 0 } else head) catch return;
    table.set(thread.owner.allocator(), .{ .integer = 1 }, .{ .integer = ref }) catch return;
}

pub export fn luaL_loadfilex(L: ?*lua_State, filename: ?[*:0]const u8, mode: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const path = cStringSlice(filename);
    if (path.len == 0) {
        _ = pushStringBytes(thread, "cannot open file");
        return LUA_ERRFILE;
    }
    const file = fopen(filename, zstr("rb")) orelse {
        var message = std.ArrayList(u8).empty;
        defer message.deinit(thread.owner.allocator());
        appendFmt(&message, thread.owner.allocator(), "cannot open {s}", .{path}) catch {};
        _ = pushStringBytes(thread, message.items);
        return LUA_ERRFILE;
    };
    defer _ = fclose(file);
    if (fseek(file, 0, 2) != 0) {
        _ = pushStringBytes(thread, "cannot read file");
        return LUA_ERRFILE;
    }
    const size = ftell(file);
    if (size < 0) {
        _ = pushStringBytes(thread, "cannot read file");
        return LUA_ERRFILE;
    }
    rewind(file);
    const source = thread.owner.allocator().alloc(u8, @intCast(size)) catch {
        _ = pushStringBytes(thread, "not enough memory");
        return LUA_ERRMEM;
    };
    defer thread.owner.allocator().free(source);
    const read = fread(source.ptr, 1, source.len, file);
    if (read != source.len) {
        _ = pushStringBytes(thread, "cannot read file");
        return LUA_ERRFILE;
    }
    var name = std.ArrayList(u8).empty;
    defer name.deinit(thread.owner.allocator());
    name.append(thread.owner.allocator(), '@') catch return LUA_ERRMEM;
    name.appendSlice(thread.owner.allocator(), path) catch return LUA_ERRMEM;
    return loadBuffer(thread, source, name.items, if (mode) |ptr| std.mem.span(ptr) else null);
}

pub export fn luaL_loadbufferx(L: ?*lua_State, buff: ?[*]const u8, size: usize, name: ?[*:0]const u8, mode: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const source = if (buff) |ptr| ptr[0..size] else &[_]u8{};
    return loadBuffer(thread, source, cStringSlice(name), if (mode) |ptr| std.mem.span(ptr) else null);
}

pub export fn luaL_loadstring(L: ?*lua_State, s: ?[*:0]const u8) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const source = cStringSlice(s);
    return loadBuffer(thread, source, source, null);
}

pub export fn luaL_newstate() callconv(.c) ?*lua_State {
    const L = lua_newstate(luaL_alloc, null, 0) orelse return null;
    lua_setwarnf(L, warnOn, L);
    return L;
}

fn warnOff(ud: ?*anyopaque, msg: ?[*:0]const u8, tocont: c_int) callconv(.c) void {
    const L: ?*lua_State = if (ud) |ptr| @ptrCast(@alignCast(ptr)) else null;
    if (isWarningControl(msg, tocont, "on")) lua_setwarnf(L, warnOn, L);
}

fn warnOn(ud: ?*anyopaque, msg: ?[*:0]const u8, tocont: c_int) callconv(.c) void {
    const L: ?*lua_State = if (ud) |ptr| @ptrCast(@alignCast(ptr)) else null;
    if (isWarningControl(msg, tocont, "off")) {
        lua_setwarnf(L, warnOff, L);
        return;
    }
    _ = write(2, zstr("Lua warning: "), 13);
    warnContinue(ud, msg, tocont);
}

fn warnContinue(ud: ?*anyopaque, msg: ?[*:0]const u8, tocont: c_int) callconv(.c) void {
    const L: ?*lua_State = if (ud) |ptr| @ptrCast(@alignCast(ptr)) else null;
    const text = cStringSlice(msg);
    if (text.len != 0) _ = write(2, text.ptr, text.len);
    if (tocont != 0) {
        lua_setwarnf(L, warnContinue, L);
    } else {
        _ = write(2, zstr("\n"), 1);
        lua_setwarnf(L, warnOn, L);
    }
}

fn isWarningControl(msg: ?[*:0]const u8, tocont: c_int, comptime command: []const u8) bool {
    if (tocont != 0) return false;
    const text = cStringSlice(msg);
    return text.len == command.len + 1 and text[0] == '@' and std.mem.eql(u8, text[1..], command);
}

pub export fn luaL_makeseed(L: ?*lua_State) callconv(.c) c_uint {
    const thread = threadFromState(L) orelse return 0;
    return @truncate(@intFromPtr(thread) ^ @intFromPtr(thread.owner));
}

pub export fn luaL_len(L: ?*lua_State, idx: c_int) callconv(.c) lua_Integer {
    lua_len(L, idx);
    var isnum: c_int = 0;
    const value = lua_tointegerx(L, -1, &isnum);
    lua_settop(L, -2);
    if (isnum == 0) _ = luaL_error(L, zstr("object length is not an integer"));
    return value;
}

pub export fn luaL_addgsub(buffer: ?*luaL_Buffer, s: ?[*:0]const u8, pattern: ?[*:0]const u8, replacement: ?[*:0]const u8) callconv(.c) void {
    const B = buffer orelse return;
    const source = cStringSlice(s);
    const pat = cStringSlice(pattern);
    const repl = cStringSlice(replacement);
    if (pat.len == 0) {
        luaL_addlstring(B, source.ptr, source.len);
        return;
    }
    var rest = source;
    while (std.mem.indexOf(u8, rest, pat)) |pos| {
        luaL_addlstring(B, rest.ptr, pos);
        luaL_addlstring(B, repl.ptr, repl.len);
        rest = rest[pos + pat.len ..];
    }
    luaL_addlstring(B, rest.ptr, rest.len);
}

pub export fn luaL_gsub(L: ?*lua_State, s: ?[*:0]const u8, pattern: ?[*:0]const u8, replacement: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    var buffer: luaL_Buffer = undefined;
    luaL_buffinit(L, &buffer);
    luaL_addgsub(&buffer, s, pattern, replacement);
    luaL_pushresult(&buffer);
    return lua_tolstring(L, -1, null);
}

pub export fn luaL_setfuncs(L: ?*lua_State, regs: ?*const luaL_Reg, nup: c_int) callconv(.c) void {
    _ = threadFromState(L) orelse return;
    if (nup < 0) return;
    luaL_checkstack(L, nup, zstr("too many upvalues"));
    const upvalue_count: usize = @intCast(nup);
    const list: [*]const luaL_Reg = @ptrCast(regs orelse return);
    var index: usize = 0;
    while (true) : (index += 1) {
        const reg = list[index];
        const name = reg.name orelse break;
        if (reg.func == null) {
            lua_pushboolean(L, 0);
        } else {
            for (0..upvalue_count) |_| lua_pushvalue(L, -nup);
            lua_pushcclosure(L, reg.func, nup);
        }
        lua_setfield(L, -(nup + 2), name);
    }
    lua_settop(L, -nup - 1);
}

pub export fn luaL_getsubtable(L: ?*lua_State, idx: c_int, field: ?[*:0]const u8) callconv(.c) c_int {
    if (lua_getfield(L, idx, field) == LUA_TTABLE) return 1;
    lua_settop(L, -2);
    const abs = lua_absindex(L, idx);
    lua_createtable(L, 0, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, abs, field);
    return 0;
}

pub export fn luaL_traceback(L: ?*lua_State, _: ?*lua_State, msg: ?[*:0]const u8, _: c_int) callconv(.c) void {
    if (msg) |text| {
        _ = lua_pushfstring(L, zstr("%s\nstack traceback:"), text);
    } else {
        _ = lua_pushstring(L, zstr("stack traceback:"));
    }
}

pub export fn luaL_requiref(L: ?*lua_State, modname: ?[*:0]const u8, openf: lua_CFunction, glb: c_int) callconv(.c) void {
    _ = luaL_getsubtable(L, LUA_REGISTRYINDEX, zstr(LUA_LOADED_TABLE));
    _ = lua_getfield(L, -1, modname);
    if (lua_toboolean(L, -1) == 0) {
        lua_settop(L, -2);
        lua_pushcclosure(L, openf, 0);
        _ = lua_pushstring(L, modname);
        lua_callk(L, 1, 1, 0, null);
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, modname);
    }
    lua_rotate(L, -2, -1);
    lua_settop(L, -2);
    if (glb != 0) {
        lua_pushvalue(L, -1);
        lua_setglobal(L, modname);
    }
}

pub export fn luaL_buffinit(L: ?*lua_State, buffer: ?*luaL_Buffer) callconv(.c) void {
    const B = buffer orelse return;
    B.L = L;
    B.b = initBufferPtr(B);
    B.n = 0;
    B.size = LUAL_BUFFERSIZE;
    lua_pushlightuserdata(L, B);
}

pub export fn luaL_prepbuffsize(buffer: ?*luaL_Buffer, size: usize) callconv(.c) ?[*]u8 {
    const B = buffer orelse return null;
    if (B.b == null) return null;
    if (B.size - B.n >= size) return B.b.? + B.n;
    const thread = threadFromState(B.L) orelse return null;
    const new_size = @max(B.n + size + 1, B.size + B.size / 2);
    const storage = thread.owner.allocator().alloc(u8, new_size) catch return null;
    if (B.n != 0) @memcpy(storage[0..B.n], B.b.?[0..B.n]);
    if (B.b.? != initBufferPtr(B)) thread.owner.allocator().free(B.b.?[0..B.size]);
    B.b = storage.ptr;
    B.size = storage.len;
    return B.b.? + B.n;
}

pub export fn luaL_addlstring(buffer: ?*luaL_Buffer, s: ?[*]const u8, len: usize) callconv(.c) void {
    if (len == 0) return;
    const B = buffer orelse return;
    const ptr = s orelse return;
    const dest = luaL_prepbuffsize(B, len) orelse return;
    @memcpy(dest[0..len], ptr[0..len]);
    B.n += len;
}

pub export fn luaL_addstring(buffer: ?*luaL_Buffer, s: ?[*:0]const u8) callconv(.c) void {
    const text = cStringSlice(s);
    luaL_addlstring(buffer, text.ptr, text.len);
}

pub export fn luaL_addvalue(buffer: ?*luaL_Buffer) callconv(.c) void {
    const B = buffer orelse return;
    var len: usize = 0;
    const text = lua_tolstring(B.L, -1, &len) orelse return;
    luaL_addlstring(B, text, len);
    lua_settop(B.L, -2);
}

pub export fn luaL_pushresult(buffer: ?*luaL_Buffer) callconv(.c) void {
    const B = buffer orelse return;
    _ = lua_pushlstring(B.L, B.b, B.n);
    if (B.b != null and B.b.? != initBufferPtr(B)) {
        if (threadFromState(B.L)) |thread| thread.owner.allocator().free(B.b.?[0..B.size]);
    }
    B.b = initBufferPtr(B);
    B.size = LUAL_BUFFERSIZE;
    B.n = 0;
    lua_rotate(B.L, -2, -1);
    lua_settop(B.L, -2);
}

pub export fn luaL_pushresultsize(buffer: ?*luaL_Buffer, size: usize) callconv(.c) void {
    const B = buffer orelse return;
    B.n += size;
    luaL_pushresult(B);
}

pub export fn luaL_buffinitsize(L: ?*lua_State, buffer: ?*luaL_Buffer, size: usize) callconv(.c) ?[*]u8 {
    luaL_buffinit(L, buffer);
    return luaL_prepbuffsize(buffer, size);
}

fn clearGlobalValue(state: *CState, name: []const u8) void {
    const key = createString(state, name) orelse return;
    state.global_table.set(state.allocator(), .{ .string = key }, .nil) catch {};
    if (state.runtime_state.global_table) |table| table.set(state.runtime_state.allocator, .{ .string = name }, .nil) catch {};
    if (state.runtime_state.globals.getKey(name)) |existing| state.runtime_state.globals.put(existing, .nil) catch {};
}

fn openRuntimeLibraries(L: ?*lua_State, libraries: stdlib.LibrarySet, result_name: []const u8, install_global: bool) c_int {
    const thread = threadFromState(L) orelse return 0;
    stdlib.openLibraries(&thread.owner.runtime_state, .{ .libraries = libraries }) catch return 0;
    stdlib.installGlobalTable(&thread.owner.runtime_state) catch return 0;
    syncRuntimeGlobalsToC(thread.owner);
    const result = if (std.mem.eql(u8, result_name, LUA_GNAME))
        Value{ .table = thread.owner.global_table }
    else blk: {
        const key = createString(thread.owner, result_name) orelse return 0;
        break :blk thread.owner.global_table.get(.{ .string = key });
    };
    if (!install_global and !std.mem.eql(u8, result_name, LUA_GNAME)) clearGlobalValue(thread.owner, result_name);
    if (std.mem.eql(u8, result_name, LUA_GNAME)) {
        _ = pushValue(thread, .{ .table = thread.owner.global_table });
    } else {
        _ = pushValue(thread, result);
    }
    return 1;
}

fn librarySetForMask(mask: c_int) stdlib.LibrarySet {
    return .{
        .base = (mask & LUA_GLIBK) != 0,
        .package = (mask & LUA_LOADLIBK) != 0,
        .coroutine = (mask & LUA_COLIBK) != 0,
        .debug = (mask & LUA_DBLIBK) != 0,
        .io = (mask & LUA_IOLIBK) != 0,
        .math = (mask & LUA_MATHLIBK) != 0,
        .os = (mask & LUA_OSLIBK) != 0,
        .string = (mask & LUA_STRLIBK) != 0,
        .table = (mask & LUA_TABLIBK) != 0,
        .utf8 = (mask & LUA_UTF8LIBK) != 0,
    };
}

pub export fn luaopen_base(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .base = true }, LUA_GNAME, true);
}

pub export fn luaopen_package(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .package = true }, "package", false);
}

pub export fn luaopen_coroutine(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .coroutine = true }, "coroutine", false);
}

pub export fn luaopen_debug(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .debug = true }, "debug", false);
}

pub export fn luaopen_io(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .io = true }, "io", false);
}

pub export fn luaopen_math(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .math = true }, "math", false);
}

pub export fn luaopen_os(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .os = true }, "os", false);
}

pub export fn luaopen_string(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .string = true }, "string", false);
}

pub export fn luaopen_table(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .table = true }, "table", false);
}

pub export fn luaopen_utf8(L: ?*lua_State) callconv(.c) c_int {
    return openRuntimeLibraries(L, .{ .utf8 = true }, "utf8", false);
}

const StdLibEntry = struct {
    name: [:0]const u8,
    mask: c_int,
    open: lua_CFunction,
};

const stdlibs = [_]StdLibEntry{
    .{ .name = LUA_GNAME, .mask = LUA_GLIBK, .open = luaopen_base },
    .{ .name = "package", .mask = LUA_LOADLIBK, .open = luaopen_package },
    .{ .name = "coroutine", .mask = LUA_COLIBK, .open = luaopen_coroutine },
    .{ .name = "debug", .mask = LUA_DBLIBK, .open = luaopen_debug },
    .{ .name = "io", .mask = LUA_IOLIBK, .open = luaopen_io },
    .{ .name = "math", .mask = LUA_MATHLIBK, .open = luaopen_math },
    .{ .name = "os", .mask = LUA_OSLIBK, .open = luaopen_os },
    .{ .name = "string", .mask = LUA_STRLIBK, .open = luaopen_string },
    .{ .name = "table", .mask = LUA_TABLIBK, .open = luaopen_table },
    .{ .name = "utf8", .mask = LUA_UTF8LIBK, .open = luaopen_utf8 },
};

pub export fn luaL_openselectedlibs(L: ?*lua_State, load: c_int, preload: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const libraries = librarySetForMask(load);
    if (!libraries.isEmpty()) {
        stdlib.openLibraries(&thread.owner.runtime_state, .{ .libraries = libraries }) catch return;
        stdlib.installGlobalTable(&thread.owner.runtime_state) catch return;
        syncRuntimeGlobalsToC(thread.owner);
    }
    _ = luaL_getsubtable(L, LUA_REGISTRYINDEX, zstr(LUA_PRELOAD_TABLE));
    for (stdlibs) |lib| {
        if ((load & lib.mask) != 0) {
            const value = if (std.mem.eql(u8, lib.name, LUA_GNAME)) Value{ .table = thread.owner.global_table } else blk: {
                const key = createString(thread.owner, lib.name) orelse break :blk Value.nil;
                break :blk thread.owner.global_table.get(.{ .string = key });
            };
            _ = setGlobalValue(thread, lib.name, value);
            _ = luaL_getsubtable(L, LUA_REGISTRYINDEX, zstr(LUA_LOADED_TABLE));
            _ = pushValue(thread, value);
            lua_setfield(L, -2, lib.name.ptr);
            lua_settop(L, -2);
        } else if ((preload & lib.mask) != 0) {
            lua_pushcclosure(L, lib.open, 0);
            lua_setfield(L, -2, lib.name.ptr);
        }
    }
    lua_settop(L, -2);
}
