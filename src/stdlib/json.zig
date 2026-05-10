const std = @import("std");
const zerde = @import("zerde");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");
const zerde_lua = @import("zerde_lua.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;
const Table = runtime.Table;

pub fn moduleTable(state: *State) !*Table {
    if (state.json_module) |module| return module;

    try zerde_lua.ensureSupportTables(state);

    const module_value = try state.newTableWithHints(0, 3);
    const module = module_value.table;
    try module.set(state.allocator, .{ .string = try state.intern("read") }, .{ .native = .json_read });
    try module.set(state.allocator, .{ .string = try state.intern("write") }, .{ .native = .json_write });
    try module.set(state.allocator, .{ .string = try state.intern("null") }, try zerde_lua.nullValue(state));
    state.json_module = module;
    return module;
}

pub fn importModule(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const name = try state.expectArgumentString(thread, op, "import", 0);
    if (std.mem.eql(u8, name, "json")) {
        try state.returnValues(thread, op.base, op.return_count, &.{.{ .table = try moduleTable(state) }});
        return;
    }

    var message: std.ArrayList(u8) = .empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "module '{s}' not found", .{name});
    return state.fail(try state.intern(message.items));
}

pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void {
    _ = try moduleTable(state);
    const input = try state.expectArgumentString(thread, op, "json.read", 0);

    var reader: std.Io.Reader = .fixed(input);
    var decoder = zerde.json.decoder(&reader, state.allocator);
    var sink = zerde_lua.LuaSink.init(state);
    defer sink.deinit();

    zerde.events.consume(state.allocator, &decoder, &sink) catch |err| return failJsonError(state, "json.read", err);
    decoder.finish() catch |err| return failJsonError(state, "json.read", err);
    if (!sink.has_root) return state.fail("json.read: empty document");

    try state.returnValues(thread, op.base, op.return_count, &.{sink.root});
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    _ = try moduleTable(state);
    if (op.arg_count == 0) return state.failArgumentMessage("json.write", 1, "value expected");

    const value = runtime.argValue(state, thread, op, 0);
    const options = try writeOptions(state, thread, op);
    var out = std.Io.Writer.Allocating.init(state.allocator);
    errdefer out.deinit();
    var encoder = zerde.json.encoderWithOptions(&out.writer, options);
    var source = zerde_lua.source(state, &encoder, "json.write");
    defer source.deinit();

    source.emit(value) catch |err| return failJsonError(state, "json.write", err);
    encoder.finish() catch |err| return failJsonError(state, "json.write", err);

    const bytes = try out.toOwnedSlice();
    defer state.allocator.free(bytes);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(bytes) }});
}

fn writeOptions(state: *State, thread: *Thread, op: bytecode.Call) !zerde.json.WriteOptions {
    var options: zerde.json.WriteOptions = .{};
    if (op.arg_count < 2 or runtime.argValue(state, thread, op, 1) == .nil) return options;

    const value = runtime.argValue(state, thread, op, 1);
    const table = switch (value) {
        .table => |table| table,
        else => return state.failArgumentType("json.write", 2, "table", value),
    };

    const pretty = table.get(.{ .string = try state.intern("pretty") });
    if (pretty != .nil) {
        options.pretty = switch (pretty) {
            .boolean => |boolean| boolean,
            else => return state.failArgumentType("json.write", 2, "table with boolean pretty", pretty),
        };
    }

    const indent = table.get(.{ .string = try state.intern("indent") });
    if (indent != .nil) {
        const integer = runtime.toInteger(indent) orelse return state.failArgumentType("json.write", 2, "table with numeric indent", indent);
        if (integer < 0) return state.failArgumentMessage("json.write", 2, "indent out of range");
        options.indent = std.math.cast(usize, integer) orelse return state.failArgumentMessage("json.write", 2, "indent out of range");
    }

    return options;
}

fn failJsonError(state: *State, operation: []const u8, err: anyerror) !void {
    if (err == error.OutOfMemory) return err;
    if (err == error.RuntimeError or err == error.StackOverflow or err == error.UnsupportedOpcode) return err;

    var message: std.ArrayList(u8) = .empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "{s}: {s}", .{ operation, @errorName(err) });
    return state.fail(try state.intern(message.items));
}
