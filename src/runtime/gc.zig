const std = @import("std");
const compile = @import("../compile.zig");
const types = @import("types.zig");
const value_mod = @import("value.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

const RuntimeErrorPayload = types.RuntimeErrorPayload;
const ProtectedCallResult = types.ProtectedCallResult;
const Value = types.Value;
const NativeFn = types.NativeFn;
const Closure = types.Closure;
const CClosure = types.CClosure;
const CUpvalue = types.CUpvalue;
const Upvalue = types.Upvalue;
const TableEntry = types.TableEntry;
const Table = types.Table;
const Userdata = types.Userdata;
const Thread = types.Thread;
const StringAllocation = types.StringAllocation;
const GcMode = types.GcMode;
const GcParam = types.GcParam;
const WeakMode = types.WeakMode;
const RuntimeAllocationStats = types.RuntimeAllocationStats;

const argValue = value_mod.argValue;
const toInteger = value_mod.toInteger;
const localActiveAt = value_mod.localActiveAt;

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
        .native_coroutine_isyieldable,
        .native_coroutine_close,
        .native_coroutine_wrap,
        .native,
        => true,
        else => false,
    };
}

fn functionLike(value: Value) bool {
    return switch (value) {
        .closure, .c_closure, .coroutine_wrapper, .gmatch_iterator => true,
        else => isNativeCallable(value),
    };
}

pub fn noteAllocation(comptime State: type, self: *State, bytes: usize) void {
    self.gc_known_total = self.gc_known_total +| bytes;
}

pub fn noteAllocationFreed(comptime State: type, self: *State, bytes: usize) void {
    self.gc_known_total = if (bytes > self.gc_known_total) 0 else self.gc_known_total - bytes;
}

pub fn refreshAllocationTotal(comptime State: type, self: *State) usize {
    const total = allocationStats(State, self.*).total();
    self.gc_known_total = total;
    return total;
}

pub fn currentAllocationTotal(comptime State: type, self: *State) usize {
    return self.gc_known_total;
}

pub fn tableCapacityBytes(table: *const Table) usize {
    return table.array.capacity * @sizeOf(Value) + table.entries.capacity * @sizeOf(TableEntry);
}

pub fn tableGcBytes(table: *const Table) usize {
    if (!table.counts_for_gc_count) return 0;
    return @sizeOf(Table) + tableCapacityBytes(table);
}

pub fn noteTableCapacityDelta(comptime State: type, self: *State, table: *const Table, old_capacity_bytes: usize) void {
    if (!table.counts_for_gc_count) return;
    const new_capacity_bytes = tableCapacityBytes(table);
    if (new_capacity_bytes > old_capacity_bytes) noteAllocation(State, self, new_capacity_bytes - old_capacity_bytes);
}

pub fn collectGarbageValue(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void {
    const option = argValue(self, thread, op, 0);
    if (option == .nil or (option == .string and std.mem.eql(u8, option.string, "collect"))) {
        if (self.is_collecting) {
            try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = false }});
            return;
        }
        if (self.conservative_gc_depth != 0) {
            try collectGarbageConservatively(State, self, thread);
        } else {
            try collectGarbageWithFinalizers(State, self, thread);
        }
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = 0 }});
        return;
    }
    if (option == .string and std.mem.eql(u8, option.string, "step")) {
        const budget = if (op.arg_count >= 2) toInteger(argValue(self, thread, op, 1)) orelse return self.fail("number expected") else 0;
        const complete = try collectGarbageStep(State, self, thread, budget);
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = complete }});
        return;
    }
    if (option == .string and std.mem.eql(u8, option.string, "count")) {
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .number = @as(f64, @floatFromInt(refreshAllocationTotal(State, self))) / 1024.0 }});
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
        const param = try collectGarbageParam(State, self, param_value);
        const old = self.gc_params.get(param);
        if (op.arg_count >= 3) {
            const new_value = toInteger(argValue(self, thread, op, 2)) orelse return self.fail("number expected");
            self.gc_params.set(param, new_value);
        }
        try self.returnValues(thread, op.base, op.return_count, &.{.{ .integer = old }});
        return;
    }
    return self.failArgumentMessage("collectgarbage", 1, "invalid option");
}

