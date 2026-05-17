# api

## Navigation

- [API Index](README.md)

<details>
<summary>All documents</summary>

- [root](root.md)
- [frontend](frontend.md)
- [errors](errors.md)
- [frontend.source](frontend/source.md)
- [frontend.token](frontend/token.md)
- [frontend.diagnostic](frontend/diagnostic.md)
- [frontend.lexer](frontend/lexer.md)
- [frontend.ast](frontend/ast.md)
- [frontend.parser](frontend/parser.md)
- [compile](compile.md)
- [compile.resolver](compile/resolver.md)
- [compile.bytecode](compile/bytecode.md)
- [compile.proto](compile/proto.md)
- [compile.compiler](compile/compiler.md)
- [compile.disasm](compile/disasm.md)
- [api](api.md)
- [runtime](runtime.md)
- [runtime.chunk](runtime/chunk.md)
- [runtime.types](runtime/types.md)
- [runtime.value](runtime/value.md)
- [runtime.execute](runtime/execute.md)
- [testing.process](testing/process.md)
- [runtime.state](runtime/state.md)
- [runtime.call](runtime/call.md)
- [runtime.coroutine](runtime/coroutine.md)
- [runtime.debug](runtime/debug.md)
- [runtime.gc](runtime/gc.md)
- [runtime.host](runtime/host.md)
- [stdlib](stdlib.md)
- [stdlib.base](stdlib/base.md)
- [stdlib.table](stdlib/table.md)
- [stdlib.string](stdlib/string.md)
- [stdlib.math](stdlib/math.md)
- [stdlib.utf8](stdlib/utf8.md)
- [stdlib.coroutine](stdlib/coroutine.md)
- [stdlib.debug](stdlib/debug.md)
- [stdlib.package](stdlib/package.md)
- [stdlib.io](stdlib/io.md)
- [stdlib.os](stdlib/os.md)
- [stdlib.json](stdlib/json.md)
- [stdlib.zerde_lua](stdlib/zerde_lua.md)
- [stdlib.toml](stdlib/toml.md)
- [stdlib.msgpack](stdlib/msgpack.md)
- [stdlib.csv](stdlib/csv.md)
- [runtime.vm](runtime/vm.md)
- [runtime.tests](runtime/tests.md)
- [runtime.internal](runtime/internal.md)
- [testing](testing.md)
- [testing.clua](testing/clua.md)
- [testing.bench_runner](testing/bench_runner.md)
- [testing.c_api_runner](testing/c_api_runner.md)
- [testing.diff_runner](testing/diff_runner.md)
- [testing.expected_failures](testing/expected_failures.md)
- [testing.metadata](testing/metadata.md)
- [testing.normalizer](testing/normalizer.md)
- [testing.extension_runner](testing/extension_runner.md)
- [testing.official_suite](testing/official_suite.md)

</details>

## Overview

Zig-native embedding API for zlua.

This module is the primary host-facing entrypoint. It provides a high-level
API around a Lua 5.5 state using Zig values, explicit host capabilities,
rooted handles, and Zig errors rather than the Lua C API stack discipline.

A typical host creates a `State`, optionally grants capabilities and limits,
loads Lua source or bytecode, installs host callbacks or userdata, and then
exchanges values through typed conversions:

```zig
var lua = try zlua.State.init(allocator, .{});
defer lua.deinit();

var chunk = try lua.loadString("return 21 * 2", .{ .name = "=example" });
defer chunk.deinit();

const answer = try chunk.call(.{}, i64);
```

Handles such as `Table`, `Function`, `Ref`, `Userdata(T)`, `AnyUserdata`,
`ErrorRef`, and `Value` variants that contain handles root their Lua values
while they live. Hosts must call `deinit` on those handles when finished.

The default `Options` open safe standard libraries while keeping filesystem,
environment, clock, process, and host I/O capabilities sandboxed. Grant host
services explicitly through `Capabilities` when embedded Lua code should be
allowed to observe or mutate the outside world.

Convenience APIs return `error.LuaError` for Lua syntax/runtime failures and
store the last Lua error value on the `State`; use `errorMessage` or
`takeErrorValue` to inspect it. `Function.protectedCall` returns Lua failures
as `CallResult(R).lua_error` instead.

The lower-level `runtime` module is an implementation detail for zlua itself
and should not be treated as a stable embedding contract.

## Functions

