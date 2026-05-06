const std = @import("std");
const runtime = @import("runtime.zig");
const stdlib = @import("stdlib.zig");

pub const Error = error{LuaError};
pub const UnsupportedOption = error{UnsupportedOption};

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

pub const GcBudget = struct {
    steps: usize = 0,
};

pub const GcStepResult = enum {
    complete,
    pending,
};

pub const State = struct {
    raw_state: runtime.State,
    last_error_value: ?runtime.Value = null,

    pub fn init(state_allocator: std.mem.Allocator, options: Options) !State {
        return .{
            .raw_state = try runtime.State.initWithOptions(state_allocator, runtimeOptions(options)),
        };
    }

    pub fn deinit(self: *State) void {
        self.raw_state.deinit();
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
        const value = self.last_error_value orelse self.raw_state.currentErrorValue();
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator());
        try runtime.appendValue(self.allocator(), &out, value);
        return self.allocator().dupe(u8, out.items);
    }

    pub fn takeErrorValue(self: *State) ?ErrorRef {
        const value = self.last_error_value orelse return null;
        self.last_error_value = null;
        return .{ .state = self, .raw_value = value };
    }

    fn captureLuaError(self: *State, err: anyerror) anyerror {
        switch (err) {
            error.RuntimeError, error.StackOverflow, error.UnsupportedOpcode => {
                self.last_error_value = self.raw_state.currentErrorValue();
                return error.LuaError;
            },
            else => return err,
        }
    }
};

pub const Ref = struct {
    pub fn deinit(self: *Ref) void {
        self.* = undefined;
    }

    pub fn value(self: Ref) Value {
        _ = self;
        return .nil;
    }
};

pub const Table = struct {
    raw_table: *runtime.Table,
};

pub const Function = struct {
    state: *State,
    raw_closure: *runtime.Closure,

    fn fromRuntime(state: *State, value: runtime.Value) !Function {
        return switch (value) {
            .closure => |closure| .{ .state = state, .raw_closure = closure },
            else => error.TypeMismatch,
        };
    }

    pub fn deinit(self: *Function) void {
        self.* = undefined;
    }

    pub fn call(self: Function, args: anytype, comptime R: type) !R {
        requireEmptyArgs(args);
        if (R != void) @compileError("phase 21.1 Function.call only supports void results");

        const results = self.state.raw_state.callLoadedClosure(self.raw_closure, &.{}) catch |err| return self.state.captureLuaError(err);
        defer self.state.allocator().free(results);
        return {};
    }

    pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R) {
        requireEmptyArgs(args);
        if (R != void) @compileError("phase 21.1 Function.protectedCall only supports void results");

        const result = try self.state.raw_state.protectedCallLoadedClosure(self.raw_closure, &.{});
        switch (result) {
            .success => |values| {
                self.state.allocator().free(values);
                return .{ .ok = {} };
            },
            .failure => |value| {
                self.state.last_error_value = value;
                return .{ .lua_error = .{ .state = self.state, .raw_value = value } };
            },
        }
    }
};

pub fn CallResult(comptime R: type) type {
    return union(enum) {
        ok: R,
        lua_error: ErrorRef,
    };
}

pub const ErrorRef = struct {
    state: *State,
    raw_value: runtime.Value,

    pub fn deinit(self: *ErrorRef) void {
        self.* = undefined;
    }

    pub fn value(self: ErrorRef) Value {
        return Value.fromRuntime(self.state, self.raw_value);
    }

    pub fn message(self: ErrorRef) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.state.allocator());
        try runtime.appendValue(self.state.allocator(), &out, self.raw_value);
        return self.state.allocator().dupe(u8, out.items);
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

    fn fromRuntime(state: *State, value: runtime.Value) Value {
        return switch (value) {
            .nil => .nil,
            .boolean => |boolean| .{ .boolean = boolean },
            .integer => |integer| .{ .integer = integer },
            .number => |number| .{ .number = number },
            .string => |string| .{ .string = string },
            .table => |table| .{ .table = .{ .raw_table = table } },
            .closure => |closure| .{ .function = .{ .state = state, .raw_closure = closure } },
            else => .unsupported,
        };
    }
};

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

fn requireEmptyArgs(args: anytype) void {
    const Args = @TypeOf(args);
    const info = @typeInfo(Args);
    if (info != .@"struct" or !info.@"struct".is_tuple) @compileError("phase 21.1 calls require an empty tuple argument list: .{}");
    if (info.@"struct".fields.len != 0) @compileError("phase 21.1 calls do not support arguments yet");
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