pub fn collectGarbageParam(comptime State: type, self: *State, value: Value) !GcParam {
    if (value != .string) return self.fail("bad argument #2 to 'collectgarbage'");
    if (std.mem.eql(u8, value.string, "minormul")) return .minormul;
    if (std.mem.eql(u8, value.string, "majorminor")) return .majorminor;
    if (std.mem.eql(u8, value.string, "minormajor")) return .minormajor;
    if (std.mem.eql(u8, value.string, "pause")) return .pause;
    if (std.mem.eql(u8, value.string, "stepmul")) return .stepmul;
    if (std.mem.eql(u8, value.string, "stepsize")) return .stepsize;
    return self.fail("bad argument #2 to 'collectgarbage'");
}

pub fn collectGarbageStep(comptime State: type, self: *State, thread: ?*Thread, budget: i64) !bool {
    _ = budget;
    if (self.conservative_gc_depth != 0) {
        try collectGarbageConservatively(State, self, thread);
    } else {
        try collectGarbageWithFinalizers(State, self, thread);
    }
    return false;
}

pub fn collectGarbage(comptime State: type, self: *State) !void {
    try collectGarbageWithFinalizers(State, self, self.current_thread);
}

pub fn collectGarbageStepPublic(comptime State: type, self: *State, budget: i64) !bool {
    return collectGarbageStep(State, self, self.current_thread, budget);
}

pub fn allocationByteCount(comptime State: type, self: State) usize {
    return allocationStats(State, self).total();
}

pub fn gcIsRunning(comptime State: type, self: State) bool {
    return self.gc_running;
}

pub fn stopGc(comptime State: type, self: *State) void {
    self.gc_running = false;
}

pub fn restartGc(comptime State: type, self: *State) void {
    self.gc_running = true;
}

pub fn switchGcMode(comptime State: type, self: *State, mode: GcMode) GcMode {
    const old = self.gc_mode;
    self.gc_mode = mode;
    return old;
}

pub fn gcParam(comptime State: type, self: State, param: GcParam) i64 {
    return self.gc_params.get(param);
}

pub fn setGcParam(comptime State: type, self: *State, param: GcParam, value: i64) void {
    self.gc_params.set(param, value);
}

pub fn collectGarbageConservatively(comptime State: type, self: *State, thread: ?*Thread) !void {
    try collectGarbageWithFinalizersMode(State, self, thread, true);
}

pub fn collectGarbageWithFinalizers(comptime State: type, self: *State, thread: ?*Thread) !void {
    try collectGarbageWithFinalizersMode(State, self, thread, false);
}

pub fn collectGarbageWithFinalizersMode(comptime State: type, self: *State, thread: ?*Thread, mark_all_stack_registers: bool) !void {
    if (self.is_collecting) return;
    self.is_collecting = true;
    const previous_mark_all = self.mark_all_stack_registers;
    self.mark_all_stack_registers = mark_all_stack_registers;
    defer {
        self.mark_all_stack_registers = previous_mark_all;
        self.is_collecting = false;
    }

    resetMarks(State, self);
    markRoots(State, self);
    if (hasWeakTables(State, self)) {
        convergeEphemerons(State, self);
        clearWeakValues(State, self);
    }
    if (self.table_metatable_count != 0) {
        try runPendingFinalizers(State, self, thread);
    }
    runPendingUserdataFinalizers(State, self);
    if (hasWeakTables(State, self)) clearWeakTables(State, self);
    clearDeadHashKeys(State, self);
    sweepThreads(State, self);
    sweepClosures(State, self);
    sweepUpvalues(State, self);
    sweepStrings(State, self);
    sweepUserdata(State, self);
    sweepTables(State, self);
    resetAutoGcThreshold(State, self);
}

pub fn shouldRunAutoGc(comptime State: type, self: *State) bool {
    return !self.is_collecting and currentAllocationTotal(State, self) >= self.gc_next_total;
}

pub fn resetAutoGcThreshold(comptime State: type, self: *State) void {
    const total = refreshAllocationTotal(State, self);
    self.gc_next_total = total + @max(total / 2, 256);
}

