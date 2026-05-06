# Milestone 21: Zig-Native Embedding API Plan

## Goal

Make zlua useful from Zig applications through an API that feels designed for Zig rather than copied from the Lua C API.

The embedding API should let a host application create a Lua environment, choose standard libraries and host capabilities, load source, call Lua functions, expose Zig functions and data, exchange values safely, and configure sandbox limits without relying on stack indexes, global process state, `longjmp`-style control flow, or C API naming patterns.

This API is separate from the future C compatibility layer in Milestone 22. The Zig API can use typed errors, allocator ownership, comptime conversion helpers, RAII-style rooted handles, and explicit capability injection.

## Current Context

`src/runtime.zig` already has pieces the API should build on:

```zig
pub const StdlibMode = enum {
    none,
    base,
    safe,
    full,
};

pub const StateOptions = struct {
    stdlib: StdlibMode = .full,
    io: ?std.Io = null,
    filesystem: FilesystemCapability = .disabled,
    environment: ?*const std.process.Environ.Map = null,
    clock: ClockCapability = .system,
    process: ProcessCapability = .disabled,
    stdin: []const u8 = "",
    debug_errors: bool = false,
    trace_vm: bool = false,
};
```

The public Milestone 21 API should not expose the current VM implementation directly. Runtime types can remain internal or semi-internal while a stable facade grows around them.

## Design Principles

- Prefer handles and typed operations over stack indexes.
- Make ownership explicit through `deinit`, `Ref`, and allocator-based APIs.
- Make host access explicit through capabilities, not process-global I/O, filesystem, environment, or process functions.
- Provide a safe default environment for embedding.
- Keep low-level escape hatches available without making them the common path.
- Treat Lua errors as values when Lua code can observe them.
- Return Zig errors for host allocation, I/O, API misuse, and VM control failures.
- Make common workflows short: run a script, register a function, call a Lua function, build a table, preload a module.
- Preserve CLua behavior for Lua semantics while letting the Zig surface be idiomatic.

## Non-Goals

- Do not mirror the Lua C API stack model as the primary Zig API.
- Do not promise ABI compatibility.
- Do not expose internal bytecode, frames, or GC object layouts as stable embedding contracts.
- Do not make `runtime.Value` the only public interop type if a safer facade can hide lifetime details.
- Do not add backwards compatibility shims before there are external users.

## Public Module Shape

Add a new facade module:

```text
src/api.zig
src/api/state.zig
src/api/value.zig
src/api/table.zig
src/api/function.zig
src/api/context.zig
src/api/userdata.zig
src/api/error.zig
src/api/convert.zig
```

Expose it from `src/root.zig`:

```zig
pub const api = @import("api.zig");

pub const State = api.State;
pub const Options = api.Options;
pub const Value = api.Value;
pub const Ref = api.Ref;
pub const Table = api.Table;
pub const Function = api.Function;
pub const Context = api.Context;
pub const Error = api.Error;
```

The high-level import experience should be:

```zig
const zlua = @import("zlua");

var lua = try zlua.State.init(allocator, .{ .stdlib = .safe });
defer lua.deinit();

try lua.doString("print('hello from lua')", .{});
```

## State Lifecycle

The main object is `zlua.State`. It owns one Lua global environment, allocator-backed runtime state, GC state, interned strings, registry roots, and host capabilities.

Proposed shape:

```zig
pub const Options = struct {
    stdlib: Stdlib = .safe,
    capabilities: Capabilities = .sandboxed,
    limits: Limits = .{},
    gc: GcOptions = .{},
    debug: DebugOptions = .{},
};

pub const Stdlib = enum {
    none,
    base,
    safe,
    full,
};

pub const State = struct {
    pub fn init(allocator: std.mem.Allocator, options: Options) !State;
    pub fn deinit(self: *State) void;

    pub fn openLibs(self: *State, mode: Stdlib) !void;
    pub fn collect(self: *State) !void;
    pub fn stepGc(self: *State, budget: GcBudget) !GcStepResult;
};
```

