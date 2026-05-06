const std = @import("std");
const runtime = @import("runtime.zig");
const stdlib = @import("stdlib.zig");

pub const Error = error{LuaError};
pub const UnsupportedOption = error{UnsupportedOption};
pub const ConversionError = error{
    TypeMismatch,
    IntegerOutOfRange,
    UnsupportedType,
    ArityMismatch,
};

pub const Stdlib = enum {
    none,
    base,
    safe,
    full,
};

pub const MemoryFile = runtime.MemoryFile;

pub const IoCapability = union(enum) {
    disabled,
    runtime: std.Io,
};

pub const FilesystemCapability = runtime.FilesystemCapability;

pub const EnvironmentCapability = union(enum) {
    disabled,
    map: *const std.process.Environ.Map,
};

pub const ClockCapability = runtime.ClockCapability;
pub const ProcessCapability = runtime.ProcessCapability;

pub const Capabilities = struct {
    io: IoCapability = .disabled,
    filesystem: FilesystemCapability = .disabled,
    environment: EnvironmentCapability = .disabled,
    clock: ClockCapability = .disabled,
    process: ProcessCapability = .disabled,

    pub const sandboxed: Capabilities = .{};
};

pub const Limits = struct {
    max_memory: ?usize = null,
    max_stack_values: ?usize = null,
    max_call_frames: ?usize = null,
    max_instructions: ?u64 = null,
};

pub const GcOptions = struct {};

pub const DebugOptions = struct {
    errors: bool = false,
    trace_vm: bool = false,
};

pub const Options = struct {
    stdlib: Stdlib = .safe,
    capabilities: Capabilities = .sandboxed,
    limits: Limits = .{},
    gc: GcOptions = .{},
    debug: DebugOptions = .{},
};

pub const LoadMode = enum {
    source_only,
};

pub const LoadOptions = struct {
    name: ?[]const u8 = null,
    environment: ?Table = null,
    mode: LoadMode = .source_only,
};

pub const DoOptions = LoadOptions;

pub const TableOptions = struct {
    array_hint: u32 = 0,
    hash_hint: u32 = 0,
};

pub const GcBudget = struct {
    steps: usize = 0,
};

pub const GcStepResult = enum {
    complete,
    pending,
};

