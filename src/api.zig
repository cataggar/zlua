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

pub fn UserdataOptions(comptime T: type) type {
    return struct {
        finalizer: ?*const fn (*T) void = null,
    };
}

pub fn UserdataPtrOptions(comptime T: type) type {
    return struct {
        finalizer: ?*const fn (*T) void = null,
    };
}

pub const Stdlib = enum {
    none,
    base,
    safe,
    full,
};

pub const MemoryFile = runtime.MemoryFile;
pub const MemoryFilesystem = runtime.MemoryFilesystem;

pub const IoCapability = struct {
    runtime: ?std.Io = null,
    stdin: []const u8 = "",
    stdout: ?*std.Io.Writer = null,
    stderr: ?*std.Io.Writer = null,

    pub const disabled: IoCapability = .{};
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
    binary_only,
    source_or_binary,
};

pub const LoadOptions = struct {
    name: ?[]const u8 = null,
    environment: ?Table = null,
    mode: LoadMode = .source_only,
};

pub const DoOptions = LoadOptions;

pub const BytecodeLoadOptions = struct {
    environment: ?Table = null,
};

pub const BytecodeDumpOptions = struct {
    strip_debug: bool = false,
};

pub const TableOptions = struct {
    array_hint: u32 = 0,
    hash_hint: u32 = 0,
};

pub const HostFn = *const fn (ctx: *Context) anyerror!void;

const RegisteredCallback = struct {
    name: []const u8,
    callback: HostFn,
};

