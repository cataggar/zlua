const std = @import("std");
const runtime = @import("runtime.zig");

pub const lua_State = opaque {};
const lua_Debug = opaque {};
const luaL_Buffer = opaque {};
const luaL_Reg = opaque {};

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

pub export const lua_ident: [18:0]u8 = "zlua C API phase 1".*;

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

const Value = union(enum) {
    nil,
    boolean: bool,
    integer: lua_Integer,
    number: lua_Number,
    table: *CTable,
    thread: *CThread,
    light_userdata: ?*anyopaque,
    c_function: lua_CFunction,

    fn typeTag(self: Value) c_int {
        return switch (self) {
            .nil => LUA_TNIL,
            .boolean => LUA_TBOOLEAN,
            .integer, .number => LUA_TNUMBER,
            .table => LUA_TTABLE,
            .thread => LUA_TTHREAD,
            .light_userdata => LUA_TLIGHTUSERDATA,
            .c_function => LUA_TFUNCTION,
        };
    }
};

const CTable = runtime.Table;

const LuaStateHeader = extern struct {
    thread: *CThread,
};

const CThread = struct {
    owner: *CState,
    public_state: *LuaStateHeader,
    stack: std.ArrayList(Value) = .empty,
    status: c_int = 0,

    fn deinit(self: *CThread) void {
        self.stack.deinit(self.owner.allocator());
    }
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
    panicf: lua_CFunction = null,

    fn allocator(self: *CState) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &lua_allocator_vtable };
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
    return if (stackSlot(thread, idx)) |slot| slot.* else null;
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
        thread.stack.items.len = new_top;
        return;
    }

    const extra = new_top - current;
    if (!ensureStack(thread, extra)) return;
    for (0..extra) |_| thread.stack.appendAssumeCapacity(.nil);
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

    state.registry_table = (state.runtime_state.newTableWithHints(0, 3) catch {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    }).table;

    state.global_table = (state.runtime_state.newTableWithHints(0, 0) catch {
        state.runtime_state.deinit();
        freeHost(StateBlock, f, ud, block);
        freeHost(CState, f, ud, state);
        return null;
    }).table;

    if (!ensureStack(&state.main_thread, LUA_MINSTACK)) return null;
    return @ptrCast(&block.header);
}

pub export fn lua_close(L: ?*lua_State) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    const state = thread.owner;
    const alloc_f = state.alloc_f;
    const alloc_ud = state.alloc_ud;
    const block = state.block;

    thread.deinit();
    state.runtime_state.deinit();
    freeHost(StateBlock, alloc_f, alloc_ud, block);
    freeHost(CState, alloc_f, alloc_ud, state);
}

pub export fn lua_newthread(_: ?*lua_State) callconv(.c) ?*lua_State {
    return null;
}

pub export fn lua_closethread(_: ?*lua_State, _: ?*lua_State) callconv(.c) c_int {
    return 0;
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
    return switch (value) {
        .integer, .number => 1,
        else => 0,
    };
}