pub const State = struct {
    raw_state: runtime.State,
    last_error_root: ?usize = null,
    memory_files: std.ArrayList(MemoryFile) = .empty,
    owned_memory_file_start: usize = 0,

    pub fn init(state_allocator: std.mem.Allocator, options: Options) !State {
        var state = State{
            .raw_state = try runtime.State.initWithOptions(state_allocator, runtimeOptions(options)),
        };
        errdefer state.raw_state.deinit();
        errdefer state.memory_files.deinit(state_allocator);

        if (options.capabilities.filesystem == .memory) {
            const files = options.capabilities.filesystem.memory;
            try state.memory_files.appendSlice(state_allocator, files);
            state.owned_memory_file_start = files.len;
            state.raw_state.options.filesystem = .{ .memory = state.memory_files.items };
        }

        return state;
    }

    pub fn deinit(self: *State) void {
        const state_allocator = self.raw_state.allocator;
        self.raw_state.deinit();
        self.deinitOwnedMemoryFiles(state_allocator);
        self.memory_files.deinit(state_allocator);
        self.* = undefined;
    }

    pub fn allocator(self: *State) std.mem.Allocator {
        return self.raw_state.allocator;
    }

    pub fn openLibs(self: *State, mode: Stdlib) !void {
        try stdlib.openLibraries(&self.raw_state, toRuntimeStdlib(mode));
        if (!toRuntimeStdlib(mode).isEmpty()) try stdlib.installGlobalTable(&self.raw_state);
    }

    pub fn collect(self: *State) !void {
        try self.raw_state.collectGarbage();
    }

    pub fn stepGc(self: *State, budget: GcBudget) !GcStepResult {
        _ = budget;
        try self.collect();
        return .complete;
    }

    pub fn push(self: *State, value: anytype) !Value {
        return Value.fromRuntime(self, try toRuntimeValue(self, value));
    }

    pub fn read(self: *State, value: Value, comptime T: type) !T {
        return fromRuntimeValue(self, try value.toRuntime(), T);
    }

    pub fn setGlobal(self: *State, name: []const u8, value: anytype) !void {
        const raw_name = try self.raw_state.intern(name);
        const raw_value = try toRuntimeValue(self, value);
        self.raw_state.putGlobal(raw_name, raw_value) catch |err| return self.captureLuaError(err);
    }

    pub fn getGlobal(self: *State, name: []const u8, comptime T: type) !T {
        return fromRuntimeValue(self, self.raw_state.getGlobal(name), T);
    }

    pub fn createTable(self: *State, options: TableOptions) !Table {
        const raw = self.raw_state.newTableWithHints(options.array_hint, options.hash_hint) catch |err| return self.captureLuaError(err);
        return Table.fromRuntime(self, raw);
    }

    pub fn createModule(self: *State, name: []const u8) !Table {
        _ = name;
        return self.createTable(.{ .hash_hint = 4 });
    }

    pub fn preloadModule(self: *State, name: []const u8, module: Table) !void {
        try self.ensurePackageLibrary();

        var package = try self.getGlobal("package", Table);
        defer package.deinit();
        var loaded = try package.get("loaded", Table);
        defer loaded.deinit();
        try loaded.set(name, module);
    }

    pub fn setPackagePath(self: *State, path: []const u8) !void {
        try self.ensurePackageLibrary();

        var package = try self.getGlobal("package", Table);
        defer package.deinit();
        try package.set("path", path);
    }

    pub fn addMemoryFile(self: *State, path: []const u8, contents: []const u8) !void {
        switch (self.raw_state.options.filesystem) {
            .disabled, .memory => {},
            .host_cwd => return error.UnsupportedOption,
        }

        const path_copy = try self.allocator().dupe(u8, path);
        errdefer self.allocator().free(path_copy);
        const contents_copy = try self.allocator().dupe(u8, contents);
        errdefer self.allocator().free(contents_copy);

        try self.memory_files.append(self.allocator(), .{ .path = path_copy, .contents = contents_copy });
        self.raw_state.options.filesystem = .{ .memory = self.memory_files.items };
    }

    pub fn loadString(self: *State, source: []const u8, options: LoadOptions) !Function {
        try validateLoadOptions(options);
        const loaded = self.raw_state.loadSourceAsClosureNamed(source, options.name) catch |err| return self.captureLuaError(err);
        return Function.fromRuntime(self, loaded);
    }

    pub fn loadFile(self: *State, path: []const u8, options: LoadOptions) !Function {
        try validateLoadOptions(options);
        const loaded = self.raw_state.loadFileAsClosureNamed(path, options.name) catch |err| return self.captureLuaError(err);
        return Function.fromRuntime(self, loaded);
    }

    pub fn doString(self: *State, source: []const u8, options: DoOptions) !void {
        var function = try self.loadString(source, options);
        defer function.deinit();
        try function.call(.{}, void);
    }

    pub fn doFile(self: *State, path: []const u8, options: DoOptions) !void {
        var function = try self.loadFile(path, options);
        defer function.deinit();
        try function.call(.{}, void);
    }

    pub fn errorMessage(self: *State) ![]const u8 {
        const value = self.lastErrorValue();
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator());
        try runtime.appendValue(self.allocator(), &out, value);
        return self.allocator().dupe(u8, out.items);
    }

    pub fn takeErrorValue(self: *State) ?ErrorRef {
        const index = self.last_error_root orelse return null;
        self.last_error_root = null;
        return .{ .ref = .{ .state = self, .index = index } };
    }

    fn setLastErrorValue(self: *State, value: runtime.Value) !void {
        if (self.last_error_root) |index| self.raw_state.unrootValue(index);
        self.last_error_root = try self.raw_state.rootValue(value);
    }

    fn lastErrorValue(self: *State) runtime.Value {
        if (self.last_error_root) |index| return self.raw_state.rootedValue(index);
        return self.raw_state.currentErrorValue();
    }

    fn captureLuaError(self: *State, err: anyerror) anyerror {
        switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                self.setLastErrorValue(self.raw_state.currentErrorValue()) catch |root_err| return root_err;
                return error.LuaError;
            },
            else => return err,
        }
    }

    fn ensurePackageLibrary(self: *State) !void {
        if (self.raw_state.globals.get("package") == null) {
            try stdlib.openLibraries(&self.raw_state, .{ .libraries = .{ .package = true } });
        }

        try self.syncOpenedGlobal("loadfile");
        try self.syncOpenedGlobal("dofile");
        try self.syncOpenedGlobal("require");
        try self.syncOpenedGlobal("package");
    }

    fn syncOpenedGlobal(self: *State, name: []const u8) !void {
        const value = self.raw_state.globals.get(name) orelse return;
        const raw_name = try self.raw_state.intern(name);
        self.raw_state.putGlobal(raw_name, value) catch |err| return self.captureLuaError(err);
    }

    fn deinitOwnedMemoryFiles(self: *State, state_allocator: std.mem.Allocator) void {
        for (self.memory_files.items[self.owned_memory_file_start..]) |file| {
            state_allocator.free(file.path);
            state_allocator.free(file.contents);
        }
    }

    fn rootCountForTest(self: *State) usize {
        return self.raw_state.activeRootCount();
    }
};

