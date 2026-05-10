const std = @import("std");
const zerde = @import("zerde");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");
const zerde_lua = @import("zerde_lua.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;

pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const input = try state.expectArgumentString(thread, op, "toml.read", 0);

    var reader: std.Io.Reader = .fixed(input);
    var decoder = zerde.toml.decoder(&reader, state.allocator) catch |err| return failTomlError(state, "toml.read", err);
    defer decoder.deinit();
    var sink = zerde_lua.LuaSink.init(state);
    defer sink.deinit();

    zerde.events.consume(state.allocator, &decoder, &sink) catch |err| return failTomlError(state, "toml.read", err);
    decoder.finish() catch |err| return failTomlError(state, "toml.read", err);
    if (!sink.has_root) return state.fail("toml.read: empty document");

    try state.returnValues(thread, op.base, op.return_count, &.{sink.root});
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.failArgumentMessage("toml.write", 1, "value expected");

    const value = runtime.argValue(state, thread, op, 0);
    const options = try writeOptions(state, thread, op);
    var out = std.Io.Writer.Allocating.init(state.allocator);
    errdefer out.deinit();
    var encoder = zerde.toml.encoderWithOptions(state.allocator, &out.writer, options);
    defer encoder.deinit();
    var source = zerde_lua.source(state, &encoder, "toml.write");
    defer source.deinit();

    source.emit(value) catch |err| return failTomlError(state, "toml.write", err);
    encoder.finish() catch |err| return failTomlError(state, "toml.write", err);

    const bytes = try out.toOwnedSlice();
    defer state.allocator.free(bytes);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(bytes) }});
}

fn writeOptions(state: *State, thread: *Thread, op: bytecode.Call) !zerde.toml.WriteOptions {
    var options: zerde.toml.WriteOptions = .{};
    if (op.arg_count < 2 or runtime.argValue(state, thread, op, 1) == .nil) return options;

    const value = runtime.argValue(state, thread, op, 1);
    const table = switch (value) {
        .table => |table| table,
        else => return state.failArgumentType("toml.write", 2, "table", value),
    };

    const layout = table.get(.{ .string = try state.intern("layout") });
    if (layout != .nil) {
        const string = switch (layout) {
            .string => |string| string,
            else => return state.failArgumentType("toml.write", 2, "table with string layout", layout),
        };
        if (std.mem.eql(u8, string, "inline_tables") or std.mem.eql(u8, string, "inline")) {
            options.layout = .inline_tables;
        } else if (std.mem.eql(u8, string, "sections")) {
            options.layout = .sections;
        } else {
            return state.failArgumentMessage("toml.write", 2, "layout must be 'inline_tables' or 'sections'");
        }
    }

    return options;
}

fn failTomlError(state: *State, operation: []const u8, err: anyerror) !void {
    if (err == error.OutOfMemory) return err;
    if (err == error.RuntimeError or err == error.StackOverflow or err == error.UnsupportedOpcode) return err;

    var message: std.ArrayList(u8) = .empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "{s}: {s}", .{ operation, @errorName(err) });
    return state.fail(try state.intern(message.items));
}