pub fn resetMarks(comptime State: type, self: *State) void {
    for (self.string_allocations.items) |*allocation| allocation.marked = false;
    for (self.table_allocations.items) |table| table.marked = false;
    for (self.userdata_allocations.items) |userdata| userdata.marked = false;
    for (self.closure_allocations.items) |closure| closure.marked = false;
    for (self.c_closure_allocations.items) |closure| closure.marked = false;
    for (self.upvalue_allocations.items) |upvalue| upvalue.marked = false;
    for (self.c_upvalue_allocations.items) |upvalue| upvalue.marked = false;
    for (self.thread_allocations.items) |thread| thread.marked = false;
    if (self.current_thread) |thread| {
        var active: ?*Thread = thread;
        while (active) |active_thread| : (active = active_thread.resume_parent) {
            if (!isTrackedThread(State, self, active_thread)) active_thread.marked = false;
        }
    }
}

pub fn markRoots(comptime State: type, self: *State) void {
    var globals = self.globals.iterator();
    while (globals.next()) |entry| {
        markString(State, self, entry.key_ptr.*);
        markValue(State, self, entry.value_ptr.*);
    }
    for (self.api_roots.items) |root| markValue(State, self, root);
    markRuntimeErrorPayload(State, self, self.last_error);
    if (self.current_thread) |thread| markThread(State, self, thread);
    if (self.string_metatable) |metatable| if (isTrackedTable(State, self, metatable)) markTable(State, self, metatable);
    if (self.number_metatable) |metatable| if (isTrackedTable(State, self, metatable)) markTable(State, self, metatable);
    if (self.boolean_metatable) |metatable| if (isTrackedTable(State, self, metatable)) markTable(State, self, metatable);
    if (self.nil_metatable) |metatable| if (isTrackedTable(State, self, metatable)) markTable(State, self, metatable);
    if (self.zerde_null) |table| if (isTrackedTable(State, self, table)) markTable(State, self, table);
    if (self.zerde_array_metatable) |table| if (isTrackedTable(State, self, table)) markTable(State, self, table);
    if (self.zerde_object_metatable) |table| if (isTrackedTable(State, self, table)) markTable(State, self, table);
}

pub fn markValue(comptime State: type, self: *State, value: Value) void {
    switch (value) {
        .string => |string| markString(State, self, string),
        .table => |table| if (isTrackedTable(State, self, table)) markTable(State, self, table),
        .userdata => |userdata| if (isTrackedUserdata(State, self, userdata)) markUserdata(State, self, userdata),
        .closure => |closure| if (isTrackedClosure(State, self, closure)) markClosure(State, self, closure),
        .c_closure => |closure| if (isTrackedCClosure(State, self, closure)) markCClosure(State, self, closure),
        .thread, .coroutine_wrapper => |thread| if (isTrackedThread(State, self, thread) or thread == self.current_thread) markThread(State, self, thread),
        .gmatch_iterator => |table| if (isTrackedTable(State, self, table)) markTable(State, self, table),
        else => {},
    }
}

pub fn markRuntimeErrorPayload(comptime State: type, self: *State, payload: ?RuntimeErrorPayload) void {
    const active = payload orelse return;
    switch (active) {
        .diagnostic => |message| markString(State, self, message),
        .argument => |argument| {
            markString(State, self, argument.function_name);
            switch (argument.detail) {
                .message => |message| markString(State, self, message),
                .expected => |expected| {
                    markString(State, self, expected.expected);
                    markString(State, self, expected.actual);
                },
            }
        },
        .lua_value => |value| markValue(State, self, value),
    }
}

pub fn markString(comptime State: type, self: *State, bytes: []const u8) void {
    if (findStringAllocation(State, self, bytes)) |index| self.string_allocations.items[index].marked = true;
}

pub fn markTable(comptime State: type, self: *State, table: *Table) void {
    if (table.marked) return;
    table.marked = true;
    if (table.metatable) |metatable| markTable(State, self, metatable);
    const weak = weakMode(State, self, table);
    if (weak.keys and weak.values) {
        markWeakTableStrings(State, self, table, true, true);
        return;
    }
    if (weak.values) {
        for (table.entries.items) |entry| if (entry.value != .nil) markValue(State, self, entry.key);
        markWeakTableStrings(State, self, table, false, true);
        return;
    }
    if (weak.keys) {
        for (table.array.items) |value| markValue(State, self, value);
        _ = markEphemeronValues(State, self, table);
        return;
    }
    for (table.array.items) |value| markValue(State, self, value);
    for (table.entries.items) |entry| {
        if (entry.value == .nil) continue;
        markValue(State, self, entry.key);
        markValue(State, self, entry.value);
    }
}

pub fn markUserdata(comptime State: type, self: *State, userdata: *Userdata) void {
    if (userdata.marked) return;
    userdata.marked = true;
    if (userdata.metatable) |metatable| markTable(State, self, metatable);
}