Default `State.init` should be safe for embedding. That means `.safe` libraries, disabled filesystem/process access, no ambient environment, and explicit I/O.

The CLI can opt into `.full`; embedded hosts should not get `.full` accidentally.

## Capabilities

Capabilities are host services available to Lua libraries and loaders.

```zig
pub const Capabilities = struct {
    io: IoCapability = .disabled,
    filesystem: FilesystemCapability = .disabled,
    environment: EnvironmentCapability = .disabled,
    clock: ClockCapability = .disabled,
    process: ProcessCapability = .disabled,

    pub const sandboxed: Capabilities = .{};
};
```

The capability model should support:

```zig
var lua = try zlua.State.init(allocator, .{
    .stdlib = .safe,
    .capabilities = .{
        .io = .{ .stdout = stdout_writer.any() },
        .clock = .{ .fixed = 0 },
    },
});
defer lua.deinit();
```

Filesystem support should have at least three modes:

```zig
pub const FilesystemCapability = union(enum) {
    disabled,
    memory: []const MemoryFile,
    host_cwd,
};
```

`memory` is important for tests, sandboxes, and embedded apps that want `require` without giving Lua host filesystem access.

## Limits

Limits should be explicit and testable.

```zig
pub const Limits = struct {
    max_memory: ?usize = null,
    max_stack_values: ?usize = null,
    max_call_frames: ?usize = null,
    max_instructions: ?u64 = null,
    instruction_budget: ?InstructionBudget = null,
};
```

Memory limits should route through allocator/GC accounting. Instruction limits should be checked by the VM dispatch loop and should produce a Lua-visible timeout error when hit from protected calls.

## Values And Handles

The API needs two layers:

```zig
pub const Value = union(enum) {
    nil,
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: Table,
    function: Function,
    userdata: AnyUserdata,
    thread: Thread,
};
```

`Value` is convenient for immediate interop. Long-lived references should use rooted handles:

```zig
pub const Ref = struct {
    pub fn deinit(self: *Ref) void;
    pub fn value(self: Ref) Value;
};

pub const Table = struct {
    ref: Ref,

    pub fn deinit(self: *Table) void;
    pub fn get(self: Table, key: anytype, comptime T: type) !T;
    pub fn set(self: Table, key: anytype, value: anytype) !void;
};

pub const Function = struct {
    ref: Ref,

    pub fn deinit(self: *Function) void;
    pub fn call(self: Function, args: anytype, comptime R: type) !R;
    pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R);
};
```

Rules:

- Returned `Table`, `Function`, `Thread`, and `Userdata` handles own a registry root unless explicitly documented as borrowed.
- `deinit` releases the root, not necessarily the Lua object immediately.
- Raw `[]const u8` strings returned from Lua are valid while their root or owning state keeps them alive.
- API functions that return slices must document whether the slice is Lua-owned or allocator-owned.

## Conversion Model

Common Zig values should convert automatically:

```text
void/null -> no returns or nil depending on context
bool -> boolean
i64/u64/comptime_int -> Lua integer when representable
f64/comptime_float -> Lua number
[]const u8 -> Lua string
struct -> Lua table by field name when requested
[]const T -> Lua array table when requested
Table/Function/Ref/Value -> existing Lua value
```

The facade should expose conversion traits for explicit control:

```zig
pub fn push(self: *State, value: anytype) !Value;
pub fn read(self: *State, value: Value, comptime T: type) !T;
```

For advanced cases, allow users to implement:

```zig
pub fn toLua(self: T, lua: *zlua.State) !zlua.Value;
pub fn fromLua(lua: *zlua.State, value: zlua.Value) !T;
```

Do not make every conversion implicit if it would hide allocation, rooting, numeric truncation, or lossy table decoding. Prefer clear errors such as `error.TypeMismatch`, `error.IntegerOutOfRange`, and `error.MissingField`.

## Loading And Execution

Provide simple convenience methods and reusable loaded chunks.

