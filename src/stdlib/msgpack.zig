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
    const input = try zerde_lua.inputBytes(state, runtime.argValue(state, thread, op, 0), "msgpack.read");

    var reader: std.Io.Reader = .fixed(input);
    var decoder = zerde.msgpack.decoder(&reader, state.allocator);
    var sink = zerde_lua.LuaSink.init(state);
    defer sink.deinit();

    zerde.events.consume(state.allocator, &decoder, &sink) catch |err| return failMsgpackError(state, "msgpack.read", err);
    decoder.finish() catch |err| return failMsgpackError(state, "msgpack.read", err);
    if (!sink.has_root) return state.fail("msgpack.read: empty document");

    try state.returnValues(thread, op.base, op.return_count, &.{sink.root});
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.failArgumentMessage("msgpack.write", 1, "value expected");

    const value = runtime.argValue(state, thread, op, 0);
    var out = std.Io.Writer.Allocating.init(state.allocator);
    errdefer out.deinit();
    var raw_encoder = zerde.msgpack.encoder(&out.writer);
    var encoder = LuaMsgpackEncoder{ .raw = &raw_encoder };
    var source = zerde_lua.source(state, &encoder, "msgpack.write");
    defer source.deinit();

    source.emit(value) catch |err| return failMsgpackError(state, "msgpack.write", err);
    encoder.finish() catch |err| return failMsgpackError(state, "msgpack.write", err);

    const bytes = try out.toOwnedSlice();
    defer state.allocator.free(bytes);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(bytes) }});
}

const LuaMsgpackEncoder = struct {
    raw: *zerde.msgpack.Encoder,

    pub fn emitNull(self: *LuaMsgpackEncoder) !void {
        try self.raw.emitNull();
    }

    pub fn emitBool(self: *LuaMsgpackEncoder, value: bool) !void {
        try self.raw.emitBool(value);
    }

    pub fn emitInt(self: *LuaMsgpackEncoder, value: anytype) !void {
        try self.raw.emitInt(value);
    }

    pub fn emitFloat(self: *LuaMsgpackEncoder, value: anytype) !void {
        try self.raw.emitFloat(value);
    }

    pub fn emitString(self: *LuaMsgpackEncoder, value: []const u8) !void {
        if (std.unicode.utf8ValidateSlice(value)) {
            try self.raw.emitString(value);
        } else {
            try self.raw.emitBytes(value);
        }
    }

    pub fn beginSeq(self: *LuaMsgpackEncoder, len: ?usize) !void {
        try self.raw.beginSeq(len);
    }

    pub fn endSeq(self: *LuaMsgpackEncoder) !void {
        try self.raw.endSeq();
    }

    pub fn beginStruct(self: *LuaMsgpackEncoder, comptime T: type, field_count: usize) !void {
        try self.raw.beginStruct(T, field_count);
    }

    pub fn emitFieldName(self: *LuaMsgpackEncoder, name: []const u8) !void {
        try self.raw.emitFieldName(name);
    }

    pub fn endStruct(self: *LuaMsgpackEncoder) !void {
        try self.raw.endStruct();
    }

    pub fn finish(self: *LuaMsgpackEncoder) !void {
        try self.raw.finish();
    }
};

fn failMsgpackError(state: *State, operation: []const u8, err: anyerror) !void {
    if (err == error.OutOfMemory) return err;
    if (err == error.RuntimeError or err == error.StackOverflow or err == error.UnsupportedOpcode) return err;

    var message: std.ArrayList(u8) = .empty;
    defer message.deinit(state.allocator);
    try runtime.appendFmt(state.allocator, &message, "{s}: {s}", .{ operation, @errorName(err) });
    return state.fail(try state.intern(message.items));
}
