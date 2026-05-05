const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const target = runtime.argValue(state, thread, op, 0);
    const value = try state.newTableWithHints(0, 8);
    const table = value.table;
    try table.set(state.allocator, .{ .string = try state.intern("source") }, .{ .string = try state.intern("zlua") });
    try table.set(state.allocator, .{ .string = try state.intern("short_src") }, .{ .string = try state.intern("zlua") });
    try table.set(state.allocator, .{ .string = try state.intern("linedefined") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("lastlinedefined") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nups") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("nparams") }, .{ .integer = 0 });
    try table.set(state.allocator, .{ .string = try state.intern("isvararg") }, .{ .boolean = false });
    const what = switch (target) {
        .integer => "Lua",
        .closure => "Lua",
        .native, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_wrap => "C",
        else => return state.fail("function or level expected"),
    };
    try table.set(state.allocator, .{ .string = try state.intern("what") }, .{ .string = try state.intern(what) });
    const currentline: i64 = if (if (target == .integer) state.currentLine(thread, target.integer) else null) |line| @intCast(line) else -1;
    try table.set(state.allocator, .{ .string = try state.intern("currentline") }, .{ .integer = currentline });
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}
