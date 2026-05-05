const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn loadfile(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try state.expectString(runtime.argValue(state, thread, op, 0));
    const closure = state.loadFileAsClosure(path) catch {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("cannot open file") } });
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{closure});
}

pub fn dofile(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try state.expectString(runtime.argValue(state, thread, op, 0));
    const closure = try state.loadFileAsClosure(path);
    const values = try state.callCollect(thread, closure, &.{});
    defer state.allocator.free(values);
    try state.returnValues(thread, op.base, op.return_count, values);
}

pub fn require(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectString(runtime.argValue(state, thread, op, 0));
    const package = try packageTable(state);
    const loaded = try state.expectTable(package.get(.{ .string = try state.intern("loaded") }));
    const preload = try state.expectTable(package.get(.{ .string = try state.intern("preload") }));
    const name_key = Value{ .string = try state.intern(name) };

    const cached = loaded.get(name_key);
    if (cached != .nil and !(cached == .boolean and !cached.boolean)) {
        try state.returnValues(thread, op.base, op.return_count, &.{cached});
        return;
    }

    var loader = preload.get(name_key);
    var loader_data: Value = .nil;
    if (loader == .nil) {
        const path = try state.expectString(package.get(.{ .string = try state.intern("path") }));
        const found = try searchPath(state, name, path) orelse return state.fail("module not found");
        defer state.allocator.free(found);
        loader = try state.loadFileAsClosure(found);
        loader_data = .{ .string = try state.intern(found) };
    }

    const values = try state.callCollect(thread, loader, &.{ name_key, loader_data });
    defer state.allocator.free(values);
    const module_value = if (values.len == 0 or values[0] == .nil) Value{ .boolean = true } else values[0];
    try loaded.set(state.allocator, name_key, module_value);
    if (loader_data == .nil) {
        try state.returnValues(thread, op.base, op.return_count, &.{module_value});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{ module_value, loader_data });
    }
}

pub fn searcherPreload(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectString(runtime.argValue(state, thread, op, 0));
    const preload = try state.expectTable((try packageTable(state)).get(.{ .string = try state.intern("preload") }));
    const loader = preload.get(.{ .string = try state.intern(name) });
    if (loader == .nil) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("no field package.preload") }});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{loader});
    }
}

pub fn searcherLua(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectString(runtime.argValue(state, thread, op, 0));
    const package = try packageTable(state);
    const path = try state.expectString(package.get(.{ .string = try state.intern("path") }));
    const found = try searchPath(state, name, path) orelse {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("no matching file") }});
        return;
    };
    defer state.allocator.free(found);
    const loader = state.loadFileAsClosure(found) catch {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern("cannot load file") }});
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{ loader, .{ .string = try state.intern(found) } });
}

fn packageTable(state: *State) !*runtime.Table {
    return state.expectTable(state.getGlobal("package"));
}

fn searchPath(state: *State, name: []const u8, path: []const u8) !?[]const u8 {
    const module_path = try state.allocator.dupe(u8, name);
    defer state.allocator.free(module_path);
    for (module_path) |*byte| {
        if (byte.* == '.') byte.* = '/';
    }

    var iterator = std.mem.splitScalar(u8, path, ';');
    while (iterator.next()) |template| {
        var candidate = std.ArrayList(u8).empty;
        defer candidate.deinit(state.allocator);
        for (template) |byte| {
            if (byte == '?') {
                try candidate.appendSlice(state.allocator, module_path);
            } else {
                try candidate.append(state.allocator, byte);
            }
        }
        const contents = state.readFileAlloc(candidate.items) catch continue;
        state.allocator.free(contents);
        const found = try state.allocator.dupe(u8, candidate.items);
        return found;
    }
    return null;
}
