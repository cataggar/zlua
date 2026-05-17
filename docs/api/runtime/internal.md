# runtime.internal

## Navigation

- [API Index](../README.md)
- Parent: [runtime](../runtime.md)

<details>
<summary>All documents</summary>

- [root](../root.md)
- [frontend](../frontend.md)
- [errors](../errors.md)
- [frontend.source](../frontend/source.md)
- [frontend.token](../frontend/token.md)
- [frontend.diagnostic](../frontend/diagnostic.md)
- [frontend.lexer](../frontend/lexer.md)
- [frontend.ast](../frontend/ast.md)
- [frontend.parser](../frontend/parser.md)
- [compile](../compile.md)
- [compile.resolver](../compile/resolver.md)
- [compile.bytecode](../compile/bytecode.md)
- [compile.proto](../compile/proto.md)
- [compile.compiler](../compile/compiler.md)
- [compile.disasm](../compile/disasm.md)
- [api](../api.md)
- [runtime](../runtime.md)
- [runtime.chunk](../runtime/chunk.md)
- [runtime.types](../runtime/types.md)
- [runtime.value](../runtime/value.md)
- [runtime.execute](../runtime/execute.md)
- [testing.process](../testing/process.md)
- [runtime.state](../runtime/state.md)
- [runtime.call](../runtime/call.md)
- [runtime.coroutine](../runtime/coroutine.md)
- [runtime.debug](../runtime/debug.md)
- [runtime.gc](../runtime/gc.md)
- [runtime.host](../runtime/host.md)
- [stdlib](../stdlib.md)
- [stdlib.base](../stdlib/base.md)
- [stdlib.table](../stdlib/table.md)
- [stdlib.string](../stdlib/string.md)
- [stdlib.math](../stdlib/math.md)
- [stdlib.utf8](../stdlib/utf8.md)
- [stdlib.coroutine](../stdlib/coroutine.md)
- [stdlib.debug](../stdlib/debug.md)
- [stdlib.package](../stdlib/package.md)
- [stdlib.io](../stdlib/io.md)
- [stdlib.os](../stdlib/os.md)
- [stdlib.json](../stdlib/json.md)
- [stdlib.zerde_lua](../stdlib/zerde_lua.md)
- [stdlib.toml](../stdlib/toml.md)
- [stdlib.msgpack](../stdlib/msgpack.md)
- [stdlib.csv](../stdlib/csv.md)
- [runtime.vm](../runtime/vm.md)
- [runtime.tests](../runtime/tests.md)
- [runtime.internal](../runtime/internal.md)
- [testing](../testing.md)
- [testing.clua](../testing/clua.md)
- [testing.bench_runner](../testing/bench_runner.md)
- [testing.c_api_runner](../testing/c_api_runner.md)
- [testing.diff_runner](../testing/diff_runner.md)
- [testing.expected_failures](../testing/expected_failures.md)
- [testing.metadata](../testing/metadata.md)
- [testing.normalizer](../testing/normalizer.md)
- [testing.extension_runner](../testing/extension_runner.md)
- [testing.official_suite](../testing/official_suite.md)

</details>

## Aliases

