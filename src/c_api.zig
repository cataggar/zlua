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

pub export const lua_ident: [18:0]u8 = "zlua C API phase 3".*;

const LUA_MULTRET: c_int = -1;
const LUA_OK: c_int = 0;
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
            .lua_closure, .c_closure => LUA_TFUNCTION,
        };
    }
};

const CString = struct {
    bytes: [:0]u8,

    fn deinit(self: *CString, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
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
    stack: std.ArrayList(Value) = .empty,
    to_close_slots: std.ArrayList(usize) = .empty,
    status: c_int = 0,
    pending_error: ?Value = null,
    current_c_closure: ?*runtime.CClosure = null,
    c_call_depth: usize = 0,

    fn deinit(self: *CThread) void {
        self.to_close_slots.deinit(self.owner.allocator());
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
    strings: std.ArrayList(*CString) = .empty,
    tables: std.ArrayList(*CTable) = .empty,
    userdata: std.ArrayList(*CUserdata) = .empty,
    panicf: lua_CFunction = null,

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

fn pushStringBytes(thread: *CThread, bytes: []const u8) ?*CString {
    const string = createString(thread.owner, bytes) orelse return null;
    if (!pushValue(thread, .{ .string = string })) return null;
    return string;
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

fn findUserdataByPtr(state: *CState, ptr: *anyopaque) ?*CUserdata {
    for (state.userdata.items) |userdata| {
        if (userdata.bytes.ptr == @as([*]u8, @ptrCast(ptr))) return userdata;
    }
    return null;
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
    };
}

fn cStringSlice(s: ?[*:0]const u8) []const u8 {
    const ptr = s orelse return &.{};
    return std.mem.span(ptr);
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
        .lua_closure, .c_closure => try out.appendSlice(allocator, "function"),
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
        .string => |string| std.fmt.parseFloat(lua_Number, std.mem.trim(u8, string.bytes, " \t\n\r\x0b\x0c")) catch null,
        else => null,
    };
}

fn toIntegerValue(value: Value) ?lua_Integer {
    return switch (value) {
        .integer => |integer| integer,
        .number => |number| floatToInteger(number),
        .string => |string| blk: {
            const trimmed = std.mem.trim(u8, string.bytes, " \t\n\r\x0b\x0c");
            if (std.fmt.parseInt(lua_Integer, trimmed, 10)) |integer| break :blk integer else |_| {}
            break :blk if (std.fmt.parseFloat(lua_Number, trimmed)) |number| floatToInteger(number) else |_| null;
        },
        else => null,
    };
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
        else => .nil,
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
    thread.c_call_depth += 1;
    defer {
        thread.c_call_depth -= 1;
        thread.current_c_closure = previous_closure;
    }
    const function = functionFromId(closure.function_id);
    const returned = if (function) |func| func(@ptrCast(thread.public_state)) else 0;
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
        .memory_error => return LUA_ERRMEM,
    }
}

fn cClosureDispatch(context: *runtime.CClosureContext) anyerror!void {
    const state: *CState = @ptrCast(@alignCast(context.user_data orelse return error.RuntimeError));
    const thread = &state.main_thread;
    const allocator = state.allocator();
    const args = try allocator.alloc(Value, context.argCount());
    defer allocator.free(args);
    for (args, 0..) |*arg, index| arg.* = try runtimeToCValue(state, context.argValue(index), 0);

    switch (runCClosure(thread, context.closure, args, true)) {
        .success => |results| {
            defer allocator.free(results);
            for (results) |result| try context.appendReturn(try cToRuntimeValue(state, result, 0));
        },
        .failure => |err_value| return context.raise(try cToRuntimeValue(state, err_value, 0)),
        .memory_error => return error.OutOfMemory,
    }
}

fn callLuaClosure(thread: *CThread, closure: *runtime.Closure, args: []const Value, nresults: c_int, protected: bool) c_int {
    const base = thread.stack.items.len - args.len - 1;
    const allocator = thread.owner.allocator();
    const runtime_args = allocator.alloc(runtime.Value, args.len) catch return LUA_ERRMEM;
    defer allocator.free(runtime_args);
    for (args, 0..) |arg, index| runtime_args[index] = cToRuntimeValue(thread.owner, arg, 0) catch return LUA_ERRMEM;

    if (protected) {
        const result = thread.owner.runtime_state.protectedCallLoadedClosure(closure, runtime_args) catch |err| switch (err) {
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

    const runtime_results = thread.owner.runtime_state.callLoadedClosure(closure, runtime_args) catch |err| switch (err) {
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
        else => blk: {
            thread.stack.items.len = base;
            _ = pushStringBytes(thread, "attempt to call a non-function value");
            if (!protected) raiseUnprotected(thread);
            break :blk LUA_ERRRUN;
        },
    };
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
    for (state.tables.items) |table| table.marked = false;
    for (state.userdata.items) |userdata| userdata.marked = false;
}

fn markCValue(state: *CState, value: Value) void {
    switch (value) {
        .table => |table| markCTable(state, table),
        .userdata => |userdata| markCUserdata(state, userdata),
        else => {},
    }
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
    for (thread.stack.items) |value| markCValue(state, value);
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
    state.runtime_state.setCClosureDispatch(cClosureDispatch, state);
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
    thread.deinit();
    state.deinitOwnedObjects();
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
            if (std.fmt.parseFloat(lua_Number, std.mem.trim(u8, string.bytes, " \t\n\r\x0b\x0c"))) |number| {
                if (isnum) |ptr| ptr.* = 1;
                break :blk number;
            } else |_| {
                if (isnum) |ptr| ptr.* = 0;
                break :blk 0;
            }
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

pub export fn lua_pushexternalstring(L: ?*lua_State, s: ?[*]const u8, len: usize, _: lua_Alloc, _: ?*anyopaque) callconv(.c) ?[*:0]const u8 {
    return lua_pushlstring(L, s, len);
}

pub export fn lua_pushstring(L: ?*lua_State, s: ?[*:0]const u8) callconv(.c) ?[*:0]const u8 {
    if (s == null) {
        lua_pushnil(L);
        return null;
    }
    return lua_pushlstring(L, s, std.mem.len(s.?));
}

extern fn vsnprintf(?[*]u8, usize, ?[*:0]const u8, VaList) c_int;

pub export fn lua_pushvfstring(L: ?*lua_State, fmt: ?[*:0]const u8, args: VaList) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    var buffer: [4096]u8 = undefined;
    const written = vsnprintf(&buffer, buffer.len, fmt, args);
    if (written < 0) return lua_pushstring(L, fmt);
    const len: usize = @min(@as(usize, @intCast(written)), buffer.len - 1);
    const string = pushStringBytes(thread, buffer[0..len]) orelse return null;
    return string.bytes.ptr;
}

pub export fn lua_pushfstring(L: ?*lua_State, fmt: ?[*:0]const u8, ...) callconv(.c) ?[*:0]const u8 {
    const thread = threadFromState(L) orelse return null;
    var args = @cVaStart();
    defer @cVaEnd(&args);

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
                const value = @cVaArg(&args, ?[*:0]const u8);
                out.appendSlice(thread.owner.allocator(), cStringSlice(value)) catch return null;
            },
            'd' => {
                const value = @cVaArg(&args, c_int);
                appendFmt(&out, thread.owner.allocator(), "{d}", .{value}) catch return null;
            },
            'I' => {
                const value = @cVaArg(&args, lua_Integer);
                appendFmt(&out, thread.owner.allocator(), "{d}", .{value}) catch return null;
            },
            'f' => {
                const value = @cVaArg(&args, f64);
                appendFmt(&out, thread.owner.allocator(), "{d}", .{value}) catch return null;
            },
            'c' => {
                const value = @cVaArg(&args, c_int);
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
        const value: Value = switch (n) {
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
        .table => |table| table.metatable = switch (metatable_value) {
            .nil => null,
            .table => |metatable| metatable,
            else => table.metatable,
        },
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

pub export fn lua_callk(L: ?*lua_State, nargs: c_int, nresults: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) void {
    const thread = threadFromState(L) orelse return;
    _ = callStackFunction(thread, nargs, nresults, false);
}

pub export fn lua_pcallk(L: ?*lua_State, nargs: c_int, nresults: c_int, msgh: c_int, _: lua_KContext, _: lua_KFunction) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return LUA_ERRRUN;
    const handler_abs = if (msgh == 0) 0 else lua_absindex(L, msgh);
    const handler = if (handler_abs == 0) null else valueAt(thread, handler_abs);
    const status = callStackFunction(thread, nargs, nresults, true);
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

pub export fn lua_gc(L: ?*lua_State, what: c_int, ...) callconv(.c) c_int {
    const thread = threadFromState(L) orelse return 0;
    switch (what) {
        LUA_GCCOLLECT => {
            collectCUserdata(thread);
            thread.owner.runtime_state.collectGarbage() catch {};
            return 0;
        },
        LUA_GCSTOP, LUA_GCRESTART, LUA_GCSTEP => return 0,
        LUA_GCCOUNT, LUA_GCCOUNTB => return 0,
        LUA_GCISRUNNING => return 1,
        else => return 0,
    }
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
    appendValueString(thread.owner.allocator(), &out, value) catch return 0;
    if (buff) |ptr| {
        @memcpy(ptr[0..out.items.len], out.items);
        ptr[out.items.len] = 0;
    }
    return @intCast(out.items.len);
}

pub export fn lua_stringtonumber(L: ?*lua_State, s: ?[*:0]const u8) callconv(.c) usize {
    const thread = threadFromState(L) orelse return 0;
    const text = cStringSlice(s);
    const trimmed = std.mem.trim(u8, text, " \t\n\r\x0b\x0c");
    if (trimmed.len != text.len) return 0;
    if (std.fmt.parseInt(lua_Integer, text, 10)) |integer| {
        _ = pushValue(thread, .{ .integer = integer });
        return text.len + 1;
    } else |_| {}
    if (std.fmt.parseFloat(lua_Number, text)) |number| {
        _ = pushValue(thread, .{ .number = number });
        return text.len + 1;
    } else |_| return 0;
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
    return luaL_testudata(L, ud, tname);
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
extern fn fopen(?[*:0]const u8, ?[*:0]const u8) ?*anyopaque;
extern fn fseek(?*anyopaque, c_long, c_int) c_int;
extern fn ftell(?*anyopaque) c_long;
extern fn rewind(?*anyopaque) void;
extern fn fread(?*anyopaque, usize, usize, ?*anyopaque) usize;
extern fn fclose(?*anyopaque) c_int;

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
    return lua_newstate(luaL_alloc, null, 0);
}

pub export fn luaL_makeseed(_: ?*lua_State) callconv(.c) c_uint {
    return 0;
}

pub export fn luaL_len(L: ?*lua_State, idx: c_int) callconv(.c) lua_Integer {
    lua_len(L, idx);
    const value = lua_tointegerx(L, -1, null);
    lua_settop(L, -2);
    return value;
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