pub fn markWeakTableStrings(comptime State: type, self: *State, table: *Table, keys: bool, values: bool) void {
    if (values) {
        for (table.array.items) |value| markWeakString(State, self, value);
    }
    for (table.entries.items) |entry| {
        if (entry.value == .nil) continue;
        if (keys) markWeakString(State, self, entry.key);
        if (values) markWeakString(State, self, entry.value);
    }
}

pub fn markWeakString(comptime State: type, self: *State, value: Value) void {
    if (value == .string) markString(State, self, value.string);
}

pub fn markClosure(comptime State: type, self: *State, closure: *Closure) void {
    if (closure.marked) return;
    closure.marked = true;
    if (closure.constants) |constants| for (constants) |constant| {
        if (constant) |value| markValue(State, self, value);
    };
    for (closure.upvalues) |upvalue| markUpvalue(State, self, upvalue);
}

pub fn markCClosure(comptime State: type, self: *State, closure: *CClosure) void {
    if (closure.marked) return;
    closure.marked = true;
    for (closure.upvalues) |upvalue| markCUpvalue(State, self, upvalue);
}

pub fn markUpvalue(comptime State: type, self: *State, upvalue: *Upvalue) void {
    if (!isTrackedUpvalue(State, self, upvalue)) return;
    if (upvalue.marked) return;
    upvalue.marked = true;
    if (upvalue.is_open) {
        if (upvalue.stack_index < upvalue.owner.stack.items.len) markValue(State, self, upvalue.owner.stack.items[upvalue.stack_index]);
    } else {
        markValue(State, self, upvalue.closed);
    }
}

pub fn markCUpvalue(comptime State: type, self: *State, upvalue: *CUpvalue) void {
    if (!isTrackedCUpvalue(State, self, upvalue)) return;
    if (upvalue.marked) return;
    upvalue.marked = true;
    markValue(State, self, upvalue.value);
}

pub fn markThread(comptime State: type, self: *State, thread: *Thread) void {
    if (thread.marked) return;
    thread.marked = true;
    markValue(State, self, thread.entry);
    if (thread.resume_parent) |parent| markThread(State, self, parent);
    markThreadStack(State, self, thread);
    markValue(State, self, thread.hook);
    markValue(State, self, thread.hook_level2_func);
    for (thread.hook_transfer_values) |value| markValue(State, self, value);
    for (thread.yield_values.items) |value| markValue(State, self, value);
    if (thread.close_error_value) |value| markValue(State, self, value);
    if (thread.error_traceback) |traceback| markString(State, self, traceback);
    for (thread.protected_continuations.items) |continuation| {
        markRuntimeErrorPayload(State, self, continuation.context.last_error);
        markValue(State, self, continuation.handler);
    }
    for (thread.frames.items) |frame| {
        markClosure(State, self, frame.closure);
        markValue(State, self, frame.vararg_table_local);
        for (frame.varargs) |value| markValue(State, self, value);
        if (frame.pending_returns) |returns| for (returns) |value| markValue(State, self, value);
    }
    var current = thread.open_upvalues;
    while (current) |upvalue| : (current = upvalue.next) markUpvalue(State, self, upvalue);
}

pub fn markThreadStack(comptime State: type, self: *State, thread: *Thread) void {
    if (self.mark_all_stack_registers) {
        markStackRange(State, self, thread, 0, thread.stack.items.len);
        return;
    }
    for (thread.frames.items) |frame| {
        for (frame.proto.locals.items) |local| {
            if (!localActiveAt(local, frame.pc)) continue;
            markStackRange(State, self, thread, frame.base + local.register, 1);
        }
    }
    markStackRange(State, self, thread, thread.last_result_base, thread.last_result_count);
    markStackRange(State, self, thread, thread.last_transfer_base, thread.last_transfer_count);
    markStackRange(State, self, thread, thread.yield_result_base, thread.yield_result_count);
}

pub fn markStackRange(comptime State: type, self: *State, thread: *Thread, base: usize, count: usize) void {
    if (base >= thread.stack.items.len) return;
    const end = @min(thread.stack.items.len, base + count);
    for (thread.stack.items[base..end]) |value| markValue(State, self, value);
}

