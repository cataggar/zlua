# runtime

## Navigation

- [API Index](README.md)
- Previous: [api](api.md)
- Next: [runtime.chunk](runtime/chunk.md)
- Submodules: [runtime.chunk](runtime/chunk.md), [runtime.types](runtime/types.md), [runtime.value](runtime/value.md), [runtime.execute](runtime/execute.md), [runtime.state](runtime/state.md), [runtime.call](runtime/call.md), [runtime.coroutine](runtime/coroutine.md), [runtime.debug](runtime/debug.md), [runtime.gc](runtime/gc.md), [runtime.host](runtime/host.md), [runtime.vm](runtime/vm.md), [runtime.tests](runtime/tests.md), [runtime.internal](runtime/internal.md)

## Aliases

- [RuntimeError](#alias-runtimeerror)
- [binary_chunk_signature](#alias-binary_chunk_signature)
- [binary_chunk_payload_magic](#alias-binary_chunk_payload_magic)
- [State](#alias-state)
- [StateOptions](#alias-stateoptions)
- [Value](#alias-value)
- [NativeFn](#alias-nativefn)
- [UserdataFinalizer](#alias-userdatafinalizer)
- [UserdataDeinit](#alias-userdatadeinit)
- [ProtectedCallResult](#alias-protectedcallresult)
- [ApiCallbackDispatchFn](#alias-apicallbackdispatchfn)
- [CClosureDispatchFn](#alias-cclosuredispatchfn)
- [CClosureResumeDispatchFn](#alias-cclosureresumedispatchfn)
- [CDebugHookDispatchFn](#alias-cdebughookdispatchfn)
- [DebugHookEvent](#alias-debughookevent)
- [CDebugHookContext](#alias-cdebughookcontext)
- [CClosureContext](#alias-cclosurecontext)
- [CClosureResumeContext](#alias-cclosureresumecontext)
- [ApiCallbackContext](#alias-apicallbackcontext)
- [RuntimeErrorPayload](#alias-runtimeerrorpayload)
- [appendBinaryChunkHeader](#alias-appendbinarychunkheader)
- [dumpClosureBinary](#alias-dumpclosurebinary)
- [Closure](#alias-closure)
- [CClosure](#alias-cclosure)
- [CUpvalue](#alias-cupvalue)
- [Upvalue](#alias-upvalue)
- [Table](#alias-table)
- [Userdata](#alias-userdata)
- [Thread](#alias-thread)
- [GcMode](#alias-gcmode)
- [GcParam](#alias-gcparam)
- [StdlibMode](#alias-stdlibmode)
- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)
- [FilesystemCapability](#alias-filesystemcapability)
- [ClockCapability](#alias-clockcapability)
- [ProcessCapability](#alias-processcapability)
- [CompareOp](#alias-compareop)
- [valuesEqual](#alias-valuesequal)
- [truthy](#alias-truthy)
- [toInteger](#alias-tointeger)
- [toNumber](#alias-tonumber)
- [appendLuaString](#alias-appendluastring)
- [localActiveAt](#alias-localactiveat)
- [parseIntegerStrict](#alias-parseintegerstrict)
- [parseLuaNumber](#alias-parseluanumber)
- [floatToInteger](#alias-floattointeger)
- [trimAscii](#alias-trimascii)
- [runtimeArgValue](#alias-runtimeargvalue)
- [argValue](#alias-argvalue)
- [appendValue](#alias-appendvalue)
- [isFileValue](#alias-isfilevalue)
- [isClosedFileValue](#alias-isclosedfilevalue)
- [appendNumber](#alias-appendnumber)
- [appendFmt](#alias-appendfmt)
- [ExecuteOptions](#alias-executeoptions)
- [executeSource](#alias-executesource)
- [executeSourceWithOptions](#alias-executesourcewithoptions)

<a id="alias-runtimeerror"></a>

## RuntimeError

```zig
pub const RuntimeError = types.RuntimeError;
```

References: [`types.RuntimeError`](runtime/types.md#const-runtimeerror)

<a id="alias-binary_chunk_signature"></a>

## binary_chunk_signature

```zig
pub const binary_chunk_signature = chunk_mod.binary_chunk_signature;
```

<a id="alias-binary_chunk_payload_magic"></a>

## binary_chunk_payload_magic

```zig
pub const binary_chunk_payload_magic = chunk_mod.binary_chunk_payload_magic;
```

<a id="alias-state"></a>

## State

```zig
pub const State = state_mod.State;
```

<a id="alias-stateoptions"></a>

## StateOptions

```zig
pub const StateOptions = state_mod.StateOptions;
```

<a id="alias-value"></a>

## Value

```zig
pub const Value = types.Value;
```

References: [`types.Value`](runtime/types.md#type-value)

<a id="alias-nativefn"></a>

## NativeFn

```zig
pub const NativeFn = types.NativeFn;
```

References: [`types.NativeFn`](runtime/types.md#type-nativefn)

<a id="alias-userdatafinalizer"></a>

## UserdataFinalizer

```zig
pub const UserdataFinalizer = types.UserdataFinalizer;
```

References: [`types.UserdataFinalizer`](runtime/types.md#const-userdatafinalizer)

<a id="alias-userdatadeinit"></a>

## UserdataDeinit

```zig
pub const UserdataDeinit = types.UserdataDeinit;
```

References: [`types.UserdataDeinit`](runtime/types.md#const-userdatadeinit)

<a id="alias-protectedcallresult"></a>

## ProtectedCallResult

```zig
pub const ProtectedCallResult = types.ProtectedCallResult;
```

References: [`types.ProtectedCallResult`](runtime/types.md#type-protectedcallresult)

<a id="alias-apicallbackdispatchfn"></a>

## ApiCallbackDispatchFn

```zig
pub const ApiCallbackDispatchFn = types.ApiCallbackDispatchFn;
```

References: [`types.ApiCallbackDispatchFn`](runtime/types.md#const-apicallbackdispatchfn)

<a id="alias-cclosuredispatchfn"></a>

## CClosureDispatchFn

```zig
pub const CClosureDispatchFn = types.CClosureDispatchFn;
```

References: [`types.CClosureDispatchFn`](runtime/types.md#const-cclosuredispatchfn)

<a id="alias-cclosureresumedispatchfn"></a>

## CClosureResumeDispatchFn

```zig
pub const CClosureResumeDispatchFn = types.CClosureResumeDispatchFn;
```

References: [`types.CClosureResumeDispatchFn`](runtime/types.md#const-cclosureresumedispatchfn)

<a id="alias-cdebughookdispatchfn"></a>

## CDebugHookDispatchFn

```zig
pub const CDebugHookDispatchFn = types.CDebugHookDispatchFn;
```

References: [`types.CDebugHookDispatchFn`](runtime/types.md#const-cdebughookdispatchfn)

<a id="alias-debughookevent"></a>

## DebugHookEvent

```zig
pub const DebugHookEvent = types.DebugHookEvent;
```

References: [`types.DebugHookEvent`](runtime/types.md#type-debughookevent)

<a id="alias-cdebughookcontext"></a>

## CDebugHookContext

```zig
pub const CDebugHookContext = types.CDebugHookContext;
```

References: [`types.CDebugHookContext`](runtime/types.md#type-cdebughookcontext)

<a id="alias-cclosurecontext"></a>

## CClosureContext

```zig
pub const CClosureContext = types.CClosureContext;
```

References: [`types.CClosureContext`](runtime/types.md#type-cclosurecontext)

<a id="alias-cclosureresumecontext"></a>

## CClosureResumeContext

```zig
pub const CClosureResumeContext = types.CClosureResumeContext;
```

References: [`types.CClosureResumeContext`](runtime/types.md#type-cclosureresumecontext)

<a id="alias-apicallbackcontext"></a>

## ApiCallbackContext

```zig
pub const ApiCallbackContext = types.ApiCallbackContext;
```

References: [`types.ApiCallbackContext`](runtime/types.md#type-apicallbackcontext)

<a id="alias-runtimeerrorpayload"></a>

## RuntimeErrorPayload

```zig
pub const RuntimeErrorPayload = types.RuntimeErrorPayload;
```

References: [`types.RuntimeErrorPayload`](runtime/types.md#type-runtimeerrorpayload)

<a id="alias-appendbinarychunkheader"></a>

## appendBinaryChunkHeader

```zig
pub const appendBinaryChunkHeader = chunk_mod.appendBinaryChunkHeader;
```

<a id="alias-dumpclosurebinary"></a>

## dumpClosureBinary

```zig
pub const dumpClosureBinary = chunk_mod.dumpClosureBinary;
```

<a id="alias-closure"></a>

## Closure

```zig
pub const Closure = types.Closure;
```

References: [`types.Closure`](runtime/types.md#type-closure)

<a id="alias-cclosure"></a>

## CClosure

```zig
pub const CClosure = types.CClosure;
```

References: [`types.CClosure`](runtime/types.md#type-cclosure)

<a id="alias-cupvalue"></a>

## CUpvalue

```zig
pub const CUpvalue = types.CUpvalue;
```

References: [`types.CUpvalue`](runtime/types.md#type-cupvalue)

<a id="alias-upvalue"></a>

## Upvalue

```zig
pub const Upvalue = types.Upvalue;
```

References: [`types.Upvalue`](runtime/types.md#type-upvalue)

<a id="alias-table"></a>

## Table

```zig
pub const Table = types.Table;
```

References: [`types.Table`](runtime/types.md#type-table)

<a id="alias-userdata"></a>

## Userdata

```zig
pub const Userdata = types.Userdata;
```

References: [`types.Userdata`](runtime/types.md#type-userdata)

<a id="alias-thread"></a>

## Thread

```zig
pub const Thread = types.Thread;
```

References: [`types.Thread`](runtime/types.md#type-thread)

<a id="alias-gcmode"></a>

## GcMode

```zig
pub const GcMode = types.GcMode;
```

References: [`types.GcMode`](runtime/types.md#type-gcmode)

<a id="alias-gcparam"></a>

## GcParam

```zig
pub const GcParam = types.GcParam;
```

References: [`types.GcParam`](runtime/types.md#type-gcparam)

<a id="alias-stdlibmode"></a>

## StdlibMode

```zig
pub const StdlibMode = state_mod.StdlibMode;
```

<a id="alias-memoryfile"></a>

## MemoryFile

```zig
pub const MemoryFile = host.MemoryFile;
```

References: [`host.MemoryFile`](runtime/host.md#type-memoryfile)

<a id="alias-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = host.MemoryFilesystem;
```

References: [`host.MemoryFilesystem`](runtime/host.md#type-memoryfilesystem)

<a id="alias-filesystemcapability"></a>

## FilesystemCapability

```zig
pub const FilesystemCapability = host.FilesystemCapability;
```

References: [`host.FilesystemCapability`](runtime/host.md#type-filesystemcapability)

<a id="alias-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = host.ClockCapability;
```

References: [`host.ClockCapability`](runtime/host.md#type-clockcapability)

<a id="alias-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = host.ProcessCapability;
```

References: [`host.ProcessCapability`](runtime/host.md#type-processcapability)

<a id="alias-compareop"></a>

## CompareOp

```zig
pub const CompareOp = state_mod.CompareOp;
```

<a id="alias-valuesequal"></a>

## valuesEqual

```zig
pub const valuesEqual = state_mod.valuesEqual;
```

<a id="alias-truthy"></a>

## truthy

```zig
pub const truthy = state_mod.truthy;
```

<a id="alias-tointeger"></a>

## toInteger

```zig
pub const toInteger = state_mod.toInteger;
```

<a id="alias-tonumber"></a>

## toNumber

```zig
pub const toNumber = state_mod.toNumber;
```

<a id="alias-appendluastring"></a>

## appendLuaString

```zig
pub const appendLuaString = state_mod.appendLuaString;
```

<a id="alias-localactiveat"></a>

## localActiveAt

```zig
pub const localActiveAt = state_mod.localActiveAt;
```

<a id="alias-parseintegerstrict"></a>

## parseIntegerStrict

```zig
pub const parseIntegerStrict = state_mod.parseIntegerStrict;
```

<a id="alias-parseluanumber"></a>

## parseLuaNumber

```zig
pub const parseLuaNumber = state_mod.parseLuaNumber;
```

<a id="alias-floattointeger"></a>

## floatToInteger

```zig
pub const floatToInteger = state_mod.floatToInteger;
```

<a id="alias-trimascii"></a>

## trimAscii

```zig
pub const trimAscii = state_mod.trimAscii;
```

<a id="alias-runtimeargvalue"></a>

## runtimeArgValue

```zig
pub const runtimeArgValue = state_mod.runtimeArgValue;
```

<a id="alias-argvalue"></a>

## argValue

```zig
pub const argValue = state_mod.argValue;
```

<a id="alias-appendvalue"></a>

## appendValue

```zig
pub const appendValue = state_mod.appendValue;
```

<a id="alias-isfilevalue"></a>

## isFileValue

```zig
pub const isFileValue = state_mod.isFileValue;
```

<a id="alias-isclosedfilevalue"></a>

## isClosedFileValue

```zig
pub const isClosedFileValue = state_mod.isClosedFileValue;
```

<a id="alias-appendnumber"></a>

## appendNumber

```zig
pub const appendNumber = state_mod.appendNumber;
```

<a id="alias-appendfmt"></a>

## appendFmt

```zig
pub const appendFmt = state_mod.appendFmt;
```

<a id="alias-executeoptions"></a>

## ExecuteOptions

```zig
pub const ExecuteOptions = execute_mod.ExecuteOptions;
```

<a id="alias-executesource"></a>

## executeSource

```zig
pub const executeSource = execute_mod.executeSource;
```

<a id="alias-executesourcewithoptions"></a>

## executeSourceWithOptions

```zig
pub const executeSourceWithOptions = execute_mod.executeSourceWithOptions;
```