pub const Ref = struct {
    state: *State,
    index: usize,

    fn fromRuntime(state: *State, raw: runtime.Value) !Ref {
        return .{ .state = state, .index = try state.raw_state.rootValue(raw) };
    }

    pub fn deinit(self: *Ref) void {
        self.state.raw_state.unrootValue(self.index);
        self.* = undefined;
    }

    pub fn value(self: Ref) !Value {
        return Value.fromRuntime(self.state, self.rawValue());
    }

    fn rawValue(self: Ref) runtime.Value {
        return self.state.raw_state.rootedValue(self.index);
    }
};

pub const Table = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !Table {
        return switch (value) {
            .table => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    pub fn deinit(self: *Table) void {
        self.ref.deinit();
        self.* = undefined;
    }

    pub fn get(self: Table, key: anytype, comptime T: type) !T {
        const raw = try self.rawValue();
        const raw_key = try toRuntimeValue(self.ref.state, key);
        const raw_value = self.ref.state.raw_state.getTableValue(raw, raw_key) catch |err| return self.ref.state.captureLuaError(err);
        return fromRuntimeValue(self.ref.state, raw_value, T);
    }

    pub fn set(self: Table, key: anytype, value: anytype) !void {
        const raw = try self.rawValue();
        const raw_key = try toRuntimeValue(self.ref.state, key);
        const raw_value = try toRuntimeValue(self.ref.state, value);
        self.ref.state.raw_state.setTableValue(raw, raw_key, raw_value) catch |err| return self.ref.state.captureLuaError(err);
    }

    fn rawValue(self: Table) !runtime.Value {
        const raw = self.ref.rawValue();
        if (raw != .table) return error.TypeMismatch;
        return raw;
    }
};

pub const Function = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !Function {
        return switch (value) {
            .closure => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    pub fn deinit(self: *Function) void {
        self.ref.deinit();
        self.* = undefined;
    }

    pub fn call(self: Function, args: anytype, comptime R: type) !R {
        const raw_args = try convertArgs(self.ref.state, args);
        defer self.ref.state.allocator().free(raw_args);

        const results = self.ref.state.raw_state.callLoadedClosure(try self.rawClosure(), raw_args) catch |err| return self.ref.state.captureLuaError(err);
        defer self.ref.state.allocator().free(results);
        return fromRuntimeResults(self.ref.state, results, R);
    }

    pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R) {
        const raw_args = try convertArgs(self.ref.state, args);
        defer self.ref.state.allocator().free(raw_args);

        const result = try self.ref.state.raw_state.protectedCallLoadedClosure(try self.rawClosure(), raw_args);
        switch (result) {
            .success => |values| {
                defer self.ref.state.allocator().free(values);
                return .{ .ok = try fromRuntimeResults(self.ref.state, values, R) };
            },
            .failure => |value| {
                try self.ref.state.setLastErrorValue(value);
                return .{ .lua_error = try ErrorRef.fromRuntime(self.ref.state, value) };
            },
        }
    }

    fn rawClosure(self: Function) !*runtime.Closure {
        return switch (self.ref.rawValue()) {
            .closure => |closure| closure,
            else => error.TypeMismatch,
        };
    }
};

pub fn CallResult(comptime R: type) type {
    return union(enum) {
        ok: R,
        lua_error: ErrorRef,
    };
}

pub const ErrorRef = struct {
    ref: Ref,

    fn fromRuntime(state: *State, raw: runtime.Value) !ErrorRef {
        return .{ .ref = try Ref.fromRuntime(state, raw) };
    }

    pub fn deinit(self: *ErrorRef) void {
        self.ref.deinit();
        self.* = undefined;
    }

    pub fn value(self: ErrorRef) !Value {
        return self.ref.value();
    }

    pub fn message(self: ErrorRef) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.ref.state.allocator());
        try runtime.appendValue(self.ref.state.allocator(), &out, self.ref.rawValue());
        return self.ref.state.allocator().dupe(u8, out.items);
    }
};

pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: Table,
    function: Function,
    unsupported,

    fn fromRuntime(state: *State, value: runtime.Value) !Value {
        return switch (value) {
            .nil => .nil,
            .boolean => |boolean| .{ .boolean = boolean },
            .integer => |integer| .{ .integer = integer },
            .number => |number| .{ .number = number },
            .string => |string| .{ .string = string },
            .table => .{ .table = try Table.fromRuntime(state, value) },
            .closure => .{ .function = try Function.fromRuntime(state, value) },
            else => .unsupported,
        };
    }

    pub fn deinit(self: *Value) void {
        switch (self.*) {
            .table => |*table| table.deinit(),
            .function => |*function| function.deinit(),
            else => {},
        }
        self.* = undefined;
    }

    fn toRuntime(self: Value) !runtime.Value {
        return switch (self) {
            .nil => .nil,
            .boolean => |boolean| .{ .boolean = boolean },
            .integer => |integer| .{ .integer = integer },
            .number => |number| .{ .number = number },
            .string => |string| .{ .string = string },
            .table => |table| table.rawValue(),
            .function => |function| .{ .closure = try function.rawClosure() },
            .unsupported => error.UnsupportedType,
        };
    }
};

pub fn Tuple(comptime types: []const type) type {
    return struct {
        pub const is_zlua_tuple = true;
        pub const field_types = types;

        values: std.meta.Tuple(types),

        pub fn deinit(self: *@This()) void {
            inline for (types, 0..) |Field, index| deinitIfOwned(Field, &self.values[index]);
            self.* = undefined;
        }

        pub fn get(self: *const @This(), comptime index: usize) types[index] {
            return self.values[index];
        }
    };
}

pub const Context = opaque {};
pub const AnyUserdata = opaque {};
pub const Thread = opaque {};

fn runtimeOptions(options: Options) runtime.StateOptions {
    return .{
        .stdlib = toRuntimeStdlib(options.stdlib),
        .io = switch (options.capabilities.io) {
            .disabled => null,
            .runtime => |io| io,
        },
        .filesystem = options.capabilities.filesystem,
        .environment = switch (options.capabilities.environment) {
            .disabled => null,
            .map => |map| map,
        },
        .clock = options.capabilities.clock,
        .process = options.capabilities.process,
        .debug_errors = options.debug.errors,
        .trace_vm = options.debug.trace_vm,
    };
}

fn toRuntimeStdlib(mode: Stdlib) runtime.StdlibMode {
    return switch (mode) {
        .none => .none,
        .base => .base,
        .safe => .safe,
        .full => .full,
    };
}

fn validateLoadOptions(options: LoadOptions) UnsupportedOption!void {
    if (options.environment != null) return error.UnsupportedOption;
    switch (options.mode) {
        .source_only => {},
    }
}

fn convertArgs(state: *State, args: anytype) ![]runtime.Value {
    const Args = @TypeOf(args);
    const info = @typeInfo(Args);
    if (info != .@"struct" or !info.@"struct".is_tuple) @compileError("calls require tuple arguments: .{ ... }");

    const fields = info.@"struct".fields;
    const raw_args = try state.allocator().alloc(runtime.Value, fields.len);
    errdefer state.allocator().free(raw_args);
    inline for (fields, 0..) |_, index| raw_args[index] = try toRuntimeValue(state, args[index]);
    return raw_args;
}