- [UserdataOptions](#fn-userdataoptions)
- [UserdataPtrOptions](#fn-userdataptroptions)
- [Userdata](#fn-userdata)
- [CallResult](#fn-callresult)
- [Tuple](#fn-tuple)

## Types

- [Error](#type-error)
- [UnsupportedOption](#type-unsupportedoption)
- [ConversionError](#type-conversionerror)
- [Stdlib](#type-stdlib)
- [IoCapability](#type-iocapability)
- [Capabilities](#type-capabilities)
- [Limits](#type-limits)
- [InstructionBudget](#type-instructionbudget)
- [GcOptions](#type-gcoptions)
- [DebugOptions](#type-debugoptions)
- [Options](#type-options)
- [LoadMode](#type-loadmode)
- [LoadOptions](#type-loadoptions)
- [BytecodeLoadOptions](#type-bytecodeloadoptions)
- [BytecodeDumpOptions](#type-bytecodedumpoptions)
- [TableOptions](#type-tableoptions)
- [GcBudget](#type-gcbudget)
- [GcStepResult](#type-gcstepresult)
- [State](#type-state)
- [Ref](#type-ref)
- [Table](#type-table)
- [Function](#type-function)
- [AnyUserdata](#type-anyuserdata)
- [ErrorRef](#type-errorref)
- [Value](#type-value)
- [Context](#type-context)
- [Thread](#type-thread)

## Constants

- [HostFn](#const-hostfn)

## Aliases

- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)
- [FilesystemCapability](#alias-filesystemcapability)
- [CustomFilesystem](#alias-customfilesystem)
- [EnvironmentCapability](#alias-environmentcapability)
- [CustomEnvironment](#alias-customenvironment)
- [ClockCapability](#alias-clockcapability)
- [CustomClock](#alias-customclock)
- [ProcessCapability](#alias-processcapability)
- [CustomProcess](#alias-customprocess)
- [ProcessResult](#alias-processresult)
- [ProcessStatus](#alias-processstatus)
- [DoOptions](#alias-dooptions)

<a id="type-error"></a>

## Error

[Error](#type-error) set used when an API operation failed because Lua raised a syntax or runtime error.

```zig
pub const Error = error{
    LuaError,
};
```

<a id="type-unsupportedoption"></a>

## UnsupportedOption

[Error](#type-error) set used when an option combination is not supported by the high-level API.

```zig
pub const UnsupportedOption = error{
    UnsupportedOption,
};
```

<a id="type-conversionerror"></a>

## ConversionError

Errors produced while converting values between Zig and Lua representations.

```zig
pub const ConversionError = error{
    TypeMismatch,
    IntegerOutOfRange,
    UnsupportedType,
    ArityMismatch,
};
```

<a id="fn-userdataoptions"></a>

## UserdataOptions

Returns options for `State.newUserdata`, parameterized by the stored Zig type.

```zig
pub fn UserdataOptions(comptime T: type) type
```

<a id="fn-userdataptroptions"></a>

## UserdataPtrOptions

Returns options for `State.newUserdataPtr`, parameterized by the pointed-to Zig type.

```zig
pub fn UserdataPtrOptions(comptime T: type) type
```

<a id="type-stdlib"></a>

## Stdlib

Standard-library selection used when creating or opening a state.

```zig
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
```

<a id="alias-memoryfile"></a>

## MemoryFile

A read-only file entry for memory-backed filesystem capabilities.

```zig
pub const MemoryFile = runtime.MemoryFile;
```

References: [`runtime.MemoryFile`](runtime.md#alias-memoryfile)

<a id="alias-memoryfilesystem"></a>

## MemoryFilesystem

Writable in-memory filesystem implementation for sandboxed file access.

```zig
pub const MemoryFilesystem = runtime.MemoryFilesystem;
```

References: [`runtime.MemoryFilesystem`](runtime.md#alias-memoryfilesystem)

<a id="type-iocapability"></a>

## IoCapability

Host I/O access granted to Lua standard-library operations.

```zig
pub const IoCapability = struct {
    /// Optional Zig I/O runtime required by host-backed filesystem, clock, and process operations.
    runtime: ?std.Io = null,
    /// Bytes returned by Lua stdin reads when the `io` library is enabled.
    stdin: []const u8 = "",
    /// Optional writer used for Lua stdout, including `print` and `io.write`.
    stdout: ?*std.Io.Writer = null,
    /// Optional writer used for Lua stderr.
    stderr: ?*std.Io.Writer = null,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [disabled](#const-iocapability-disabled) |  |  | I/O capability with no host I/O handles or captured streams. |

<a id="const-iocapability-disabled"></a>

### IoCapability.disabled

I/O capability with no host I/O handles or captured streams.

```zig
pub const disabled: IoCapability = .{};
```

References: [`IoCapability`](#type-iocapability)

<a id="alias-filesystemcapability"></a>

## FilesystemCapability

Filesystem access granted to Lua file APIs, `loadfile`, `dofile`, and `require`.

```zig
pub const FilesystemCapability = runtime.FilesystemCapability;
```

References: [`runtime.FilesystemCapability`](runtime.md#alias-filesystemcapability)

<a id="alias-customfilesystem"></a>

## CustomFilesystem

Callback-backed filesystem access for embedders with non-std host services.

```zig
pub const CustomFilesystem = runtime.CustomFilesystem;
```

References: [`runtime.CustomFilesystem`](runtime.md#alias-customfilesystem)

<a id="alias-environmentcapability"></a>

## EnvironmentCapability

Environment-variable access granted to `os.getenv` and enabled child processes.

```zig
pub const EnvironmentCapability = runtime.EnvironmentCapability;
```

References: [`runtime.EnvironmentCapability`](runtime.md#alias-environmentcapability)

<a id="alias-customenvironment"></a>

## CustomEnvironment

Callback-backed environment access for embedders with non-std host services.

```zig
pub const CustomEnvironment = runtime.CustomEnvironment;
```

References: [`runtime.CustomEnvironment`](runtime.md#alias-customenvironment)

<a id="alias-clockcapability"></a>

## ClockCapability

Clock access granted to Lua time/date APIs.

```zig
pub const ClockCapability = runtime.ClockCapability;
```

References: [`runtime.ClockCapability`](runtime.md#alias-clockcapability)

<a id="alias-customclock"></a>

## CustomClock

Callback-backed clock access for embedders with non-std host services.

```zig
pub const CustomClock = runtime.CustomClock;
```

References: [`runtime.CustomClock`](runtime.md#alias-customclock)

<a id="alias-processcapability"></a>

## ProcessCapability

Process-spawning access granted to `os.execute`.

```zig
pub const ProcessCapability = runtime.ProcessCapability;
```

References: [`runtime.ProcessCapability`](runtime.md#alias-processcapability)

<a id="alias-customprocess"></a>

## CustomProcess

Callback-backed process execution for embedders with non-std host services.

```zig
pub const CustomProcess = runtime.CustomProcess;
```

References: [`runtime.CustomProcess`](runtime.md#alias-customprocess)

<a id="alias-processresult"></a>

## ProcessResult

Result returned by callback-backed process execution.

```zig
pub const ProcessResult = runtime.ProcessResult;
```

References: [`runtime.ProcessResult`](runtime.md#alias-processresult)

<a id="alias-processstatus"></a>

## ProcessStatus

```zig
pub const ProcessStatus = runtime.ProcessStatus;
```

References: [`runtime.ProcessStatus`](runtime.md#alias-processstatus)

<a id="type-capabilities"></a>

## Capabilities

Host services Lua code may use when matching standard-library functions are open.

```zig
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
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [sandboxed](#const-capabilities-sandboxed) |  |  | Capability set that denies all ambient host access. |

<a id="const-capabilities-sandboxed"></a>

### Capabilities.sandboxed

Capability set that denies all ambient host access.

```zig
pub const sandboxed: Capabilities = .{};
```

References: [`Capabilities`](#type-capabilities)

<a id="type-limits"></a>

## Limits

Resource limits enforced by the state.

```zig
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
```

<a id="type-instructionbudget"></a>

## InstructionBudget

Snapshot of the state's cumulative instruction budget.

```zig
pub const InstructionBudget = struct {
    /// Configured instruction limit, or null when unlimited.
    limit: ?u64,
    /// Number of VM instructions executed since state creation or the last reset.
    used: u64,
    /// Remaining instructions before the limit is exhausted, or null when unlimited.
    remaining: ?u64,
};
```

<a id="type-gcoptions"></a>

## GcOptions

Garbage-collector tuning options, reserved for future API expansion.

```zig
pub const GcOptions = struct {};
```

<a id="type-debugoptions"></a>

## DebugOptions

Diagnostics and tracing options intended for development and tests.

```zig
pub const DebugOptions = struct {
    /// Include richer internal error diagnostics where available.
    errors: bool = false,
    /// Trace VM execution.
    trace_vm: bool = false,
};
```

<a id="type-options"></a>

## Options

[State](#type-state) creation options.

```zig
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
```

<a id="type-loadmode"></a>

## LoadMode

Accepted chunk kinds for `loadString` and `loadFile`.

```zig
pub const LoadMode = enum {
    /// Accept only Lua source text.
    source_only,
    /// Accept only zlua binary chunks.
    binary_only,
    /// Accept either Lua source text or zlua binary chunks.
    source_or_binary,
};
```

<a id="type-loadoptions"></a>

## LoadOptions

[Options](#type-options) for loading a Lua chunk from source or a file.

```zig
pub const LoadOptions = struct {
    /// Optional source name used in diagnostics; use Lua-style `=name` or `@path` when desired.
    name: ?[]const u8 = null,
    /// Optional environment table used as the chunk's `_ENV`.
    environment: ?Table = null,
    /// Whether source text, binary chunks, or both are accepted.
    mode: LoadMode = .source_only,
};
```

<a id="alias-dooptions"></a>

## DoOptions

[Options](#type-options) for one-shot `doString` and `doFile` execution.

```zig
pub const DoOptions = LoadOptions;
```

References: [`LoadOptions`](#type-loadoptions)

<a id="type-bytecodeloadoptions"></a>

## BytecodeLoadOptions

[Options](#type-options) for loading zlua bytecode directly.

```zig
pub const BytecodeLoadOptions = struct {
    /// Optional environment table used as the loaded function's `_ENV`.
    environment: ?Table = null,
};
```

<a id="type-bytecodedumpoptions"></a>

## BytecodeDumpOptions

[Options](#type-options) for dumping a loaded function to zlua bytecode.

```zig
pub const BytecodeDumpOptions = struct {
    /// Whether debug/source metadata should be omitted from the dump.
    strip_debug: bool = false,
};
```

<a id="type-tableoptions"></a>

## TableOptions

Initial capacity hints for a newly created Lua table.

```zig
pub const TableOptions = struct {
    /// Expected number of array-part entries.
    array_hint: u32 = 0,
    /// Expected number of hash-part entries.
    hash_hint: u32 = 0,
};
```

<a id="const-hostfn"></a>

## HostFn

Untyped host callback signature used by `State.register`.

```zig
pub const HostFn = *const fn (ctx: *Context) anyerror!void;
```

References: [`Context`](#type-context)

<a id="type-gcbudget"></a>

## GcBudget

Budget passed to `State.stepGc`.

```zig
pub const GcBudget = struct {
    /// Requested number of GC steps; currently reserved because `stepGc` performs a full collection.
    steps: usize = 0,
};
```

<a id="type-gcstepresult"></a>

## GcStepResult

Result of an incremental garbage-collection step.

```zig
pub const GcStepResult = enum {
    /// The requested collection work completed.
    complete,
    /// More work remains.
    pending,
};
```

<a id="type-state"></a>

## State

Owns a Lua VM instance and its host-facing API state.

```zig
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
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [init](#fn-state-init) | `state_allocator: std.mem.Allocator, options: Options` | `!State` | Creates a new Lua state using &#96;state_allocator&#96; and the supplied options. |
| [deinit](#fn-state-deinit) | `self: *State` | `void` | Releases all resources owned by the state and invalidates outstanding API handles. |
| [allocator](#fn-state-allocator) | `self: *State` | `std.mem.Allocator` | Returns the allocator used for API-owned allocations returned to the host. |
| [instructionBudget](#fn-state-instructionbudget) | `self: *const State` | `InstructionBudget` | Returns the cumulative instruction budget usage for this state. |
| [resetInstructionBudget](#fn-state-resetinstructionbudget) | `self: *State` | `void` | Resets the cumulative instruction counter to zero. |
| [openLibs](#fn-state-openlibs) | `self: *State, mode: Stdlib` | `!void` | Opens additional standard libraries after state creation. |
| [collect](#fn-state-collect) | `self: *State` | `!void` | Runs a full garbage collection cycle. |
| [stepGc](#fn-state-stepgc) | `self: *State, budget: GcBudget` | `!GcStepResult` | Runs garbage-collection work for &#96;budget&#96; and reports whether collection completed. |
| [push](#fn-state-push) | `self: *State, value: anytype` | `!Value` | Converts a Zig value into a rooted high-level Lua &#96;Value&#96;. |
| [read](#fn-state-read) | `self: *State, value: Value, comptime T: type` | `!T` | Converts a high-level Lua &#96;Value&#96; to the requested Zig type. |
| [setGlobal](#fn-state-setglobal) | `self: *State, name: []const u8, value: anytype` | `!void` | Sets a global variable after converting &#96;value&#96; to a Lua value. |
| [getGlobal](#fn-state-getglobal) | `self: *State, name: []const u8, comptime T: type` | `!T` | Reads a global variable and converts it to &#96;T&#96;. |
| [register](#fn-state-register) | `self: *State, name: []const u8, callback: HostFn` | `!Function` | Creates a Lua function handle that dispatches to an untyped Zig callback. |
| [registerTyped](#fn-state-registertyped) | `self: *State, name: []const u8, comptime function: anytype` | `!Function` | Creates a Lua function handle from a typed Zig function. |
| [registerUserdataInitializerWith](#fn-state-registeruserdatainitializerwith) | `self: *State, comptime T: type, name: []const u8, comptime initializer: anytype, comptime options: UserdataOptions(T)` | `!Function` | Creates a Lua function handle that constructs auto-bound userdata using &#96;initializer&#96;. |
| [createTable](#fn-state-createtable) | `self: *State, options: TableOptions` | `!Table` | Creates a rooted Lua table handle with optional capacity hints. |
| [newUserdata](#fn-state-newuserdata) | `self: *State, comptime T: type, value: T, options: UserdataOptions(T)` | `!Userdata(T)` | Allocates Lua-owned userdata storage initialized with &#96;value&#96;. |
| [newUserdataAuto](#fn-state-newuserdataauto) | `self: *State, comptime T: type, value: T, options: UserdataOptions(T)` | `!Userdata(T)` | Allocates Lua-owned userdata and installs eligible methods declared on &#96;T&#96;. |
| [newUserdataPtr](#fn-state-newuserdataptr) | `self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)` | `!Userdata(T)` | Wraps host-owned storage as Lua userdata without taking ownership of &#96;ptr&#96;. |
| [newUserdataPtrAuto](#fn-state-newuserdataptrauto) | `self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)` | `!Userdata(T)` | Wraps host-owned storage as Lua userdata and installs eligible methods declared on &#96;T&#96;. |
| [createModule](#fn-state-createmodule) | `self: *State, name: []const u8` | `!Table` | Creates a table intended to be installed as a Lua module. |
| [preloadModule](#fn-state-preloadmodule) | `self: *State, name: []const u8, module: Table` | `!void` | Adds &#96;module&#96; to &#96;package.loaded&#96; so &#96;require(name)&#96; returns it. |
| [setPackagePath](#fn-state-setpackagepath) | `self: *State, path: []const u8` | `!void` | Sets &#96;package.path&#96;, opening the package library first if needed. |
| [addMemoryFile](#fn-state-addmemoryfile) | `self: *State, path: []const u8, contents: []const u8` | `!void` | Adds or writes a file in the state's memory-backed filesystem. |
| [loadString](#fn-state-loadstring) | `self: *State, source: []const u8, options: LoadOptions` | `!Function` | Loads source text or bytecode from memory and returns a rooted function handle. |
| [loadFile](#fn-state-loadfile) | `self: *State, path: []const u8, options: LoadOptions` | `!Function` | Loads source text or bytecode from the configured filesystem. |
| [loadBytecode](#fn-state-loadbytecode) | `self: *State, bytecode: []const u8, options: BytecodeLoadOptions` | `!Function` | Loads a zlua bytecode dump and returns a rooted function handle. |
| [doString](#fn-state-dostring) | `self: *State, source: []const u8, options: DoOptions` | `!void` | Loads and immediately executes source text or bytecode from memory. |
| [doFile](#fn-state-dofile) | `self: *State, path: []const u8, options: DoOptions` | `!void` | Loads and immediately executes a chunk from the configured filesystem. |
| [errorMessage](#fn-state-errormessage) | `self: *State` | `![]const u8` | Formats the last Lua error value as an allocated message. |
| [takeErrorValue](#fn-state-takeerrorvalue) | `self: *State` | `?ErrorRef` | Takes ownership of the last captured Lua error value, if one exists. |

<a id="fn-state-init"></a>

### State.init

Creates a new Lua state using `state_allocator` and the supplied options.

The allocator must remain valid until `deinit`. The default options open
safe libraries with sandboxed host capabilities.

```zig
pub fn init(state_allocator: std.mem.Allocator, options: Options) !State
```

References: [`Options`](#type-options), [`State`](#type-state)

<a id="fn-state-deinit"></a>

### State.deinit

Releases all resources owned by the state and invalidates outstanding API handles.

```zig
pub fn deinit(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-allocator"></a>

### State.allocator

Returns the allocator used for API-owned allocations returned to the host.

```zig
pub fn allocator(self: *State) std.mem.Allocator
```

References: [`State`](#type-state)

<a id="fn-state-instructionbudget"></a>

### State.instructionBudget

Returns the cumulative instruction budget usage for this state.

```zig
pub fn instructionBudget(self: *const State) InstructionBudget
```

References: [`State`](#type-state), [`InstructionBudget`](#type-instructionbudget)

<a id="fn-state-resetinstructionbudget"></a>

### State.resetInstructionBudget

Resets the cumulative instruction counter to zero.

```zig
pub fn resetInstructionBudget(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-openlibs"></a>

### State.openLibs

Opens additional standard libraries after state creation.

```zig
pub fn openLibs(self: *State, mode: Stdlib) !void
```

References: [`State`](#type-state), [`Stdlib`](#type-stdlib)

<a id="fn-state-collect"></a>

### State.collect

Runs a full garbage collection cycle.

```zig
pub fn collect(self: *State) !void
```

References: [`State`](#type-state)

<a id="fn-state-stepgc"></a>

### State.stepGc

Runs garbage-collection work for `budget` and reports whether collection completed.

This currently performs a full collection regardless of the budget.

```zig
pub fn stepGc(self: *State, budget: GcBudget) !GcStepResult
```

References: [`State`](#type-state), [`GcBudget`](#type-gcbudget), [`GcStepResult`](#type-gcstepresult)

<a id="fn-state-push"></a>

### State.push

Converts a Zig value into a rooted high-level Lua `Value`.

```zig
pub fn push(self: *State, value: anytype) !Value
```

References: [`State`](#type-state), [`Value`](#type-value)

<a id="fn-state-read"></a>

### State.read

Converts a high-level Lua `Value` to the requested Zig type.

```zig
pub fn read(self: *State, value: Value, comptime T: type) !T
```

References: [`State`](#type-state), [`Value`](#type-value)

<a id="fn-state-setglobal"></a>

### State.setGlobal

Sets a global variable after converting `value` to a Lua value.

```zig
pub fn setGlobal(self: *State, name: []const u8, value: anytype) !void
```

References: [`State`](#type-state)

<a id="fn-state-getglobal"></a>

### State.getGlobal

Reads a global variable and converts it to `T`.

```zig
pub fn getGlobal(self: *State, name: []const u8, comptime T: type) !T
```

References: [`State`](#type-state)

<a id="fn-state-register"></a>

### State.register

Creates a Lua function handle that dispatches to an untyped Zig callback.

The returned function is not installed automatically; use `setGlobal` or
`Table.set` to expose it to Lua code.

```zig
pub fn register(self: *State, name: []const u8, callback: HostFn) !Function
```

References: [`State`](#type-state), [`HostFn`](#const-hostfn), [`Function`](#type-function)

<a id="fn-state-registertyped"></a>

### State.registerTyped

Creates a Lua function handle from a typed Zig function.

Parameters are read from Lua arguments by type. A `*Context` parameter may
be included to access the state or advanced callback APIs.

```zig
pub fn registerTyped(self: *State, name: []const u8, comptime function: anytype) !Function
```

References: [`State`](#type-state), [`Function`](#type-function)

<a id="fn-state-registeruserdatainitializerwith"></a>

### State.registerUserdataInitializerWith

Creates a Lua function handle that constructs auto-bound userdata using `initializer`.

The initializer's parameters are read from Lua arguments by type. A
`*Context` parameter may be included and is injected without consuming a
Lua argument. The initializer must return `T` or `!T`; the result is
wrapped with `newUserdataAuto` before being returned to Lua.

```zig
pub fn registerUserdataInitializerWith(self: *State, comptime T: type, name: []const u8, comptime initializer: anytype, comptime options: UserdataOptions(T)) !Function
```

References: [`State`](#type-state), [`Function`](#type-function)

<a id="fn-state-createtable"></a>

### State.createTable

Creates a rooted Lua table handle with optional capacity hints.

```zig
pub fn createTable(self: *State, options: TableOptions) !Table
```

References: [`State`](#type-state), [`TableOptions`](#type-tableoptions), [`Table`](#type-table)

<a id="fn-state-newuserdata"></a>

### State.newUserdata

Allocates Lua-owned userdata storage initialized with `value`.

```zig
pub fn newUserdata(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-newuserdataauto"></a>

### State.newUserdataAuto

Allocates Lua-owned userdata and installs eligible methods declared on `T`.

Public function declarations whose first parameter is `*T` or `*const T`
are installed on the userdata. Names beginning with `__` are installed as
metamethods; all other eligible names are installed on `__index`.

```zig
pub fn newUserdataAuto(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-newuserdataptr"></a>

### State.newUserdataPtr

Wraps host-owned storage as Lua userdata without taking ownership of `ptr`.

```zig
pub fn newUserdataPtr(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-newuserdataptrauto"></a>

### State.newUserdataPtrAuto

Wraps host-owned storage as Lua userdata and installs eligible methods declared on `T`.

```zig
pub fn newUserdataPtrAuto(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-createmodule"></a>

### State.createModule

Creates a table intended to be installed as a Lua module.

```zig
pub fn createModule(self: *State, name: []const u8) !Table
```

References: [`State`](#type-state), [`Table`](#type-table)

<a id="fn-state-preloadmodule"></a>

### State.preloadModule

Adds `module` to `package.loaded` so `require(name)` returns it.

```zig
pub fn preloadModule(self: *State, name: []const u8, module: Table) !void
```

References: [`State`](#type-state), [`Table`](#type-table)

<a id="fn-state-setpackagepath"></a>

### State.setPackagePath

Sets `package.path`, opening the package library first if needed.

```zig
pub fn setPackagePath(self: *State, path: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-addmemoryfile"></a>

### State.addMemoryFile

Adds or writes a file in the state's memory-backed filesystem.

Disabled and read-only memory states store an owned copy. Writable memory
filesystems receive a write. Host and custom filesystem states return
`error.UnsupportedOption`.

```zig
pub fn addMemoryFile(self: *State, path: []const u8, contents: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-loadstring"></a>

### State.loadString

Loads source text or bytecode from memory and returns a rooted function handle.

```zig
pub fn loadString(self: *State, source: []const u8, options: LoadOptions) !Function
```

References: [`State`](#type-state), [`LoadOptions`](#type-loadoptions), [`Function`](#type-function)

<a id="fn-state-loadfile"></a>

### State.loadFile

Loads source text or bytecode from the configured filesystem.

```zig
pub fn loadFile(self: *State, path: []const u8, options: LoadOptions) !Function
```

References: [`State`](#type-state), [`LoadOptions`](#type-loadoptions), [`Function`](#type-function)

<a id="fn-state-loadbytecode"></a>

### State.loadBytecode

Loads a zlua bytecode dump and returns a rooted function handle.

```zig
pub fn loadBytecode(self: *State, bytecode: []const u8, options: BytecodeLoadOptions) !Function
```

References: [`State`](#type-state), [`BytecodeLoadOptions`](#type-bytecodeloadoptions), [`Function`](#type-function)

<a id="fn-state-dostring"></a>

### State.doString

Loads and immediately executes source text or bytecode from memory.

```zig
pub fn doString(self: *State, source: []const u8, options: DoOptions) !void
```

References: [`State`](#type-state), [`DoOptions`](#alias-dooptions)

<a id="fn-state-dofile"></a>

### State.doFile

Loads and immediately executes a chunk from the configured filesystem.

```zig
pub fn doFile(self: *State, path: []const u8, options: DoOptions) !void
```

References: [`State`](#type-state), [`DoOptions`](#alias-dooptions)

<a id="fn-state-errormessage"></a>

### State.errorMessage

Formats the last Lua error value as an allocated message.

The caller owns the returned slice and must free it with `allocator()`.

```zig
pub fn errorMessage(self: *State) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-takeerrorvalue"></a>

### State.takeErrorValue

Takes ownership of the last captured Lua error value, if one exists.

The returned `ErrorRef` must be deinitialized by the host.

```zig
pub fn takeErrorValue(self: *State) ?ErrorRef
```

References: [`State`](#type-state), [`ErrorRef`](#type-errorref)

<a id="type-ref"></a>

## Ref

Rooted handle to any Lua value.

```zig
pub const Ref = struct {
    state: *State,
    index: usize,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-ref-deinit) | `self: *Ref` | `void` | Releases this handle's root. |
| [value](#fn-ref-value) | `self: Ref` | `!Value` | Returns the referenced value as a high-level &#96;Value&#96;. |

<a id="fn-ref-deinit"></a>

### Ref.deinit

Releases this handle's root.

```zig
pub fn deinit(self: *Ref) void
```

References: [`Ref`](#type-ref)

<a id="fn-ref-value"></a>

### Ref.value

Returns the referenced value as a high-level `Value`.

```zig
pub fn value(self: Ref) !Value
```

References: [`Ref`](#type-ref), [`Value`](#type-value)

<a id="type-table"></a>

## Table

Rooted handle to a Lua table.

```zig
pub const Table = struct {
    ref: Ref,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-table-deinit) | `self: *Table` | `void` | Releases this table handle's root. |
| [get](#fn-table-get) | `self: Table, key: anytype, comptime T: type` | `!T` | Reads &#96;key&#96; from the table and converts the result to &#96;T&#96;. |
| [set](#fn-table-set) | `self: Table, key: anytype, value: anytype` | `!void` | Converts and assigns &#96;value&#96; at &#96;key&#96; in the table. |

<a id="fn-table-deinit"></a>

### Table.deinit

Releases this table handle's root.

```zig
pub fn deinit(self: *Table) void
```

References: [`Table`](#type-table)

<a id="fn-table-get"></a>

### Table.get

Reads `key` from the table and converts the result to `T`.

```zig
pub fn get(self: Table, key: anytype, comptime T: type) !T
```

References: [`Table`](#type-table)

<a id="fn-table-set"></a>

### Table.set

Converts and assigns `value` at `key` in the table.

```zig
pub fn set(self: Table, key: anytype, value: anytype) !void
```

References: [`Table`](#type-table)

<a id="type-function"></a>

## Function

Rooted handle to a Lua function or loaded chunk.

```zig
pub const Function = struct {
    ref: Ref,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-function-deinit) | `self: *Function` | `void` | Releases this function handle's root. |
| [call](#fn-function-call) | `self: Function, args: anytype, comptime R: type` | `!R` | Calls the function with tuple arguments and converts the first or tuple result to &#96;R&#96;. |
| [protectedCall](#fn-function-protectedcall) | `self: Function, args: anytype, comptime R: type` | `!CallResult(R)` | Calls the function and returns Lua failures as an &#96;ErrorRef&#96; instead of &#96;error.LuaError&#96;. |
| [dumpBytecode](#fn-function-dumpbytecode) | `self: Function, options: BytecodeDumpOptions` | `![]const u8` | Dumps this function to zlua bytecode. |

<a id="fn-function-deinit"></a>

### Function.deinit

Releases this function handle's root.

```zig
pub fn deinit(self: *Function) void
```

References: [`Function`](#type-function)

<a id="fn-function-call"></a>

### Function.call

Calls the function with tuple arguments and converts the first or tuple result to `R`.

Lua failures are returned as `error.LuaError` and captured on the state.

```zig
pub fn call(self: Function, args: anytype, comptime R: type) !R
```

References: [`Function`](#type-function)

<a id="fn-function-protectedcall"></a>

### Function.protectedCall

Calls the function and returns Lua failures as an `ErrorRef` instead of `error.LuaError`.

```zig
pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R)
```

References: [`Function`](#type-function)

<a id="fn-function-dumpbytecode"></a>

### Function.dumpBytecode

Dumps this function to zlua bytecode.

The caller owns the returned slice and must free it with the state's allocator.

```zig
pub fn dumpBytecode(self: Function, options: BytecodeDumpOptions) ![]const u8
```

References: [`Function`](#type-function), [`BytecodeDumpOptions`](#type-bytecodedumpoptions)

<a id="fn-userdata"></a>

## Userdata

Returns the typed userdata handle type for `T`.

```zig
pub fn Userdata(comptime T: type) type
```

<a id="type-anyuserdata"></a>

## AnyUserdata

Rooted handle to userdata when the host does not know its Zig payload type.

```zig
pub const AnyUserdata = struct {
    ref: Ref,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-anyuserdata-deinit) | `self: *AnyUserdata` | `void` | Releases this userdata handle's root. |

<a id="fn-anyuserdata-deinit"></a>

### AnyUserdata.deinit

Releases this userdata handle's root.

```zig
pub fn deinit(self: *AnyUserdata) void
```

References: [`AnyUserdata`](#type-anyuserdata)

<a id="fn-callresult"></a>

## CallResult

Result type returned by `Function.protectedCall`.

```zig
pub fn CallResult(comptime R: type) type
```

<a id="type-errorref"></a>

## ErrorRef

Rooted handle to a Lua error value.

```zig
pub const ErrorRef = struct {
    ref: Ref,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-errorref-deinit) | `self: *ErrorRef` | `void` | Releases this error handle's root. |
| [value](#fn-errorref-value) | `self: ErrorRef` | `!Value` | Returns the raw Lua error value as a high-level &#96;Value&#96;. |
| [message](#fn-errorref-message) | `self: ErrorRef` | `![]const u8` | Formats the Lua error value as an allocated message. |

<a id="fn-errorref-deinit"></a>

### ErrorRef.deinit

Releases this error handle's root.

```zig
pub fn deinit(self: *ErrorRef) void
```

References: [`ErrorRef`](#type-errorref)

<a id="fn-errorref-value"></a>

### ErrorRef.value

Returns the raw Lua error value as a high-level `Value`.

```zig
pub fn value(self: ErrorRef) !Value
```

References: [`ErrorRef`](#type-errorref), [`Value`](#type-value)

<a id="fn-errorref-message"></a>

### ErrorRef.message

Formats the Lua error value as an allocated message.

The caller owns the returned slice and must free it with the state's allocator.

```zig
pub fn message(self: ErrorRef) ![]const u8
```

References: [`ErrorRef`](#type-errorref)

<a id="type-value"></a>

## Value

High-level Lua value union used for dynamic conversion and inspection.

```zig
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
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-value-deinit) | `self: *Value` | `void` | Releases any rooted handle contained by this value. |

<a id="fn-value-deinit"></a>

### Value.deinit

Releases any rooted handle contained by this value.

```zig
pub fn deinit(self: *Value) void
```

References: [`Value`](#type-value)

<a id="fn-tuple"></a>

## Tuple

Returns a result container for multiple Lua return values.

```zig
pub fn Tuple(comptime types: []const type) type
```

<a id="type-context"></a>

## Context

Host-callback context passed to functions registered with `State.register`.

```zig
pub const Context = struct {
    lua: *State,
    raw: *runtime.ApiCallbackContext,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [state](#fn-context-state) | `self: *Context` | `*State` | Returns the owning Lua state. |
| [argCount](#fn-context-argcount) | `self: *Context` | `usize` | Returns the number of Lua arguments passed to the callback. |
| [arg](#fn-context-arg) | `self: *Context, index: usize, comptime T: type` | `!T` | Reads required argument &#96;index&#96; and converts it to &#96;T&#96;. |
| [optionalArg](#fn-context-optionalarg) | `self: *Context, index: usize, comptime T: type` | `!?T` | Reads optional argument &#96;index&#96;, returning null when absent or Lua &#96;nil&#96;. |
| [pushReturn](#fn-context-pushreturn) | `self: *Context, value: anytype` | `!void` | Appends one converted Lua return value for the current callback. |
| [returnValues](#fn-context-returnvalues) | `self: *Context, values: anytype` | `!void` | Replaces callback returns with &#96;values&#96;. |
| [raise](#fn-context-raise) | `self: *Context, value: anytype` | `error` | Raises a Lua error using &#96;value&#96; as the error object. |

<a id="fn-context-state"></a>

### Context.state

Returns the owning Lua state.

```zig
pub fn state(self: *Context) *State
```

References: [`Context`](#type-context), [`State`](#type-state)

<a id="fn-context-argcount"></a>

### Context.argCount

Returns the number of Lua arguments passed to the callback.

```zig
pub fn argCount(self: *Context) usize
```

References: [`Context`](#type-context)

<a id="fn-context-arg"></a>

### Context.arg

Reads required argument `index` and converts it to `T`.

```zig
pub fn arg(self: *Context, index: usize, comptime T: type) !T
```

References: [`Context`](#type-context)

<a id="fn-context-optionalarg"></a>

### Context.optionalArg

Reads optional argument `index`, returning null when absent or Lua `nil`.

```zig
pub fn optionalArg(self: *Context, index: usize, comptime T: type) !?T
```

References: [`Context`](#type-context)

<a id="fn-context-pushreturn"></a>

### Context.pushReturn

Appends one converted Lua return value for the current callback.

```zig
pub fn pushReturn(self: *Context, value: anytype) !void
```

References: [`Context`](#type-context)

<a id="fn-context-returnvalues"></a>

### Context.returnValues

Replaces callback returns with `values`.

Tuple structs such as `.{ a, b }` return multiple Lua values.

```zig
pub fn returnValues(self: *Context, values: anytype) !void
```

References: [`Context`](#type-context)

<a id="fn-context-raise"></a>

### Context.raise

Raises a Lua error using `value` as the error object.

```zig
pub fn raise(self: *Context, value: anytype) error{ LuaError, OutOfMemory }
```

References: [`Context`](#type-context)

<a id="type-thread"></a>

## Thread

Opaque placeholder for future high-level coroutine/thread handles.

```zig
pub const Thread = opaque {};
```

