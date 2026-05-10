const std = @import("std");
const zerde = @import("zerde");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");
const zerde_lua = @import("zerde_lua.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn nullValue(state: *State) !Value {
    return zerde_lua.nullValue(state);
}

pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const input = try zerde_lua.inputBytes(state, runtime.argValue(state, thread, op, 0), "csv.read");
    const options = try csvOptions(state, thread, op, "csv.read");

    var reader: std.Io.Reader = .fixed(input);
    var decoder = zerde.csv.decoder(&reader, state.allocator, options) catch |err| return failCsvError(state, "csv.read", err);
    defer decoder.deinit();
    var sink = zerde_lua.LuaSink.init(state);
    defer sink.deinit();

    zerde.events.consume(state.allocator, &decoder, &sink) catch |err| return failCsvError(state, "csv.read", err);
    decoder.finish() catch |err| return failCsvError(state, "csv.read", err);
    if (!sink.has_root) return state.fail("csv.read: empty document");

    try state.returnValues(thread, op.base, op.return_count, &.{sink.root});
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.failArgumentMessage("csv.write", 1, "value expected");

    const value = runtime.argValue(state, thread, op, 0);
    const options = try csvOptions(state, thread, op, "csv.write");
    var out = std.Io.Writer.Allocating.init(state.allocator);
    errdefer out.deinit();
    var encoder = zerde.csv.eventEncoderWithOptions(&out.writer, state.allocator, options);
    defer encoder.deinit();
    var source = zerde_lua.source(state, &encoder, "csv.write");
    defer source.deinit();

    source.emit(value) catch |err| return failCsvError(state, "csv.write", err);
    encoder.finish() catch |err| return failCsvError(state, "csv.write", err);

    const bytes = try out.toOwnedSlice();
    defer state.allocator.free(bytes);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(bytes) }});
}

fn csvOptions(state: *State, thread: *Thread, op: bytecode.Call, operation: []const u8) !zerde.csv.Options {
    var options: zerde.csv.Options = .{};
    if (op.arg_count < 2 or runtime.argValue(state, thread, op, 1) == .nil) return options;

    const value = runtime.argValue(state, thread, op, 1);
    const table = switch (value) {
        .table => |table| table,
        else => return state.failArgumentType(operation, 2, "table", value),
    };

    const delimiter = table.get(.{ .string = try state.intern("delimiter") });
    if (delimiter != .nil) {
        const string = switch (delimiter) {
            .string => |string| string,
            else => return state.failArgumentType(operation, 2, "table with string delimiter", delimiter),
        };
        if (std.mem.eql(u8, string, "comma") or std.mem.eql(u8, string, ",")) {
            options.delimiter = .comma;
        } else if (std.mem.eql(u8, string, "tab") or std.mem.eql(u8, string, "tsv") or std.mem.eql(u8, string, "\t")) {
            options.delimiter = .tab;
        } else {
            return state.failArgumentMessage(operation, 2, "delimiter must be 'comma' or 'tab'");
        }
    }

    const header = table.get(.{ .string = try state.intern("header") });
    if (header != .nil) {
        options.header = switch (header) {
            .boolean => |boolean| boolean,
            else => return state.failArgumentType(operation, 2, "table with boolean header", header),
        };
    }

    const record_terminator = table.get(.{ .string = try state.intern("record_terminator") });
    if (record_terminator != .nil) {
        const string = switch (record_terminator) {
            .string => |string| string,
            else => return state.failArgumentType(operation, 2, "table with string record_terminator", record_terminator),
        };
        if (std.mem.eql(u8, string, "lf") or std.mem.eql(u8, string, "\n")) {
            options.record_terminator = .lf;
        } else if (std.mem.eql(u8, string, "crlf") or std.mem.eql(u8, string, "\r\n")) {
            options.record_terminator = .crlf;
        } else {
            return state.failArgumentMessage(operation, 2, "record_terminator must be 'lf' or 'crlf'");
        }
    }

    const final_record_terminator = table.get(.{ .string = try state.intern("final_record_terminator") });
    if (final_record_terminator != .nil) {
        options.final_record_terminator = switch (final_record_terminator) {
            .boolean => |boolean| boolean,
            else => return state.failArgumentType(operation, 2, "table with boolean final_record_terminator", final_record_terminator),
        };
    }

    return options;
}

fn failCsvError(state: *State, operation: []const u8, err: anyerror) !void {
    if (err == error.OutOfMemory) return err;
    if (err == error.RuntimeError or err == error.StackOverflow or err == error.UnsupportedOpcode) return err;

    var message: std.ArrayList(u8) = .empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "{s}: {s}", .{ operation, @errorName(err) });
    return state.fail(try state.intern(message.items));
}