fn toRuntimeValue(state: *State, value: anytype) !runtime.Value {
    const T = @TypeOf(value);
    if (T == Value) return value.toRuntime();
    if (T == Ref) return value.rawValue();
    if (T == Table) return value.rawValue();
    if (T == Function) return .{ .closure = try value.rawClosure() };

    return switch (@typeInfo(T)) {
        .null => .nil,
        .optional => if (value) |payload| toRuntimeValue(state, payload) else .nil,
        .bool => .{ .boolean = value },
        .int, .comptime_int => .{ .integer = std.math.cast(i64, value) orelse return error.IntegerOutOfRange },
        .float, .comptime_float => .{ .number = @floatCast(value) },
        .pointer => |pointer| pointerToRuntimeValue(state, value, pointer),
        .array => |array| if (array.child == u8)
            .{ .string = try state.raw_state.intern(value[0..]) }
        else
            arrayToRuntimeValue(state, value[0..]),
        .@"struct" => |info| structToRuntimeValue(state, value, info),
        else => error.UnsupportedType,
    };
}

fn pointerToRuntimeValue(state: *State, value: anytype, comptime pointer: std.builtin.Type.Pointer) !runtime.Value {
    switch (pointer.size) {
        .slice => {
            if (pointer.child == u8) return .{ .string = try state.raw_state.intern(value) };
            return arrayToRuntimeValue(state, value);
        },
        .one => switch (@typeInfo(pointer.child)) {
            .array => |array| {
                if (array.child == u8) return .{ .string = try state.raw_state.intern(value[0..]) };
                return arrayToRuntimeValue(state, value[0..]);
            },
            .@"struct" => return toRuntimeValue(state, value.*),
            else => return error.UnsupportedType,
        },
        else => return error.UnsupportedType,
    }
}

fn arrayToRuntimeValue(state: *State, values: anytype) !runtime.Value {
    const array_hint = std.math.cast(u32, values.len) orelse return error.IntegerOutOfRange;
    const table = state.raw_state.newTableWithHints(array_hint, 0) catch |err| return state.captureLuaError(err);
    for (values, 0..) |item, index| {
        const raw_item = try toRuntimeValue(state, item);
        const raw_index: i64 = @intCast(index + 1);
        state.raw_state.setTableValue(table, .{ .integer = raw_index }, raw_item) catch |err| return state.captureLuaError(err);
    }
    return table;
}

fn structToRuntimeValue(state: *State, value: anytype, comptime info: std.builtin.Type.Struct) !runtime.Value {
    if (info.is_tuple) return tupleToRuntimeValue(state, value, info.fields.len);

    const hash_hint = std.math.cast(u32, info.fields.len) orelse return error.IntegerOutOfRange;

    const table = state.raw_state.newTableWithHints(0, hash_hint) catch |err| return state.captureLuaError(err);
    inline for (info.fields) |field| {
        const raw_key = runtime.Value{ .string = try state.raw_state.intern(field.name) };
        const raw_value = try toRuntimeValue(state, @field(value, field.name));
        state.raw_state.setTableValue(table, raw_key, raw_value) catch |err| return state.captureLuaError(err);
    }
    return table;
}

fn tupleToRuntimeValue(state: *State, value: anytype, comptime len: usize) !runtime.Value {
    const array_hint = std.math.cast(u32, len) orelse return error.IntegerOutOfRange;
    const table = state.raw_state.newTableWithHints(array_hint, 0) catch |err| return state.captureLuaError(err);
    inline for (0..len) |index| {
        const raw_item = try toRuntimeValue(state, value[index]);
        const raw_index: i64 = @intCast(index + 1);
        state.raw_state.setTableValue(table, .{ .integer = raw_index }, raw_item) catch |err| return state.captureLuaError(err);
    }
    return table;
}

fn fromRuntimeResults(state: *State, results: []const runtime.Value, comptime R: type) !R {
    if (R == void) return {};
    if (comptime isTupleResult(R)) {
        var values: std.meta.Tuple(R.field_types) = undefined;
        inline for (R.field_types, 0..) |Field, index| {
            const raw = if (index < results.len) results[index] else runtime.Value.nil;
            values[index] = try fromRuntimeValue(state, raw, Field);
        }
        return .{ .values = values };
    }

    const raw = if (results.len == 0) runtime.Value.nil else results[0];
    return fromRuntimeValue(state, raw, R);
}