const callback_dispatch_global = "__zlua_api_callback";

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
    callbacks: std.ArrayList(RegisteredCallback) = .empty,

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
        self.deinitCallbacks(state_allocator);
        self.callbacks.deinit(state_allocator);
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

    pub fn register(self: *State, name: []const u8, callback: HostFn) !Function {
        if (std.mem.eql(u8, name, callback_dispatch_global)) return error.UnsupportedOption;
        return self.createCallbackFunction(name, callback);
    }

    pub fn registerTyped(self: *State, name: []const u8, comptime function: anytype) !Function {
        const Wrapper = struct {
            fn call(ctx: *Context) !void {
                try callTyped(function, ctx);
            }
        };

        return self.register(name, Wrapper.call);
    }

    pub fn createTable(self: *State, options: TableOptions) !Table {
        const raw = self.raw_state.newTableWithHints(options.array_hint, options.hash_hint) catch |err| return self.captureLuaError(err);
        return Table.fromRuntime(self, raw);
    }

    pub fn newUserdata(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T) {
        const ptr = try self.allocator().create(T);
        errdefer self.allocator().destroy(ptr);
        ptr.* = value;

        const raw = try self.raw_state.newUserdata(ptr, typeId(T), @typeName(T), userdataFinalizer(T, options.finalizer), userdataFinalizerData(T, options.finalizer), userdataDestroy(T));
        var userdata = try Userdata(T).fromRuntime(self, raw);
        errdefer userdata.deinit();
        try userdata.initMetatable();
        return userdata;
    }

    pub fn newUserdataPtr(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T) {
        const raw = try self.raw_state.newUserdata(ptr, typeId(T), @typeName(T), userdataFinalizer(T, options.finalizer), userdataFinalizerData(T, options.finalizer), null);
        var userdata = try Userdata(T).fromRuntime(self, raw);
        errdefer userdata.deinit();
        try userdata.initMetatable();
        return userdata;
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
            .memory_rw => |filesystem| {
                try filesystem.writeFile(path, contents);
                return;
            },
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
        const environment = try self.loadEnvironment(options);
        const loaded = self.loadBuffer(source, options.name, environment, options.mode) catch |err| return self.captureLuaError(err);
        return Function.fromRuntime(self, loaded);
    }

    pub fn loadFile(self: *State, path: []const u8, options: LoadOptions) !Function {
        const source = self.raw_state.readFileAlloc(path) catch |err| return self.captureLuaError(err);
        var keep_source = false;
        defer if (!keep_source) self.allocator().free(source);

        const allocated_source_name = if (options.name == null) try std.fmt.allocPrint(self.allocator(), "@{s}", .{path}) else null;
        defer if (allocated_source_name) |name| self.allocator().free(name);

        const environment = try self.loadEnvironment(options);
        const source_name = options.name orelse allocated_source_name.?;
        const loaded = self.loadBuffer(source, source_name, environment, options.mode) catch |err| return self.captureLuaError(err);
        if (!looksLikeBinaryChunk(source)) {
            try self.raw_state.source_allocations.append(self.allocator(), source);
            keep_source = true;
        }
        return Function.fromRuntime(self, loaded);
    }

    pub fn loadBytecode(self: *State, bytecode: []const u8, options: BytecodeLoadOptions) !Function {
        const environment = try self.environmentValue(options.environment);
        const loaded = self.raw_state.loadBinaryDump(bytecode, environment) catch |err| return self.captureLuaError(err);
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

    fn loadEnvironment(self: *State, options: LoadOptions) !runtime.Value {
        return self.environmentValue(options.environment);
    }

    fn environmentValue(self: *State, environment: ?Table) !runtime.Value {
        return if (environment) |table| try table.rawValue() else if (self.raw_state.global_table) |table| .{ .table = table } else self.raw_state.getGlobal("_G");
    }

    fn loadBuffer(self: *State, source: []const u8, source_name: ?[]const u8, environment: runtime.Value, mode: LoadMode) !runtime.Value {
        const binary = looksLikeBinaryChunk(source);
        switch (mode) {
            .source_only => if (binary) return self.raw_state.fail("attempt to load a binary chunk"),
            .binary_only => if (!binary) return self.raw_state.fail("attempt to load a text chunk"),
            .source_or_binary => {},
        }

        return if (binary)
            self.raw_state.loadBinaryDump(source, environment)
        else
            self.raw_state.loadSourceAsClosureNamedEnv(source, source_name, environment);
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

    fn ensureCallbackDispatcher(self: *State) !void {
        self.raw_state.setApiCallbackDispatch(apiCallbackDispatch, self);
        const raw_name = try self.raw_state.intern(callback_dispatch_global);
        self.raw_state.putGlobal(raw_name, .{ .native = .api_callback_dispatch }) catch |err| return self.captureLuaError(err);
    }

    fn createCallbackFunction(self: *State, name: []const u8, callback: HostFn) !Function {
        try self.ensureCallbackDispatcher();

        const name_copy = try self.allocator().dupe(u8, name);
        errdefer self.allocator().free(name_copy);

        try self.callbacks.append(self.allocator(), .{ .name = name_copy, .callback = callback });
        var callback_installed = false;
        errdefer if (!callback_installed) {
            const entry = self.callbacks.pop().?;
            self.allocator().free(entry.name);
        };

        const callback_id = self.callbacks.items.len;
        const source = try std.fmt.allocPrint(self.allocator(),
            \\return function(...)
            \\  return __zlua_api_callback({d}, ...)
            \\end
        , .{callback_id});
        defer self.allocator().free(source);

        var chunk = try self.loadString(source, .{ .name = "=zlua api callback wrapper" });
        defer chunk.deinit();
        const function = try chunk.call(.{}, Function);
        callback_installed = true;
        return function;
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

    fn deinitCallbacks(self: *State, state_allocator: std.mem.Allocator) void {
        for (self.callbacks.items) |entry| state_allocator.free(entry.name);
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

    pub fn dumpBytecode(self: Function, options: BytecodeDumpOptions) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        errdefer out.deinit(self.ref.state.allocator());
        try runtime.dumpClosureBinary(self.ref.state.allocator(), &out, try self.rawClosure(), options.strip_debug);
        return out.toOwnedSlice(self.ref.state.allocator());
    }

    fn rawClosure(self: Function) !*runtime.Closure {
        return switch (self.ref.rawValue()) {
            .closure => |closure| closure,
            else => error.TypeMismatch,
        };
    }
};

pub fn Userdata(comptime T: type) type {
    return struct {
        pub const is_zlua_userdata = true;
        pub const ValueType = T;

        ref: Ref,

        fn fromRuntime(state: *State, value: runtime.Value) !@This() {
            const raw = switch (value) {
                .userdata => |userdata| userdata,
                else => return error.TypeMismatch,
            };
            if (raw.type_id != typeId(T)) return error.TypeMismatch;
            return .{ .ref = try Ref.fromRuntime(state, value) };
        }

        pub fn deinit(self: *@This()) void {
            self.ref.deinit();
            self.* = undefined;
        }

        pub fn ptr(self: @This()) !*T {
            return userdataPtr(T, try self.rawUserdata());
        }

        pub fn method(self: @This(), name: []const u8, comptime function: anytype) !void {
            const Wrapper = struct {
                fn call(ctx: *Context) !void {
                    try callUserdataMethod(T, function, ctx);
                }
            };

            const callback_name = try std.fmt.allocPrint(self.ref.state.allocator(), "{s}.{s}", .{ @typeName(T), name });
            defer self.ref.state.allocator().free(callback_name);

            var method_function = try self.ref.state.createCallbackFunction(callback_name, Wrapper.call);
            defer method_function.deinit();

            const metatable = try self.metatableValue();
            const index_key = runtime.Value{ .string = try self.ref.state.raw_state.intern("__index") };
            var index_value = metatable.table.get(index_key);
            if (index_value == .nil) {
                index_value = self.ref.state.raw_state.newTableWithHints(0, 4) catch |err| return self.ref.state.captureLuaError(err);
                try metatable.table.set(self.ref.state.allocator(), index_key, index_value);
                self.ref.state.raw_state.setTableValue(metatable, index_key, index_value) catch |err| return self.ref.state.captureLuaError(err);
            }
            if (index_value != .table) return error.TypeMismatch;
            try self.ref.state.raw_state.setTableValue(index_value, .{ .string = try self.ref.state.raw_state.intern(name) }, .{ .closure = try method_function.rawClosure() });
        }

        pub fn metamethod(self: @This(), name: []const u8, comptime function: anytype) !void {
            const Wrapper = struct {
                fn call(ctx: *Context) !void {
                    try callUserdataMethod(T, function, ctx);
                }
            };

            const callback_name = try std.fmt.allocPrint(self.ref.state.allocator(), "{s}.{s}", .{ @typeName(T), name });
            defer self.ref.state.allocator().free(callback_name);

            var metamethod_function = try self.ref.state.createCallbackFunction(callback_name, Wrapper.call);
            defer metamethod_function.deinit();

            const metatable = try self.metatableValue();
            try self.ref.state.raw_state.setTableValue(metatable, .{ .string = try self.ref.state.raw_state.intern(name) }, .{ .closure = try metamethod_function.rawClosure() });
        }

        fn initMetatable(self: @This()) !void {
            const raw = try self.rawUserdata();
            if (raw.metatable != null) return;
            const metatable = self.ref.state.raw_state.newTableWithHints(0, 3) catch |err| return self.ref.state.captureLuaError(err);
            const index = self.ref.state.raw_state.newTableWithHints(0, 4) catch |err| return self.ref.state.captureLuaError(err);
            try metatable.table.set(self.ref.state.allocator(), .{ .string = try self.ref.state.raw_state.intern("__name") }, .{ .string = try self.ref.state.raw_state.intern(@typeName(T)) });
            try metatable.table.set(self.ref.state.allocator(), .{ .string = try self.ref.state.raw_state.intern("__index") }, index);
            raw.metatable = metatable.table;
        }

        fn rawValue(self: @This()) !runtime.Value {
            const raw = self.ref.rawValue();
            if (raw != .userdata) return error.TypeMismatch;
            return raw;
        }

        fn rawUserdata(self: @This()) !*runtime.Userdata {
            return switch (self.ref.rawValue()) {
                .userdata => |userdata| userdata,
                else => error.TypeMismatch,
            };
        }

        fn metatableValue(self: @This()) !runtime.Value {
            const raw = try self.rawUserdata();
            const metatable = raw.metatable orelse return error.TypeMismatch;
            return .{ .table = metatable };
        }
    };
}

pub const AnyUserdata = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !AnyUserdata {
        return switch (value) {
            .userdata => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    pub fn deinit(self: *AnyUserdata) void {
        self.ref.deinit();
        self.* = undefined;
    }

    fn rawValue(self: AnyUserdata) !runtime.Value {
        const raw = self.ref.rawValue();
        if (raw != .userdata) return error.TypeMismatch;
        return raw;
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
    userdata: AnyUserdata,
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
            .userdata => .{ .userdata = try AnyUserdata.fromRuntime(state, value) },
            else => .unsupported,
        };
    }

    pub fn deinit(self: *Value) void {
        switch (self.*) {
            .table => |*table| table.deinit(),
            .function => |*function| function.deinit(),
            .userdata => |*userdata| userdata.deinit(),
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
            .userdata => |userdata| userdata.rawValue(),
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

pub const Context = struct {
    lua: *State,
    raw: *runtime.ApiCallbackContext,

    pub fn state(self: *Context) *State {
        return self.lua;
    }

    pub fn argCount(self: *Context) usize {
        return self.raw.argCount();
    }

    pub fn arg(self: *Context, index: usize, comptime T: type) !T {
        const raw = self.raw.callbackArgValue(index);
        return fromRuntimeValue(self.lua, raw, T) catch |err| return self.argConversionError(index, T, raw, err);
    }

    pub fn optionalArg(self: *Context, index: usize, comptime T: type) !?T {
        if (index >= self.argCount()) return null;
        const raw = self.raw.callbackArgValue(index);
        if (raw == .nil) return null;
        return self.arg(index, T);
    }

    pub fn pushReturn(self: *Context, value: anytype) !void {
        const raw_value = toRuntimeValue(self.lua, value) catch |err| return self.returnConversionError(err);
        try self.raw.appendReturn(raw_value);
    }

    pub fn returnValues(self: *Context, values: anytype) !void {
        self.raw.clearReturns();
        try self.appendReturnValues(values);
    }

    pub fn raise(self: *Context, value: anytype) error{ LuaError, OutOfMemory } {
        const raw_value = toRuntimeValue(self.lua, value) catch |err| return raiseConversionError(err);
        return self.raw.raise(raw_value);
    }

    fn argConversionError(self: *Context, index: usize, comptime T: type, raw: runtime.Value, err: anyerror) anyerror {
        return switch (err) {
            error.TypeMismatch => self.raw.failArgumentType(index, expectedLuaType(T), raw),
            error.IntegerOutOfRange => self.raw.failArgumentMessage(index, "integer out of range"),
            error.UnsupportedType => self.raw.failArgumentMessage(index, "unsupported host argument type"),
            else => err,
        };
    }

    fn returnConversionError(self: *Context, err: anyerror) anyerror {
        return switch (err) {
            error.IntegerOutOfRange => self.raw.fail("host callback return integer out of range"),
            error.UnsupportedType => self.raw.fail("unsupported host callback return type"),
            else => err,
        };
    }

    fn raiseConversionError(err: anyerror) error{ LuaError, OutOfMemory } {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.LuaError,
        };
    }

    fn appendReturnValues(self: *Context, values: anytype) !void {
        const T = @TypeOf(values);
        const info = @typeInfo(T);
        if (info == .@"struct" and info.@"struct".is_tuple) {
            inline for (info.@"struct".fields, 0..) |_, index| try self.pushReturn(values[index]);
            return;
        }

        try self.pushReturn(values);
    }
};
pub const Thread = opaque {};

fn runtimeOptions(options: Options) runtime.StateOptions {
    return .{
        .stdlib = toRuntimeStdlib(options.stdlib),
        .io = options.capabilities.io.runtime,
        .stdout = options.capabilities.io.stdout,
        .stderr = options.capabilities.io.stderr,
        .filesystem = options.capabilities.filesystem,
        .environment = switch (options.capabilities.environment) {
            .disabled => null,
            .map => |map| map,
        },
        .clock = options.capabilities.clock,
        .process = options.capabilities.process,
        .stdin = options.capabilities.io.stdin,
        .max_memory = options.limits.max_memory,
        .max_stack_values = options.limits.max_stack_values,
        .max_call_frames = options.limits.max_call_frames,
        .max_instructions = options.limits.max_instructions,
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
    switch (options.mode) {
        .source_only => {},
        .binary_only => {},
        .source_or_binary => {},
    }
}

fn looksLikeBinaryChunk(source: []const u8) bool {
    return (source.len > 0 and source[0] == 0x1b) or
        std.mem.startsWith(u8, source, runtime.binary_chunk_signature) or
        (source.len > 0 and std.mem.startsWith(u8, runtime.binary_chunk_signature, source));
}

fn apiCallbackDispatch(raw: *runtime.ApiCallbackContext) anyerror!void {
    const user_data = raw.user_data orelse return raw.raise(.{ .string = try raw.state.intern("host callback state unavailable") });
    const state: *State = @ptrCast(@alignCast(user_data));
    if (raw.callback_id == 0 or raw.callback_id > state.callbacks.items.len) {
        return raw.raise(.{ .string = try raw.state.intern("unknown host callback") });
    }

    const entry = state.callbacks.items[raw.callback_id - 1];
    raw.function_name = entry.name;
    var context = Context{ .lua = state, .raw = raw };
    try entry.callback(&context);
}

fn callTyped(comptime function: anytype, ctx: *Context) !void {
    const FunctionType = @TypeOf(function);
    const SignatureType = switch (@typeInfo(FunctionType)) {
        .@"fn" => FunctionType,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => pointer.child,
            else => @compileError("registerTyped requires a function or function pointer"),
        },
        else => @compileError("registerTyped requires a function or function pointer"),
    };
    const function_info = switch (@typeInfo(FunctionType)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("registerTyped requires a function or function pointer"),
        },
        else => @compileError("registerTyped requires a function or function pointer"),
    };

    if (function_info.is_var_args) @compileError("registerTyped does not support varargs functions");

    var args: std.meta.ArgsTuple(SignatureType) = undefined;
    inline for (function_info.params, 0..) |param, index| {
        const Param = param.type orelse @compileError("registerTyped requires typed parameters");
        args[index] = try ctx.arg(index, Param);
    }

    const Return = function_info.return_type orelse void;
    if (Return == void) {
        @call(.auto, function, args);
        try ctx.returnValues(.{});
        return;
    }

    switch (@typeInfo(Return)) {
        .error_union => |error_union| {
            const result = try @call(.auto, function, args);
            if (error_union.payload == void) {
                try ctx.returnValues(.{});
            } else {
                try ctx.returnValues(result);
            }
        },
        else => {
            const result = @call(.auto, function, args);
            try ctx.returnValues(result);
        },
    }
}

fn callUserdataMethod(comptime T: type, comptime function: anytype, ctx: *Context) !void {
    _ = Userdata(T);
    const FunctionType = @TypeOf(function);
    const SignatureType = switch (@typeInfo(FunctionType)) {
        .@"fn" => FunctionType,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => pointer.child,
            else => @compileError("userdata methods require a function or function pointer"),
        },
        else => @compileError("userdata methods require a function or function pointer"),
    };
    const function_info = switch (@typeInfo(FunctionType)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("userdata methods require a function or function pointer"),
        },
        else => @compileError("userdata methods require a function or function pointer"),
    };

    if (function_info.is_var_args) @compileError("userdata methods do not support varargs functions");
    if (function_info.params.len == 0) @compileError("userdata methods require a receiver parameter");
    const Receiver = function_info.params[0].type orelse @compileError("userdata method receiver must be typed");
    if (@typeInfo(Receiver) != .pointer) @compileError("userdata method receiver must be a pointer");

    var args: std.meta.ArgsTuple(SignatureType) = undefined;
    args[0] = try ctx.arg(0, Receiver);
    inline for (function_info.params[1..], 1..) |param, index| {
        const Param = param.type orelse @compileError("userdata method parameters must be typed");
        args[index] = try ctx.arg(index, Param);
    }

    const Return = function_info.return_type orelse void;
    if (Return == void) {
        @call(.auto, function, args);
        try ctx.returnValues(.{});
        return;
    }

    switch (@typeInfo(Return)) {
        .error_union => |error_union| {
            const result = try @call(.auto, function, args);
            if (error_union.payload == void) {
                try ctx.returnValues(.{});
            } else {
                try ctx.returnValues(result);
            }
        },
        else => {
            const result = @call(.auto, function, args);
            try ctx.returnValues(result);
        },
    }
}

fn TypeToken(comptime T: type) type {
    return struct {
        const ValueType = T;
        var id: u8 = 0;
    };
}

fn typeId(comptime T: type) usize {
    return @intFromPtr(&TypeToken(T).id);
}

fn userdataPtr(comptime T: type, raw: *runtime.Userdata) !*T {
    if (raw.type_id != typeId(T)) return error.TypeMismatch;
    return @ptrCast(@alignCast(raw.ptr));
}

fn userdataFinalizer(comptime T: type, finalizer: ?*const fn (*T) void) ?runtime.UserdataFinalizer {
    if (finalizer == null) return null;
    return struct {
        fn call(ptr: *anyopaque, data: ?*const anyopaque) void {
            const typed_finalizer: *const fn (*T) void = @ptrCast(@alignCast(data.?));
            typed_finalizer(@ptrCast(@alignCast(ptr)));
        }
    }.call;
}

fn userdataFinalizerData(comptime T: type, finalizer: ?*const fn (*T) void) ?*const anyopaque {
    return if (finalizer) |active| @ptrCast(active) else null;
}

fn userdataDestroy(comptime T: type) runtime.UserdataDeinit {
    return struct {
        fn destroy(allocator: std.mem.Allocator, ptr: *anyopaque) void {
            allocator.destroy(@as(*T, @ptrCast(@alignCast(ptr))));
        }
    }.destroy;
}

fn isUserdataHandle(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => @hasDecl(T, "is_zlua_userdata") and T.is_zlua_userdata,
        else => false,
    };
}