pub fn weakMode(comptime State: type, self: *State, table: *Table) WeakMode {
    _ = self;
    const metatable = table.metatable orelse return .{};
    const mode = metatable.get(.{ .string = "__mode" });
    if (mode != .string) return .{};
    return .{
        .keys = std.mem.indexOfScalar(u8, mode.string, 'k') != null,
        .values = std.mem.indexOfScalar(u8, mode.string, 'v') != null,
    };
}

pub fn hasWeakTables(comptime State: type, self: *State) bool {
    var current = self.table_metatable_head;
    while (current) |table| : (current = table.metatable_next) {
        const weak = weakMode(State, self, table);
        if (weak.keys or weak.values) return true;
    }
    return false;
}

pub fn markEphemeronValues(comptime State: type, self: *State, table: *Table) bool {
    var changed = false;
    for (table.entries.items) |entry| {
        if (entry.value == .nil) continue;
        if (valueIsWeaklyCleared(State, self, entry.key)) continue;
        markValue(State, self, entry.key);
        if (markValueChanged(State, self, entry.value)) changed = true;
    }
    return changed;
}

pub fn convergeEphemerons(comptime State: type, self: *State) void {
    var changed = true;
    while (changed) {
        changed = false;
        var current = self.table_metatable_head;
        while (current) |table| : (current = table.metatable_next) {
            if (!table.marked) continue;
            const weak = weakMode(State, self, table);
            if (!weak.keys or weak.values) continue;
            if (markEphemeronValues(State, self, table)) changed = true;
        }
    }
}

pub fn markValueChanged(comptime State: type, self: *State, value: Value) bool {
    const was_marked = valueIsMarked(State, self, value);
    markValue(State, self, value);
    return !was_marked and valueIsMarked(State, self, value);
}

pub fn valueIsMarked(comptime State: type, self: *State, value: Value) bool {
    return switch (value) {
        .string => |string| if (findStringAllocation(State, self, string)) |index| self.string_allocations.items[index].marked else true,
        .table => |table| !isTrackedTable(State, self, table) or table.marked,
        .userdata => |userdata| !isTrackedUserdata(State, self, userdata) or userdata.marked,
        .closure => |closure| !isTrackedClosure(State, self, closure) or closure.marked,
        .thread, .coroutine_wrapper => |thread| !isTrackedThread(State, self, thread) or thread.marked,
        else => true,
    };
}

pub fn valueIsWeaklyCleared(comptime State: type, self: *State, value: Value) bool {
    return switch (value) {
        .table => |table| isTrackedTable(State, self, table) and !table.marked,
        .userdata => |userdata| isTrackedUserdata(State, self, userdata) and !userdata.marked,
        .closure => |closure| isTrackedClosure(State, self, closure) and !closure.marked,
        .thread, .coroutine_wrapper => |thread| isTrackedThread(State, self, thread) and !thread.marked,
        else => false,
    };
}

pub fn valueIsCollectableUnmarked(comptime State: type, self: *State, value: Value) bool {
    return switch (value) {
        .string => |string| if (findStringAllocation(State, self, string)) |index| !self.string_allocations.items[index].marked else false,
        .table => |table| isTrackedTable(State, self, table) and !table.marked,
        .userdata => |userdata| isTrackedUserdata(State, self, userdata) and !userdata.marked,
        .closure => |closure| isTrackedClosure(State, self, closure) and !closure.marked,
        .thread, .coroutine_wrapper => |thread| isTrackedThread(State, self, thread) and !thread.marked,
        else => false,
    };
}

pub fn clearWeakValues(comptime State: type, self: *State) void {
    var current = self.table_metatable_head;
    while (current) |table| : (current = table.metatable_next) {
        if (!table.marked) continue;
        if (!weakMode(State, self, table).values) continue;
        clearWeakTableValues(State, self, table);
    }
}

pub fn clearWeakTables(comptime State: type, self: *State) void {
    var current = self.table_metatable_head;
    while (current) |table| : (current = table.metatable_next) {
        if (!table.marked) continue;
        const weak = weakMode(State, self, table);
        if (weak.values) clearWeakTableValues(State, self, table);
        if (weak.keys) clearWeakTableKeys(State, self, table);
    }
}

