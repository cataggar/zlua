const std = @import("std");
const runtime = @import("../runtime.zig");

const State = runtime.State;
const Value = runtime.Value;
const Table = runtime.Table;

const max_zerde_table_len = @as(usize, @intCast(std.math.maxInt(i64)));

pub fn ensureSupportTables(state: *State) !void {
    if (state.zerde_null == null) {
        const null_value = try state.newTableWithHints(0, 0);
        const null_metatable = try zerdeMetatable(state, "zerde null");
        state.setTableMetatableRaw(null_value.table, null_metatable);
        state.zerde_null = null_value.table;
    }
    if (state.zerde_array_metatable == null) state.zerde_array_metatable = try zerdeMetatable(state, "zerde array");
    if (state.zerde_object_metatable == null) state.zerde_object_metatable = try zerdeMetatable(state, "zerde object");
}

pub fn nullValue(state: *State) !Value {
    try ensureSupportTables(state);
    return .{ .table = state.zerde_null.? };
}

fn zerdeMetatable(state: *State, name: []const u8) !*Table {
    const value = try state.newTableWithHints(0, 2);
    const table = value.table;
    try table.set(state.allocator, .{ .string = try state.intern("__metatable") }, .{ .boolean = false });
    try table.set(state.allocator, .{ .string = try state.intern("__name") }, .{ .string = try state.intern(name) });
    return table;
}

pub const LuaSink = struct {
    const Frame = struct {
        kind: enum { seq, object },
        table: *Table,
        next_index: i64 = 1,
        field_name: ?[]const u8 = null,
    };

    state: *State,
    stack: std.ArrayList(Frame) = .empty,
    root: Value = .nil,
    has_root: bool = false,

    pub fn init(state: *State) LuaSink {
        return .{ .state = state };
    }

    pub fn deinit(self: *LuaSink) void {
        self.stack.deinit(self.state.allocator);
    }

    pub fn emitNull(self: *LuaSink) !void {
        try self.appendValue(try nullValue(self.state));
    }

    pub fn emitBool(self: *LuaSink, value: bool) !void {
        try self.appendValue(.{ .boolean = value });
    }

    pub fn emitInt(self: *LuaSink, value: i128) !void {
        const integer = std.math.cast(i64, value) orelse return error.ZerdeIntegerOutOfRange;
        try self.appendValue(.{ .integer = integer });
    }

    pub fn emitFloat(self: *LuaSink, value: f64) !void {
        try self.appendValue(.{ .number = value });
    }

    pub fn emitString(self: *LuaSink, value: []const u8) !void {
        try self.appendValue(.{ .string = try self.state.intern(value) });
    }

    pub fn emitBytes(self: *LuaSink, value: []const u8) !void {
        try self.appendValue(.{ .string = try self.state.intern(value) });
    }

    pub fn emitDateTimeRaw(self: *LuaSink, value: []const u8) !void {
        try self.emitString(value);
    }

    pub fn beginSeq(self: *LuaSink, len: ?usize) !void {
        try ensureSupportTables(self.state);
        const hint = if (len) |count| std.math.cast(u32, count) orelse std.math.maxInt(u32) else 0;
        const value = try self.state.newTableWithHints(hint, 0);
        self.state.setTableMetatableRaw(value.table, self.state.zerde_array_metatable.?);
        try self.stack.append(self.state.allocator, .{ .kind = .seq, .table = value.table });
    }

    pub fn endSeq(self: *LuaSink) !void {
        const frame = self.stack.pop() orelse return error.InvalidZerdeSinkState;
        if (frame.kind != .seq) return error.InvalidZerdeSinkState;
        try self.appendValue(.{ .table = frame.table });
    }

    pub fn beginStruct(self: *LuaSink, len: ?usize) !void {
        try ensureSupportTables(self.state);
        const hint = if (len) |count| std.math.cast(u32, count) orelse std.math.maxInt(u32) else 0;
        const value = try self.state.newTableWithHints(0, hint);
        self.state.setTableMetatableRaw(value.table, self.state.zerde_object_metatable.?);
        try self.stack.append(self.state.allocator, .{ .kind = .object, .table = value.table });
    }

    pub fn emitFieldName(self: *LuaSink, name: []const u8) !void {
        if (self.stack.items.len == 0) return error.InvalidZerdeSinkState;
        const frame = &self.stack.items[self.stack.items.len - 1];
        if (frame.kind != .object or frame.field_name != null) return error.InvalidZerdeSinkState;
        frame.field_name = try self.state.intern(name);
    }

    pub fn endStruct(self: *LuaSink) !void {
        const frame = self.stack.pop() orelse return error.InvalidZerdeSinkState;
        if (frame.kind != .object or frame.field_name != null) return error.InvalidZerdeSinkState;
        try self.appendValue(.{ .table = frame.table });
    }

    fn appendValue(self: *LuaSink, value: Value) !void {
        if (self.stack.items.len == 0) {
            if (self.has_root) return error.InvalidZerdeSinkState;
            self.root = value;
            self.has_root = true;
            return;
        }

        const frame = &self.stack.items[self.stack.items.len - 1];
        switch (frame.kind) {
            .seq => {
                try frame.table.set(self.state.allocator, .{ .integer = frame.next_index }, value);
                frame.next_index += 1;
            },
            .object => {
                const name = frame.field_name orelse return error.InvalidZerdeSinkState;
                try frame.table.set(self.state.allocator, .{ .string = name }, value);
                frame.field_name = null;
            },
        }
    }
};