```zig
pub const LoadOptions = struct {
    name: ?[]const u8 = null,
    environment: ?Table = null,
    mode: LoadMode = .source_only,
};

pub const DoOptions = LoadOptions;

pub fn loadString(self: *State, source: []const u8, options: LoadOptions) !Function;
pub fn loadFile(self: *State, path: []const u8, options: LoadOptions) !Function;
pub fn doString(self: *State, source: []const u8, options: DoOptions) !void;
pub fn doFile(self: *State, path: []const u8, options: DoOptions) !void;
```

`loadString` returns a rooted `Function`; callers can run it more than once or install it in a table.

## Calling Lua

Avoid C API stack operations for common calls.

```zig
pub fn callGlobal(self: *State, name: []const u8, args: anytype, comptime R: type) !R;
pub fn protectedCallGlobal(self: *State, name: []const u8, args: anytype, comptime R: type) !CallResult(R);
```

Examples:

```zig
const sum = try lua.callGlobal("add", .{ 20, 22 }, i64);

var row = try lua.callGlobal("lookup", .{ "grant" }, zlua.Tuple(&.{ i64, []const u8 }));
defer row.deinit();
```

For multiple returns, provide a tuple helper rather than forcing users to read the Lua stack:

```zig
const Result = zlua.Tuple(&.{ bool, []const u8 });
var result = try lua.callGlobal("check", .{ "input" }, Result);
defer result.deinit();
```

## Host Functions

The first supported callback shape should be low-level but Zig-friendly:

```zig
pub const HostFn = *const fn (ctx: *Context) anyerror!void;

pub const Context = struct {
    pub fn state(self: *Context) *State;
    pub fn argCount(self: *Context) usize;
    pub fn arg(self: *Context, index: usize, comptime T: type) !T;
    pub fn optionalArg(self: *Context, index: usize, comptime T: type) !?T;
    pub fn pushReturn(self: *Context, value: anytype) !void;
    pub fn returnValues(self: *Context, values: anytype) !void;
    pub fn raise(self: *Context, value: anytype) error{LuaError};
};
```

Registering functions:

```zig
try lua.register("host_log", hostLog);

fn hostLog(ctx: *zlua.Context) !void {
    const level = try ctx.arg(0, []const u8);
    const message = try ctx.arg(1, []const u8);

    try appLog(level, message);
    try ctx.returnValues(.{});
}
```

Then add a typed wrapper layer for common functions:

```zig
try lua.registerTyped("clamp", clamp);

fn clamp(value: f64, min: f64, max: f64) f64 {
    return @min(@max(value, min), max);
}
```

The typed wrapper should be implemented on top of `Context`, not instead of it.

Callbacks need a context pointer story. Prefer explicit host objects over global variables:

```zig
try lua.registerMethod("log", logger, Logger.log);

const Logger = struct {
    writer: std.Io.Writer,

    fn log(self: *Logger, ctx: *zlua.Context) !void {
        const message = try ctx.arg(0, []const u8);
        try self.writer.print("{s}\n", .{message});
        try ctx.returnValues(.{});
    }
};
```

The API should support host context lifetimes without making zlua own arbitrary Zig memory by default.

## Tables And Globals

Global access should look like ordinary named access:

```zig
try lua.setGlobal("answer", 42);
const answer = try lua.getGlobal("answer", i64);
```

Tables should be easy to build and mutate:

```zig
var config = try lua.createTable(.{ .hash_hint = 4 });
defer config.deinit();

try config.set("title", "demo");
try config.set("max_players", 8);
try config.set("debug", true);

try lua.setGlobal("config", config);
```

Array tables should not require manual integer key loops for the common case:

```zig
try lua.setGlobal("search_path", &.{ "scripts/?.lua", "scripts/?/init.lua" });
```

Nested table builders can come later, but the API should leave room for:

```zig
try lua.setGlobal("app", .{
    .name = "zlua-host",
    .version = 1,
    .features = &.{ "plugins", "sandbox" },
});
```

## Modules And `require`

Embedded hosts often need to provide modules without filesystem access.

Provide preload helpers:

