# runtime

## Navigation

- [API Index](README.md)
- Previous: [api](api.md)
- Next: [stdlib](stdlib.md)

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

<a id="alias-nativefn"></a>

## NativeFn

```zig
pub const NativeFn = types.NativeFn;
```

<a id="alias-userdatafinalizer"></a>

## UserdataFinalizer

```zig
pub const UserdataFinalizer = types.UserdataFinalizer;
```

<a id="alias-userdatadeinit"></a>

## UserdataDeinit

```zig
pub const UserdataDeinit = types.UserdataDeinit;
```

<a id="alias-protectedcallresult"></a>

## ProtectedCallResult

```zig
pub const ProtectedCallResult = types.ProtectedCallResult;
```

<a id="alias-apicallbackdispatchfn"></a>

## ApiCallbackDispatchFn

```zig
pub const ApiCallbackDispatchFn = types.ApiCallbackDispatchFn;
```

<a id="alias-cclosuredispatchfn"></a>

## CClosureDispatchFn

```zig
pub const CClosureDispatchFn = types.CClosureDispatchFn;
```

<a id="alias-cclosureresumedispatchfn"></a>

## CClosureResumeDispatchFn

```zig
pub const CClosureResumeDispatchFn = types.CClosureResumeDispatchFn;
```

<a id="alias-cdebughookdispatchfn"></a>

## CDebugHookDispatchFn

```zig
pub const CDebugHookDispatchFn = types.CDebugHookDispatchFn;
```

<a id="alias-debughookevent"></a>

## DebugHookEvent

```zig
pub const DebugHookEvent = types.DebugHookEvent;
```

<a id="alias-cdebughookcontext"></a>

## CDebugHookContext

```zig
pub const CDebugHookContext = types.CDebugHookContext;
```

<a id="alias-cclosurecontext"></a>

## CClosureContext

```zig
pub const CClosureContext = types.CClosureContext;
```

<a id="alias-cclosureresumecontext"></a>

## CClosureResumeContext

```zig
pub const CClosureResumeContext = types.CClosureResumeContext;
```

<a id="alias-apicallbackcontext"></a>

## ApiCallbackContext

```zig
pub const ApiCallbackContext = types.ApiCallbackContext;
```

<a id="alias-runtimeerrorpayload"></a>

## RuntimeErrorPayload

```zig
pub const RuntimeErrorPayload = types.RuntimeErrorPayload;
```

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

<a id="alias-cclosure"></a>

## CClosure

```zig
pub const CClosure = types.CClosure;
```

<a id="alias-cupvalue"></a>

## CUpvalue

```zig
pub const CUpvalue = types.CUpvalue;
```

<a id="alias-upvalue"></a>

## Upvalue

```zig
pub const Upvalue = types.Upvalue;
```

<a id="alias-table"></a>

## Table

```zig
pub const Table = types.Table;
```

<a id="alias-userdata"></a>

## Userdata

```zig
pub const Userdata = types.Userdata;
```

<a id="alias-thread"></a>

## Thread

```zig
pub const Thread = types.Thread;
```

<a id="alias-gcmode"></a>

## GcMode

```zig
pub const GcMode = types.GcMode;
```

<a id="alias-gcparam"></a>

## GcParam

```zig
pub const GcParam = types.GcParam;
```

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

<a id="alias-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = host.MemoryFilesystem;
```

<a id="alias-filesystemcapability"></a>

## FilesystemCapability

```zig
pub const FilesystemCapability = host.FilesystemCapability;
```

<a id="alias-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = host.ClockCapability;
```

<a id="alias-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = host.ProcessCapability;
```

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