pub fn clearDeadHashKeys(comptime State: type, self: *State) void {
    for (self.table_allocations.items) |table| {
        if (!table.marked) continue;
        var read_index: usize = 0;
        var write_index: usize = 0;
        while (read_index < table.entries.items.len) : (read_index += 1) {
            const entry = table.entries.items[read_index];
            if (entry.value == .nil and valueIsCollectableUnmarked(State, self, entry.key)) {
                _ = table.entry_index.remove(entry.key);
            } else {
                if (write_index != read_index) table.entries.items[write_index] = entry;
                table.entry_index.getPtr(entry.key).?.* = write_index;
                write_index += 1;
            }
        }
        table.entries.items.len = write_index;
    }
}

pub fn clearWeakTableValues(comptime State: type, self: *State, table: *Table) void {
    for (table.array.items) |*value| {
        if (valueIsWeaklyCleared(State, self, value.*)) value.* = .nil;
    }
    var index: usize = 0;
    while (index < table.entries.items.len) {
        if (valueIsWeaklyCleared(State, self, table.entries.items[index].value)) {
            table.removeEntryAt(index);
        } else {
            index += 1;
        }
    }
}

pub fn clearWeakTableKeys(comptime State: type, self: *State, table: *Table) void {
    var index: usize = 0;
    while (index < table.entries.items.len) {
        if (valueIsWeaklyCleared(State, self, table.entries.items[index].key)) {
            table.removeEntryAt(index);
        } else {
            index += 1;
        }
    }
}

pub fn writeTableBarrier(comptime State: type, self: *State, table: *Table, key: Value, value: Value) void {
    if (!self.is_collecting or !table.marked) return;
    const weak = weakMode(State, self, table);
    if (!weak.keys) markValue(State, self, key);
    if (!weak.values and (!weak.keys or !valueIsWeaklyCleared(State, self, key))) markValue(State, self, value);
}

pub fn writeBarrier(comptime State: type, self: *State, parent_marked: bool, child: Value) void {
    if (!self.is_collecting or !parent_marked) return;
    markValue(State, self, child);
}

pub fn runPendingFinalizers(comptime State: type, self: *State, thread: ?*Thread) !void {
    const active_thread = thread orelse return;
    var ran_finalizer = false;
    var current = self.table_metatable_head;
    while (current) |table| {
        current = table.metatable_next;
        if (table.marked or table.finalized) continue;
        const metatable = table.metatable orelse continue;
        const finalizer = metatable.get(.{ .string = "__gc" });
        if (finalizer == .nil) continue;
        if (weakMode(State, self, metatable).values and valueIsWeaklyCleared(State, self, finalizer)) continue;
        if (!callableValue(State, self, finalizer)) continue;
        markTable(State, self, table);
        table.finalized = true;
        convergeEphemerons(State, self);
        clearWeakValues(State, self);
        clearWeakTables(State, self);
        {
            const saved_stack_len = active_thread.stack.items.len;
            const saved_last_result_base = active_thread.last_result_base;
            const saved_last_result_count = active_thread.last_result_count;
            defer {
                active_thread.stack.items.len = saved_stack_len;
                active_thread.last_result_base = saved_last_result_base;
                active_thread.last_result_count = saved_last_result_count;
            }
            const previous_name = active_thread.next_call_name;
            const previous_namewhat = active_thread.next_call_namewhat;
            active_thread.next_call_name = "__gc";
            active_thread.next_call_namewhat = "metamethod";
            defer {
                active_thread.next_call_name = previous_name;
                active_thread.next_call_namewhat = previous_namewhat;
            }
            _ = try self.callOneResult(active_thread, finalizer, &.{.{ .table = table }});
            try self.runThreadUntil(active_thread, active_thread.frames.items.len);
        }
        ran_finalizer = true;
    }
    if (!ran_finalizer) return;
    resetMarks(State, self);
    markRoots(State, self);
    convergeEphemerons(State, self);
    clearWeakValues(State, self);
}

pub fn runPendingUserdataFinalizers(comptime State: type, self: *State) void {
    var ran_finalizer = false;
    for (self.userdata_allocations.items) |userdata| {
        if (userdata.marked or userdata.finalized) continue;
        const finalizer = userdata.finalizer orelse continue;
        userdata.marked = true;
        userdata.finalized = true;
        finalizer(userdata.ptr, userdata.finalizer_data);
        ran_finalizer = true;
    }
    if (!ran_finalizer) return;
    resetMarks(State, self);
    markRoots(State, self);
    convergeEphemerons(State, self);
    clearWeakValues(State, self);
}