pub export fn lua_isstring(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_iscfunction(L: ?*lua_State, idx: c_int) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    const value = valueAt(thread, idx) orelse return 0;
    return switch (value) {
        .c_function => 1,
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
        .light_userdata => 1,
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

pub export fn lua_tolstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn lua_rawlen(_: ?*lua_State, _: c_int) callconv(.c) lua_Unsigned {
    return 0;
}

pub export fn lua_tocfunction(L: ?*lua_State, idx: c_int) callconv(.c) lua_CFunction {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .c_function => |function| function,
        else => null,
    };
}

pub export fn lua_touserdata(L: ?*lua_State, idx: c_int) callconv(.c) ?*anyopaque {
    const thread = threadFromState(L) orelse return null;
    const value = valueAt(thread, idx) orelse return null;
    return switch (value) {
        .light_userdata => |ptr| ptr,
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
        .table => |table| table,
        .thread => |target| target.public_state,
        .light_userdata => |ptr| ptr,
        .c_function => null,
        else => null,
    };
}

pub export fn lua_arith(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_rawequal(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_compare(_: ?*lua_State, _: c_int, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
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

pub export fn lua_pushlstring(_: ?*lua_State, s: ?[*]const u8, _: usize) callconv(.c) ?[*:0]const u8 {
    return @ptrCast(s);
}

pub export fn lua_pushexternalstring(_: ?*lua_State, s: ?[*]const u8, _: usize, _: lua_Alloc, _: ?*anyopaque) callconv(.c) ?[*:0]const u8 {
    return @ptrCast(s);
}

pub export fn lua_pushstring(_: ?*lua_State, s: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return s;
}

pub export fn lua_pushvfstring(_: ?*lua_State, fmt: ?[*:0]const u8, _: VaList) callconv(.c) ?[*:0]const u8 {
    return fmt;
}

pub export fn lua_pushfstring(_: ?*lua_State, fmt: ?[*:0]const u8, ...) callconv(.c) ?[*:0]const u8 {
    return fmt;
}

pub export fn lua_pushcclosure(L: ?*lua_State, function: lua_CFunction, _: c_int) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = pushValue(thread, .{ .c_function = function });
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

pub export fn lua_getglobal(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_gettable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getfield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_geti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) c_int {
    return 0;
}

pub export fn lua_rawget(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_rawgeti(L: ?*lua_State, idx: c_int, n: lua_Integer) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_TNONE;
    if (idx == LUA_REGISTRYINDEX) {
        const value: Value = switch (n) {
            1 => .{ .boolean = false },
            LUA_RIDX_GLOBALS => .{ .table = thread.owner.global_table },
            LUA_RIDX_MAINTHREAD => .{ .thread = &thread.owner.main_thread },
            else => .nil,
        };
        _ = pushValue(thread, value);
        return value.typeTag();
    }
    _ = pushValue(thread, .nil);
    return LUA_TNIL;
}

pub export fn lua_rawgetp(_: ?*lua_State, _: c_int, _: ?*const anyopaque) callconv(.c) c_int {
    return 0;
}

pub export fn lua_createtable(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}

pub export fn lua_newuserdatauv(_: ?*lua_State, _: usize, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn lua_getmetatable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getiuservalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setglobal(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn lua_settable(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_setfield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn lua_seti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) void {}
pub export fn lua_rawset(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_rawseti(_: ?*lua_State, _: c_int, _: lua_Integer) callconv(.c) void {}
pub export fn lua_rawsetp(_: ?*lua_State, _: c_int, _: ?*const anyopaque) callconv(.c) void {}

pub export fn lua_setmetatable(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setiuservalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_callk(_: ?*lua_State, _: c_int, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) void {}

pub export fn lua_pcallk(_: ?*lua_State, _: c_int, _: c_int, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) c_int {
    return 0;
}

pub export fn lua_load(_: ?*lua_State, _: lua_Reader, _: ?*anyopaque, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn lua_dump(_: ?*lua_State, _: lua_Writer, _: ?*anyopaque, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_yieldk(_: ?*lua_State, _: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) c_int {
    return 0;
}

pub export fn lua_resume(_: ?*lua_State, _: ?*lua_State, _: c_int, nres: ?*c_int) callconv(.c) c_int {
    if (nres) |ptr| ptr.* = 0;
    return 0;
}

pub export fn lua_status(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_isyieldable(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_setwarnf(_: ?*lua_State, _: lua_WarnFunction, _: ?*anyopaque) callconv(.c) void {}
pub export fn lua_warning(_: ?*lua_State, _: ?[*:0]const u8, _: c_int) callconv(.c) void {}

pub export fn lua_gc(_: ?*lua_State, _: c_int, ...) callconv(.c) c_int {
    return 0;
}

pub export fn lua_error(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_next(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return 0;
}

pub export fn lua_concat(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_len(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_numbertocstring(_: ?*lua_State, _: c_int, buff: ?[*]u8) callconv(.c) c_uint {
    if (buff) |ptr| ptr[0] = 0;
    return 0;
}

pub export fn lua_stringtonumber(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) usize {
    return 0;
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
    state.alloc_f = alloc_f;
    state.alloc_ud = ud;
}
pub export fn lua_toclose(_: ?*lua_State, _: c_int) callconv(.c) void {}
pub export fn lua_closeslot(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn lua_getstack(_: ?*lua_State, _: c_int, _: ?*lua_Debug) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getinfo(_: ?*lua_State, _: ?[*:0]const u8, _: ?*lua_Debug) callconv(.c) c_int {
    return 0;
}

pub export fn lua_getlocal(_: ?*lua_State, _: ?*const lua_Debug, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_setlocal(_: ?*lua_State, _: ?*const lua_Debug, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_getupvalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_setupvalue(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?[*:0]const u8 {
    return null;
}

pub export fn lua_upvalueid(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn lua_upvaluejoin(_: ?*lua_State, _: c_int, _: c_int, _: c_int, _: c_int) callconv(.c) void {}
pub export fn lua_sethook(_: ?*lua_State, _: lua_Hook, _: c_int, _: c_int) callconv(.c) void {}

pub export fn lua_gethook(_: ?*lua_State) callconv(.c) lua_Hook {
    return null;
}

pub export fn lua_gethookmask(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn lua_gethookcount(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checkversion_(_: ?*lua_State, _: lua_Number, _: usize) callconv(.c) void {}

pub export fn luaL_getmetafield(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_callmeta(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_tolstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn luaL_argerror(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_typeerror(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checklstring(_: ?*lua_State, _: c_int, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return null;
}

pub export fn luaL_optlstring(_: ?*lua_State, _: c_int, def: ?[*:0]const u8, len: ?*usize) callconv(.c) ?[*:0]const u8 {
    if (len) |ptr| ptr.* = 0;
    return def;
}

pub export fn luaL_checknumber(_: ?*lua_State, _: c_int) callconv(.c) lua_Number {
    return 0;
}

pub export fn luaL_optnumber(_: ?*lua_State, _: c_int, def: lua_Number) callconv(.c) lua_Number {
    return def;
}

pub export fn luaL_checkinteger(_: ?*lua_State, _: c_int) callconv(.c) lua_Integer {
    return 0;
}

pub export fn luaL_optinteger(_: ?*lua_State, _: c_int, def: lua_Integer) callconv(.c) lua_Integer {
    return def;
}

pub export fn luaL_checkstack(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn luaL_checktype(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}
pub export fn luaL_checkany(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn luaL_newmetatable(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_setmetatable(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) void {}

pub export fn luaL_testudata(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn luaL_checkudata(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return null;
}

pub export fn luaL_where(_: ?*lua_State, _: c_int) callconv(.c) void {}

pub export fn luaL_error(_: ?*lua_State, _: ?[*:0]const u8, ...) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_checkoption(_: ?*lua_State, _: c_int, _: ?[*:0]const u8, _: [*]const ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_fileresult(_: ?*lua_State, stat: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return stat;
}

pub export fn luaL_execresult(_: ?*lua_State, stat: c_int) callconv(.c) c_int {
    return stat;
}

extern fn malloc(usize) ?*anyopaque;
extern fn realloc(?*anyopaque, usize) ?*anyopaque;
extern fn free(?*anyopaque) void;

pub export fn luaL_alloc(_: ?*anyopaque, ptr: ?*anyopaque, _: usize, nsize: usize) callconv(.c) ?*anyopaque {
    if (nsize == 0) {
        free(ptr);
        return null;
    }
    if (ptr == null) return malloc(nsize);
    return realloc(ptr, nsize);
}

pub export fn luaL_ref(_: ?*lua_State, _: c_int) callconv(.c) c_int {
    return -2;
}

pub export fn luaL_unref(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}

pub export fn luaL_loadfilex(_: ?*lua_State, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_loadbufferx(_: ?*lua_State, _: ?[*]const u8, _: usize, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_loadstring(_: ?*lua_State, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_newstate() callconv(.c) ?*lua_State {
    return lua_newstate(luaL_alloc, null, 0);
}

pub export fn luaL_makeseed(_: ?*lua_State) callconv(.c) c_uint {
    return 0;
}

pub export fn luaL_len(_: ?*lua_State, _: c_int) callconv(.c) lua_Integer {
    return 0;
}

pub export fn luaL_addgsub(_: ?*luaL_Buffer, _: ?[*:0]const u8, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) void {}

pub export fn luaL_gsub(_: ?*lua_State, s: ?[*:0]const u8, _: ?[*:0]const u8, _: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return s;
}

pub export fn luaL_setfuncs(_: ?*lua_State, _: ?*const luaL_Reg, _: c_int) callconv(.c) void {}

pub export fn luaL_getsubtable(_: ?*lua_State, _: c_int, _: ?[*:0]const u8) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_traceback(_: ?*lua_State, _: ?*lua_State, _: ?[*:0]const u8, _: c_int) callconv(.c) void {}
pub export fn luaL_requiref(_: ?*lua_State, _: ?[*:0]const u8, _: lua_CFunction, _: c_int) callconv(.c) void {}
pub export fn luaL_buffinit(_: ?*lua_State, _: ?*luaL_Buffer) callconv(.c) void {}

pub export fn luaL_prepbuffsize(_: ?*luaL_Buffer, _: usize) callconv(.c) ?[*]u8 {
    return null;
}

pub export fn luaL_addlstring(_: ?*luaL_Buffer, _: ?[*]const u8, _: usize) callconv(.c) void {}
pub export fn luaL_addstring(_: ?*luaL_Buffer, _: ?[*:0]const u8) callconv(.c) void {}
pub export fn luaL_addvalue(_: ?*luaL_Buffer) callconv(.c) void {}
pub export fn luaL_pushresult(_: ?*luaL_Buffer) callconv(.c) void {}
pub export fn luaL_pushresultsize(_: ?*luaL_Buffer, _: usize) callconv(.c) void {}

pub export fn luaL_buffinitsize(_: ?*lua_State, _: ?*luaL_Buffer, _: usize) callconv(.c) ?[*]u8 {
    return null;
}

pub export fn luaopen_base(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_package(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_coroutine(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_debug(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_io(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_math(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_os(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_string(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_table(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaopen_utf8(_: ?*lua_State) callconv(.c) c_int {
    return 0;
}

pub export fn luaL_openselectedlibs(_: ?*lua_State, _: c_int, _: c_int) callconv(.c) void {}
