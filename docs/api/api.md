# api

## Navigation

- [API Index](README.md)
- Previous: [errors](errors.md)
- Next: [runtime](runtime.md)

## Functions

- [UserdataOptions](#fn-userdataoptions)
- [UserdataPtrOptions](#fn-userdataptroptions)
- [Userdata](#fn-userdata)
- [CallResult](#fn-callresult)
- [Tuple](#fn-tuple)

## Types

- [Stdlib](#type-stdlib)
- [IoCapability](#type-iocapability)
- [EnvironmentCapability](#type-environmentcapability)
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

- [Error](#const-error)
- [UnsupportedOption](#const-unsupportedoption)
- [ConversionError](#const-conversionerror)
- [HostFn](#const-hostfn)

## Aliases

- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)
- [FilesystemCapability](#alias-filesystemcapability)
- [ClockCapability](#alias-clockcapability)
- [ProcessCapability](#alias-processcapability)
- [DoOptions](#alias-dooptions)

<a id="const-error"></a>

## Error

```zig
pub const Error = error{LuaError};
```

<a id="const-unsupportedoption"></a>

## UnsupportedOption

```zig
pub const UnsupportedOption = error{UnsupportedOption};
```

<a id="const-conversionerror"></a>

## ConversionError

```zig
pub const ConversionError =...;
```

<a id="fn-userdataoptions"></a>

## UserdataOptions

```zig
pub fn UserdataOptions(comptime T: type) type
```

<a id="fn-userdataptroptions"></a>

## UserdataPtrOptions

```zig
pub fn UserdataPtrOptions(comptime T: type) type
```

<a id="type-stdlib"></a>

## Stdlib

```zig
pub const Stdlib = enum { ... };
```

<a id="alias-memoryfile"></a>

## MemoryFile

```zig
pub const MemoryFile = runtime.MemoryFile;
```

References: [`runtime.MemoryFile`](runtime.md#alias-memoryfile)

<a id="alias-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = runtime.MemoryFilesystem;
```

References: [`runtime.MemoryFilesystem`](runtime.md#alias-memoryfilesystem)

<a id="type-iocapability"></a>

## IoCapability

```zig
pub const IoCapability = struct { ... };
```

### Fields

- `runtime: ?std.Io = null`
- `stdin: []const u8 = ""`
- `stdout: ?*std.Io.Writer = null`
- `stderr: ?*std.Io.Writer = null`

### Nested Declarations

- [disabled](#const-iocapability-disabled)

<a id="const-iocapability-disabled"></a>

### IoCapability.disabled

```zig
pub const disabled: IoCapability = .{};
```

References: [`IoCapability`](#type-iocapability)

<a id="alias-filesystemcapability"></a>

## FilesystemCapability

```zig
pub const FilesystemCapability = runtime.FilesystemCapability;
```

References: [`runtime.FilesystemCapability`](runtime.md#alias-filesystemcapability)

<a id="type-environmentcapability"></a>

## EnvironmentCapability

```zig
pub const EnvironmentCapability = union(enum) { ... };
```

### Fields

- `map: *const std.process.Environ.Map`

<a id="alias-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = runtime.ClockCapability;
```

References: [`runtime.ClockCapability`](runtime.md#alias-clockcapability)

<a id="alias-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = runtime.ProcessCapability;
```

References: [`runtime.ProcessCapability`](runtime.md#alias-processcapability)

<a id="type-capabilities"></a>

## Capabilities

```zig
pub const Capabilities = struct { ... };
```

### Fields

- `io: IoCapability = .disabled`
- `filesystem: FilesystemCapability = .disabled`
- `environment: EnvironmentCapability = .disabled`
- `clock: ClockCapability = .disabled`
- `process: ProcessCapability = .disabled`

### Nested Declarations

- [sandboxed](#const-capabilities-sandboxed)

<a id="const-capabilities-sandboxed"></a>

### Capabilities.sandboxed

```zig
pub const sandboxed: Capabilities = .{};
```

References: [`Capabilities`](#type-capabilities)

<a id="type-limits"></a>

## Limits

```zig
pub const Limits = struct { ... };
```

### Fields

- `max_memory: ?usize = null`
- `max_stack_values: ?usize = null`
- `max_call_frames: ?usize = null`
- `max_instructions: ?u64 = null`

<a id="type-instructionbudget"></a>

## InstructionBudget

```zig
pub const InstructionBudget = struct { ... };
```

### Fields

- `limit: ?u64`
- `used: u64`
- `remaining: ?u64`

<a id="type-gcoptions"></a>

## GcOptions

```zig
pub const GcOptions = struct { ... };
```

<a id="type-debugoptions"></a>

## DebugOptions

```zig
pub const DebugOptions = struct { ... };
```

### Fields

- `errors: bool = false`
- `trace_vm: bool = false`

<a id="type-options"></a>

## Options

```zig
pub const Options = struct { ... };
```

### Fields

- `stdlib: Stdlib = .safe`
- `capabilities: Capabilities = .sandboxed`
- `limits: Limits = .{}`
- `gc: GcOptions = .{}`
- `debug: DebugOptions = .{}`

<a id="type-loadmode"></a>

## LoadMode

```zig
pub const LoadMode = enum { ... };
```

<a id="type-loadoptions"></a>

## LoadOptions

```zig
pub const LoadOptions = struct { ... };
```

### Fields

- `name: ?[]const u8 = null`
- `environment: ?Table = null`
- `mode: LoadMode = .source_only`

<a id="alias-dooptions"></a>

## DoOptions

```zig
pub const DoOptions = LoadOptions;
```

References: [`LoadOptions`](#type-loadoptions)

<a id="type-bytecodeloadoptions"></a>

## BytecodeLoadOptions

```zig
pub const BytecodeLoadOptions = struct { ... };
```

### Fields

- `environment: ?Table = null`

<a id="type-bytecodedumpoptions"></a>

## BytecodeDumpOptions

```zig
pub const BytecodeDumpOptions = struct { ... };
```

### Fields

- `strip_debug: bool = false`

<a id="type-tableoptions"></a>

## TableOptions

```zig
pub const TableOptions = struct { ... };
```

### Fields

- `array_hint: u32 = 0`
- `hash_hint: u32 = 0`

<a id="const-hostfn"></a>

## HostFn

```zig
pub const HostFn = *const fn (ctx: *Context) anyerror!void;
```

References: [`Context`](#type-context)

<a id="type-gcbudget"></a>

## GcBudget

```zig
pub const GcBudget = struct { ... };
```

### Fields

- `steps: usize = 0`

<a id="type-gcstepresult"></a>

## GcStepResult

```zig
pub const GcStepResult = enum { ... };
```

<a id="type-state"></a>

## State

```zig
pub const State = struct { ... };
```

### Fields

- `base_allocator: std.mem.Allocator`
- `memory_limit_allocator: ?*MemoryLimitAllocator = null`
- `raw_state: runtime.State`
- `last_error_root: ?usize = null`
- `memory_files: std.ArrayList(MemoryFile) = .empty`
- `memory_file_owned_contents: std.ArrayList(bool) = .empty`
- `callbacks: std.ArrayList(RegisteredCallback) = .empty`

### Nested Declarations

- [init](#fn-state-init)
- [deinit](#fn-state-deinit)
- [allocator](#fn-state-allocator)
- [instructionBudget](#fn-state-instructionbudget)
- [resetInstructionBudget](#fn-state-resetinstructionbudget)
- [openLibs](#fn-state-openlibs)
- [collect](#fn-state-collect)
- [stepGc](#fn-state-stepgc)
- [push](#fn-state-push)
- [read](#fn-state-read)
- [setGlobal](#fn-state-setglobal)
- [getGlobal](#fn-state-getglobal)
- [register](#fn-state-register)
- [registerTyped](#fn-state-registertyped)
- [createTable](#fn-state-createtable)
- [newUserdata](#fn-state-newuserdata)
- [newUserdataPtr](#fn-state-newuserdataptr)
- [createModule](#fn-state-createmodule)
- [preloadModule](#fn-state-preloadmodule)
- [setPackagePath](#fn-state-setpackagepath)
- [addMemoryFile](#fn-state-addmemoryfile)
- [loadString](#fn-state-loadstring)
- [loadFile](#fn-state-loadfile)
- [loadBytecode](#fn-state-loadbytecode)
- [doString](#fn-state-dostring)
- [doFile](#fn-state-dofile)
- [errorMessage](#fn-state-errormessage)
- [takeErrorValue](#fn-state-takeerrorvalue)

<a id="fn-state-init"></a>

### State.init

```zig
pub fn init(state_allocator: std.mem.Allocator, options: Options) !State
```

References: [`Options`](#type-options), [`State`](#type-state)

<a id="fn-state-deinit"></a>

### State.deinit

```zig
pub fn deinit(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-allocator"></a>

### State.allocator

```zig
pub fn allocator(self: *State) std.mem.Allocator
```

References: [`State`](#type-state)

<a id="fn-state-instructionbudget"></a>

### State.instructionBudget

```zig
pub fn instructionBudget(self: *const State) InstructionBudget
```

References: [`State`](#type-state), [`InstructionBudget`](#type-instructionbudget)

<a id="fn-state-resetinstructionbudget"></a>

### State.resetInstructionBudget

```zig
pub fn resetInstructionBudget(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-openlibs"></a>

### State.openLibs

```zig
pub fn openLibs(self: *State, mode: Stdlib) !void
```

References: [`State`](#type-state), [`Stdlib`](#type-stdlib)

<a id="fn-state-collect"></a>

### State.collect

```zig
pub fn collect(self: *State) !void
```

References: [`State`](#type-state)

<a id="fn-state-stepgc"></a>

### State.stepGc

```zig
pub fn stepGc(self: *State, budget: GcBudget) !GcStepResult
```

References: [`State`](#type-state), [`GcBudget`](#type-gcbudget), [`GcStepResult`](#type-gcstepresult)

<a id="fn-state-push"></a>

### State.push

```zig
pub fn push(self: *State, value: anytype) !Value
```

References: [`State`](#type-state), [`Value`](#type-value)

<a id="fn-state-read"></a>

### State.read

```zig
pub fn read(self: *State, value: Value, comptime T: type) !T
```

References: [`State`](#type-state), [`Value`](#type-value)

<a id="fn-state-setglobal"></a>

### State.setGlobal

```zig
pub fn setGlobal(self: *State, name: []const u8, value: anytype) !void
```

References: [`State`](#type-state)

<a id="fn-state-getglobal"></a>

### State.getGlobal

```zig
pub fn getGlobal(self: *State, name: []const u8, comptime T: type) !T
```

References: [`State`](#type-state)

<a id="fn-state-register"></a>

### State.register

```zig
pub fn register(self: *State, name: []const u8, callback: HostFn) !Function
```

References: [`State`](#type-state), [`HostFn`](#const-hostfn), [`Function`](#type-function)

<a id="fn-state-registertyped"></a>

### State.registerTyped

```zig
pub fn registerTyped(self: *State, name: []const u8, comptime function: anytype) !Function
```

References: [`State`](#type-state), [`Function`](#type-function)

<a id="fn-state-createtable"></a>

### State.createTable

```zig
pub fn createTable(self: *State, options: TableOptions) !Table
```

References: [`State`](#type-state), [`TableOptions`](#type-tableoptions), [`Table`](#type-table)

<a id="fn-state-newuserdata"></a>

### State.newUserdata

```zig
pub fn newUserdata(self: *State, comptime T: type, value: T, options: UserdataOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-newuserdataptr"></a>

### State.newUserdataPtr

```zig
pub fn newUserdataPtr(self: *State, comptime T: type, ptr: *T, options: UserdataPtrOptions(T)) !Userdata(T)
```

References: [`State`](#type-state)

<a id="fn-state-createmodule"></a>

### State.createModule

```zig
pub fn createModule(self: *State, name: []const u8) !Table
```

References: [`State`](#type-state), [`Table`](#type-table)

<a id="fn-state-preloadmodule"></a>

### State.preloadModule

```zig
pub fn preloadModule(self: *State, name: []const u8, module: Table) !void
```

References: [`State`](#type-state), [`Table`](#type-table)

<a id="fn-state-setpackagepath"></a>

### State.setPackagePath

```zig
pub fn setPackagePath(self: *State, path: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-addmemoryfile"></a>

### State.addMemoryFile

```zig
pub fn addMemoryFile(self: *State, path: []const u8, contents: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-loadstring"></a>

### State.loadString

```zig
pub fn loadString(self: *State, source: []const u8, options: LoadOptions) !Function
```

References: [`State`](#type-state), [`LoadOptions`](#type-loadoptions), [`Function`](#type-function)

<a id="fn-state-loadfile"></a>

### State.loadFile

```zig
pub fn loadFile(self: *State, path: []const u8, options: LoadOptions) !Function
```

References: [`State`](#type-state), [`LoadOptions`](#type-loadoptions), [`Function`](#type-function)

<a id="fn-state-loadbytecode"></a>

### State.loadBytecode

```zig
pub fn loadBytecode(self: *State, bytecode: []const u8, options: BytecodeLoadOptions) !Function
```

References: [`State`](#type-state), [`BytecodeLoadOptions`](#type-bytecodeloadoptions), [`Function`](#type-function)

<a id="fn-state-dostring"></a>

### State.doString

```zig
pub fn doString(self: *State, source: []const u8, options: DoOptions) !void
```

References: [`State`](#type-state), [`DoOptions`](#alias-dooptions)

<a id="fn-state-dofile"></a>

### State.doFile

```zig
pub fn doFile(self: *State, path: []const u8, options: DoOptions) !void
```

References: [`State`](#type-state), [`DoOptions`](#alias-dooptions)

<a id="fn-state-errormessage"></a>

### State.errorMessage

```zig
pub fn errorMessage(self: *State) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-takeerrorvalue"></a>

### State.takeErrorValue

```zig
pub fn takeErrorValue(self: *State) ?ErrorRef
```

References: [`State`](#type-state), [`ErrorRef`](#type-errorref)

<a id="type-ref"></a>

## Ref

```zig
pub const Ref = struct { ... };
```

### Fields

- `state: *State`
- `index: usize`

### Nested Declarations

- [deinit](#fn-ref-deinit)
- [value](#fn-ref-value)

<a id="fn-ref-deinit"></a>

### Ref.deinit

```zig
pub fn deinit(self: *Ref) void
```

References: [`Ref`](#type-ref)

<a id="fn-ref-value"></a>

### Ref.value

```zig
pub fn value(self: Ref) !Value
```

References: [`Ref`](#type-ref), [`Value`](#type-value)

<a id="type-table"></a>

## Table

```zig
pub const Table = struct { ... };
```

### Fields

- `ref: Ref`

### Nested Declarations

- [deinit](#fn-table-deinit)
- [get](#fn-table-get)
- [set](#fn-table-set)

<a id="fn-table-deinit"></a>

### Table.deinit

```zig
pub fn deinit(self: *Table) void
```

References: [`Table`](#type-table)

<a id="fn-table-get"></a>

### Table.get

```zig
pub fn get(self: Table, key: anytype, comptime T: type) !T
```

References: [`Table`](#type-table)

<a id="fn-table-set"></a>

### Table.set

```zig
pub fn set(self: Table, key: anytype, value: anytype) !void
```

References: [`Table`](#type-table)

<a id="type-function"></a>

## Function

```zig
pub const Function = struct { ... };
```

### Fields

- `ref: Ref`

### Nested Declarations

- [deinit](#fn-function-deinit)
- [call](#fn-function-call)
- [protectedCall](#fn-function-protectedcall)
- [dumpBytecode](#fn-function-dumpbytecode)

<a id="fn-function-deinit"></a>

### Function.deinit

```zig
pub fn deinit(self: *Function) void
```

References: [`Function`](#type-function)

<a id="fn-function-call"></a>

### Function.call

```zig
pub fn call(self: Function, args: anytype, comptime R: type) !R
```

References: [`Function`](#type-function)

<a id="fn-function-protectedcall"></a>

### Function.protectedCall

```zig
pub fn protectedCall(self: Function, args: anytype, comptime R: type) !CallResult(R)
```

References: [`Function`](#type-function)

<a id="fn-function-dumpbytecode"></a>

### Function.dumpBytecode

```zig
pub fn dumpBytecode(self: Function, options: BytecodeDumpOptions) ![]const u8
```

References: [`Function`](#type-function), [`BytecodeDumpOptions`](#type-bytecodedumpoptions)

<a id="fn-userdata"></a>

## Userdata

```zig
pub fn Userdata(comptime T: type) type
```

<a id="type-anyuserdata"></a>

## AnyUserdata

```zig
pub const AnyUserdata = struct { ... };
```

### Fields

- `ref: Ref`

### Nested Declarations

- [deinit](#fn-anyuserdata-deinit)

<a id="fn-anyuserdata-deinit"></a>

### AnyUserdata.deinit

```zig
pub fn deinit(self: *AnyUserdata) void
```

References: [`AnyUserdata`](#type-anyuserdata)

<a id="fn-callresult"></a>

## CallResult

```zig
pub fn CallResult(comptime R: type) type
```

<a id="type-errorref"></a>

## ErrorRef

```zig
pub const ErrorRef = struct { ... };
```

### Fields

- `ref: Ref`

### Nested Declarations

- [deinit](#fn-errorref-deinit)
- [value](#fn-errorref-value)
- [message](#fn-errorref-message)

<a id="fn-errorref-deinit"></a>

### ErrorRef.deinit

```zig
pub fn deinit(self: *ErrorRef) void
```

References: [`ErrorRef`](#type-errorref)

<a id="fn-errorref-value"></a>

### ErrorRef.value

```zig
pub fn value(self: ErrorRef) !Value
```

References: [`ErrorRef`](#type-errorref), [`Value`](#type-value)

<a id="fn-errorref-message"></a>

### ErrorRef.message

```zig
pub fn message(self: ErrorRef) ![]const u8
```

References: [`ErrorRef`](#type-errorref)

<a id="type-value"></a>

## Value

```zig
pub const Value = union(enum) { ... };
```

### Fields

- `boolean: bool`
- `integer: i64`
- `number: f64`
- `string: []const u8`
- `table: Table`
- `function: Function`
- `userdata: AnyUserdata`

### Nested Declarations

- [deinit](#fn-value-deinit)

<a id="fn-value-deinit"></a>

### Value.deinit

```zig
pub fn deinit(self: *Value) void
```

References: [`Value`](#type-value)

<a id="fn-tuple"></a>

## Tuple

```zig
pub fn Tuple(comptime types: []const type) type
```

<a id="type-context"></a>

## Context

```zig
pub const Context = struct { ... };
```

### Fields

- `lua: *State`
- `raw: *runtime.ApiCallbackContext`

### Nested Declarations

- [state](#fn-context-state)
- [argCount](#fn-context-argcount)
- [arg](#fn-context-arg)
- [optionalArg](#fn-context-optionalarg)
- [pushReturn](#fn-context-pushreturn)
- [returnValues](#fn-context-returnvalues)
- [raise](#fn-context-raise)

<a id="fn-context-state"></a>

### Context.state

```zig
pub fn state(self: *Context) *State
```

References: [`Context`](#type-context), [`State`](#type-state)

<a id="fn-context-argcount"></a>

### Context.argCount

```zig
pub fn argCount(self: *Context) usize
```

References: [`Context`](#type-context)

<a id="fn-context-arg"></a>

### Context.arg

```zig
pub fn arg(self: *Context, index: usize, comptime T: type) !T
```

References: [`Context`](#type-context)

<a id="fn-context-optionalarg"></a>

### Context.optionalArg

```zig
pub fn optionalArg(self: *Context, index: usize, comptime T: type) !?T
```

References: [`Context`](#type-context)

<a id="fn-context-pushreturn"></a>

### Context.pushReturn

```zig
pub fn pushReturn(self: *Context, value: anytype) !void
```

References: [`Context`](#type-context)

<a id="fn-context-returnvalues"></a>

### Context.returnValues

```zig
pub fn returnValues(self: *Context, values: anytype) !void
```

References: [`Context`](#type-context)

<a id="fn-context-raise"></a>

### Context.raise

```zig
pub fn raise(self: *Context, value: anytype) error{ LuaError, OutOfMemory }
```

References: [`Context`](#type-context)

<a id="type-thread"></a>

## Thread

```zig
pub const Thread = opaque { ... };
```

