//! Zig-native embedding API for zlua.
//!
//! This module is the primary host-facing entrypoint. It provides a high-level
//! API around a Lua 5.5 state using Zig values, explicit host capabilities,
//! rooted handles, and Zig errors rather than the Lua C API stack discipline.
//!
//! A typical host creates a `State`, optionally grants capabilities and limits,
//! loads Lua source or bytecode, installs host callbacks or userdata, and then
//! exchanges values through typed conversions:
//!
//! ```zig
//! var lua = try zlua.State.init(allocator, .{});
//! defer lua.deinit();
//!
//! var chunk = try lua.loadString("return 21 * 2", .{ .name = "=example" });
//! defer chunk.deinit();
//!
//! const answer = try chunk.call(.{}, i64);
//! ```
//!
//! Handles such as `Table`, `Function`, `Ref`, `Userdata(T)`, `AnyUserdata`,
//! `ErrorRef`, and `Value` variants that contain handles root their Lua values
//! while they live. Hosts must call `deinit` on those handles when finished.
//!
//! The default `Options` open safe standard libraries while keeping filesystem,
//! environment, clock, process, and host I/O capabilities sandboxed. Grant host
//! services explicitly through `Capabilities` when embedded Lua code should be
//! allowed to observe or mutate the outside world.
//!
//! Convenience APIs return `error.LuaError` for Lua syntax/runtime failures and
//! store the last Lua error value on the `State`; use `errorMessage` or
//! `takeErrorValue` to inspect it. `Function.protectedCall` returns Lua failures
//! as `CallResult(R).lua_error` instead.
//!
//! The lower-level `runtime` module is an implementation detail for zlua itself
//! and should not be treated as a stable embedding contract.

const std = @import("std");
const runtime = @import("runtime.zig");
const stdlib = @import("stdlib.zig");

/// Error set used when an API operation failed because Lua raised a syntax or runtime error.
pub const Error = error{LuaError};
/// Error set used when an option combination is not supported by the high-level API.
pub const UnsupportedOption = error{UnsupportedOption};
/// Errors produced while converting values between Zig and Lua representations.
pub const ConversionError = error{
    TypeMismatch,
    IntegerOutOfRange,
    UnsupportedType,
    ArityMismatch,
};

/// Returns options for `State.newUserdata`, parameterized by the stored Zig type.
pub fn UserdataOptions(comptime T: type) type {
    return struct {
        /// Optional callback run before Lua-owned userdata storage is destroyed.
        finalizer: ?*const fn (*T) void = null,
    };
}

/// Returns options for `State.newUserdataPtr`, parameterized by the pointed-to Zig type.
pub fn UserdataPtrOptions(comptime T: type) type {
    return struct {
        /// Optional callback run when the Lua userdata wrapper is finalized.
        finalizer: ?*const fn (*T) void = null,
    };
}

/// Standard-library selection used when creating or opening a state.
pub const Stdlib = enum {
    /// Open no standard libraries.
    none,
    /// Open only base functionality.
    base,
    /// Open libraries considered safe for sandboxed embedding.
    safe,
    /// Open the full Lua standard-library surface; host capabilities still gate ambient access.
    full,
};

/// A read-only file entry for memory-backed filesystem capabilities.
pub const MemoryFile = runtime.MemoryFile;
/// Writable in-memory filesystem implementation for sandboxed file access.
pub const MemoryFilesystem = runtime.MemoryFilesystem;

/// Host I/O access granted to Lua standard-library operations.
pub const IoCapability = struct {
    /// Optional Zig I/O runtime required by host-backed filesystem, clock, and process operations.
    runtime: ?std.Io = null,
    /// Bytes returned by Lua stdin reads when the `io` library is enabled.
    stdin: []const u8 = "",
    /// Optional writer used for Lua stdout, including `print` and `io.write`.
    stdout: ?*std.Io.Writer = null,
    /// Optional writer used for Lua stderr.
    stderr: ?*std.Io.Writer = null,

    /// I/O capability with no host I/O handles or captured streams.
    pub const disabled: IoCapability = .{};
};

/// Filesystem access granted to Lua file APIs, `loadfile`, `dofile`, and `require`.
pub const FilesystemCapability = runtime.FilesystemCapability;
/// Callback-backed filesystem access for embedders with non-std host services.
pub const CustomFilesystem = runtime.CustomFilesystem;

/// Environment-variable access granted to `os.getenv` and enabled child processes.
pub const EnvironmentCapability = runtime.EnvironmentCapability;
/// Callback-backed environment access for embedders with non-std host services.
pub const CustomEnvironment = runtime.CustomEnvironment;

/// Clock access granted to Lua time/date APIs.
pub const ClockCapability = runtime.ClockCapability;
/// Callback-backed clock access for embedders with non-std host services.
pub const CustomClock = runtime.CustomClock;
/// Process-spawning access granted to `os.execute`.
pub const ProcessCapability = runtime.ProcessCapability;
/// Callback-backed process execution for embedders with non-std host services.
pub const CustomProcess = runtime.CustomProcess;
/// Result returned by callback-backed process execution.
pub const ProcessResult = runtime.ProcessResult;
pub const ProcessStatus = runtime.ProcessStatus;

/// Host services Lua code may use when matching standard-library functions are open.
pub const Capabilities = struct {
    /// I/O streams and runtime used by host-facing libraries.
    io: IoCapability = .disabled,
    /// Filesystem backend or denial mode.
    filesystem: FilesystemCapability = .disabled,
    /// Environment-variable source or denial mode.
    environment: EnvironmentCapability = .disabled,
    /// Clock source or denial mode.
    clock: ClockCapability = .disabled,
    /// Process execution mode.
    process: ProcessCapability = .disabled,

    /// Capability set that denies all ambient host access.
    pub const sandboxed: Capabilities = .{};
};

/// Resource limits enforced by the state.
pub const Limits = struct {
    /// Maximum bytes allocated through the state's runtime allocator, or unlimited when null.
    max_memory: ?usize = null,
    /// Maximum VM stack values, or the runtime default when null.
    max_stack_values: ?usize = null,
    /// Maximum active call frames, or the runtime default when null.
    max_call_frames: ?usize = null,
    /// Maximum VM instructions executed since the last budget reset, or unlimited when null.
    max_instructions: ?u64 = null,
};

/// Snapshot of the state's cumulative instruction budget.
pub const InstructionBudget = struct {
    /// Configured instruction limit, or null when unlimited.
    limit: ?u64,
    /// Number of VM instructions executed since state creation or the last reset.
    used: u64,
    /// Remaining instructions before the limit is exhausted, or null when unlimited.
    remaining: ?u64,
};

/// Garbage-collector tuning options, reserved for future API expansion.
pub const GcOptions = struct {};

/// Diagnostics and tracing options intended for development and tests.
pub const DebugOptions = struct {
    /// Include richer internal error diagnostics where available.
    errors: bool = false,
    /// Trace VM execution.
    trace_vm: bool = false,
};

/// State creation options.
pub const Options = struct {
    /// Standard libraries opened during `State.init`.
    stdlib: Stdlib = .safe,
    /// Host services made available to opened standard libraries.
    capabilities: Capabilities = .sandboxed,
    /// Resource limits for the state.
    limits: Limits = .{},
    /// Garbage-collector options.
    gc: GcOptions = .{},
    /// Debug and tracing options.
    debug: DebugOptions = .{},
};

/// Accepted chunk kinds for `loadString` and `loadFile`.
pub const LoadMode = enum {
    /// Accept only Lua source text.
    source_only,
    /// Accept only zlua binary chunks.
    binary_only,
    /// Accept either Lua source text or zlua binary chunks.
    source_or_binary,
};

/// Options for loading a Lua chunk from source or a file.
pub const LoadOptions = struct {
    /// Optional source name used in diagnostics; use Lua-style `=name` or `@path` when desired.
    name: ?[]const u8 = null,
    /// Optional environment table used as the chunk's `_ENV`.
    environment: ?Table = null,
    /// Whether source text, binary chunks, or both are accepted.
    mode: LoadMode = .source_only,
};

/// Options for one-shot `doString` and `doFile` execution.
pub const DoOptions = LoadOptions;

/// Options for loading zlua bytecode directly.
pub const BytecodeLoadOptions = struct {
    /// Optional environment table used as the loaded function's `_ENV`.
    environment: ?Table = null,
};

/// Options for dumping a loaded function to zlua bytecode.
pub const BytecodeDumpOptions = struct {
    /// Whether debug/source metadata should be omitted from the dump.
    strip_debug: bool = false,
};

/// Initial capacity hints for a newly created Lua table.
pub const TableOptions = struct {
    /// Expected number of array-part entries.
    array_hint: u32 = 0,
    /// Expected number of hash-part entries.
    hash_hint: u32 = 0,
};

/// Untyped host callback signature used by `State.register`.
pub const HostFn = *const fn (ctx: *Context) anyerror!void;

const RegisteredCallback = struct {
    name: []const u8,
    callback: HostFn,
};

const callback_dispatch_global = "__zlua_api_callback";
const memory_limit_error_message = "memory limit exceeded";

const MemoryLimitAllocator = struct {
    parent: std.mem.Allocator,
    limit: usize,
    used: usize = 0,
    exceeded: bool = false,

    fn init(parent: std.mem.Allocator, limit: usize) MemoryLimitAllocator {
        return .{ .parent = parent, .limit = limit };
    }

    fn allocator(self: *MemoryLimitAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn canGrow(self: *const MemoryLimitAllocator, amount: usize) bool {
        return amount <= self.limit -| self.used;
    }

    fn deny(self: *MemoryLimitAllocator) ?[*]u8 {
        self.exceeded = true;
        return null;
    }

    const vtable = std.mem.Allocator.VTable{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));
        if (!self.canGrow(len)) return self.deny();
        const ptr = self.parent.rawAlloc(len, alignment, ret_addr) orelse return null;
        self.used += len;
        return ptr;
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));
        if (new_len > memory.len and !self.canGrow(new_len - memory.len)) {
            self.exceeded = true;
            return false;
        }
        if (!self.parent.rawResize(memory, alignment, new_len, ret_addr)) return false;
        if (new_len > memory.len) {
            self.used += new_len - memory.len;
        } else {
            self.used -= @min(self.used, memory.len - new_len);
        }
        return true;
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));
        if (new_len > memory.len and !self.canGrow(new_len - memory.len)) return self.deny();
        const ptr = self.parent.rawRemap(memory, alignment, new_len, ret_addr) orelse return null;
        if (new_len > memory.len) {
            self.used += new_len - memory.len;
        } else {
            self.used -= @min(self.used, memory.len - new_len);
        }
        return ptr;
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));
        self.used -= @min(self.used, memory.len);
        self.parent.rawFree(memory, alignment, ret_addr);
    }
};