fn fromRuntimeValue(state: *State, raw: runtime.Value, comptime T: type) !T {
    if (T == Value) return Value.fromRuntime(state, raw);
    if (T == Ref) return Ref.fromRuntime(state, raw);
    if (T == Table) return Table.fromRuntime(state, raw);
    if (T == Function) return Function.fromRuntime(state, raw);
    if (T == void) return {};

    return switch (@typeInfo(T)) {
        .bool => switch (raw) {
            .boolean => |value| value,
            else => error.TypeMismatch,
        },
        .int, .comptime_int => switch (raw) {
            .integer => |value| std.math.cast(T, value) orelse return error.IntegerOutOfRange,
            .number => |value| if (integerFromFloat(value)) |integer|
                std.math.cast(T, integer) orelse return error.IntegerOutOfRange
            else
                error.TypeMismatch,
            else => error.TypeMismatch,
        },
        .float, .comptime_float => switch (raw) {
            .integer => |value| @as(T, @floatFromInt(value)),
            .number => |value| @as(T, @floatCast(value)),
            else => error.TypeMismatch,
        },
        .optional => |optional| if (raw == .nil)
            null
        else
            try fromRuntimeValue(state, raw, optional.child),
        .pointer => |pointer| switch (pointer.size) {
            .slice => if (pointer.child == u8) switch (raw) {
                .string => |value| value,
                else => error.TypeMismatch,
            } else error.UnsupportedType,
            else => error.UnsupportedType,
        },
        else => error.UnsupportedType,
    };
}

fn integerFromFloat(value: f64) ?i64 {
    if (!std.math.isFinite(value)) return null;
    if (@trunc(value) != value) return null;
    if (value < @as(f64, @floatFromInt(std.math.minInt(i64))) or value > @as(f64, @floatFromInt(std.math.maxInt(i64)))) return null;
    return @intFromFloat(value);
}

fn isTupleResult(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "is_zlua_tuple") and T.is_zlua_tuple,
        else => false,
    };
}

fn deinitIfOwned(comptime T: type, value: *T) void {
    if (T == Value or T == Ref or T == Table or T == Function or T == ErrorRef) {
        value.deinit();
    }
}

test "api state initializes with safe defaults" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try lua.doString("assert(_VERSION == 'Lua 5.5')", .{});
    try std.testing.expectError(error.LuaError, lua.doFile("missing.lua", .{}));

    const message = try lua.errorMessage();
    defer lua.allocator().free(message);
    try std.testing.expect(std.mem.indexOf(u8, message, "filesystem access disabled") != null);
}

test "api load string, do string, and protected error" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var chunk = try lua.loadString("assert(1 + 1 == 2)", .{ .name = "=unit" });
    defer chunk.deinit();
    try chunk.call(.{}, void);

    var failing = try lua.loadString("error('boom')", .{ .name = "=unit" });
    defer failing.deinit();

    const result = try failing.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "boom") != null);
        },
    }
}

test "api do file uses memory filesystem and reports source names" {
    const files = [_]MemoryFile{
        .{ .path = "ok.lua", .contents = "assert(2 * 3 == 6)" },
        .{ .path = "bad.lua", .contents = "return (" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();

    try lua.doFile("ok.lua", .{ .name = "@ok.lua" });
    try std.testing.expectError(error.LuaError, lua.doFile("bad.lua", .{ .name = "@bad.lua" }));

    const message = try lua.errorMessage();
    defer lua.allocator().free(message);
    try std.testing.expect(std.mem.indexOf(u8, message, "bad.lua") != null);
}

test "api primitive values round trip through calls and conversion" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var identity = try lua.loadString("return ...", .{ .name = "=identity" });
    defer identity.deinit();

    try std.testing.expectEqual(true, try identity.call(.{true}, bool));
    try std.testing.expectEqual(@as(i64, -42), try identity.call(.{-42}, i64));
    try std.testing.expectEqual(@as(u8, 42), try identity.call(.{42}, u8));
    try std.testing.expectEqual(@as(f64, 1.5), try identity.call(.{1.5}, f64));
    try std.testing.expectEqualStrings("hello", try identity.call(.{"hello"}, []const u8));

    const pushed = try lua.push(@as(i64, 123));
    try std.testing.expectEqual(@as(i64, 123), try lua.read(pushed, i64));
}

test "api tuple helper reads multiple returns" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var chunk = try lua.loadString("return true, 42, 'ok'", .{ .name = "=tuple" });
    defer chunk.deinit();

    const Result = Tuple(&.{ bool, i64, []const u8 });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();

    try std.testing.expectEqual(true, result.get(0));
    try std.testing.expectEqual(@as(i64, 42), result.get(1));
    try std.testing.expectEqualStrings("ok", result.get(2));
}

