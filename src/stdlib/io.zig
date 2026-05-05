const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const spec = if (op.arg_count == 0 or runtime.argValue(state, thread, op, 0) == .nil)
        "*l"
    else
        try state.expectString(runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, &.{try state.readStdin(spec)});
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    for (0..op.arg_count) |index| {
        try runtime.appendLuaString(state.allocator, &state.stdout, runtime.argValue(state, thread, op, @intCast(index)));
    }
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn open(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try state.expectString(runtime.argValue(state, thread, op, 0));
    const mode = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        try state.expectString(runtime.argValue(state, thread, op, 1))
    else
        "r";

    if (mode.len == 0) return openFailure(state, thread, op, "invalid file mode");
    switch (mode[0]) {
        'r' => {
            const contents = state.readFileAlloc(path) catch return openFailure(state, thread, op, "cannot open file");
            defer state.allocator.free(contents);
            try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, "r", contents)});
        },
        'w' => try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, "w", "")}),
        'a' => {
            const contents = state.readFileAlloc(path) catch try state.allocator.dupe(u8, "");
            defer state.allocator.free(contents);
            try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, "a", contents)});
        },
        else => return openFailure(state, thread, op, "invalid file mode"),
    }
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = runtime.argValue(state, thread, op, 0);
    if (file != .table or file.table.get(.{ .string = try state.intern("__zlua_file") }) == .nil) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const closed = file.table.get(.{ .string = try state.intern("__zlua_file_closed") });
    const name = if (closed == .boolean and closed.boolean) "closed file" else "file";
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(name) }});
}

pub fn fileRead(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try ensureOpen(state, file);
    const spec = if (op.arg_count < 2 or runtime.argValue(state, thread, op, 1) == .nil)
        "*l"
    else
        try state.expectString(runtime.argValue(state, thread, op, 1));
    const content = try fileString(state, file, "__zlua_file_content");
    var pos = fileInteger(file, "__zlua_file_pos") orelse 1;
    if (pos < 1) pos = 1;
    const start: usize = @intCast(@min(@as(i64, @intCast(content.len)), pos - 1));

    if (std.mem.eql(u8, spec, "*a") or std.mem.eql(u8, spec, "a")) {
        try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = @intCast(content.len + 1) });
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(content[start..]) }});
        return;
    }
    if (std.mem.eql(u8, spec, "*l") or std.mem.eql(u8, spec, "l")) {
        if (start >= content.len) {
            try state.returnValues(thread, op.base, op.return_count, &.{.nil});
            return;
        }
        var end = start;
        while (end < content.len and content[end] != '\n') end += 1;
        const next_pos = if (end < content.len) end + 2 else end + 1;
        try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = @intCast(next_pos) });
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(content[start..end]) }});
        return;
    }
    return state.fail("unsupported read option");
}

pub fn fileWrite(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try ensureOpen(state, file);
    const mode = try fileString(state, file, "__zlua_file_mode");
    if (mode.len == 0 or mode[0] == 'r') return state.fail("file is not writable");
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try out.appendSlice(state.allocator, try fileString(state, file, "__zlua_file_content"));
    var index: u16 = 1;
    while (index < op.arg_count) : (index += 1) {
        try runtime.appendLuaString(state.allocator, &out, runtime.argValue(state, thread, op, index));
    }
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern(out.items) });
    try state.returnValues(thread, op.base, op.return_count, &.{runtime.argValue(state, thread, op, 0)});
}

pub fn fileClose(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    const closed_key = try state.intern("__zlua_file_closed");
    const already_closed = file.get(.{ .string = closed_key });
    if (already_closed == .boolean and already_closed.boolean) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const mode = try fileString(state, file, "__zlua_file_mode");
    if (mode.len != 0 and mode[0] != 'r') {
        try state.writeFile(try fileString(state, file, "__zlua_file_path"), try fileString(state, file, "__zlua_file_content"));
    }
    try file.set(state.allocator, .{ .string = closed_key }, .{ .boolean = true });
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

fn newFile(state: *State, path: []const u8, mode: []const u8, contents: []const u8) !Value {
    const value = try state.newTableWithHints(0, 10);
    const file = value.table;
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file") }, .{ .boolean = true });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_path") }, .{ .string = try state.intern(path) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_mode") }, .{ .string = try state.intern(mode) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern(contents) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = 1 });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_closed") }, .{ .boolean = false });
    try file.set(state.allocator, .{ .string = try state.intern("read") }, .{ .native = .io_file_read });
    try file.set(state.allocator, .{ .string = try state.intern("write") }, .{ .native = .io_file_write });
    try file.set(state.allocator, .{ .string = try state.intern("close") }, .{ .native = .io_file_close });
    return value;
}

fn openFailure(state: *State, thread: *Thread, op: bytecode.Call, message: []const u8) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
}

fn expectFile(state: *State, value: Value) !*runtime.Table {
    if (value != .table or value.table.get(.{ .string = try state.intern("__zlua_file") }) == .nil) return state.fail("file expected");
    return value.table;
}

fn ensureOpen(state: *State, file: *runtime.Table) !void {
    const closed = file.get(.{ .string = try state.intern("__zlua_file_closed") });
    if (closed == .boolean and closed.boolean) return state.fail("attempt to use a closed file");
}

fn fileString(state: *State, file: *runtime.Table, name: []const u8) ![]const u8 {
    return state.expectString(file.get(.{ .string = try state.intern(name) }));
}

fn fileInteger(file: *runtime.Table, comptime name: []const u8) ?i64 {
    const value = file.get(.{ .string = name });
    return runtime.toInteger(value);
}