fn isOwnedApiValue(comptime T: type) bool {
    return T == Value or T == Ref or T == Table or T == Function or T == ErrorRef or T == AnyUserdata or isUserdataHandle(T);
}

fn expectedLuaType(comptime T: type) []const u8 {
    if (T == Value or T == Ref or T == ErrorRef) return "value";
    if (T == Table) return "table";
    if (T == Function) return "function";
    if (T == AnyUserdata or isUserdataHandle(T)) return "userdata";

    return switch (@typeInfo(T)) {
        .bool => "boolean",
        .int, .comptime_int, .float, .comptime_float => "number",
        .optional => |optional| expectedLuaType(optional.child),
        .pointer => |pointer| switch (pointer.size) {
            .slice => if (pointer.child == u8) "string" else "value",
            .one => if (@typeInfo(pointer.child) == .@"struct") @typeName(pointer.child) else "value",
            else => "value",
        },
        else => "value",
    };
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
    if (comptime isUserdataHandle(T)) return value.rawValue();

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
    if (T == AnyUserdata) return AnyUserdata.fromRuntime(state, raw);
    if (comptime isUserdataHandle(T)) return T.fromRuntime(state, raw);
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
            .one => if (@typeInfo(pointer.child) == .@"struct") switch (raw) {
                .userdata => |userdata| userdataPtr(pointer.child, userdata),
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
    if (comptime isOwnedApiValue(T)) {
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

test "api host callbacks read arguments and return multiple values" {
    const Callbacks = struct {
        fn add(ctx: *Context) !void {
            const lhs = try ctx.arg(0, i64);
            const rhs = try ctx.arg(1, i64);
            try ctx.returnValues(.{ lhs + rhs, "ok" });
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var host_add = try lua.register("host_add", Callbacks.add);
    defer host_add.deinit();

    try std.testing.expectError(error.TypeMismatch, lua.getGlobal("host_add", Function));

    const Result = Tuple(&.{ i64, []const u8 });
    var result = try host_add.call(.{ 20, 22 }, Result);
    defer result.deinit();

    try std.testing.expectEqual(@as(i64, 42), result.get(0));
    try std.testing.expectEqualStrings("ok", result.get(1));
}

test "api host callback functions can be installed as globals" {
    const Callbacks = struct {
        fn add(ctx: *Context) !void {
            const lhs = try ctx.arg(0, i64);
            const rhs = try ctx.arg(1, i64);
            try ctx.returnValues(.{ lhs + rhs, "ok" });
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var host_add = try lua.register("host_add", Callbacks.add);
    defer host_add.deinit();
    try lua.setGlobal("host_add", host_add);
    try lua.doString(
        \\local sum, label = host_add(20, 22)
        \\assert(sum == 42)
        \\assert(label == 'ok')
    , .{ .name = "=api-21.4-host-add" });
}

test "api host callback argument errors become Lua errors" {
    const Callbacks = struct {
        fn needInteger(ctx: *Context) !void {
            _ = try ctx.arg(0, i64);
            try ctx.returnValues(.{});
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var need_integer = try lua.register("need_integer", Callbacks.needInteger);
    defer need_integer.deinit();
    try lua.setGlobal("need_integer", need_integer);
    var chunk = try lua.loadString("return need_integer('nope')", .{ .name = "=api-21.4-arg-error" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "need_integer") != null);
            try std.testing.expect(std.mem.indexOf(u8, message, "number") != null);
        },
    }
}

test "api host callback can raise Lua error values" {
    const Callbacks = struct {
        fn fail(ctx: *Context) !void {
            return ctx.raise("host boom");
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var host_fail = try lua.register("host_fail", Callbacks.fail);
    defer host_fail.deinit();
    try lua.setGlobal("host_fail", host_fail);
    var chunk = try lua.loadString("host_fail()", .{ .name = "=api-21.4-raise" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "host boom") != null);
        },
    }
}

test "api host callback can hold and call Lua callback function" {
    const Callbacks = struct {
        fn each(ctx: *Context) !void {
            var callback = try ctx.arg(0, Function);
            defer callback.deinit();

            const first = try callback.call(.{20}, i64);
            const second = try callback.call(.{41}, i64);
            try ctx.returnValues(.{ first, second });
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var host_each = try lua.register("host_each", Callbacks.each);
    defer host_each.deinit();
    try lua.setGlobal("host_each", host_each);
    try lua.doString(
        \\local a, b = host_each(function(value)
        \\  return value + 1
        \\end)
        \\assert(a == 21)
        \\assert(b == 42)
    , .{ .name = "=api-21.4-lua-callback" });
}

test "api typed host callback wrapper compiles and runs" {
    const Callbacks = struct {
        fn clamp(value: f64, min: f64, max: f64) f64 {
            return @min(@max(value, min), max);
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var clamp = try lua.registerTyped("clamp", Callbacks.clamp);
    defer clamp.deinit();
    try lua.setGlobal("clamp", clamp);
    try lua.doString(
        \\assert(clamp(5, 1, 10) == 5)
        \\assert(clamp(-1, 1, 10) == 1)
        \\assert(clamp(11, 1, 10) == 10)
    , .{ .name = "=api-21.4-typed" });
}

test "api userdata methods receive typed Zig pointers" {
    const Counter = struct {
        value: i64,

        fn inc(self: *@This(), amount: i64) i64 {
            self.value += amount;
            return self.value;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdata(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();
    try counter.method("inc", Counter.inc);
    try lua.setGlobal("counter", counter);

    try lua.doString(
        \\assert(type(counter) == 'userdata')
        \\assert(counter:inc(2) == 2)
        \\assert(counter:inc(3) == 5)
    , .{ .name = "=api-21.5-counter" });

    try std.testing.expectEqual(@as(i64, 5), (try counter.ptr()).value);
}

test "api userdata pointer wrappers and Context.arg typed reads" {
    const Counter = struct {
        value: i64,
    };
    const Callbacks = struct {
        fn add(ctx: *Context) !void {
            const counter = try ctx.arg(0, *Counter);
            const amount = try ctx.arg(1, i64);
            counter.value += amount;
            try ctx.returnValues(counter.value);
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var backing = Counter{ .value = 10 };
    var counter = try lua.newUserdataPtr(Counter, &backing, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);
    var add_counter = try lua.register("add_counter", Callbacks.add);
    defer add_counter.deinit();
    try lua.setGlobal("add_counter", add_counter);

    try lua.doString("assert(add_counter(counter, 32) == 42)", .{ .name = "=api-21.5-ptr" });
    try std.testing.expectEqual(@as(i64, 42), backing.value);
}

test "api userdata wrong type errors are clear" {
    const Counter = struct { value: i64 };
    const Other = struct { value: i64 };
    const Callbacks = struct {
        fn needCounter(ctx: *Context) !void {
            _ = try ctx.arg(0, *Counter);
            try ctx.returnValues(.{});
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var other = try lua.newUserdata(Other, .{ .value = 1 }, .{});
    defer other.deinit();
    try lua.setGlobal("other", other);
    var need_counter = try lua.register("need_counter", Callbacks.needCounter);
    defer need_counter.deinit();
    try lua.setGlobal("need_counter", need_counter);

    var chunk = try lua.loadString("need_counter(other)", .{ .name = "=api-21.5-wrong-userdata" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "need_counter") != null);
            try std.testing.expect(std.mem.indexOf(u8, message, @typeName(Counter)) != null);
            try std.testing.expect(std.mem.indexOf(u8, message, @typeName(Other)) != null);
        },
    }
}

test "api userdata finalizers run under forced GC" {
    const Tracker = struct {
        finalized: *usize,

        fn finalize(self: *@This()) void {
            self.finalized.* += 1;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var finalized: usize = 0;
    {
        var tracker = try lua.newUserdata(Tracker, .{ .finalized = &finalized }, .{ .finalizer = Tracker.finalize });
        tracker.deinit();
    }

    try lua.collect();
    try std.testing.expectEqual(@as(usize, 1), finalized);
}

test "api userdata close metamethod runs for to-be-closed locals" {
    const Closer = struct {
        closed: *usize,

        fn close(self: *@This()) void {
            self.closed.* += 1;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var closed: usize = 0;
    var closer = try lua.newUserdata(Closer, .{ .closed = &closed }, .{});
    defer closer.deinit();
    try closer.metamethod("__close", Closer.close);
    try lua.setGlobal("closer", closer);

    try lua.doString(
        \\do
        \\  local scoped <close> = closer
        \\end
    , .{ .name = "=api-21.5-close" });
    try std.testing.expectEqual(@as(usize, 1), closed);
}

test "api full stdlib still denies ambient host access by default" {
    var lua = try State.init(std.testing.allocator, .{ .stdlib = .full });
    defer lua.deinit();

    try lua.doString(
        \\assert(os.getenv('ZLUA_API_ENV') == nil)
        \\local ok, err = pcall(os.execute, 'true')
        \\assert(ok == false and tostring(err):find('process access disabled'))
        \\local file = io.open('missing.lua', 'r')
        \\assert(file == nil)
        \\local loaded, load_err = loadfile('missing.lua')
        \\assert(loaded == nil and load_err == 'cannot open file')
        \\local ok_file, file_err = pcall(dofile, 'missing.lua')
        \\assert(ok_file == false and tostring(file_err):find('filesystem access disabled'))
    , .{ .name = "=api-21.6-safe-host-access" });
}

test "api os filesystem mutations respect filesystem capability" {
    const files = [_]MemoryFile{
        .{ .path = "keep.lua", .contents = "return 42" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();

    try lua.doString(
        \\local removed, remove_err = os.remove('keep.lua')
        \\assert(removed == nil and tostring(remove_err):find('filesystem write access disabled'))
        \\local renamed, rename_err = os.rename('keep.lua', 'gone.lua')
        \\assert(renamed == nil and tostring(rename_err):find('filesystem write access disabled'))
        \\assert(dofile('keep.lua') == 42)
    , .{ .name = "=api-21.6-os-fs-capability" });
}

test "api writable memory filesystem supports Lua writes and mutations" {
    var filesystem = MemoryFilesystem.init(std.testing.allocator);
    defer filesystem.deinit();
    try filesystem.writeFile("seed.lua", "return 'seed'");

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory_rw = &filesystem } },
    });
    defer lua.deinit();

    try lua.doString(
        \\assert(dofile('seed.lua') == 'seed')
        \\local file = assert(io.open('generated.lua', 'w'))
        \\assert(file:write("return 'generated'"))
        \\assert(file:close())
        \\assert(dofile('generated.lua') == 'generated')
        \\local log = assert(io.open('log.txt', 'w'))
        \\assert(log:write('alpha'))
        \\assert(log:close())
        \\log = assert(io.open('log.txt', 'a'))
        \\assert(log:write(' beta'))
        \\assert(log:close())
        \\local read = assert(io.open('log.txt', 'r'))
        \\assert(read:read('*a') == 'alpha beta')
        \\assert(read:close())
        \\assert(os.rename('generated.lua', 'renamed.lua'))
        \\assert(dofile('renamed.lua') == 'generated')
        \\assert(os.remove('renamed.lua'))
        \\assert(loadfile('renamed.lua') == nil)
    , .{ .name = "=api-21.6-memory-rw" });

    const log = try filesystem.readFileAlloc(std.testing.allocator, "log.txt");
    defer std.testing.allocator.free(log);
    try std.testing.expectEqualStrings("alpha beta", log);
}

test "api custom stdout captures print and io writes" {
    var output = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer output.deinit();
    var errors = std.Io.Writer.Allocating.init(std.testing.allocator);
    defer errors.deinit();

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .io = .{ .stdin = "input\n", .stdout = &output.writer, .stderr = &errors.writer } },
    });
    defer lua.deinit();

    try lua.doString(
        \\print('alpha', io.read('*l'))
        \\io.write('beta', '\n')
        \\io.stderr:write('gamma', '\n')
        \\io.flush()
        \\io.stderr:flush()
    , .{ .name = "=api-21.6-stdout" });

    try std.testing.expectEqualStrings("alpha\tinput\nbeta\n", output.writer.buffered());
    try std.testing.expectEqualStrings("gamma\n", errors.writer.buffered());
}

test "api memory filesystem backs loadfile dofile and require" {
    const files = [_]MemoryFile{
        .{ .path = "script.lua", .contents = "return 42" },
        .{ .path = "moddir/chunk.lua", .contents = "return 7" },
        .{ .path = "plugins/plugin.lua", .contents = "return { value = 9 }" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();
    try lua.setPackagePath("plugins/?.lua");

    try lua.doString(
        \\assert(dofile('script.lua') == 42)
        \\local chunk = assert(loadfile('moddir/chunk.lua'))
        \\assert(chunk() == 7)
        \\local plugin = require('plugin')
        \\assert(plugin.value == 9)
    , .{ .name = "=api-21.6-memory-fs" });
}

test "api environment and fixed clock capabilities are explicit" {
    var env = std.process.Environ.Map.init(std.testing.allocator);
    defer env.deinit();
    try env.put("ZLUA_API_ENV", "present");

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{
            .environment = .{ .map = &env },
            .clock = .{ .fixed = 123 },
        },
    });
    defer lua.deinit();

    try lua.doString(
        \\assert(os.getenv('ZLUA_API_ENV') == 'present')
        \\assert(os.time() == 123)
        \\assert(os.date('!%Y', 0) == '1970')
    , .{ .name = "=api-21.6-env-clock" });
}

test "api instruction limit returns a protected Lua error" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_instructions = 50 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString("while true do end", .{ .name = "=api-21.6-instruction-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "instruction limit exceeded") != null);
        },
    }
}

test "api load options support environments and binary modes" {
    var lua = try State.init(std.testing.allocator, .{ .stdlib = .full });
    defer lua.deinit();

    var env = try lua.createTable(.{ .hash_hint = 1 });
    defer env.deinit();
    try env.set("secret", 42);

    var source_chunk = try lua.loadString("return secret", .{ .name = "=api-21.6-env", .environment = env });
    defer source_chunk.deinit();
    try std.testing.expectEqual(@as(i64, 42), try source_chunk.call(.{}, i64));

    var dumper = try lua.loadString("return string.dump(function() return secret end)", .{ .name = "=api-21.6-dump" });
    defer dumper.deinit();
    const dumped = try dumper.call(.{}, []const u8);

    var binary_chunk = try lua.loadString(dumped, .{ .mode = .source_or_binary, .environment = env });
    defer binary_chunk.deinit();
    try std.testing.expectEqual(@as(i64, 42), try binary_chunk.call(.{}, i64));

    try std.testing.expectError(error.LuaError, lua.loadString(dumped, .{ .mode = .source_only }));
    try std.testing.expectError(error.LuaError, lua.loadString("return 1", .{ .mode = .binary_only }));
}

test "api dumps and loads zlua bytecode" {
    var source_state = try State.init(std.testing.allocator, .{});
    defer source_state.deinit();

    var source_chunk = try source_state.loadString("return secret, ...", .{ .name = "=api-bytecode" });
    defer source_chunk.deinit();

    const dumped = try source_chunk.dumpBytecode(.{ .strip_debug = true });
    defer source_state.allocator().free(dumped);

    var target_state = try State.init(std.testing.allocator, .{});
    defer target_state.deinit();

    var env = try target_state.createTable(.{ .hash_hint = 1 });
    defer env.deinit();
    try env.set("secret", "roundtrip");

    var loaded = try target_state.loadBytecode(dumped, .{ .environment = env });
    defer loaded.deinit();

    const Result = Tuple(&.{ []const u8, i64 });
    var result = try loaded.call(.{42}, Result);
    defer result.deinit();

    try std.testing.expectEqualStrings("roundtrip", result.get(0));
    try std.testing.expectEqual(@as(i64, 42), result.get(1));
    try std.testing.expectError(error.LuaError, target_state.loadBytecode("return 1", .{}));
}

test "api stack value limit returns a protected Lua error" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_stack_values = 4 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString("local a, b, c, d, e = 1, 2, 3, 4, 5; return a", .{ .name = "=api-21.6-stack-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "stack overflow") != null);
        },
    }
}

test "api call frame limit returns a protected Lua error" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_call_frames = 8 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local function recurse()
        \\  local value = recurse()
        \\  return value
        \\end
        \\recurse()
    , .{ .name = "=api-21.6-call-frame-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "stack overflow") != null);
        },
    }
}

test "api memory limit returns a protected Lua error" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_memory = 96 * 1024 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local t = {}
        \\for i = 1, 20000 do
        \\  t[i] = { i, i, i, i }
        \\end
        \\return t
    , .{ .name = "=api-21.6-memory-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "memory limit exceeded") != null);
        },
    }
}
