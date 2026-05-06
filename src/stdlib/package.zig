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
    const result_values = if (values.len >= 2 and values[0] == .native and values[0].native == .dofile and values[1] == .string and std.mem.eql(u8, values[1].string, path)) values[2..] else values;
    try state.returnValues(thread, op.base, op.return_count, result_values);
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
        const path_value = package.get(.{ .string = try state.intern("path") });
        if (path_value != .string) return state.fail("package.path must be a string");
        const path = path_value.string;
        const found = try searchPath(state, name, path, ".", "/") orelse {
            const message = try moduleNotFoundMessage(state, name, package, path);
            return state.fail(message);
        };
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

pub fn searchpath(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectString(runtime.argValue(state, thread, op, 0));
    const path = try state.expectString(runtime.argValue(state, thread, op, 1));
    const sep_value = runtime.argValue(state, thread, op, 2);
    const rep_value = runtime.argValue(state, thread, op, 3);
    const sep = if (sep_value == .nil) "." else try state.expectString(sep_value);
    const rep = if (rep_value == .nil) "/" else try state.expectString(rep_value);

    if (try searchPath(state, name, path, sep, rep)) |found| {
        defer state.allocator.free(found);
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(found) }});
        return;
    }

    const message = try searchPathError(state, name, path, sep, rep);
    defer state.allocator.free(message);
    try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
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
    const found = try searchPath(state, name, path, ".", "/") orelse {
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

fn searchPath(state: *State, name: []const u8, path: []const u8, sep: []const u8, rep: []const u8) !?[]const u8 {
    const module_path = try modulePath(state, name, sep, rep);
    defer state.allocator.free(module_path);

    var iterator = std.mem.splitScalar(u8, path, ';');
    while (iterator.next()) |template| {
        var candidate = try applyTemplate(state.allocator, template, module_path);
        defer candidate.deinit(state.allocator);
        const contents = state.readFileAlloc(candidate.items) catch continue;
        state.allocator.free(contents);
        const found = try state.allocator.dupe(u8, candidate.items);
        return found;
    }
    return null;
}

fn moduleNotFoundMessage(state: *State, name: []const u8, package: *runtime.Table, path: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    defer out.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &out, "module '{s}' not found:\n\tno field package.preload['{s}']", .{ name, name });
    try appendSearchPathError(state, &out, name, path, ".", "/");
    const cpath_value = package.get(.{ .string = try state.intern("cpath") });
    if (cpath_value == .string) try appendSearchPathError(state, &out, name, cpath_value.string, ".", "/");
    return state.intern(out.items);
}

fn searchPathError(state: *State, name: []const u8, path: []const u8, sep: []const u8, rep: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(state.allocator);
    try appendSearchPathError(state, &out, name, path, sep, rep);
    return out.toOwnedSlice(state.allocator);
}

fn appendSearchPathError(state: *State, out: *std.ArrayList(u8), name: []const u8, path: []const u8, sep: []const u8, rep: []const u8) !void {
    const module_path = try modulePath(state, name, sep, rep);
    defer state.allocator.free(module_path);

    var iterator = std.mem.splitScalar(u8, path, ';');
    while (iterator.next()) |template| {
        var candidate = try applyTemplate(state.allocator, template, module_path);
        defer candidate.deinit(state.allocator);
        try runtime.appendFmt(state.allocator, out, "\n\tno file '{s}'", .{candidate.items});
    }
}

fn modulePath(state: *State, name: []const u8, sep: []const u8, rep: []const u8) ![]u8 {
    if (sep.len == 0) return state.allocator.dupe(u8, name);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(state.allocator);
    var rest = name;
    while (std.mem.indexOf(u8, rest, sep)) |index| {
        try out.appendSlice(state.allocator, rest[0..index]);
        try out.appendSlice(state.allocator, rep);
        rest = rest[index + sep.len ..];
    }
    try out.appendSlice(state.allocator, rest);
    return out.toOwnedSlice(state.allocator);
}

fn applyTemplate(allocator: std.mem.Allocator, template: []const u8, module_path: []const u8) !std.ArrayList(u8) {
    var candidate = std.ArrayList(u8).empty;
    errdefer candidate.deinit(allocator);
    for (template) |byte| {
        if (byte == '?') {
            try candidate.appendSlice(allocator, module_path);
        } else {
            try candidate.append(allocator, byte);
        }
    }
    return candidate;
}