pub fn callableValue(comptime State: type, self: *State, value: Value) bool {
    if (functionLike(value)) return true;
    return (self.getMetamethod(value, "__call") catch null) != null;
}

pub fn sweepStrings(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.string_allocations.items.len) {
        const allocation = self.string_allocations.items[index];
        if (allocation.marked) {
            index += 1;
            continue;
        }
        if (self.strings.get(allocation.bytes)) |interned| {
            if (interned.ptr == allocation.bytes.ptr and interned.len == allocation.bytes.len) _ = self.strings.remove(allocation.bytes);
        }
        if (allocation.bytes.len != 0) _ = self.string_allocation_index.remove(@intFromPtr(allocation.bytes.ptr));
        self.allocator.free(allocation.bytes);
        const moved_index = self.string_allocations.items.len - 1;
        _ = self.string_allocations.swapRemove(index);
        if (index < moved_index) {
            const moved = self.string_allocations.items[index];
            if (moved.bytes.len != 0) self.string_allocation_index.getPtr(@intFromPtr(moved.bytes.ptr)).?.* = index;
        }
    }
}

pub fn sweepUserdata(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.userdata_allocations.items.len) {
        const userdata = self.userdata_allocations.items[index];
        if (userdata.marked) {
            index += 1;
            continue;
        }
        destroyUserdata(State, self, userdata);
        _ = self.userdata_allocations.swapRemove(index);
    }
}

pub fn sweepTables(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.table_allocations.items.len) {
        const table = self.table_allocations.items[index];
        if (table.marked) {
            index += 1;
            continue;
        }
        _ = self.table_allocation_index.remove(@intFromPtr(table));
        destroyTable(State, self, table);
        const moved_index = self.table_allocations.items.len - 1;
        _ = self.table_allocations.swapRemove(index);
        if (index < moved_index) {
            const moved = self.table_allocations.items[index];
            self.table_allocation_index.getPtr(@intFromPtr(moved)).?.* = index;
        }
    }
}

pub fn sweepClosures(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.closure_allocations.items.len) {
        const closure = self.closure_allocations.items[index];
        if (closure.marked) {
            index += 1;
            continue;
        }
        destroyClosure(State, self, closure);
        _ = self.closure_allocations.swapRemove(index);
    }
}

pub fn sweepCClosures(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.c_closure_allocations.items.len) {
        const closure = self.c_closure_allocations.items[index];
        if (closure.marked) {
            index += 1;
            continue;
        }
        destroyCClosure(State, self, closure);
        _ = self.c_closure_allocations.swapRemove(index);
    }
}

pub fn sweepUpvalues(comptime State: type, self: *State) void {
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

pub fn sweepCUpvalues(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.c_upvalue_allocations.items.len) {
        const upvalue = self.c_upvalue_allocations.items[index];
        if (upvalue.marked) {
            index += 1;
            continue;
        }
        self.allocator.destroy(upvalue);
        _ = self.c_upvalue_allocations.swapRemove(index);
    }
}

pub fn sweepThreads(comptime State: type, self: *State) void {
    var index: usize = 0;
    while (index < self.thread_allocations.items.len) {
        const thread = self.thread_allocations.items[index];
        if (thread.marked) {
            index += 1;
            continue;
        }
        self.closeUpvalues(thread, 0);
        destroyThread(State, self, thread);
        _ = self.thread_allocations.swapRemove(index);
    }
}

pub fn findStringAllocation(comptime State: type, self: *State, bytes: []const u8) ?usize {
    if (bytes.len == 0) {
        for (self.string_allocations.items, 0..) |allocation, index| {
            if (allocation.bytes.ptr == bytes.ptr and allocation.bytes.len == bytes.len) return index;
        }
        return null;
    }
    return self.string_allocation_index.get(@intFromPtr(bytes.ptr));
}

pub fn isTrackedThread(comptime State: type, self: *State, thread: *Thread) bool {
    for (self.thread_allocations.items) |allocation| {
        if (allocation == thread) return true;
    }
    return false;
}

pub fn isTrackedTable(comptime State: type, self: *State, table: *Table) bool {
    return self.table_allocation_index.contains(@intFromPtr(table));
}

pub fn isTrackedUserdata(comptime State: type, self: *State, userdata: *Userdata) bool {
    for (self.userdata_allocations.items) |allocation| {
        if (allocation == userdata) return true;
    }
    return false;
}