/// Budget passed to `State.stepGc`.
pub const GcBudget = struct {
    /// Requested number of GC steps; currently reserved because `stepGc` performs a full collection.
    steps: usize = 0,
};

/// Result of an incremental garbage-collection step.
pub const GcStepResult = enum {
    /// The requested collection work completed.
    complete,
    /// More work remains.
    pending,
};

/// Owns a Lua VM instance and its host-facing API state.
pub const State = struct {
    /// Allocator originally supplied by the host for state-owned storage.
    base_allocator: std.mem.Allocator,
    /// Optional bounded allocator state used when `Limits.max_memory` is configured.
    memory_limit_allocator: ?*MemoryLimitAllocator = null,
    /// Underlying Lua runtime state.
    raw_state: runtime.State,
    /// Registry root for the last captured Lua error value.
    last_error_root: ?usize = null,
    /// Owned memory-file entries visible to the configured memory filesystem.
    memory_files: std.ArrayList(MemoryFile) = .empty,
    /// Tracks whether each memory-file entry owns its contents slice.
    memory_file_owned_contents: std.ArrayList(bool) = .empty,
    /// Host callbacks registered through the high-level API dispatcher.
    callbacks: std.ArrayList(RegisteredCallback) = .empty,

    /// Creates a new Lua state using `state_allocator` and the supplied options.
    ///
    /// The allocator must remain valid until `deinit`. The default options open
    /// safe libraries with sandboxed host capabilities.
    pub fn init(state_allocator: std.mem.Allocator, options: Options) !State {
        var memory_limit_allocator: ?*MemoryLimitAllocator = null;
        errdefer if (memory_limit_allocator) |allocator_ptr| state_allocator.destroy(allocator_ptr);

        const runtime_allocator = if (options.limits.max_memory) |limit| blk: {
            const allocator_ptr = try state_allocator.create(MemoryLimitAllocator);
            allocator_ptr.* = MemoryLimitAllocator.init(state_allocator, limit);
            memory_limit_allocator = allocator_ptr;
            break :blk allocator_ptr.allocator();
        } else state_allocator;

        var state = State{
            .base_allocator = state_allocator,
            .memory_limit_allocator = memory_limit_allocator,
            .raw_state = try runtime.State.initWithOptions(runtime_allocator, runtimeOptions(options)),
        };
        memory_limit_allocator = null;
        errdefer state.deinit();

        if (options.capabilities.filesystem == .memory) {
            const files = options.capabilities.filesystem.memory;
            for (files) |file| try state.appendMemoryFile(file.path, file.contents, false);
            state.raw_state.options.filesystem = .{ .memory = state.memory_files.items };
        }

        return state;
    }

    /// Releases all resources owned by the state and invalidates outstanding API handles.
    pub fn deinit(self: *State) void {
        const state_allocator = self.allocator();
        self.raw_state.deinit();
        self.deinitOwnedMemoryFiles(state_allocator);
        self.memory_files.deinit(state_allocator);
        self.memory_file_owned_contents.deinit(state_allocator);
        self.deinitCallbacks(state_allocator);
        self.callbacks.deinit(state_allocator);
        self.destroyMemoryLimitAllocator();
        self.* = undefined;
    }

    /// Returns the allocator used for API-owned allocations returned to the host.
    pub fn allocator(self: *State) std.mem.Allocator {
        return self.raw_state.allocator;
    }

    /// Returns the cumulative instruction budget usage for this state.
    pub fn instructionBudget(self: *const State) InstructionBudget {
        const used = self.raw_state.instruction_count;
        const remaining = if (self.raw_state.options.max_instructions) |limit|
            if (used >= limit) 0 else limit - used
        else
            null;
        return .{
            .limit = self.raw_state.options.max_instructions,
            .used = used,
            .remaining = remaining,
        };
    }

    /// Resets the cumulative instruction counter to zero.
    pub fn resetInstructionBudget(self: *State) void {
        self.raw_state.instruction_count = 0;
    }

    /// Opens additional standard libraries after state creation.
    pub fn openLibs(self: *State, mode: Stdlib) !void {
        try stdlib.openLibraries(&self.raw_state, toRuntimeStdlib(mode));
        if (!toRuntimeStdlib(mode).isEmpty()) try stdlib.installGlobalTable(&self.raw_state);
    }

    /// Runs a full garbage collection cycle.
    pub fn collect(self: *State) !void {
        try self.raw_state.collectGarbage();
    }

    /// Runs garbage-collection work for `budget` and reports whether collection completed.
    ///
    /// This currently performs a full collection regardless of the budget.
    pub fn stepGc(self: *State, budget: GcBudget) !GcStepResult {
        _ = budget;
        try self.collect();
        return .complete;
    }

    /// Converts a Zig value into a rooted high-level Lua `Value`.
    pub fn push(self: *State, value: anytype) !Value {
        return Value.fromRuntime(self, try toRuntimeValue(self, value));
    }

    /// Converts a high-level Lua `Value` to the requested Zig type.
    pub fn read(self: *State, value: Value, comptime T: type) !T {
        return fromRuntimeValue(self, try value.toRuntime(), T);
    }

    /// Sets a global variable after converting `value` to a Lua value.
    pub fn setGlobal(self: *State, name: []const u8, value: anytype) !void {
        const raw_name = try self.raw_state.intern(name);
        const raw_value = try toRuntimeValue(self, value);
        self.raw_state.putGlobal(raw_name, raw_value) catch |err| return self.captureLuaError(err);
    }

    /// Reads a global variable and converts it to `T`.
    pub fn getGlobal(self: *State, name: []const u8, comptime T: type) !T {
        return fromRuntimeValue(self, self.raw_state.getGlobal(name), T);
    }

    /// Creates a Lua function handle that dispatches to an untyped Zig callback.
    ///
    /// The returned function is not installed automatically; use `setGlobal` or
    /// `Table.set` to expose it to Lua code.
    pub fn register(self: *State, name: []const u8, callback: HostFn) !Function {
        if (std.mem.eql(u8, name, callback_dispatch_global)) return error.UnsupportedOption;
        return self.createCallbackFunction(name, callback);
    }

    /// Creates a Lua function handle from a typed Zig function.
    ///
    /// Parameters are read from Lua arguments by type. A `*Context` parameter may
    /// be included to access the state or advanced callback APIs.
    pub fn registerTyped(self: *State, name: []const u8, comptime function: anytype) !Function {
        const Wrapper = struct {
            fn call(ctx: *Context) !void {
                try callTyped(function, ctx);
            }
        };

        return self.register(name, Wrapper.call);
    }

    /// Creates a Lua function handle that constructs auto-bound userdata using `initializer`.
    ///
    /// The initializer's parameters are read from Lua arguments by type. A
    /// `*Context` parameter may be included and is injected without consuming a
    /// Lua argument. The initializer must return `T` or `!T`; the result is
    /// wrapped with `newUserdataAuto` before being returned to Lua.
    pub fn registerUserdataInitializerWith(self: *State, comptime T: type, name: []const u8, comptime initializer: anytype, comptime options: UserdataOptions(T)) !Function {
        const Wrapper = struct {
            fn call(ctx: *Context) !void {
                try callUserdataInitializer(T, initializer, options, ctx);
            }
        };

        return self.register(name, Wrapper.call);
    }

    /// Creates a rooted Lua table handle with optional capacity hints.
    pub fn createTable(self: *State, options: TableOptions) !Table {
        const raw = self.raw_state.newTableWithHints(options.array_hint, options.hash_hint) catch |err| return self.captureLuaError(err);
        return Table.fromRuntime(self, raw);
    }

    /// Allocates Lua-owned userdata storage initialized with `value`.
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

    /// Allocates Lua-owned userdata and installs eligible methods declared on `T`.
    ///
    /// Public function declarations whose first parameter is `*T` or `*const T`
    /// are installed on the userdata. Names beginning with `__` are installed as
    /// metamethods; all other eligible names are installed on `__index`.
    pub fn newUserdataAuto(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T) {
        var userdata = try self.newUserdata(T, value, options);
        errdefer userdata.deinit();
        try userdata.bindMethods(T);
        return userdata;
    }

    /// Wraps host-owned storage as Lua userdata without taking ownership of `ptr`.
    pub fn newUserdataPtr(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T) {
        const raw = try self.raw_state.newUserdata(ptr, typeId(T), @typeName(T), userdataFinalizer(T, options.finalizer), userdataFinalizerData(T, options.finalizer), null);
        var userdata = try Userdata(T).fromRuntime(self, raw);
        errdefer userdata.deinit();
        try userdata.initMetatable();
        return userdata;
    }

    /// Wraps host-owned storage as Lua userdata and installs eligible methods declared on `T`.
    pub fn newUserdataPtrAuto(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T) {
        var userdata = try self.newUserdataPtr(T, ptr, options);
        errdefer userdata.deinit();
        try userdata.bindMethods(T);
        return userdata;
    }

    /// Creates a table intended to be installed as a Lua module.
    pub fn createModule(self: *State, name: []const u8) !Table {
        _ = name;
        return self.createTable(.{ .hash_hint = 4 });
    }

    /// Adds `module` to `package.loaded` so `require(name)` returns it.
    pub fn preloadModule(self: *State, name: []const u8, module: Table) !void {
        try self.ensurePackageLibrary();

        var package = try self.getGlobal("package", Table);
        defer package.deinit();
        var loaded = try package.get("loaded", Table);
        defer loaded.deinit();
        try loaded.set(name, module);
    }

    /// Sets `package.path`, opening the package library first if needed.
    pub fn setPackagePath(self: *State, path: []const u8) !void {
        try self.ensurePackageLibrary();

        var package = try self.getGlobal("package", Table);
        defer package.deinit();
        try package.set("path", path);
    }

    /// Adds or writes a file in the state's memory-backed filesystem.
    ///
    /// Disabled and read-only memory states store an owned copy. Writable memory
    /// filesystems receive a write. Host and custom filesystem states return
    /// `error.UnsupportedOption`.
    pub fn addMemoryFile(self: *State, path: []const u8, contents: []const u8) !void {
        switch (self.raw_state.options.filesystem) {
            .disabled, .memory => {},
            .memory_rw => |filesystem| {
                try filesystem.writeFile(path, contents);
                return;
            },
            .host_cwd, .custom => return error.UnsupportedOption,
        }

        try self.appendMemoryFile(path, contents, true);
        self.raw_state.options.filesystem = .{ .memory = self.memory_files.items };
    }

    /// Loads source text or bytecode from memory and returns a rooted function handle.
    pub fn loadString(self: *State, source: []const u8, options: LoadOptions) !Function {
        const environment = try self.loadEnvironment(options);
        const loaded = self.loadBuffer(source, options.name, environment, options.mode) catch |err| return self.captureLuaError(err);
        return Function.fromRuntime(self, loaded);
    }

    /// Loads source text or bytecode from the configured filesystem.
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

    /// Loads a zlua bytecode dump and returns a rooted function handle.
    pub fn loadBytecode(self: *State, bytecode: []const u8, options: BytecodeLoadOptions) !Function {
        const environment = try self.environmentValue(options.environment);
        const loaded = self.raw_state.loadBinaryDump(bytecode, environment) catch |err| return self.captureLuaError(err);
        return Function.fromRuntime(self, loaded);
    }

    /// Loads and immediately executes source text or bytecode from memory.
    pub fn doString(self: *State, source: []const u8, options: DoOptions) !void {
        var function = try self.loadString(source, options);
        defer function.deinit();
        try function.call(.{}, void);
    }

    /// Loads and immediately executes a chunk from the configured filesystem.
    pub fn doFile(self: *State, path: []const u8, options: DoOptions) !void {
        var function = try self.loadFile(path, options);
        defer function.deinit();
        try function.call(.{}, void);
    }

    /// Formats the last Lua error value as an allocated message.
    ///
    /// The caller owns the returned slice and must free it with `allocator()`.
    pub fn errorMessage(self: *State) ![]const u8 {
        const value = self.lastErrorValue();
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.allocator());
        try runtime.appendValue(self.allocator(), &out, value);
        return self.allocator().dupe(u8, out.items);
    }

    /// Takes ownership of the last captured Lua error value, if one exists.
    ///
    /// The returned `ErrorRef` must be deinitialized by the host.
    pub fn takeErrorValue(self: *State) ?ErrorRef {
        const index = self.last_error_root orelse return null;
        self.last_error_root = null;
        return .{ .ref = .{ .state = self, .index = index } };
    }

    fn setLastErrorValue(self: *State, value: runtime.Value) !void {
        if (self.last_error_root) |index| self.raw_state.unrootValue(index);
        self.last_error_root = null;
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
            error.OutOfMemory => if (self.takeMemoryLimitExceeded()) {
                self.raw_state.last_error = .{ .diagnostic = memory_limit_error_message };
                self.setLastErrorValue(self.raw_state.currentErrorValue()) catch {};
                return error.LuaError;
            } else return err,
            else => return err,
        }
    }

    fn takeMemoryLimitExceeded(self: *State) bool {
        const allocator_ptr = self.memory_limit_allocator orelse return false;
        if (!allocator_ptr.exceeded) return false;
        allocator_ptr.exceeded = false;
        return true;
    }

    fn memoryLimitErrorRef(self: *State) !ErrorRef {
        self.raw_state.last_error = .{ .diagnostic = memory_limit_error_message };
        const value = self.raw_state.currentErrorValue();
        self.setLastErrorValue(value) catch {};
        return ErrorRef.fromRuntime(self, value);
    }

    fn destroyMemoryLimitAllocator(self: *State) void {
        if (self.memory_limit_allocator) |allocator_ptr| {
            self.base_allocator.destroy(allocator_ptr);
            self.memory_limit_allocator = null;
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
        for (self.memory_files.items, 0..) |file, index| {
            state_allocator.free(file.path);
            if (self.memory_file_owned_contents.items[index]) state_allocator.free(file.contents);
        }
    }

    fn appendMemoryFile(self: *State, path: []const u8, contents: []const u8, owned_contents: bool) !void {
        const normalized_path = try MemoryFilesystem.normalizePathAlloc(self.allocator(), path, MemoryFilesystem.default_max_path_len);
        errdefer self.allocator().free(normalized_path);
        const stored_contents = if (owned_contents) try self.allocator().dupe(u8, contents) else contents;
        errdefer if (owned_contents) self.allocator().free(stored_contents);

        try self.memory_files.ensureUnusedCapacity(self.allocator(), 1);
        try self.memory_file_owned_contents.ensureUnusedCapacity(self.allocator(), 1);
        self.memory_files.appendAssumeCapacity(.{ .path = normalized_path, .contents = stored_contents });
        self.memory_file_owned_contents.appendAssumeCapacity(owned_contents);
    }

    fn deinitCallbacks(self: *State, state_allocator: std.mem.Allocator) void {
        for (self.callbacks.items) |entry| state_allocator.free(entry.name);
    }

    fn rootCountForTest(self: *State) usize {
        return self.raw_state.activeRootCount();
    }
};