```zig
var host = try lua.createModule("host");
defer host.deinit();

try host.set("log", zlua.hostFn(hostLog));
try host.set("sleep_ms", zlua.hostFn(hostSleep));

try lua.preloadModule("host", host);
```

Lua usage:

```lua
local host = require("host")
host.log("plugin loaded")
```

For pure Lua modules in memory:

```zig
try lua.addMemoryFile("plugins/math.lua",
    \\local M = {}
    \\function M.double(x) return x * 2 end
    \\return M
);
try lua.setPackagePath("plugins/?.lua");
```

This should work without host filesystem access.

## Userdata

Userdata is the main interop mechanism for host-owned or Lua-owned native objects.

Support two modes:

```zig
pub fn newUserdata(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T);
pub fn newUserdataPtr(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T);
```

`newUserdata` copies or moves a Zig value into Lua-owned storage. `newUserdataPtr` wraps a host-owned pointer and should not free it unless the host explicitly supplies a finalizer.

Example:

```zig
const Counter = struct {
    value: i64,

    fn inc(self: *Counter, amount: i64) i64 {
        self.value += amount;
        return self.value;
    }
};

var counter = try lua.newUserdata(Counter, .{ .value = 0 }, .{});
defer counter.deinit();

try counter.method("inc", Counter.inc);
try lua.setGlobal("counter", counter);
```

Lua usage:

```lua
print(counter:inc(2))
print(counter:inc(3))
```

Userdata should support:

- Method registration through metatables.
- `__gc` finalizers for Lua-owned native storage.
- `__close` when used with Lua 5.5 to-be-closed variables.
- User value access where Lua 5.5 semantics require it.
- Type-safe downcasts in host callbacks.

## Errors And Protected Calls

The API needs to distinguish host/Zig failures from Lua failures.

Convenience APIs can return `error.LuaError`, with details stored on the state:

```zig
lua.doString(source, .{}) catch |err| switch (err) {
    error.LuaError => {
        const message = try lua.errorMessage();
        defer lua.allocator().free(message);
        try stderr.print("lua error: {s}\n", .{message});
    },
    else => return err,
};
```

For embedding code that needs Lua error values, provide protected result objects:

```zig
pub fn protectedCallGlobal(self: *State, name: []const u8, args: anytype, comptime R: type) !CallResult(R);

pub fn CallResult(comptime R: type) type {
    return union(enum) {
        ok: R,
        lua_error: ErrorRef,
    };
}
```

Example:

```zig
const result = try lua.protectedCallGlobal("plugin_main", .{}, void);
switch (result) {
    .ok => {},
    .lua_error => |err| {
        var lua_err = err;
        defer lua_err.deinit();
        try stderr.print("plugin failed: {s}\n", .{try lua_err.message()});
    },
}
```

No Zig API should use `longjmp` semantics. Errors unwind through Zig error returns and explicit result unions.

## Sandboxed Plugin Workflow

This should be the headline embedding use case.

```zig
var output = std.ArrayList(u8).empty;
defer output.deinit(allocator);

var lua = try zlua.State.init(allocator, .{
    .stdlib = .safe,
    .capabilities = .{
        .io = .{ .stdout = output.writer(allocator).any() },
        .filesystem = .{ .memory = &.{
            .{ .path = "plugin.lua", .contents = plugin_source },
        } },
        .clock = .{ .fixed = 0 },
    },
    .limits = .{
        .max_memory = 16 * 1024 * 1024,
        .max_call_frames = 128,
        .max_instructions = 1_000_000,
    },
});
defer lua.deinit();

try lua.register("emit", emit);
try lua.doFile("plugin.lua", .{});
```

Lua plugin:

```lua
emit({ kind = "loaded", version = 1 })
```

Host callback:

```zig
fn emit(ctx: *zlua.Context) !void {
    var event = try ctx.arg(0, zlua.Table);
    defer event.deinit();

    const kind = try event.get("kind", []const u8);
    try recordEvent(kind);
    try ctx.returnValues(.{});
}
```

## Calling Lua Callback From Host Function

Lua scripts often pass callbacks into host APIs.