pub fn source(state: *State, encoder: anytype, operation: []const u8) LuaSource(@TypeOf(encoder.*)) {
    return LuaSource(@TypeOf(encoder.*)).init(state, encoder, operation);
}

pub fn LuaSource(comptime Encoder: type) type {
    return struct {
        const Self = @This();

        const Kind = union(enum) {
            null,
            array: usize,
            object: usize,
        };

        state: *State,
        encoder: *Encoder,
        operation: []const u8,
        visiting: std.AutoHashMap(*Table, void),

        pub fn init(state: *State, encoder: *Encoder, operation: []const u8) Self {
            return .{ .state = state, .encoder = encoder, .operation = operation, .visiting = std.AutoHashMap(*Table, void).init(state.allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.visiting.deinit();
        }

        pub fn emit(self: *Self, value: Value) anyerror!void {
            switch (value) {
                .nil => try self.encoder.emitNull(),
                .boolean => |boolean| try self.encoder.emitBool(boolean),
                .integer => |integer| try self.encoder.emitInt(integer),
                .number => |number| {
                    if (!std.math.isFinite(number)) return self.fail("non-finite number");
                    try self.encoder.emitFloat(number);
                },
                .string => |string| try self.encoder.emitString(string),
                .table => |table| try self.emitTable(table),
                else => return self.fail("unsupported value type"),
            }
        }

        fn emitTable(self: *Self, table: *Table) anyerror!void {
            const kind = try self.tableKind(table);
            switch (kind) {
                .null => try self.encoder.emitNull(),
                .array => |len| {
                    if (self.visiting.contains(table)) return self.fail("cyclic table");
                    try self.visiting.put(table, {});
                    defer _ = self.visiting.remove(table);

                    try self.encoder.beginSeq(len);
                    var index: usize = 1;
                    while (index <= len) : (index += 1) {
                        const value = table.get(.{ .integer = @intCast(index) });
                        if (value == .nil) return self.fail("array contains nil hole");
                        try self.emit(value);
                    }
                    try self.encoder.endSeq();
                },
                .object => |field_count| {
                    if (self.visiting.contains(table)) return self.fail("cyclic table");
                    try self.visiting.put(table, {});
                    defer _ = self.visiting.remove(table);

                    try self.encoder.beginStruct(void, field_count);
                    for (table.entries.items) |entry| {
                        if (entry.value == .nil) continue;
                        const name = switch (entry.key) {
                            .string => |string| string,
                            else => return self.fail("object keys must be strings"),
                        };
                        try self.encoder.emitFieldName(name);
                        try self.emit(entry.value);
                    }
                    try self.encoder.endStruct();
                },
            }
        }

        fn tableKind(self: *Self, table: *Table) !Kind {
            if (self.state.zerde_null == table) return .null;

            const shape = tableShape(table);
            if (table.metatable == self.state.zerde_array_metatable) return .{ .array = try self.arrayLen(shape) };
            if (table.metatable == self.state.zerde_object_metatable) return .{ .object = try self.objectFieldCount(shape) };

            if (shape.other_count != 0) return self.fail("unsupported table keys");
            if (shape.integer_count != 0 and shape.string_count != 0) return self.fail("cannot encode mixed array/object table");
            if (shape.integer_count != 0) return .{ .array = try self.arrayLen(shape) };
            return .{ .object = shape.string_count };
        }

        fn arrayLen(self: *Self, shape: LuaSourceShape) !usize {
            if (shape.string_count != 0 or shape.other_count != 0) return self.fail("cannot encode mixed array/object table");
            if (shape.max_index > max_zerde_table_len) return self.fail("array too large");
            if (shape.integer_count != shape.max_index) return self.fail("array contains nil hole");
            return shape.max_index;
        }

        fn objectFieldCount(self: *Self, shape: LuaSourceShape) !usize {
            if (shape.integer_count != 0 or shape.other_count != 0) return self.fail("object keys must be strings");
            return shape.string_count;
        }

        fn fail(self: *Self, message: []const u8) runtime.RuntimeError {
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(self.state.allocator);
            runtime.appendFmt(self.state.allocator, &out, "{s}: {s}", .{ self.operation, message }) catch return self.state.fail(message);
            return self.state.fail(self.state.intern(out.items) catch message);
        }
    };
}

fn tableShape(table: *Table) LuaSourceShape {
    var shape: LuaSourceShape = .{};
    for (table.array.items, 0..) |value, index| {
        if (value == .nil) continue;
        shape.integer_count += 1;
        shape.max_index = @max(shape.max_index, index + 1);
    }
    for (table.entries.items) |entry| {
        if (entry.value == .nil) continue;
        if (positiveIntegerIndex(entry.key)) |index| {
            shape.integer_count += 1;
            shape.max_index = @max(shape.max_index, index);
        } else if (entry.key == .string) {
            shape.string_count += 1;
        } else {
            shape.other_count += 1;
        }
    }
    return shape;
}

const LuaSourceShape = struct {
    integer_count: usize = 0,
    max_index: usize = 0,
    string_count: usize = 0,
    other_count: usize = 0,
};

fn positiveIntegerIndex(value: Value) ?usize {
    const integer = switch (value) {
        .integer => |integer| integer,
        .number => |number| runtime.floatToInteger(number) orelse return null,
        else => return null,
    };
    if (integer <= 0) return null;
    return std.math.cast(usize, integer);
}