- [State](#alias-state)
- [StateOptions](#alias-stateoptions)
- [StdlibMode](#alias-stdlibmode)
- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)
- [FilesystemCapability](#alias-filesystemcapability)
- [EnvironmentCapability](#alias-environmentcapability)
- [ClockCapability](#alias-clockcapability)
- [ProcessCapability](#alias-processcapability)
- [RuntimeError](#alias-runtimeerror)
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
- [ProtectedCallContext](#alias-protectedcallcontext)
- [ProtectedContinuationKind](#alias-protectedcontinuationkind)
- [ProtectedContinuation](#alias-protectedcontinuation)
- [GenericForContinuation](#alias-genericforcontinuation)
- [BranchContinuation](#alias-branchcontinuation)
- [TailCallContinuation](#alias-tailcallcontinuation)
- [CallOneContinuationResult](#alias-callonecontinuationresult)
- [CallOneContinuation](#alias-callonecontinuation)
- [CoroutineResumeResult](#alias-coroutineresumeresult)
- [Closure](#alias-closure)
- [CClosure](#alias-cclosure)
- [CUpvalue](#alias-cupvalue)
- [Upvalue](#alias-upvalue)
- [TableEntry](#alias-tableentry)
- [TableEntryIndex](#alias-tableentryindex)
- [Table](#alias-table)
- [Userdata](#alias-userdata)
- [Thread](#alias-thread)
- [ThreadStatus](#alias-threadstatus)
- [CallFrame](#alias-callframe)
- [StringAllocation](#alias-stringallocation)
- [PointerAllocationIndex](#alias-pointerallocationindex)
- [GcMode](#alias-gcmode)
- [GcParam](#alias-gcparam)
- [GcParams](#alias-gcparams)
- [WeakMode](#alias-weakmode)
- [RuntimeAllocationStats](#alias-runtimeallocationstats)
- [binary_chunk_signature](#alias-binary_chunk_signature)
- [binary_chunk_payload_magic](#alias-binary_chunk_payload_magic)
- [appendBinaryChunkHeader](#alias-appendbinarychunkheader)
- [dumpClosureBinary](#alias-dumpclosurebinary)
- [ExecuteOptions](#alias-executeoptions)
- [executeSource](#alias-executesource)
- [executeSourceWithOptions](#alias-executesourcewithoptions)
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

## Imports

- [host](#import-host) `@import("host.zig")`
- [state](#import-state) `@import("state.zig")`
- [types](#import-types) `@import("types.zig")`
- [value](#import-value) `@import("value.zig")`
- [chunk](#import-chunk) `@import("chunk.zig")`
- [execute_mod](#import-execute_mod) `@import("execute.zig")`
- [gc](#import-gc) `@import("gc.zig")`
- [call](#import-call) `@import("call.zig")`
- [coroutine_mod](#import-coroutine_mod) `@import("coroutine.zig")`
- [debug_mod](#import-debug_mod) `@import("debug.zig")`
- [vm](#import-vm) `@import("vm.zig")`

<a id="import-host"></a>

## host

```zig
pub const host = @import("host.zig");
```

<a id="import-state"></a>

## state

```zig
pub const state = @import("state.zig");
```

<a id="import-types"></a>

## types

```zig
pub const types = @import("types.zig");
```

<a id="import-value"></a>

## value

```zig
pub const value = @import("value.zig");
```

<a id="import-chunk"></a>

## chunk

```zig
pub const chunk = @import("chunk.zig");
```

<a id="import-execute_mod"></a>

## execute_mod

```zig
pub const execute_mod = @import("execute.zig");
```

<a id="import-gc"></a>

## gc

```zig
pub const gc = @import("gc.zig");
```

<a id="import-call"></a>

## call

```zig
pub const call = @import("call.zig");
```

<a id="import-coroutine_mod"></a>

## coroutine_mod

```zig
pub const coroutine_mod = @import("coroutine.zig");
```

<a id="import-debug_mod"></a>

## debug_mod

```zig
pub const debug_mod = @import("debug.zig");
```

<a id="import-vm"></a>

## vm

```zig
pub const vm = @import("vm.zig");
```

<a id="alias-state"></a>

## State

```zig
pub const State = state.State;
```

<a id="alias-stateoptions"></a>

## StateOptions

```zig
pub const StateOptions = state.StateOptions;
```

<a id="alias-stdlibmode"></a>

## StdlibMode

```zig
pub const StdlibMode = state.StdlibMode;
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

<a id="alias-environmentcapability"></a>

## EnvironmentCapability

```zig
pub const EnvironmentCapability = host.EnvironmentCapability;
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

<a id="alias-runtimeerror"></a>

## RuntimeError

```zig
pub const RuntimeError = types.RuntimeError;
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

<a id="alias-protectedcallcontext"></a>

## ProtectedCallContext

```zig
pub const ProtectedCallContext = types.ProtectedCallContext;
```

<a id="alias-protectedcontinuationkind"></a>

## ProtectedContinuationKind

```zig
pub const ProtectedContinuationKind = types.ProtectedContinuationKind;
```

<a id="alias-protectedcontinuation"></a>

## ProtectedContinuation

```zig
pub const ProtectedContinuation = types.ProtectedContinuation;
```

<a id="alias-genericforcontinuation"></a>

## GenericForContinuation

```zig
pub const GenericForContinuation = types.GenericForContinuation;
```

<a id="alias-branchcontinuation"></a>

## BranchContinuation

```zig
pub const BranchContinuation = types.BranchContinuation;
```

<a id="alias-tailcallcontinuation"></a>

## TailCallContinuation

```zig
pub const TailCallContinuation = types.TailCallContinuation;
```

<a id="alias-callonecontinuationresult"></a>

## CallOneContinuationResult

```zig
pub const CallOneContinuationResult = types.CallOneContinuationResult;
```

<a id="alias-callonecontinuation"></a>

## CallOneContinuation

```zig
pub const CallOneContinuation = types.CallOneContinuation;
```

<a id="alias-coroutineresumeresult"></a>

## CoroutineResumeResult

```zig
pub const CoroutineResumeResult = types.CoroutineResumeResult;
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

<a id="alias-tableentry"></a>

## TableEntry

```zig
pub const TableEntry = types.TableEntry;
```

<a id="alias-tableentryindex"></a>

## TableEntryIndex

```zig
pub const TableEntryIndex = types.TableEntryIndex;
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

<a id="alias-threadstatus"></a>

## ThreadStatus

```zig
pub const ThreadStatus = types.ThreadStatus;
```

<a id="alias-callframe"></a>

## CallFrame

```zig
pub const CallFrame = types.CallFrame;
```

<a id="alias-stringallocation"></a>

## StringAllocation

```zig
pub const StringAllocation = types.StringAllocation;
```

<a id="alias-pointerallocationindex"></a>

## PointerAllocationIndex

```zig
pub const PointerAllocationIndex = types.PointerAllocationIndex;
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

<a id="alias-gcparams"></a>

## GcParams

```zig
pub const GcParams = types.GcParams;
```

<a id="alias-weakmode"></a>

## WeakMode

```zig
pub const WeakMode = types.WeakMode;
```

<a id="alias-runtimeallocationstats"></a>

## RuntimeAllocationStats

```zig
pub const RuntimeAllocationStats = types.RuntimeAllocationStats;
```

<a id="alias-binary_chunk_signature"></a>

## binary_chunk_signature

```zig
pub const binary_chunk_signature = chunk.binary_chunk_signature;
```

<a id="alias-binary_chunk_payload_magic"></a>

## binary_chunk_payload_magic

```zig
pub const binary_chunk_payload_magic = chunk.binary_chunk_payload_magic;
```

<a id="alias-appendbinarychunkheader"></a>

## appendBinaryChunkHeader

```zig
pub const appendBinaryChunkHeader = chunk.appendBinaryChunkHeader;
```

<a id="alias-dumpclosurebinary"></a>

## dumpClosureBinary

```zig
pub const dumpClosureBinary = chunk.dumpClosureBinary;
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

<a id="alias-valuesequal"></a>

## valuesEqual

```zig
pub const valuesEqual = value.valuesEqual;
```

<a id="alias-truthy"></a>

## truthy

```zig
pub const truthy = value.truthy;
```

<a id="alias-tointeger"></a>

## toInteger

```zig
pub const toInteger = value.toInteger;
```

<a id="alias-tonumber"></a>

## toNumber

```zig
pub const toNumber = value.toNumber;
```

<a id="alias-appendluastring"></a>

## appendLuaString

```zig
pub const appendLuaString = value.appendLuaString;
```

<a id="alias-localactiveat"></a>

## localActiveAt

```zig
pub const localActiveAt = value.localActiveAt;
```

<a id="alias-parseintegerstrict"></a>

## parseIntegerStrict

```zig
pub const parseIntegerStrict = value.parseIntegerStrict;
```

<a id="alias-parseluanumber"></a>

## parseLuaNumber

```zig
pub const parseLuaNumber = value.parseLuaNumber;
```

<a id="alias-floattointeger"></a>

## floatToInteger

```zig
pub const floatToInteger = value.floatToInteger;
```

<a id="alias-trimascii"></a>

## trimAscii

```zig
pub const trimAscii = value.trimAscii;
```

<a id="alias-runtimeargvalue"></a>

## runtimeArgValue

```zig
pub const runtimeArgValue = value.runtimeArgValue;
```

<a id="alias-argvalue"></a>

## argValue

```zig
pub const argValue = value.argValue;
```

<a id="alias-appendvalue"></a>

## appendValue

```zig
pub const appendValue = value.appendValue;
```

<a id="alias-isfilevalue"></a>

## isFileValue

```zig
pub const isFileValue = value.isFileValue;
```

<a id="alias-isclosedfilevalue"></a>

## isClosedFileValue

```zig
pub const isClosedFileValue = value.isClosedFileValue;
```

<a id="alias-appendnumber"></a>

## appendNumber

```zig
pub const appendNumber = value.appendNumber;
```

<a id="alias-appendfmt"></a>

## appendFmt

```zig
pub const appendFmt = value.appendFmt;
```