```lua
host.each_item(function(item)
  print(item.name)
end)
```

Host implementation:

```zig
fn eachItem(ctx: *zlua.Context) !void {
    var callback = try ctx.arg(0, zlua.Function);
    defer callback.deinit();

    for (items) |item| {
        _ = try callback.call(.{ .{ .name = item.name, .id = item.id } }, void);
    }

    try ctx.returnValues(.{});
}
```

If callbacks can store references after the host function returns, the host must keep a rooted `Function` and release it later.

## Environment Workflow

Hosts should be able to run code with a specific `_ENV` instead of mutating globals.

```zig
var env = try lua.createTable(.{});
defer env.deinit();

var print_fn = try lua.getGlobal("print", zlua.Function);
defer print_fn.deinit();

try env.set("print", print_fn);
try env.set("config", .{ .difficulty = "hard" });

var chunk = try lua.loadString(script, .{ .name = "plugin", .environment = env });
defer chunk.deinit();

try chunk.call(.{}, void);
```

This is important for sandboxing and for running multiple plugin environments in one `State`.

## Low-Level Escape Hatch

Some stdlib and performance-sensitive code needs lower-level access. Keep this separate from the main API:

```zig
pub const Raw = struct {
    pub fn runtimeState(self: *Raw) *runtime.State;
    pub fn runtimeValue(self: *Raw, value: Value) runtime.Value;
};

pub fn raw(self: *State) Raw;
```

The raw API should be documented as unstable unless explicitly promoted.

## Testing Strategy

Embedding tests should live in Zig unit tests and, where useful, reuse Lua differential fixtures.

Test categories:

```text
state init/deinit in all stdlib modes
safe defaults deny filesystem/process/environment access
custom stdout captures print output
memory filesystem supports loadfile/dofile/require
loadString/loadFile source names appear in errors
setGlobal/getGlobal round trips basic Zig values
table set/get and nested table conversion
host callback argument validation
host callback multiple returns
host callback raises Lua error
Lua calls host, host calls Lua callback
protected calls preserve Lua error values
unprotected convenience calls expose error messages
userdata methods and finalizers
memory and instruction limits terminate scripts cleanly
GC does not collect rooted handles
released roots become collectable under forced GC
```

Add example programs under a dedicated tree:

```text
examples/embed/run_script.zig
examples/embed/register_function.zig
examples/embed/plugin_sandbox.zig
examples/embed/userdata_counter.zig
examples/embed/preload_module.zig
```

Build should compile examples in CI or through a dedicated step:

```text
zig build test-api
zig build examples
```

## Implementation Plan

### 21.0 Facade Skeleton

Goal: introduce public API names without changing runtime behavior.

Tasks:

```text
create src/api.zig facade
export zlua.api and top-level convenience aliases from src/root.zig
wrap runtime.State in api.State
map api.Options to runtime.StateOptions
add basic init/deinit/openLibs
add compile-only smoke tests for imports
```

Acceptance criteria:

```text
users can create and destroy zlua.State through the new facade
existing runtime tests still pass
no public examples import src/runtime.zig directly
```

### 21.1 Loading, Running, And Error Surface

Goal: make script execution usable from Zig.

Tasks:

```text
add loadString and doString
add loadFile and doFile through filesystem capabilities
add source name options
add error.LuaError convention
add State.errorMessage and State.takeErrorValue
add protected call result type
```

Acceptance criteria:

```text
embedding tests can run source strings and files
syntax/runtime errors can be inspected without parsing stderr
protected calls return Lua error values
```

### 21.2 Values, Roots, And Conversion

Goal: make value exchange safe and ergonomic.

Tasks:

```text
define api.Value separate from runtime.Value where useful
add Ref registry root type
add Table and Function rooted wrappers
add primitive Zig-to-Lua conversion
add primitive Lua-to-Zig conversion
add tuple/multiple-return helper
add forced-GC rooting tests
```

Acceptance criteria:

```text
basic bool/int/float/string/table/function values round trip
rooted handles survive forced GC
released handles do not leak roots
```