test "api table and function handles round trip and survive forced GC" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local t = { answer = 42 }
        \\local function f(x) return x + 1 end
        \\return t, f
    , .{ .name = "=handles" });
    defer chunk.deinit();

    const Result = Tuple(&.{ Table, Function });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();

    try lua.collect();
    try std.testing.expectEqual(@as(i64, 42), try result.get(0).get("answer", i64));
    try std.testing.expectEqual(@as(i64, 42), try result.get(1).call(.{41}, i64));
}

test "api released handles remove runtime roots" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try std.testing.expectEqual(@as(usize, 0), lua.rootCountForTest());

    var chunk = try lua.loadString("return { alive = true }", .{ .name = "=root-count" });
    try std.testing.expectEqual(@as(usize, 1), lua.rootCountForTest());

    var table = try chunk.call(.{}, Table);
    try std.testing.expectEqual(@as(usize, 2), lua.rootCountForTest());

    try lua.collect();
    try std.testing.expectEqual(true, try table.get("alive", bool));

    table.deinit();
    try std.testing.expectEqual(@as(usize, 1), lua.rootCountForTest());
    chunk.deinit();
    try std.testing.expectEqual(@as(usize, 0), lua.rootCountForTest());

    try lua.collect();
}

test "api globals tables arrays and structs build Lua environments" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try lua.setGlobal("answer", 42);
    try std.testing.expectEqual(@as(i64, 42), try lua.getGlobal("answer", i64));

    var config = try lua.createTable(.{ .hash_hint = 4 });
    defer config.deinit();
    try config.set("title", "demo");
    try config.set("max_players", 8);
    try config.set("debug", true);
    try lua.setGlobal("config", config);

    try lua.setGlobal("search_path", &.{ "scripts/?.lua", "scripts/?/init.lua" });
    try lua.setGlobal("app", .{
        .name = "zlua-host",
        .version = 1,
        .features = &.{ "plugins", "sandbox" },
    });

    try lua.doString(
        \\assert(config.title == 'demo')
        \\assert(config.max_players == 8)
        \\assert(config.debug == true)
        \\assert(search_path[1] == 'scripts/?.lua')
        \\assert(search_path[2] == 'scripts/?/init.lua')
        \\assert(app.name == 'zlua-host')
        \\assert(app.version == 1)
        \\assert(app.features[1] == 'plugins')
        \\assert(app.features[2] == 'sandbox')
    , .{ .name = "=api-21.3-env" });

    var app = try lua.getGlobal("app", Table);
    defer app.deinit();
    var features = try app.get("features", Table);
    defer features.deinit();
    try std.testing.expectEqualStrings("sandbox", try features.get(2, []const u8));
}

test "api preloaded module is returned by require" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var host = try lua.createModule("host");
    defer host.deinit();
    try host.set("name", "host-module");
    try host.set("version", 3);
    try lua.preloadModule("host", host);

    try lua.doString(
        \\local host = require('host')
        \\assert(host.name == 'host-module')
        \\assert(host.version == 3)
    , .{ .name = "=api-21.3-preload" });
}

test "api package path loads memory backed Lua modules" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try lua.addMemoryFile("plugins/mathx.lua",
        \\local M = {}
        \\function M.double(x) return x * 2 end
        \\return M
    );
    try lua.setPackagePath("plugins/?.lua");

    try lua.doString(
        \\local mathx = require('mathx')
        \\assert(mathx.double(21) == 42)
    , .{ .name = "=api-21.3-memory-require" });
}