pub fn isTrackedClosure(comptime State: type, self: *State, closure: *Closure) bool {
    for (self.closure_allocations.items) |allocation| {
        if (allocation == closure) return true;
    }
    return false;
}

pub fn isTrackedCClosure(comptime State: type, self: *State, closure: *CClosure) bool {
    for (self.c_closure_allocations.items) |allocation| {
        if (allocation == closure) return true;
    }
    return false;
}

pub fn isTrackedUpvalue(comptime State: type, self: *State, upvalue: *Upvalue) bool {
    for (self.upvalue_allocations.items) |allocation| {
        if (allocation == upvalue) return true;
    }
    return false;
}

pub fn isTrackedCUpvalue(comptime State: type, self: *State, upvalue: *CUpvalue) bool {
    for (self.c_upvalue_allocations.items) |allocation| {
        if (allocation == upvalue) return true;
    }
    return false;
}

pub fn destroyTable(comptime State: type, self: *State, table: *Table) void {
    if (table.metatable != null) {
        unlinkTableMetatable(State, self, table);
        self.table_metatable_count -= 1;
    }
    table.deinit(self.allocator);
    self.allocator.destroy(table);
}

pub fn destroyUserdata(comptime State: type, self: *State, userdata: *Userdata) void {
    if (!userdata.finalized) {
        if (userdata.finalizer) |finalizer| finalizer(userdata.ptr, userdata.finalizer_data);
        userdata.finalized = true;
    }
    if (userdata.deinit_fn) |deinit_fn| deinit_fn(self.allocator, userdata.ptr);
    self.allocator.destroy(userdata);
}

pub fn destroyClosure(comptime State: type, self: *State, closure: *Closure) void {
    if (closure.constants) |constants| self.allocator.free(constants);
    if (closure.upvalues.len != 0) self.allocator.free(closure.upvalues);
    self.allocator.destroy(closure);
}

pub fn destroyCClosure(comptime State: type, self: *State, closure: *CClosure) void {
    if (closure.upvalues.len != 0) self.allocator.free(closure.upvalues);
    self.allocator.destroy(closure);
}

pub fn destroyThread(comptime State: type, self: *State, thread: *Thread) void {
    thread.deinit(self.allocator);
    self.allocator.destroy(thread);
}

pub fn allocationStats(comptime State: type, self: State) RuntimeAllocationStats {
    var bytes: usize = 0;
    for (self.string_allocations.items) |allocation| bytes += @sizeOf(StringAllocation) + allocation.bytes.len;
    for (self.table_allocations.items) |table| {
        if (table.counts_for_gc_count) bytes += @sizeOf(Table) + table.array.capacity * @sizeOf(Value) + table.entries.capacity * @sizeOf(TableEntry);
    }
    bytes += self.userdata_allocations.items.len * @sizeOf(Userdata);
    bytes += self.closure_allocations.items.len * @sizeOf(Closure);
    for (self.closure_allocations.items) |closure| {
        if (closure.constants) |constants| bytes += constants.len * @sizeOf(?Value);
    }
    bytes += self.c_closure_allocations.items.len * @sizeOf(CClosure);
    bytes += self.upvalue_allocations.items.len * @sizeOf(Upvalue);
    bytes += self.c_upvalue_allocations.items.len * @sizeOf(CUpvalue);
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

pub fn noteTableMetatableChanged(comptime State: type, self: *State, table: *Table, old_has_metatable: bool) void {
    if (!isTrackedTable(State, self, table)) return;
    const new_has_metatable = table.metatable != null;
    if (old_has_metatable == new_has_metatable) return;
    if (new_has_metatable) {
        table.metatable_prev = null;
        table.metatable_next = self.table_metatable_head;
        if (self.table_metatable_head) |head| head.metatable_prev = table;
        self.table_metatable_head = table;
        self.table_metatable_count += 1;
    } else {
        unlinkTableMetatable(State, self, table);
        self.table_metatable_count -= 1;
    }
}

pub fn unlinkTableMetatable(comptime State: type, self: *State, table: *Table) void {
    if (table.metatable_prev) |prev| {
        prev.metatable_next = table.metatable_next;
    } else if (self.table_metatable_head == table) {
        self.table_metatable_head = table.metatable_next;
    }
    if (table.metatable_next) |next| next.metatable_prev = table.metatable_prev;
    table.metatable_prev = null;
    table.metatable_next = null;
}