### 21.3 Globals, Tables, And Modules

Goal: cover common environment construction workflows.

Tasks:

```text
add setGlobal/getGlobal
add createTable with array/hash hints
add Table.get/Table.set
add array slice conversion
add simple struct-to-table conversion
add createModule and preloadModule
add package path helpers for memory filesystem
```

Acceptance criteria:

```text
hosts can build config tables and module tables without stack manipulation
Lua require can load host-preloaded modules
Lua require can load memory-backed Lua modules
```

### 21.4 Host Callback API

Goal: let Lua call Zig code without exposing VM internals.

Tasks:

```text
define Context argument and return APIs
add State.register for Context callbacks
add callback error conversion policy
add callback multiple returns
add callback-held rooted Lua functions
add optional typed registerTyped helper
```

Acceptance criteria:

```text
Lua can call registered Zig functions
Zig callbacks can validate arguments and return useful Lua errors
Zig callbacks can call Lua callback functions
typed wrapper examples compile if implemented in this phase
```

### 21.5 Userdata

Goal: expose host objects idiomatically.

Tasks:

```text
add Userdata(T) handle
add Lua-owned native storage path
add host-owned pointer wrapper path
add metatable method registration
add __gc and __close hooks
add type-safe userdata reads in Context.arg
```

Acceptance criteria:

```text
counter-style userdata example works
methods receive typed Zig pointers
finalizers run under forced GC tests
wrong userdata type errors are clear
```

### 21.6 Capabilities And Limits Polish

Goal: make sandboxing reliable enough for real embedding.

Tasks:

```text
make safe defaults explicit in api.Options
wire custom std.Io readers/writers through print/io APIs
wire memory filesystem through loadfile/dofile/require
add environment and clock capability wrappers
add memory limit accounting to public options
add instruction limit checks to VM loop
add limit error tests through protected calls
```

Acceptance criteria:

```text
safe API state has no filesystem/process/environment access by default
custom output capture works
instruction and memory limits terminate runaway scripts cleanly
```

### 21.7 Documentation And Examples

Goal: make the API discoverable.

Tasks:

```text
add docs/embedding.md or promote this plan into user-facing docs
add examples/embed programs
add build step that compiles examples
add README embedding snippet
document unstable raw escape hatch
document current unsupported API areas
```

Acceptance criteria:

```text
embedding examples compile in CI
API docs cover lifecycle, callbacks, tables, errors, userdata, and sandboxing
unsupported features are listed explicitly
```

## Milestone 21 Acceptance Criteria

```text
zlua.State is the preferred public embedding entrypoint
embedding examples compile and run
host functions can be registered and called from Lua
host functions can read arguments and return multiple values
Zig can call Lua globals and function handles with typed arguments/results
tables can be created, read, written, and installed as globals/modules
userdata supports at least methods and finalization basics
safe sandbox defaults are documented and tested
memory/instruction limits have API coverage and tests
Lua errors can be inspected as messages and as Lua values through protected calls
rooting semantics are documented and tested under forced GC
```

## Open Design Decisions

- Exact `std.Io` wrapper shape for Zig 0.16 readers/writers.
- Whether `State.init` should default to `.safe` or require the caller to choose a stdlib mode explicitly.
- Whether string results should default to Lua-owned slices or allocator-owned copies.
- How much struct/table conversion should be included in Milestone 21 versus later polish.
- Whether typed callback wrappers should support arbitrary Zig function signatures in the first version or start with `Context` only.
- How public the raw runtime escape hatch should be.

## Recommended First Cut

Implement the smallest useful API first:

```text
State init/deinit with safe defaults
doString/loadString
setGlobal/getGlobal for primitives
register Context-style host callbacks
Context.arg and Context.returnValues
Function rooted handle with call/protectedCall
Table rooted handle with get/set
custom stdout and memory filesystem capabilities
basic errorMessage support
forced-GC root tests
```

Defer typed callback reflection, broad struct conversion, userdata finalizer polish, coroutine handles, and raw escape hatch stabilization until the first cut is proven by examples.