/// Rooted handle to any Lua value.
pub const Ref = struct {
    state: *State,
    index: usize,

    fn fromRuntime(state: *State, raw: runtime.Value) !Ref {
        return .{ .state = state, .index = try state.raw_state.rootValue(raw) };
    }

    /// Releases this handle's root.
    pub fn deinit(self: *Ref) void {
        self.state.raw_state.unrootValue(self.index);
        self.* = undefined;
    }

    /// Returns the referenced value as a high-level `Value`.
    pub fn value(self: Ref) !Value {
        return Value.fromRuntime(self.state, self.rawValue());
    }

    fn rawValue(self: Ref) runtime.Value {
        return self.state.raw_state.rootedValue(self.index);
    }
};

/// Rooted handle to a Lua table.
pub const Table = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !Table {
        return switch (value) {
            .table => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    /// Releases this table handle's root.
    pub fn deinit(self: *Table) void {
        self.ref.deinit();
        self.* = undefined;
    }

    /// Reads `key` from the table and converts the result to `T`.
    pub fn get(self: Table, key: anytype, comptime T: type) !T {
        const raw = try self.rawValue();
        const raw_key = try toRuntimeValue(self.ref.state, key);
        const raw_value = self.ref.state.raw_state.getTableValue(raw, raw_key) catch |err| return self.ref.state.captureLuaError(err);
        return fromRuntimeValue(self.ref.state, raw_value, T);
    }

    /// Converts and assigns `value` at `key` in the table.
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

/// Rooted handle to a Lua function or loaded chunk.
pub const Function = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !Function {
        return switch (value) {
            .closure => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    /// Releases this function handle's root.
    pub fn deinit(self: *Function) void {
        self.ref.deinit();
        self.* = undefined;
    }

    /// Calls the function with tuple arguments and converts the first or tuple result to `R`.
    ///
    /// Lua failures are returned as `error.LuaError` and captured on the state.
    pub fn call(self: Function, args: anytype, comptime R: type) !R {
        const raw_args = try convertArgs(self.ref.state, args);
        defer self.ref.state.allocator().free(raw_args);

        const results = self.ref.state.raw_state.callLoadedClosure(try self.rawClosure(), raw_args) catch |err| return self.ref.state.captureLuaError(err);
        defer self.ref.state.allocator().free(results);
        return fromRuntimeResults(self.ref.state, results, R);
    }

    /// Calls the function and returns Lua failures as an `ErrorRef` instead of `error.LuaError`.
    pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R) {
        const raw_args = try convertArgs(self.ref.state, args);
        defer self.ref.state.allocator().free(raw_args);

        const result = self.ref.state.raw_state.protectedCallLoadedClosure(try self.rawClosure(), raw_args) catch |err| {
            if (err == error.OutOfMemory and self.ref.state.takeMemoryLimitExceeded()) {
                return .{ .lua_error = try self.ref.state.memoryLimitErrorRef() };
            }
            return err;
        };
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

    /// Dumps this function to zlua bytecode.
    ///
    /// The caller owns the returned slice and must free it with the state's allocator.
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

/// Returns the typed userdata handle type for `T`.
pub fn Userdata(comptime T: type) type {
    return struct {
        /// Marker used by zlua's compile-time conversion helpers.
        pub const is_zlua_userdata = true;
        /// Zig payload type stored in this userdata handle.
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

        /// Releases this userdata handle's root.
        pub fn deinit(self: *@This()) void {
            self.ref.deinit();
            self.* = undefined;
        }

        /// Returns a typed pointer to the userdata payload.
        pub fn ptr(self: @This()) !*T {
            return userdataPtr(T, try self.rawUserdata());
        }

        /// Installs a typed Zig method on the userdata `__index` table.
        ///
        /// The Zig function's first parameter must be a pointer receiver for `T`.
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

        /// Installs eligible methods declared on `Source`.
        ///
        /// Function declarations whose first parameter is `*T` or `*const T` are
        /// installed. Names beginning with `__` are installed as metamethods;
        /// all other eligible names are installed on `__index`.
        pub fn bindMethods(self: @This(), comptime Source: type) !void {
            if (@typeInfo(Source) != .@"struct") @compileError("bindMethods requires a struct type");

            inline for (@typeInfo(Source).@"struct".decls) |decl| {
                const member = @field(Source, decl.name);
                if (comptime isUserdataMethod(T, @TypeOf(member))) {
                    if (comptime isMetamethodName(decl.name)) {
                        try self.metamethod(decl.name, member);
                    } else {
                        try self.method(decl.name, member);
                    }
                }
            }
        }

        /// Installs a typed Zig function as a userdata metamethod such as `__close`.
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

/// Rooted handle to userdata when the host does not know its Zig payload type.
pub const AnyUserdata = struct {
    ref: Ref,

    fn fromRuntime(state: *State, value: runtime.Value) !AnyUserdata {
        return switch (value) {
            .userdata => .{ .ref = try Ref.fromRuntime(state, value) },
            else => error.TypeMismatch,
        };
    }

    /// Releases this userdata handle's root.
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

/// Result type returned by `Function.protectedCall`.
pub fn CallResult(comptime R: type) type {
    return union(enum) {
        /// Successful call result converted to `R`.
        ok: R,
        /// Lua error value rooted for host inspection.
        lua_error: ErrorRef,
    };
}

/// Rooted handle to a Lua error value.
pub const ErrorRef = struct {
    ref: Ref,

    fn fromRuntime(state: *State, raw: runtime.Value) !ErrorRef {
        return .{ .ref = try Ref.fromRuntime(state, raw) };
    }

    /// Releases this error handle's root.
    pub fn deinit(self: *ErrorRef) void {
        self.ref.deinit();
        self.* = undefined;
    }

    /// Returns the raw Lua error value as a high-level `Value`.
    pub fn value(self: ErrorRef) !Value {
        return self.ref.value();
    }

    /// Formats the Lua error value as an allocated message.
    ///
    /// The caller owns the returned slice and must free it with the state's allocator.
    pub fn message(self: ErrorRef) ![]const u8 {
        var out = std.ArrayList(u8).empty;
        defer out.deinit(self.ref.state.allocator());
        try runtime.appendValue(self.ref.state.allocator(), &out, self.ref.rawValue());
        return self.ref.state.allocator().dupe(u8, out.items);
    }
};

/// High-level Lua value union used for dynamic conversion and inspection.
pub const Value = union(enum) {
    /// Lua `nil`.
    nil,
    /// Lua boolean.
    boolean: bool,
    /// Lua integer.
    integer: i64,
    /// Lua floating-point number.
    number: f64,
    /// Lua string bytes interned in the state.
    string: []const u8,
    /// Rooted Lua table handle.
    table: Table,
    /// Rooted Lua function handle.
    function: Function,
    /// Rooted Lua userdata handle with unknown Zig payload type.
    userdata: AnyUserdata,
    /// Lua value kind not represented by the high-level API.
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

    /// Releases any rooted handle contained by this value.
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

/// Returns a result container for multiple Lua return values.
pub fn Tuple(comptime types: []const type) type {
    return struct {
        /// Marker used by zlua's compile-time conversion helpers.
        pub const is_zlua_tuple = true;
        /// Field types requested from Lua return values.
        pub const field_types = types;

        /// Converted tuple values.
        values: std.meta.Tuple(types),

        /// Releases any owned handles stored in tuple fields.
        pub fn deinit(self: *@This()) void {
            inline for (types, 0..) |Field, index| deinitIfOwned(Field, &self.values[index]);
            self.* = undefined;
        }

        /// Returns the converted value at `index`.
        pub fn get(self: *const @This(), comptime index: usize) types[index] {
            return self.values[index];
        }
    };
}

/// Host-callback context passed to functions registered with `State.register`.
pub const Context = struct {
    lua: *State,
    raw: *runtime.ApiCallbackContext,

    /// Returns the owning Lua state.
    pub fn state(self: *Context) *State {
        return self.lua;
    }

    /// Returns the number of Lua arguments passed to the callback.
    pub fn argCount(self: *Context) usize {
        return self.raw.argCount();
    }

    /// Reads required argument `index` and converts it to `T`.
    pub fn arg(self: *Context, index: usize, comptime T: type) !T {
        const raw = self.raw.callbackArgValue(index);
        return fromRuntimeValue(self.lua, raw, T) catch |err| return self.argConversionError(index, T, raw, err);
    }

    /// Reads optional argument `index`, returning null when absent or Lua `nil`.
    pub fn optionalArg(self: *Context, index: usize, comptime T: type) !?T {
        if (index >= self.argCount()) return null;
        const raw = self.raw.callbackArgValue(index);
        if (raw == .nil) return null;
        return self.arg(index, T);
    }

    /// Appends one converted Lua return value for the current callback.
    pub fn pushReturn(self: *Context, value: anytype) !void {
        const raw_value = toRuntimeValue(self.lua, value) catch |err| return self.returnConversionError(err);
        try self.raw.appendReturn(raw_value);
    }

    /// Replaces callback returns with `values`.
    ///
    /// Tuple structs such as `.{ a, b }` return multiple Lua values.
    pub fn returnValues(self: *Context, values: anytype) !void {
        self.raw.clearReturns();
        try self.appendReturnValues(values);
    }

    /// Raises a Lua error using `value` as the error object.
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

/// Opaque placeholder for future high-level coroutine/thread handles.
pub const Thread = opaque {};

fn runtimeOptions(options: Options) runtime.StateOptions {
    return .{
        .stdlib = toRuntimeStdlib(options.stdlib),
        .io = options.capabilities.io.runtime,
        .stdout = options.capabilities.io.stdout,
        .stderr = options.capabilities.io.stderr,
        .filesystem = options.capabilities.filesystem,
        .environment = options.capabilities.environment,
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
    var lua_arg_index: usize = 0;
    inline for (function_info.params, 0..) |param, index| {
        const Param = param.type orelse @compileError("registerTyped requires typed parameters");
        if (Param == *Context) {
            args[index] = ctx;
        } else {
            args[index] = try ctx.arg(lua_arg_index, Param);
            lua_arg_index += 1;
        }
    }

    const Return = function_info.return_type orelse void;
    if (Return == void) {
        @call(.auto, function, args);
        try ctx.returnValues(.{});
        return;
    }

    switch (@typeInfo(Return)) {
        .error_union => |error_union| {
            if (comptime error_union.payload == void) {
                try @call(.auto, function, args);
                try ctx.returnValues(.{});
            } else {
                var result = try @call(.auto, function, args);
                defer deinitIfOwned(error_union.payload, &result);
                try ctx.returnValues(result);
            }
        },
        else => {
            var result = @call(.auto, function, args);
            defer deinitIfOwned(Return, &result);
            try ctx.returnValues(result);
        },
    }
}

fn callUserdataInitializer(comptime T: type, comptime initializer: anytype, comptime options: UserdataOptions(T), ctx: *Context) !void {
    const FunctionType = @TypeOf(initializer);
    const SignatureType = switch (@typeInfo(FunctionType)) {
        .@"fn" => FunctionType,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => pointer.child,
            else => @compileError("userdata initializers require a function or function pointer"),
        },
        else => @compileError("userdata initializers require a function or function pointer"),
    };
    const function_info = switch (@typeInfo(FunctionType)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => @compileError("userdata initializers require a function or function pointer"),
        },
        else => @compileError("userdata initializers require a function or function pointer"),
    };

    if (function_info.is_var_args) @compileError("userdata initializers do not support varargs functions");

    var args: std.meta.ArgsTuple(SignatureType) = undefined;
    var lua_arg_index: usize = 0;
    inline for (function_info.params, 0..) |param, index| {
        const Param = param.type orelse @compileError("userdata initializer parameters must be typed");
        if (Param == *Context) {
            args[index] = ctx;
        } else {
            args[index] = try ctx.arg(lua_arg_index, Param);
            lua_arg_index += 1;
        }
    }

    const Return = function_info.return_type orelse @compileError("userdata initializers must return T or !T");
    switch (@typeInfo(Return)) {
        .error_union => |error_union| {
            if (comptime error_union.payload != T) @compileError("userdata initializers must return T or !T");
            const value = try @call(.auto, initializer, args);
            var userdata = try ctx.state().newUserdataAuto(T, value, options);
            defer userdata.deinit();
            try ctx.returnValues(userdata);
        },
        else => {
            if (comptime Return != T) @compileError("userdata initializers must return T or !T");
            const value = @call(.auto, initializer, args);
            var userdata = try ctx.state().newUserdataAuto(T, value, options);
            defer userdata.deinit();
            try ctx.returnValues(userdata);
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
    if (comptime !isUserdataReceiver(T, Receiver)) @compileError("userdata method receiver must be *T or *const T");

    var args: std.meta.ArgsTuple(SignatureType) = undefined;
    args[0] = try userdataReceiverArg(T, Receiver, ctx);
    var lua_arg_index: usize = 1;
    inline for (function_info.params[1..], 1..) |param, index| {
        const Param = param.type orelse @compileError("userdata method parameters must be typed");
        if (Param == *Context) {
            args[index] = ctx;
        } else {
            args[index] = try ctx.arg(lua_arg_index, Param);
            lua_arg_index += 1;
        }
    }

    const Return = function_info.return_type orelse void;
    if (Return == void) {
        @call(.auto, function, args);
        try ctx.returnValues(.{});
        return;
    }

    switch (@typeInfo(Return)) {
        .error_union => |error_union| {
            if (comptime error_union.payload == void) {
                try @call(.auto, function, args);
                try ctx.returnValues(.{});
            } else {
                var result = try @call(.auto, function, args);
                defer deinitIfOwned(error_union.payload, &result);
                try ctx.returnValues(result);
            }
        },
        else => {
            var result = @call(.auto, function, args);
            defer deinitIfOwned(Return, &result);
            try ctx.returnValues(result);
        },
    }
}

fn isUserdataMethod(comptime T: type, comptime FunctionType: type) bool {
    const function_info = switch (@typeInfo(FunctionType)) {
        .@"fn" => |info| info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |info| info,
            else => return false,
        },
        else => return false,
    };

    if (function_info.is_var_args or function_info.params.len == 0) return false;
    const Receiver = function_info.params[0].type orelse return false;
    return isUserdataReceiver(T, Receiver);
}

fn isUserdataReceiver(comptime T: type, comptime Receiver: type) bool {
    return switch (@typeInfo(Receiver)) {
        .pointer => |pointer| pointer.size == .one and
            pointer.child == T and
            !pointer.is_volatile and
            pointer.alignment == null and
            pointer.address_space == .generic and
            !pointer.is_allowzero and
            pointer.sentinel_ptr == null,
        else => false,
    };
}

fn isMetamethodName(comptime name: []const u8) bool {
    return std.mem.startsWith(u8, name, "__");
}

fn userdataReceiverArg(comptime T: type, comptime Receiver: type, ctx: *Context) !Receiver {
    const raw = ctx.raw.callbackArgValue(0);
    const userdata = switch (raw) {
        .userdata => |value| value,
        else => return ctx.argConversionError(0, Receiver, raw, error.TypeMismatch),
    };

    const ptr = userdataPtr(T, userdata) catch |err| return ctx.argConversionError(0, Receiver, raw, err);
    return ptr;
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

fn expectLastErrorContains(lua: *State, needle: []const u8) !void {
    const message = try lua.errorMessage();
    defer lua.allocator().free(message);
    try std.testing.expect(std.mem.indexOf(u8, message, needle) != null);
}

fn expectProtectedErrorContains(lua: *State, function: Function, needle: []const u8) !void {
    const result = try function.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, needle) != null);
        },
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

test "api safe stdlib excludes ambient capability libraries" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try lua.doString(
        \\assert(io == nil)
        \\assert(os == nil)
        \\assert(debug == nil)
        \\assert(package == nil)
        \\assert(require == nil)
    , .{ .name = "=api-safe-stdlib-negative" });
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

test "api public handles survive forced GC" {
    const Counter = struct {
        value: i64,
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var ref_chunk = try lua.loadString("return { answer = 42 }", .{ .name = "=ref-handle" });
    var ref = try ref_chunk.call(.{}, Ref);
    ref_chunk.deinit();
    defer ref.deinit();

    try lua.collect();
    var ref_value = try ref.value();
    defer ref_value.deinit();
    switch (ref_value) {
        .table => |table| try std.testing.expectEqual(@as(i64, 42), try table.get("answer", i64)),
        else => return error.TypeMismatch,
    }

    var table = try lua.createTable(.{ .hash_hint = 1 });
    defer table.deinit();
    try table.set("answer", 43);

    try lua.collect();
    try std.testing.expectEqual(@as(i64, 43), try table.get("answer", i64));

    var function_chunk = try lua.loadString("return function(x) return x + 1 end", .{ .name = "=function-handle" });
    var function = try function_chunk.call(.{}, Function);
    function_chunk.deinit();
    defer function.deinit();

    try lua.collect();
    try std.testing.expectEqual(@as(i64, 44), try function.call(.{43}, i64));

    var value = try lua.push(.{ .answer = 45 });
    defer value.deinit();

    try lua.collect();
    switch (value) {
        .table => |value_table| try std.testing.expectEqual(@as(i64, 45), try value_table.get("answer", i64)),
        else => return error.TypeMismatch,
    }

    var tuple_chunk = try lua.loadString(
        \\local t = { answer = 46 }
        \\local function f(x) return x + 1 end
        \\return t, f
    , .{ .name = "=tuple-handle" });

    const Result = Tuple(&.{ Table, Function });
    var result = try tuple_chunk.call(.{}, Result);
    tuple_chunk.deinit();
    defer result.deinit();

    try lua.collect();
    try std.testing.expectEqual(@as(i64, 46), try result.get(0).get("answer", i64));
    try std.testing.expectEqual(@as(i64, 47), try result.get(1).call(.{46}, i64));

    var userdata = try lua.newUserdata(Counter, .{ .value = 48 }, .{});
    defer userdata.deinit();

    try lua.collect();
    try std.testing.expectEqual(@as(i64, 48), (try userdata.ptr()).value);

    var typed_userdata = try lua.newUserdata(Counter, .{ .value = 49 }, .{});
    var any_chunk = try lua.loadString("return ...", .{ .name = "=any-userdata-handle" });
    var any_userdata = try any_chunk.call(.{typed_userdata}, AnyUserdata);
    any_chunk.deinit();
    typed_userdata.deinit();
    defer any_userdata.deinit();

    try lua.collect();
    switch (try any_userdata.rawValue()) {
        .userdata => |raw| try std.testing.expectEqual(@as(i64, 49), (try userdataPtr(Counter, raw)).value),
        else => return error.TypeMismatch,
    }
}

test "api error refs survive forced GC" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var failing = try lua.loadString("error({ message = 'boom' }, 0)", .{ .name = "=error-ref-gc" });
    var err = blk: {
        const result = try failing.protectedCall(.{}, void);
        switch (result) {
            .ok => return error.TestExpectedLuaError,
            .lua_error => |err_ref| break :blk err_ref,
        }
    };
    failing.deinit();
    defer err.deinit();

    if (lua.takeErrorValue()) |last_error_ref| {
        var last = last_error_ref;
        last.deinit();
    }
    lua.raw_state.last_error = null;

    try lua.collect();
    var value = try err.value();
    defer value.deinit();
    switch (value) {
        .table => |table| try std.testing.expectEqualStrings("boom", try table.get("message", []const u8)),
        else => return error.TypeMismatch,
    }
}

test "api callback argument roots survive forced GC through weak tables" {
    const Tracker = struct {
        id: i64,
    };
    const Callbacks = struct {
        fn stress(ctx: *Context) !void {
            var payload = try ctx.arg(0, Table);
            defer payload.deinit();
            var tracker = try ctx.arg(1, Userdata(Tracker));
            defer tracker.deinit();
            var check = try ctx.arg(2, Function);
            defer check.deinit();

            try ctx.state().collect();
            try std.testing.expectEqualStrings("payload", try payload.get("name", []const u8));
            try std.testing.expectEqual(@as(i64, 7), (try tracker.ptr()).id);

            const CheckResult = Tuple(&.{ []const u8, bool });
            var checked = try check.call(.{}, CheckResult);
            defer checked.deinit();
            try std.testing.expectEqualStrings("payload", checked.get(0));
            try std.testing.expectEqual(true, checked.get(1));

            try ctx.state().collect();
            try ctx.returnValues(.{ try payload.get("name", []const u8), (try tracker.ptr()).id });
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var tracker = try lua.newUserdata(Tracker, .{ .id = 7 }, .{});
    defer tracker.deinit();

    var stress = try lua.register("stress_roots", Callbacks.stress);
    defer stress.deinit();
    try lua.setGlobal("stress_roots", stress);

    var chunk = try lua.loadString(
        \\local tracker = ...
        \\local weak = setmetatable({}, { __mode = 'v' })
        \\local payload = { name = 'payload' }
        \\weak.payload = payload
        \\weak.tracker = tracker
        \\return stress_roots(payload, weak.tracker, function()
        \\  collectgarbage('collect')
        \\  return weak.payload.name, weak.tracker ~= nil
        \\end)
    , .{ .name = "=api-callback-root-stress" });
    defer chunk.deinit();

    const Result = Tuple(&.{ []const u8, i64 });
    var result = try chunk.call(.{tracker}, Result);
    defer result.deinit();
    try std.testing.expectEqualStrings("payload", result.get(0));
    try std.testing.expectEqual(@as(i64, 7), result.get(1));
}

test "api native callback dispatch tolerates forced GC" {
    const Callbacks = struct {
        fn stress(ctx: *Context) !void {
            var callback = try ctx.arg(0, Function);
            defer callback.deinit();

            try ctx.state().collect();
            const returned = try callback.call(.{"native"}, []const u8);
            try ctx.returnValues(.{returned});
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var stress = try lua.register("stress_callback_gc", Callbacks.stress);
    defer stress.deinit();
    try lua.setGlobal("stress_callback_gc", stress);

    var chunk = try lua.loadString(
        \\return stress_callback_gc(function(value)
        \\  collectgarbage('collect')
        \\  return value .. '-callback'
        \\end)
    , .{ .name = "=api-callback-dispatch-gc" });
    defer chunk.deinit();

    try std.testing.expectEqualStrings("native-callback", try chunk.call(.{}, []const u8));
}

test "api userdata handles root weak values until finalizers can run" {
    const Tracker = struct {
        finalized: *usize,

        fn finalize(self: *@This()) void {
            self.finalized.* += 1;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var finalized: usize = 0;
    var tracker = try lua.newUserdata(Tracker, .{ .finalized = &finalized }, .{ .finalizer = Tracker.finalize });
    try lua.setGlobal("tracker", tracker);
    try lua.doString(
        \\weak_trackers = setmetatable({}, { __mode = 'v' })
        \\weak_trackers.item = tracker
    , .{ .name = "=api-userdata-root-weak-setup" });
    try lua.setGlobal("tracker", null);

    try lua.collect();
    try std.testing.expectEqual(@as(usize, 0), finalized);
    try lua.doString("assert(weak_trackers.item ~= nil)", .{ .name = "=api-userdata-root-weak-alive" });

    tracker.deinit();
    try lua.collect();
    try lua.collect();
    try std.testing.expectEqual(@as(usize, 1), finalized);
    try lua.doString("assert(weak_trackers.item == nil)", .{ .name = "=api-userdata-root-weak-collected" });
}

test "api error value refs root weak-table values through forced GC" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var failing = try lua.loadString(
        \\weak_errors = setmetatable({}, { __mode = 'v' })
        \\local err = { tag = 'kept' }
        \\weak_errors.err = err
        \\error(err, 0)
    , .{ .name = "=api-error-root-weak" });
    var err = blk: {
        const result = try failing.protectedCall(.{}, void);
        switch (result) {
            .ok => return error.TestExpectedLuaError,
            .lua_error => |err_ref| break :blk err_ref,
        }
    };
    failing.deinit();

    if (lua.takeErrorValue()) |last_error_ref| {
        var last = last_error_ref;
        last.deinit();
    }
    lua.raw_state.last_error = null;

    try lua.collect();
    var value = try err.value();
    switch (value) {
        .table => |table| try std.testing.expectEqualStrings("kept", try table.get("tag", []const u8)),
        else => return error.TypeMismatch,
    }
    value.deinit();

    var check_alive = try lua.loadString("return weak_errors.err and weak_errors.err.tag or 'gone'", .{ .name = "=api-error-root-weak-alive" });
    defer check_alive.deinit();
    try std.testing.expectEqualStrings("kept", try check_alive.call(.{}, []const u8));

    err.deinit();
    try lua.collect();
    try lua.doString("assert(weak_errors.err == nil)", .{ .name = "=api-error-root-weak-collected" });
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

test "api memory limit applies to host callback return conversion" {
    const Callbacks = struct {
        const payload = [_]u8{'x'} ** (512 * 1024);

        fn large(ctx: *Context) !void {
            try ctx.returnValues(payload[0..]);
        }
    };

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .base,
        .limits = .{ .max_memory = 128 * 1024 },
    });
    defer lua.deinit();

    var large = try lua.register("large", Callbacks.large);
    defer large.deinit();
    try lua.setGlobal("large", large);
    var chunk = try lua.loadString("return large()", .{ .name = "=api-memory-callback-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, memory_limit_error_message) != null);
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

test "api typed host callback can create userdata through context" {
    const Budget = struct {
        remaining: i64,

        fn spend(self: *@This(), amount: i64) i64 {
            self.remaining = @max(self.remaining - amount, 0);
            return self.remaining;
        }
    };
    const Callbacks = struct {
        fn newBudget(ctx: *Context, amount: i64) !Userdata(Budget) {
            var budget = try ctx.state().newUserdata(Budget, .{ .remaining = amount }, .{});
            errdefer budget.deinit();
            try budget.method("spend", Budget.spend);
            return budget;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var new_budget = try lua.registerTyped("new_budget", Callbacks.newBudget);
    defer new_budget.deinit();
    try lua.setGlobal("new_budget", new_budget);

    var chunk = try lua.loadString(
        \\local budget = new_budget(25)
        \\assert(type(budget) == 'userdata')
        \\assert(budget:spend(7) == 18)
        \\assert(budget:spend(20) == 0)
        \\return budget
    , .{ .name = "=api-21.4-typed-userdata" });
    defer chunk.deinit();

    var budget = try chunk.call(.{}, Userdata(Budget));
    defer budget.deinit();
    try std.testing.expectEqual(@as(i64, 0), (try budget.ptr()).remaining);
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

test "api auto userdata binding installs receiver methods" {
    const Counter = struct {
        value: i64,

        pub fn inc(self: *@This(), ctx: *Context, amount: i64) !i64 {
            try std.testing.expectEqual(@as(usize, 2), ctx.argCount());
            self.value += amount;
            return self.value;
        }

        pub fn get(self: *const @This()) i64 {
            return self.value;
        }

        pub fn clear(self: *@This()) !void {
            self.value = 0;
        }

        pub fn __tostring(self: *const @This()) []const u8 {
            _ = self;
            return "Counter";
        }

        pub fn helper(amount: i64) i64 {
            return amount;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdataAuto(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);

    try lua.doString(
        \\assert(type(counter) == 'userdata')
        \\assert(counter:inc(2) == 2)
        \\assert(counter:get() == 2)
        \\assert(tostring(counter) == 'Counter')
        \\counter:clear()
        \\assert(counter:get() == 0)
        \\assert(counter.helper == nil)
    , .{ .name = "=api-auto-userdata" });

    try std.testing.expectEqual(@as(i64, 0), (try counter.ptr()).value);
}

test "api auto userdata pointer wrappers bind methods" {
    const Counter = struct {
        value: i64,

        pub fn inc(self: *@This(), amount: i64) i64 {
            self.value += amount;
            return self.value;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var backing = Counter{ .value = 10 };
    var counter = try lua.newUserdataPtrAuto(Counter, &backing, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);

    try lua.doString("assert(counter:inc(32) == 42)", .{ .name = "=api-auto-userdata-ptr" });
    try std.testing.expectEqual(@as(i64, 42), backing.value);
}

test "api userdata initializer with returns auto-bound userdata" {
    const Budget = struct {
        remaining: i64,
        label: []const u8,

        pub fn init(ctx: *Context, amount: i64, label: []const u8) !@This() {
            try std.testing.expectEqual(@as(usize, 2), ctx.argCount());
            return .{ .remaining = amount, .label = label };
        }

        pub fn spend(self: *@This(), amount: i64) i64 {
            self.remaining = @max(self.remaining - amount, 0);
            return self.remaining;
        }

        pub fn name(self: *const @This()) []const u8 {
            return self.label;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var new_budget = try lua.registerUserdataInitializerWith(Budget, "new_budget", Budget.init, .{});
    defer new_budget.deinit();
    try lua.setGlobal("new_budget", new_budget);

    var chunk = try lua.loadString(
        \\local budget = new_budget(25, 'ops')
        \\assert(type(budget) == 'userdata')
        \\assert(budget:name() == 'ops')
        \\assert(budget:spend(7) == 18)
        \\return budget
    , .{ .name = "=api-userdata-initializer-with" });
    defer chunk.deinit();

    var budget = try chunk.call(.{}, Userdata(Budget));
    defer budget.deinit();
    try std.testing.expectEqual(@as(i64, 18), (try budget.ptr()).remaining);
}

test "api userdata initializer with accepts plain initializer functions" {
    const Counter = struct {
        value: i64,

        pub fn init(value: i64) @This() {
            return .{ .value = value };
        }

        pub fn get(self: *const @This()) i64 {
            return self.value;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var new_counter = try lua.registerUserdataInitializerWith(Counter, "new_counter", Counter.init, .{});
    defer new_counter.deinit();
    try lua.setGlobal("new_counter", new_counter);

    try lua.doString("assert(new_counter(42):get() == 42)", .{ .name = "=api-userdata-initializer-plain" });
}

test "api userdata initializer with argument errors become Lua errors" {
    const Counter = struct {
        value: i64,

        pub fn init(value: i64) @This() {
            return .{ .value = value };
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var new_counter = try lua.registerUserdataInitializerWith(Counter, "new_counter", Counter.init, .{});
    defer new_counter.deinit();
    try lua.setGlobal("new_counter", new_counter);

    var chunk = try lua.loadString("new_counter('bad')", .{ .name = "=api-userdata-initializer-arg-error" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "new_counter") != null);
            try std.testing.expect(std.mem.indexOf(u8, message, "number") != null);
        },
    }
}

test "api userdata initializer with can raise Lua errors" {
    const Counter = struct {
        value: i64,

        pub fn init(ctx: *Context, value: i64) !@This() {
            if (value < 0) return ctx.raise("negative counter");
            return .{ .value = value };
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var new_counter = try lua.registerUserdataInitializerWith(Counter, "new_counter", Counter.init, .{});
    defer new_counter.deinit();
    try lua.setGlobal("new_counter", new_counter);

    var chunk = try lua.loadString("new_counter(-1)", .{ .name = "=api-userdata-initializer-raise" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "negative counter");
}

test "api auto userdata binding skips non receiver declarations" {
    const Other = struct { value: i64 };
    const Fixture = struct {
        value: i64,

        pub const tag = "not a method";

        pub fn ok(self: *const @This()) i64 {
            return self.value;
        }

        pub fn static() i64 {
            return 1;
        }

        pub fn wrongReceiver(self: *Other) i64 {
            return self.value;
        }

        pub fn wrongConstReceiver(self: *const Other) i64 {
            return self.value;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var fixture = try lua.newUserdataAuto(Fixture, .{ .value = 7 }, .{});
    defer fixture.deinit();
    try lua.setGlobal("fixture", fixture);

    try lua.doString(
        \\assert(fixture:ok() == 7)
        \\assert(fixture.tag == nil)
        \\assert(fixture.static == nil)
        \\assert(fixture.wrongReceiver == nil)
        \\assert(fixture.wrongConstReceiver == nil)
    , .{ .name = "=api-auto-userdata-skips" });
}

test "api userdata method context injection works in later positions" {
    const Counter = struct {
        value: i64,

        pub fn middle(self: *@This(), amount: i64, ctx: *Context, label: []const u8) !i64 {
            try std.testing.expectEqual(@as(usize, 3), ctx.argCount());
            try std.testing.expectEqualStrings("middle", label);
            self.value += amount;
            return self.value;
        }

        pub fn trailing(self: *@This(), amount: i64, label: []const u8, ctx: *Context) !i64 {
            try std.testing.expectEqual(@as(usize, 3), ctx.argCount());
            try std.testing.expectEqualStrings("trailing", label);
            self.value += amount;
            return self.value;
        }
    };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdataAuto(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);

    try lua.doString(
        \\assert(counter:middle(2, 'middle') == 2)
        \\assert(counter:trailing(3, 'trailing') == 5)
    , .{ .name = "=api-userdata-context-positions" });

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

test "api userdata method wrong receiver errors are clear" {
    const Counter = struct {
        value: i64,

        pub fn inc(self: *@This(), amount: i64) i64 {
            self.value += amount;
            return self.value;
        }
    };
    const Other = struct { value: i64 };

    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    var counter = try lua.newUserdataAuto(Counter, .{ .value = 0 }, .{});
    defer counter.deinit();
    try lua.setGlobal("counter", counter);

    var other = try lua.newUserdata(Other, .{ .value = 1 }, .{});
    defer other.deinit();
    try lua.setGlobal("other", other);

    var chunk = try lua.loadString("counter.inc(other, 1)", .{ .name = "=api-userdata-wrong-receiver" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "inc") != null);
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
        \\local ok_time, time_err = pcall(os.time)
        \\assert(ok_time == false and tostring(time_err):find('clock access disabled'))
        \\local ok_date, date_err = pcall(os.date)
        \\assert(ok_date == false and tostring(date_err):find('clock access disabled'))
        \\local file = io.open('missing.lua', 'r')
        \\assert(file == nil)
        \\local ok_write, write_err = pcall(io.open, 'blocked.lua', 'w')
        \\assert(ok_write == false and tostring(write_err):find('filesystem write access disabled'))
        \\local ok_append, append_err = pcall(io.open, 'blocked.lua', 'a')
        \\assert(ok_append == false and tostring(append_err):find('filesystem write access disabled'))
        \\local ok_input, input_err = pcall(io.input, 'missing.lua')
        \\assert(ok_input == false and tostring(input_err):find('cannot open file'))
        \\local tmp = assert(io.tmpfile())
        \\local ok_tmp_close, tmp_close_err = pcall(function() return tmp:close() end)
        \\assert(ok_tmp_close == false and tostring(tmp_close_err):find('filesystem write access disabled'))
        \\local loaded, load_err = loadfile('missing.lua')
        \\assert(loaded == nil and load_err == 'cannot open file')
        \\local ok_file, file_err = pcall(dofile, 'missing.lua')
        \\assert(ok_file == false and tostring(file_err):find('filesystem access disabled'))
        \\local ok_require, require_err = pcall(require, 'missing')
        \\assert(ok_require == false and tostring(require_err):find("module 'missing' not found"))
        \\package.path = '/tmp/?.lua;../?.lua'
        \\local ok_escape_require, escape_require_err = pcall(require, 'missing')
        \\assert(ok_escape_require == false and tostring(escape_require_err):find("module 'missing' not found"))
        \\local found, search_err = package.searchpath('missing', '?.lua')
        \\assert(found == nil and tostring(search_err):find("missing.lua"))
        \\local ok_lines, lines_err = pcall(io.lines, 'missing.lua')
        \\assert(ok_lines == false and tostring(lines_err):find('cannot open file'))
        \\local removed, remove_err = os.remove('missing.lua')
        \\assert(removed == nil and tostring(remove_err):find('filesystem write access disabled'))
        \\local renamed, rename_err = os.rename('missing.lua', 'other.lua')
        \\assert(renamed == nil and tostring(rename_err):find('filesystem write access disabled'))
    , .{ .name = "=api-21.6-safe-host-access" });
}

test "api default stdlib omits host-facing libraries" {
    var lua = try State.init(std.testing.allocator, .{});
    defer lua.deinit();

    try lua.doString(
        \\assert(io == nil)
        \\assert(os == nil)
        \\assert(package == nil)
        \\assert(debug == nil)
    , .{ .name = "=api-default-safe-libs" });
}

test "api host-backed capabilities require explicit I/O access" {
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{
            .filesystem = .host_cwd,
            .clock = .system,
            .process = .enabled,
        },
    });
    defer lua.deinit();

    try lua.doString(
        \\local ok_process, process_err = pcall(os.execute, 'true')
        \\assert(ok_process == false and tostring(process_err):find('process I/O unavailable'))
        \\local ok_time, time_err = pcall(os.time)
        \\assert(ok_time == false and tostring(time_err):find('clock I/O unavailable'))
        \\local ok_file, file_err = pcall(dofile, 'missing.lua')
        \\assert(ok_file == false and tostring(file_err):find('filesystem I/O unavailable'))
    , .{ .name = "=api-host-backed-capabilities-need-io" });
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

test "api read-only memory filesystem denies stdlib writes" {
    const files = [_]MemoryFile{
        .{ .path = "seed.txt", .contents = "seed" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();

    try lua.doString(
        \\local read = assert(io.open('seed.txt', 'r'))
        \\assert(read:read('*a') == 'seed')
        \\assert(read:close())
        \\local ok_write, write_err = pcall(io.open, 'new.txt', 'w')
        \\assert(ok_write == false and tostring(write_err):find('filesystem write access disabled'))
        \\local ok_append, append_err = pcall(io.open, 'seed.txt', 'a')
        \\assert(ok_append == false and tostring(append_err):find('filesystem write access disabled'))
        \\local tmp = assert(io.tmpfile())
        \\assert(tmp:write('temporary'))
        \\local ok_tmp, tmp_err = pcall(function() return tmp:close() end)
        \\assert(ok_tmp == false and tostring(tmp_err):find('filesystem write access disabled'))
        \\local removed, remove_err = os.remove('seed.txt')
        \\assert(removed == nil and tostring(remove_err):find('filesystem write access disabled'))
        \\local renamed, rename_err = os.rename('seed.txt', 'renamed.txt')
        \\assert(renamed == nil and tostring(rename_err):find('filesystem write access disabled'))
        \\read = assert(io.open('seed.txt', 'r'))
        \\assert(read:read('*a') == 'seed')
    , .{ .name = "=api-memory-read-only-negative" });
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

test "api writable memory filesystem rejects sandbox escape writes" {
    var filesystem = MemoryFilesystem.init(std.testing.allocator);
    defer filesystem.deinit();
    try filesystem.writeFile("seed.txt", "seed");

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory_rw = &filesystem } },
    });
    defer lua.deinit();

    try lua.doString(
        \\local absolute, absolute_err = io.open('/tmp/escape.txt', 'w')
        \\assert(absolute == nil and tostring(absolute_err):find('cannot open file'))
        \\local ok_write, write_err = pcall(io.open, '../escape.txt', 'w')
        \\assert(ok_write == false and tostring(write_err):find('cannot write file'))
        \\local ok_output, output_err = pcall(function()
        \\  local file = assert(io.open('generated.txt', 'w'))
        \\  assert(file:write('generated'))
        \\  return file:close()
        \\end)
        \\assert(ok_output == true)
        \\local removed, remove_err = os.remove('../escape.txt')
        \\assert(removed == nil and tostring(remove_err):find('cannot remove file'))
        \\local renamed, rename_err = os.rename('seed.txt', '../escape.txt')
        \\assert(renamed == nil and tostring(rename_err):find('cannot rename file'))
        \\local loaded, load_err = loadfile('../escape.lua')
        \\assert(loaded == nil and tostring(load_err):find('cannot open file'))
        \\local ok_do, do_err = pcall(dofile, '../escape.lua')
        \\assert(ok_do == false and tostring(do_err):find('cannot open file'))
    , .{ .name = "=api-memory-rw-escape-negative" });

    const seed = try filesystem.readFileAlloc(std.testing.allocator, "seed.txt");
    defer std.testing.allocator.free(seed);
    try std.testing.expectEqualStrings("seed", seed);
    try std.testing.expectError(error.FileNotFound, filesystem.readFileAlloc(std.testing.allocator, "escape.txt"));
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
        .{ .path = "./script.lua", .contents = "return 42" },
        .{ .path = "moddir/chunk.lua", .contents = "return 7" },
        .{ .path = "plugins//plugin.lua", .contents = "return { value = 9 }" },
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

test "api extension readers accept Lua file handles" {
    const files = [_]MemoryFile{
        .{ .path = "data.json", .contents = "xx{\"name\":\"Ada\",\"nums\":[1,null]}" },
        .{ .path = "data.toml", .contents = "name = \"Ada\"\nok = true\nnums = [1, 2]\n" },
        .{ .path = "data.csv", .contents = "name,age\nAda,37\nBob,\n" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();

    try lua.doString(
        \\local jf = assert(io.open('data.json', 'r'))
        \\assert(jf:read(2) == 'xx')
        \\local j = json.read(jf)
        \\assert(j.name == 'Ada' and j.nums[2] == json.null)
        \\assert(jf:read(0) == nil)
        \\
        \\local tf = assert(io.open('data.toml', 'r'))
        \\local t = toml.read(tf)
        \\assert(t.name == 'Ada' and t.ok == true and t.nums[2] == 2)
        \\assert(tf:read(0) == nil)
        \\
        \\local cf = assert(io.open('data.csv', 'r'))
        \\local c = csv.read(cf)
        \\assert(c[1].name == 'Ada' and c[1].age == '37')
        \\assert(c[2].age == csv.null)
        \\assert(cf:read(0) == nil)
        \\
        \\local mf = assert(io.tmpfile())
        \\assert(mf:write(msgpack.write({ name = 'Ada', ok = true, nums = { 1, msgpack.null } })))
        \\assert(mf:seek('set') == 0)
        \\local m = msgpack.read(mf)
        \\assert(m.name == 'Ada' and m.ok == true and m.nums[2] == msgpack.null)
        \\assert(mf:read(0) == nil)
        \\
        \\local closed = assert(io.open('data.json', 'r'))
        \\assert(closed:close())
        \\local ok, err = pcall(json.read, closed)
        \\assert(ok == false and tostring(err):find('json.read'))
    , .{ .name = "=api-extension-read-file-handles" });
}

test "api memory filesystem rejects sandbox escape paths" {
    const bad_files = [_]MemoryFile{
        .{ .path = "../secret.lua", .contents = "return 1" },
    };
    try std.testing.expectError(error.InvalidPath, State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &bad_files } },
    }));

    var lua = try State.init(std.testing.allocator, .{ .stdlib = .full });
    defer lua.deinit();
    try std.testing.expectError(error.InvalidPath, lua.addMemoryFile("/tmp/plugin.lua", "return 1"));
    try std.testing.expectError(error.InvalidPath, lua.addMemoryFile("plugins/../secret.lua", "return 1"));

    const files = [_]MemoryFile{
        .{ .path = "plugins/safe.lua", .contents = "return true" },
    };
    var sandboxed = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer sandboxed.deinit();
    try sandboxed.setPackagePath("../?.lua;/tmp/?.lua;plugins/?.lua");
    try sandboxed.doString(
        \\local ok, err = pcall(require, 'secret')
        \\assert(ok == false and tostring(err):find("module 'secret' not found"))
        \\assert(require('safe') == true)
    , .{ .name = "=api-memory-require-sandbox-paths" });
}

test "api package loading rejects sandbox escape module paths" {
    const files = [_]MemoryFile{
        .{ .path = "plugins/safe.lua", .contents = "return true" },
        .{ .path = "secret.lua", .contents = "return 'secret'" },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .full,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
    });
    defer lua.deinit();
    try lua.setPackagePath("?.lua;plugins/?.lua;../?.lua;/tmp/?.lua");

    try lua.doString(
        \\local found, search_err = package.searchpath('../secret', '?.lua;../?.lua;/tmp/?.lua', '', '')
        \\assert(found == nil and tostring(search_err):find('no file'))
        \\local loader, loader_data = package.searchers[2]('..secret')
        \\assert(type(loader) == 'string' and loader:find('no matching file'))
        \\assert(loader_data == nil)
        \\local ok, require_err = pcall(require, '..secret')
        \\assert(ok == false and tostring(require_err):find("module '..secret' not found"))
        \\assert(require('safe') == true)
    , .{ .name = "=api-package-escape-negative" });
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

test "api instruction budget can be queried and reset" {
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .none,
        .limits = .{ .max_instructions = 1_000 },
    });
    defer lua.deinit();

    try std.testing.expectEqual(@as(?u64, 1_000), lua.instructionBudget().limit);
    try std.testing.expectEqual(@as(u64, 0), lua.instructionBudget().used);
    try std.testing.expectEqual(@as(?u64, 1_000), lua.instructionBudget().remaining);

    var chunk = try lua.loadString("local x = 0; for i = 1, 5 do x = x + i end; return x", .{ .name = "=api-instruction-budget-query" });
    defer chunk.deinit();
    try std.testing.expectEqual(@as(i64, 15), try chunk.call(.{}, i64));

    const used = lua.instructionBudget().used;
    try std.testing.expect(used > 0);
    try std.testing.expectEqual(@as(?u64, 1_000 - used), lua.instructionBudget().remaining);

    lua.resetInstructionBudget();
    try std.testing.expectEqual(@as(u64, 0), lua.instructionBudget().used);
    try std.testing.expectEqual(@as(?u64, 1_000), lua.instructionBudget().remaining);
}

test "api instruction budget reset allows more execution after exhaustion" {
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .none,
        .limits = .{ .max_instructions = 20 },
    });
    defer lua.deinit();

    var loop = try lua.loadString("while true do end", .{ .name = "=api-instruction-budget-exhaust" });
    defer loop.deinit();
    const failed = try loop.protectedCall(.{}, void);
    switch (failed) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, "instruction limit exceeded") != null);
        },
    }
    try std.testing.expectEqual(@as(u64, 20), lua.instructionBudget().used);
    try std.testing.expectEqual(@as(?u64, 0), lua.instructionBudget().remaining);

    lua.resetInstructionBudget();
    var simple = try lua.loadString("return 42", .{ .name = "=api-instruction-budget-reset" });
    defer simple.deinit();
    try std.testing.expectEqual(@as(i64, 42), try simple.call(.{}, i64));
}

test "api instruction query tracks states without an instruction limit" {
    var lua = try State.init(std.testing.allocator, .{ .stdlib = .none });
    defer lua.deinit();

    try std.testing.expectEqual(@as(?u64, null), lua.instructionBudget().limit);
    try std.testing.expectEqual(@as(?u64, null), lua.instructionBudget().remaining);

    var chunk = try lua.loadString("local x = 0; for i = 1, 3 do x = x + i end; return x", .{ .name = "=api-instruction-budget-unlimited" });
    defer chunk.deinit();
    try std.testing.expectEqual(@as(i64, 6), try chunk.call(.{}, i64));
    try std.testing.expect(lua.instructionBudget().used > 0);

    lua.resetInstructionBudget();
    try std.testing.expectEqual(@as(u64, 0), lua.instructionBudget().used);
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

test "api stack value limit catches recursive calls" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_stack_values = 64 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local function recurse(a, b, c, d, e, f, g, h)
        \\  local value = recurse(a, b, c, d, e, f, g, h)
        \\  return value
        \\end
        \\recurse(1, 2, 3, 4, 5, 6, 7, 8)
    , .{ .name = "=api-stack-limit-recursion" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "stack overflow");
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

test "api stack value limit catches metamethod recursion" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_stack_values = 64 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local target
        \\target = setmetatable({}, {
        \\  __index = function(self, key)
        \\    local value = self[key]
        \\    return value
        \\  end,
        \\})
        \\return target.missing
    , .{ .name = "=api-stack-limit-metamethod-recursion" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "stack overflow");
}

test "api call frame limit catches metamethod recursion" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_call_frames = 8 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local target
        \\target = setmetatable({}, {
        \\  __index = function(self, key)
        \\    local value = self[key]
        \\    return value
        \\  end,
        \\})
        \\return target.missing
    , .{ .name = "=api-call-frame-limit-metamethod-recursion" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "stack overflow");
}

test "api stack value limit catches coroutine recursion" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_stack_values = 64 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local co = coroutine.create(function(a, b, c, d, e, f, g, h)
        \\  local function recurse(x1, x2, x3, x4, x5, x6, x7, x8)
        \\    local value = recurse(x1, x2, x3, x4, x5, x6, x7, x8)
        \\    return value
        \\  end
        \\  recurse(a, b, c, d, e, f, g, h)
        \\end)
        \\local ok, err = coroutine.resume(co, 1, 2, 3, 4, 5, 6, 7, 8)
        \\return ok, tostring(err), coroutine.status(co)
    , .{ .name = "=api-stack-limit-coroutine-recursion" });
    defer chunk.deinit();

    const Result = Tuple(&.{ bool, []const u8, []const u8 });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();
    try std.testing.expectEqual(false, result.get(0));
    try std.testing.expectEqualStrings("dead", result.get(2));
}

test "api call frame limit catches coroutine recursion" {
    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_call_frames = 8 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(
        \\local co = coroutine.create(function()
        \\  local function recurse()
        \\    local value = recurse()
        \\    return value
        \\  end
        \\  recurse()
        \\end)
        \\local ok, err = coroutine.resume(co)
        \\return ok, tostring(err), coroutine.status(co)
    , .{ .name = "=api-call-frame-limit-coroutine-recursion" });
    defer chunk.deinit();

    const Result = Tuple(&.{ bool, []const u8, []const u8 });
    var result = try chunk.call(.{}, Result);
    defer result.deinit();
    try std.testing.expectEqual(false, result.get(0));
    try std.testing.expect(std.mem.indexOf(u8, result.get(1), "stack overflow") != null);
    try std.testing.expectEqualStrings("dead", result.get(2));
}

test "api stack value limit catches host callback reentry" {
    const Callbacks = struct {
        fn enter(ctx: *Context) !void {
            var callback = try ctx.arg(0, Function);
            defer callback.deinit();
            callback.call(.{}, void) catch |err| switch (err) {
                error.LuaError => {
                    const message = try ctx.state().errorMessage();
                    defer ctx.state().allocator().free(message);
                    return ctx.raise(message);
                },
                else => return err,
            };
            try ctx.returnValues(.{});
        }
    };

    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_stack_values = 96 },
    });
    defer lua.deinit();

    var enter = try lua.register("enter", Callbacks.enter);
    defer enter.deinit();
    try lua.setGlobal("enter", enter);

    var chunk = try lua.loadString(
        \\enter(function()
        \\  local function recurse(a, b, c, d, e, f, g, h)
        \\    local value = recurse(a, b, c, d, e, f, g, h)
        \\    return value
        \\  end
        \\  recurse(1, 2, 3, 4, 5, 6, 7, 8)
        \\end)
    , .{ .name = "=api-stack-limit-host-reentry" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "stack overflow");
}

test "api call frame limit catches host callback reentry" {
    const Callbacks = struct {
        fn enter(ctx: *Context) !void {
            var callback = try ctx.arg(0, Function);
            defer callback.deinit();
            callback.call(.{}, void) catch |err| switch (err) {
                error.LuaError => {
                    const message = try ctx.state().errorMessage();
                    defer ctx.state().allocator().free(message);
                    return ctx.raise(message);
                },
                else => return err,
            };
            try ctx.returnValues(.{});
        }
    };

    var lua = try State.init(std.testing.allocator, .{
        .limits = .{ .max_call_frames = 8 },
    });
    defer lua.deinit();

    var enter = try lua.register("enter", Callbacks.enter);
    defer enter.deinit();
    try lua.setGlobal("enter", enter);

    var chunk = try lua.loadString(
        \\enter(function()
        \\  local function recurse()
        \\    local value = recurse()
        \\    return value
        \\  end
        \\  recurse()
        \\end)
    , .{ .name = "=api-call-frame-limit-host-reentry" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, "stack overflow");
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

test "api memory limit applies while loading source" {
    var source = std.ArrayList(u8).empty;
    defer source.deinit(std.testing.allocator);
    try source.appendSlice(std.testing.allocator, "global x\n");
    for (0..20_000) |_| try source.appendSlice(std.testing.allocator, "x = 1\n");

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .none,
        .limits = .{ .max_memory = 64 * 1024 },
    });
    defer lua.deinit();

    try std.testing.expectError(error.LuaError, lua.loadString(source.items, .{ .name = "=api-memory-load-source-limit" }));
    try expectLastErrorContains(&lua, memory_limit_error_message);
}

test "api memory limit applies while loading bytecode" {
    var source = std.ArrayList(u8).empty;
    defer source.deinit(std.testing.allocator);
    try source.appendSlice(std.testing.allocator, "return function() return '");
    for (0..256 * 1024) |_| try source.append(std.testing.allocator, 'x');
    try source.appendSlice(std.testing.allocator, "' end");

    var source_state = try State.init(std.testing.allocator, .{ .stdlib = .none });
    defer source_state.deinit();

    var source_chunk = try source_state.loadString(source.items, .{ .name = "=api-memory-bytecode-source" });
    defer source_chunk.deinit();
    const dumped = try source_chunk.dumpBytecode(.{});
    defer source_state.allocator().free(dumped);

    var target_state = try State.init(std.testing.allocator, .{
        .stdlib = .none,
        .limits = .{ .max_memory = 64 * 1024 },
    });
    defer target_state.deinit();

    try std.testing.expectError(error.LuaError, target_state.loadBytecode(dumped, .{}));
    try expectLastErrorContains(&target_state, memory_limit_error_message);
}

test "api memory limit applies to captured output buffers" {
    var source = std.ArrayList(u8).empty;
    defer source.deinit(std.testing.allocator);
    try source.appendSlice(std.testing.allocator, "print('");
    for (0..128 * 1024) |_| try source.append(std.testing.allocator, 'x');
    try source.appendSlice(std.testing.allocator, "')");

    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .base,
        .limits = .{ .max_memory = 224 * 1024 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString(source.items, .{ .name = "=api-memory-output-limit" });
    defer chunk.deinit();

    const result = try chunk.protectedCall(.{}, void);
    switch (result) {
        .ok => return error.TestExpectedLuaError,
        .lua_error => |err_ref| {
            var err = err_ref;
            defer err.deinit();
            const message = try err.message();
            defer lua.allocator().free(message);
            try std.testing.expect(std.mem.indexOf(u8, message, memory_limit_error_message) != null);
        },
    }
}

test "api memory limit applies to stdlib temporaries" {
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .safe,
        .limits = .{ .max_memory = 160 * 1024 },
    });
    defer lua.deinit();

    var chunk = try lua.loadString("return string.rep('x', 256 * 1024)", .{ .name = "=api-memory-stdlib-temporary-limit" });
    defer chunk.deinit();

    try expectProtectedErrorContains(&lua, chunk, memory_limit_error_message);
}

test "api memory limit applies to memory filesystem read copies" {
    const BigFile = struct {
        const contents = [_]u8{'x'} ** (256 * 1024);
    };
    const files = [_]MemoryFile{
        .{ .path = "large.lua", .contents = BigFile.contents[0..] },
    };
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .safe,
        .capabilities = .{ .filesystem = .{ .memory = &files } },
        .limits = .{ .max_memory = 160 * 1024 },
    });
    defer lua.deinit();

    try std.testing.expectError(error.LuaError, lua.loadFile("large.lua", .{}));
    try expectLastErrorContains(&lua, memory_limit_error_message);
}

test "api memory limit recovery preserves nested protected calls" {
    var lua = try State.init(std.testing.allocator, .{
        .stdlib = .safe,
        .limits = .{ .max_memory = 160 * 1024 },
    });
    defer lua.deinit();

    var failing = try lua.loadString("return string.rep('x', 256 * 1024)", .{ .name = "=api-memory-recovery-fail" });
    defer failing.deinit();
    try expectProtectedErrorContains(&lua, failing, memory_limit_error_message);

    var recovered = try lua.loadString(
        \\local ok, value = pcall(function()
        \\  local inner_ok, inner_value = pcall(function()
        \\    return 21
        \\  end)
        \\  assert(inner_ok and inner_value == 21)
        \\  return inner_value * 2
        \\end)
        \\assert(ok and value == 42)
    , .{ .name = "=api-memory-recovery-nested-pcall" });
    defer recovered.deinit();
    try recovered.call(.{}, void);
}
