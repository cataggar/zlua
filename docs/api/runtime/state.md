# runtime.state

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

## Functions

- [valuesEqual](#fn-valuesequal)
- [truthy](#fn-truthy)
- [toInteger](#fn-tointeger)
- [toNumber](#fn-tonumber)
- [appendLuaString](#fn-appendluastring)
- [localActiveAt](#fn-localactiveat)
- [parseIntegerStrict](#fn-parseintegerstrict)
- [parseLuaNumber](#fn-parseluanumber)
- [floatToInteger](#fn-floattointeger)
- [trimAscii](#fn-trimascii)
- [runtimeArgValue](#fn-runtimeargvalue)
- [argValue](#fn-argvalue)
- [appendValue](#fn-appendvalue)
- [isFileValue](#fn-isfilevalue)
- [isClosedFileValue](#fn-isclosedfilevalue)
- [appendNumber](#fn-appendnumber)
- [appendFmt](#fn-appendfmt)

## Types

- [StateOptions](#type-stateoptions)
- [State](#type-state)
- [CompareOp](#type-compareop)

## Aliases

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
- [StdlibMode](#alias-stdlibmode)
- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)
- [FilesystemCapability](#alias-filesystemcapability)
- [EnvironmentCapability](#alias-environmentcapability)
- [ClockCapability](#alias-clockcapability)
- [ProcessCapability](#alias-processcapability)
- [ProcessResult](#alias-processresult)
- [Closure](#alias-closure)
- [CClosure](#alias-cclosure)
- [CUpvalue](#alias-cupvalue)
- [Upvalue](#alias-upvalue)
- [Table](#alias-table)
- [Userdata](#alias-userdata)
- [Thread](#alias-thread)
- [GcMode](#alias-gcmode)
- [GcParam](#alias-gcparam)

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

<a id="alias-stdlibmode"></a>

## StdlibMode

```zig
pub const StdlibMode = stdlib.LibrarySelection;
```

References: [`stdlib.LibrarySelection`](../stdlib.md#type-libraryselection)

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

<a id="alias-processresult"></a>

## ProcessResult

```zig
pub const ProcessResult = host.ProcessResult;
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

<a id="type-stateoptions"></a>

## StateOptions

```zig
pub const StateOptions = struct {
    stdlib: StdlibMode = .full,
    io: ?std.Io = null,
    stdout: ?*std.Io.Writer = null,
    stderr: ?*std.Io.Writer = null,
    filesystem: FilesystemCapability = .disabled,
    environment: EnvironmentCapability = .disabled,
    clock: ClockCapability = .system,
    process: ProcessCapability = .disabled,
    stdin: []const u8 = "",
    max_memory: ?usize = null,
    max_stack_values: ?usize = null,
    max_call_frames: ?usize = null,
    max_instructions: ?u64 = null,
    debug_errors: bool = false,
    trace_vm: bool = false,
};
```

<a id="type-state"></a>

## State

```zig
pub const State = struct {
    allocator: std.mem.Allocator,
    globals: std.StringHashMap(Value),
    global_table: ?*Table = null,
    strings: std.StringHashMap([]const u8),
    string_allocations: std.ArrayList(StringAllocation) = .empty,
    string_allocation_index: PointerAllocationIndex,
    table_allocations: std.ArrayList(*Table) = .empty,
    table_allocation_index: PointerAllocationIndex,
    table_metatable_head: ?*Table = null,
    table_metatable_count: usize = 0,
    userdata_allocations: std.ArrayList(*Userdata) = .empty,
    closure_allocations: std.ArrayList(*Closure) = .empty,
    c_closure_allocations: std.ArrayList(*CClosure) = .empty,
    upvalue_allocations: std.ArrayList(*Upvalue) = .empty,
    c_upvalue_allocations: std.ArrayList(*CUpvalue) = .empty,
    thread_allocations: std.ArrayList(*Thread) = .empty,
    proto_allocations: std.ArrayList(*proto_mod.Proto) = .empty,
    source_allocations: std.ArrayList([]const u8) = .empty,
    api_roots: std.ArrayList(Value) = .empty,
    stdout: std.ArrayList(u8) = .empty,
    stderr: std.ArrayList(u8) = .empty,
    options: StateOptions,
    stdin_pos: usize = 0,
    last_error: ?RuntimeErrorPayload = null,
    last_error_in_close: bool = false,
    traceback_error_in_close: bool = false,
    current_thread: ?*Thread = null,
    api_callback_dispatch: ?ApiCallbackDispatchFn = null,
    api_callback_user_data: ?*anyopaque = null,
    c_closure_dispatch: ?CClosureDispatchFn = null,
    c_closure_resume_dispatch: ?CClosureResumeDispatchFn = null,
    c_debug_hook_dispatch: ?CDebugHookDispatchFn = null,
    c_closure_user_data: ?*anyopaque = null,
    coroutine_close_depth: usize = 0,
    string_metatable: ?*Table = null,
    number_metatable: ?*Table = null,
    boolean_metatable: ?*Table = null,
    nil_metatable: ?*Table = null,
    zerde_null: ?*Table = null,
    zerde_array_metatable: ?*Table = null,
    zerde_object_metatable: ?*Table = null,
    is_collecting: bool = false,
    collect_after_instruction: bool = false,
    gc_running: bool = true,
    gc_mode: GcMode = .generational,
    gc_params: GcParams = .{},
    gc_next_total: usize = 0,
    gc_known_total: usize = 0,
    mark_all_stack_registers: bool = false,
    conservative_gc_depth: usize = 0,
    random_state: [4]u64 = .{ 0x123456789abcdef0, 0xff, 0xfedcba9876543210, 0 },
    instruction_count: u64 = 0,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [init](#fn-state-init) | `allocator: std.mem.Allocator` | `!State` |  |
| [initWithOptions](#fn-state-initwithoptions) | `allocator: std.mem.Allocator, options: StateOptions` | `!State` |  |
| [stackValueLimit](#fn-state-stackvaluelimit) | `self: *const State` | `usize` |  |
| [callFrameLimit](#fn-state-callframelimit) | `self: *const State` | `usize` |  |
| [fileMetatable](#fn-state-filemetatable) | `state: *State` | `!*Table` |  |
| [deinit](#fn-state-deinit) | `self: *State` | `void` |  |
| [execute](#fn-state-execute) | `self: *State, proto: *const proto_mod.Proto` | `!void` |  |
| [callLoadedClosure](#fn-state-callloadedclosure) | `self: *State, closure: *Closure, args: []const Value` | `![]Value` |  |
| [protectedCallLoadedClosure](#fn-state-protectedcallloadedclosure) | `self: *State, closure: *Closure, args: []const Value` | `!ProtectedCallResult` |  |
| [executeSourceChunk](#fn-state-executesourcechunk) | `self: *State, source: []const u8` | `!void` |  |
| [executeSourceChunkNamed](#fn-state-executesourcechunknamed) | `self: *State, source: []const u8, source_name: []const u8` | `!void` |  |
| [runThreadUntil](#fn-state-runthreaduntil) | `self: *State, thread: *Thread, target_frame_count: usize` | `anyerror!void` |  |
| [checkExecutionLimits](#fn-state-checkexecutionlimits) | `self: *State, thread: *Thread` | `!void` |  |
| [noteAllocation](#fn-state-noteallocation) | `self: *State, bytes: usize` | `void` |  |
| [noteAllocationFreed](#fn-state-noteallocationfreed) | `self: *State, bytes: usize` | `void` |  |
| [refreshAllocationTotal](#fn-state-refreshallocationtotal) | `self: *State` | `usize` |  |
| [currentAllocationTotal](#fn-state-currentallocationtotal) | `self: *State` | `usize` |  |
| [tableCapacityBytes](#fn-state-tablecapacitybytes) | `table: *const Table` | `usize` |  |
| [tableGcBytes](#fn-state-tablegcbytes) | `table: *const Table` | `usize` |  |
| [noteTableCapacityDelta](#fn-state-notetablecapacitydelta) | `self: *State, table: *const Table, old_capacity_bytes: usize` | `void` |  |
| [getGlobal](#fn-state-getglobal) | `self: *State, name: []const u8` | `Value` |  |
| [currentLine](#fn-state-currentline) | `self: *State, thread: *Thread, level: i64` | `?usize` |  |
| [currentExtraArgs](#fn-state-currentextraargs) | `self: *State, thread: *Thread, level: i64` | `?usize` |  |
| [currentWhat](#fn-state-currentwhat) | `self: *State, thread: *Thread, level: i64` | `[]const u8` |  |
| [currentFunctionName](#fn-state-currentfunctionname) | `self: *State, thread: *Thread, level: i64` | `?[]const u8` |  |
| [currentFunctionNameWhat](#fn-state-currentfunctionnamewhat) | `self: *State, thread: *Thread, level: i64` | `?[]const u8` |  |
| [setThreadHook](#fn-state-setthreadhook) | `self: *State, target: *Thread, hook: Value, mask: []const u8, count: u32` | `void` |  |
| [threadHookMask](#fn-state-threadhookmask) | `self: *State, thread: *Thread` | `![]const u8` |  |
| [callHook](#fn-state-callhook) | `self: *State, thread: *Thread, event: []const u8` | `!void` |  |
| [putGlobal](#fn-state-putglobal) | `self: *State, name: []const u8, value: Value` | `!void` |  |
| [rootValue](#fn-state-rootvalue) | `self: *State, value: Value` | `!usize` |  |
| [unrootValue](#fn-state-unrootvalue) | `self: *State, index: usize` | `void` |  |
| [rootedValue](#fn-state-rootedvalue) | `self: *State, index: usize` | `Value` |  |
| [activeRootCount](#fn-state-activerootcount) | `self: State` | `usize` |  |
| [setApiCallbackDispatch](#fn-state-setapicallbackdispatch) | `self: *State, dispatch: ApiCallbackDispatchFn, user_data: *anyopaque` | `void` |  |
| [setCClosureDispatch](#fn-state-setcclosuredispatch) | `self: *State, dispatch: CClosureDispatchFn, user_data: *anyopaque` | `void` |  |
| [setCClosureResumeDispatch](#fn-state-setcclosureresumedispatch) | `self: *State, dispatch: CClosureResumeDispatchFn` | `void` |  |
| [setCDebugHookDispatch](#fn-state-setcdebughookdispatch) | `self: *State, dispatch: CDebugHookDispatchFn` | `void` |  |
| [newCClosure](#fn-state-newcclosure) | `self: *State, function_id: usize, upvalue_values: []const Value` | `!*CClosure` |  |
| [newCoroutine](#fn-state-newcoroutine) | `self: *State, entry: Value` | `!*Thread` |  |
| [resumeThread](#fn-state-resumethread) | `self: *State, target: *Thread, args: []const Value` | `!ProtectedCallResult` |  |
| [closeThread](#fn-state-closethread) | `self: *State, target: *Thread` | `!?Value` |  |
| [threadWasYielded](#fn-state-threadwasyielded) | `_: *State, target: *Thread` | `bool` |  |
| [callCClosureDispatch](#fn-state-callcclosuredispatch) | `self: *State, thread: *Thread, op: bytecode.Call, closure: *CClosure` | `!void` |  |
| [resumeCClosureDispatch](#fn-state-resumecclosuredispatch) | `self: *State, thread: *Thread, args: []const Value` | `!void` |  |
| [callApiCallbackDispatch](#fn-state-callapicallbackdispatch) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [readFileAlloc](#fn-state-readfilealloc) | `self: *State, path: []const u8` | `![]const u8` |  |
| [writeStdout](#fn-state-writestdout) | `self: *State, bytes: []const u8` | `!void` |  |
| [writeStderr](#fn-state-writestderr) | `self: *State, bytes: []const u8` | `!void` |  |
| [flushStdout](#fn-state-flushstdout) | `self: *State` | `!void` |  |
| [flushStderr](#fn-state-flushstderr) | `self: *State` | `!void` |  |
| [writeFile](#fn-state-writefile) | `self: *State, path: []const u8, data: []const u8` | `!void` |  |
| [removeFile](#fn-state-removefile) | `self: *State, path: []const u8` | `!void` |  |
| [renameFile](#fn-state-renamefile) | `self: *State, old_path: []const u8, new_path: []const u8` | `!void` |  |
| [getenv](#fn-state-getenv) | `self: *State, name: []const u8` | `?[]const u8` |  |
| [currentTime](#fn-state-currenttime) | `self: *State` | `!i64` |  |
| [executeProcess](#fn-state-executeprocess) | `self: *State, command: []const u8` | `!ProcessResult` |  |
| [requireIo](#fn-state-requireio) | `self: *State, unavailable_message: []const u8` | `RuntimeError!std.Io` |  |
| [processEnabled](#fn-state-processenabled) | `self: *State` | `bool` |  |
| [readStdin](#fn-state-readstdin) | `self: *State, spec: []const u8` | `!Value` |  |
| [loadSourceAsClosure](#fn-state-loadsourceasclosure) | `self: *State, source: []const u8` | `!Value` |  |
| [loadSourceAsClosureNamed](#fn-state-loadsourceasclosurenamed) | `self: *State, source: []const u8, source_name: ?[]const u8` | `!Value` |  |
| [loadSourceAsClosureNamedEnv](#fn-state-loadsourceasclosurenamedenv) | `self: *State, source: []const u8, source_name: ?[]const u8, environment: Value` | `!Value` |  |
| [loadBinaryDump](#fn-state-loadbinarydump) | `self: *State, source: []const u8, environment: Value` | `!Value` |  |
| [loadFileAsClosure](#fn-state-loadfileasclosure) | `self: *State, path: []const u8` | `!Value` |  |
| [loadFileAsClosureNamed](#fn-state-loadfileasclosurenamed) | `self: *State, path: []const u8, source_name: ?[]const u8` | `!Value` |  |
| [callCollect](#fn-state-callcollect) | `self: *State, thread: *Thread, callable: Value, args: []const Value` | `anyerror![]Value` |  |
| [intern](#fn-state-intern) | `self: *State, bytes: []const u8` | `![]const u8` |  |
| [allocateString](#fn-state-allocatestring) | `self: *State, bytes: []const u8` | `![]const u8` |  |
| [newTableWithHints](#fn-state-newtablewithhints) | `self: *State, array_hint: u32, hash_hint: u32` | `!Value` |  |
| [newUserdata](#fn-state-newuserdata) | `self: *State, ptr: *anyopaque, type_id: usize, type_name: []const u8, finalizer: ?UserdataFinalizer, finalizer_data: ?*const anyopaque, deinit_fn: ?UserdataDeinit` | `!Value` |  |
| [closeUpvalues](#fn-state-closeupvalues) | `self: *State, thread: *Thread, first_stack_index: usize` | `void` |  |
| [closeFramesTo](#fn-state-closeframesto) | `self: *State, thread: *Thread, frame_count: usize, error_value: ?Value` | `!void` |  |
| [getTableValue](#fn-state-gettablevalue) | `self: *State, table_value: Value, key_value: Value` | `!Value` |  |
| [getTableFromThread](#fn-state-gettablefromthread) | `self: *State, thread: *Thread, table_value: Value, key_value: Value` | `!Value` |  |
| [setTableValue](#fn-state-settablevalue) | `self: *State, table_value: Value, key_value: Value, value: Value` | `!void` |  |
| [setTableFromThread](#fn-state-settablefromthread) | `self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value` | `!void` |  |
| [lengthOf](#fn-state-lengthof) | `self: *State, thread: *Thread, value: Value` | `!Value` |  |
| [invokeValue](#fn-state-invokevalue) | `self: *State, thread: *Thread, resolved: bytecode.Call, depth: usize` | `anyerror!void` |  |
| [callOneResult](#fn-state-calloneresult) | `self: *State, thread: *Thread, callable: Value, args: []const Value` | `anyerror!Value` |  |
| [callOneResultWithContinuation](#fn-state-calloneresultwithcontinuation) | `self: *State, thread: *Thread, callable: Value, args: []const Value, result: CallOneContinuationResult` | `anyerror!Value` |  |
| [callOneMetamethodWithContinuation](#fn-state-callonemetamethodwithcontinuation) | `self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value, result: CallOneContinuationResult` | `anyerror!Value` |  |
| [callOneMetamethod](#fn-state-callonemetamethod) | `self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value` | `anyerror!Value` |  |
| [metamethodDebugName](#fn-state-metamethoddebugname) | `name: []const u8` | `[]const u8` |  |
| [callOneResultMaybeContinuation](#fn-state-calloneresultmaybecontinuation) | `self: *State, thread: *Thread, callable: Value, args: []const Value, continuation_result: ?CallOneContinuationResult` | `anyerror!Value` |  |
| [pushCallOneContinuation](#fn-state-pushcallonecontinuation) | `self: *State, thread: *Thread, frame_count: usize, result: CallOneContinuationResult` | `!void` |  |
| [readyCallOneContinuationIndex](#fn-state-readycallonecontinuationindex) | `thread: *Thread` | `?usize` |  |
| [completeReadyCallOneContinuation](#fn-state-completereadycallonecontinuation) | `self: *State, thread: *Thread` | `!bool` |  |
| [protectedCall](#fn-state-protectedcall) | `self: *State, thread: *Thread, callable: Value, args: []const Value` | `anyerror!ProtectedCallResult` |  |
| [protectedCallContext](#fn-state-protectedcallcontext) | `_: *State, thread: *Thread` | `ProtectedCallContext` |  |
| [protectedCallContextWithErrors](#fn-state-protectedcallcontextwitherrors) | `self: *State, thread: *Thread` | `ProtectedCallContext` |  |
| [runProtectedCall](#fn-state-runprotectedcall) | `self: *State, thread: *Thread, context: ProtectedCallContext, callable: Value, args: []const Value` | `anyerror!ProtectedCallResult` |  |
| [restoreProtectedCall](#fn-state-restoreprotectedcall) | `self: *State,         thread: *Thread,         context: ProtectedCallContext,         error_value: Value,` | `!Value` |  |
| [pushProtectedContinuation](#fn-state-pushprotectedcontinuation) | `self: *State, thread: *Thread, context: ProtectedCallContext, base: bytecode.Register, return_count: u16, kind: ProtectedContinuationKind, handler: Value, handler_depth: usize` | `!void` |  |
| [readyProtectedContinuationIndex](#fn-state-readyprotectedcontinuationindex) | `thread: *Thread` | `?usize` |  |
| [errorProtectedContinuationIndex](#fn-state-errorprotectedcontinuationindex) | `thread: *Thread` | `?usize` |  |
| [completeReadyProtectedContinuation](#fn-state-completereadyprotectedcontinuation) | `self: *State, thread: *Thread` | `!bool` |  |
| [completeProtectedContinuationError](#fn-state-completeprotectedcontinuationerror) | `self: *State, thread: *Thread, error_value: Value` | `!bool` |  |
| [returnProtectedContinuationSuccess](#fn-state-returnprotectedcontinuationsuccess) | `self: *State, thread: *Thread, continuation: ProtectedContinuation, values: []Value` | `!void` |  |
| [returnProtectedContinuationFailure](#fn-state-returnprotectedcontinuationfailure) | `self: *State, thread: *Thread, continuation: ProtectedContinuation, failure: Value` | `!void` |  |
| [valueToString](#fn-state-valuetostring) | `self: *State, thread: *Thread, value: Value` | `anyerror![]const u8` |  |
| [setDebugMetatableValue](#fn-state-setdebugmetatablevalue) | `self: *State, value: Value, metatable_value: Value` | `!void` |  |
| [getMetamethod](#fn-state-getmetamethod) | `self: *State, value: Value, name: []const u8` | `!?Value` |  |
| [setTableMetatableRaw](#fn-state-settablemetatableraw) | `self: *State, table: *Table, metatable: ?*Table` | `void` |  |
| [noteTableMetatableChanged](#fn-state-notetablemetatablechanged) | `self: *State, table: *Table, old_has_metatable: bool` | `void` |  |
| [unlinkTableMetatable](#fn-state-unlinktablemetatable) | `self: *State, table: *Table` | `void` |  |
| [luaTypeNameForError](#fn-state-luatypenameforerror) | `self: *State, value: Value` | `[]const u8` |  |
| [jumpIfBranchResult](#fn-state-jumpifbranchresult) | `self: *State, thread: *Thread, result: bool, jump_if_truthy: bool, offset: bytecode.JumpOffset` | `!void` |  |
| [compareValues](#fn-state-comparevalues) | `self: *State, thread: *Thread, lhs: Value, rhs: Value, op: CompareOp` | `!bool` |  |
| [returnValues](#fn-state-returnvalues) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, values: []const Value` | `!void` |  |
| [prepareClosureFrame](#fn-state-prepareclosureframe) | `self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16` | `!CallFrame` |  |
| [captureVarargs](#fn-state-capturevarargs) | `self: *State, thread: *Thread, source_start: usize, count: usize` | `![]const Value` |  |
| [namedVarargTable](#fn-state-namedvarargtable) | `self: *State, varargs: []const Value` | `!Value` |  |
| [resolveReturnCount](#fn-state-resolvereturncount) | `self: *State, count: u16, available: usize` | `!usize` |  |
| [returnXpcallFailure](#fn-state-returnxpcallfailure) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value` | `!void` |  |
| [returnXpcallFailureFromDepth](#fn-state-returnxpcallfailurefromdepth) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value, initial_depth: usize` | `!void` |  |
| [snapshotCoroutineErrorTraceback](#fn-state-snapshotcoroutineerrortraceback) | `self: *State, target: *Thread` | `![]const u8` |  |
| [coroutineCreate](#fn-state-coroutinecreate) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineResume](#fn-state-coroutineresume) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineYield](#fn-state-coroutineyield) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineStatus](#fn-state-coroutinestatus) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineRunning](#fn-state-coroutinerunning) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineIsYieldable](#fn-state-coroutineisyieldable) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineClose](#fn-state-coroutineclose) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [coroutineWrap](#fn-state-coroutinewrap) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [callCoroutineWrapper](#fn-state-callcoroutinewrapper) | `self: *State, thread: *Thread, op: bytecode.Call, target: *Thread` | `!void` |  |
| [callCoroutineWrapperWithArgs](#fn-state-callcoroutinewrapperwithargs) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value` | `!void` |  |
| [newCoroutineThread](#fn-state-newcoroutinethread) | `self: *State, entry: Value` | `!*Thread` |  |
| [closeCoroutine](#fn-state-closecoroutine) | `self: *State, target: *Thread, error_value: ?Value` | `!?Value` |  |
| [resumeCoroutine](#fn-state-resumecoroutine) | `self: *State, target: *Thread, args: []const Value` | `!CoroutineResumeResult` |  |
| [startCoroutine](#fn-state-startcoroutine) | `self: *State, target: *Thread, args: []const Value` | `!void` |  |
| [callableEntryClosure](#fn-state-callableentryclosure) | `self: *State` | `!*Closure` |  |
| [setCoroutineResumeValues](#fn-state-setcoroutineresumevalues) | `self: *State, target: *Thread, args: []const Value` | `!void` |  |
| [returnCoroutineResumeResult](#fn-state-returncoroutineresumeresult) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult` | `!void` |  |
| [copyValues](#fn-state-copyvalues) | `self: *State, values: []const Value` | `![]Value` |  |
| [copyStackSlice](#fn-state-copystackslice) | `self: *State, thread: *Thread, base: usize, count: usize` | `![]Value` |  |
| [collectArgs](#fn-state-collectargs) | `self: *State, thread: *Thread, op: bytecode.Call, first: u16` | `![]Value` |  |
| [returnProtectedResult](#fn-state-returnprotectedresult) | `self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult` | `!void` |  |
| [expectTable](#fn-state-expecttable) | `self: *State, value: Value` | `!*Table` |  |
| [expectString](#fn-state-expectstring) | `self: *State, value: Value` | `![]const u8` |  |
| [expectThread](#fn-state-expectthread) | `self: *State, value: Value` | `!*Thread` |  |
| [collectGarbageValue](#fn-state-collectgarbagevalue) | `self: *State, thread: *Thread, op: bytecode.Call` | `!void` |  |
| [collectGarbageParam](#fn-state-collectgarbageparam) | `self: *State, value: Value` | `!GcParam` |  |
| [collectGarbageStep](#fn-state-collectgarbagestep) | `self: *State, thread: ?*Thread, budget: i64` | `!bool` |  |
| [collectGarbage](#fn-state-collectgarbage) | `self: *State` | `!void` |  |
| [collectGarbageStepPublic](#fn-state-collectgarbagesteppublic) | `self: *State, budget: i64` | `!bool` |  |
| [allocationByteCount](#fn-state-allocationbytecount) | `self: State` | `usize` |  |
| [gcIsRunning](#fn-state-gcisrunning) | `self: State` | `bool` |  |
| [stopGc](#fn-state-stopgc) | `self: *State` | `void` |  |
| [restartGc](#fn-state-restartgc) | `self: *State` | `void` |  |
| [switchGcMode](#fn-state-switchgcmode) | `self: *State, mode: GcMode` | `GcMode` |  |
| [gcParam](#fn-state-gcparam) | `self: State, param: GcParam` | `i64` |  |
| [setGcParam](#fn-state-setgcparam) | `self: *State, param: GcParam, value: i64` | `void` |  |
| [collectGarbageConservatively](#fn-state-collectgarbageconservatively) | `self: *State, thread: ?*Thread` | `!void` |  |
| [collectGarbageWithFinalizers](#fn-state-collectgarbagewithfinalizers) | `self: *State, thread: ?*Thread` | `!void` |  |
| [collectGarbageWithFinalizersMode](#fn-state-collectgarbagewithfinalizersmode) | `self: *State, thread: ?*Thread, mark_all_stack_registers: bool` | `!void` |  |
| [shouldRunAutoGc](#fn-state-shouldrunautogc) | `self: *State` | `bool` |  |
| [resetAutoGcThreshold](#fn-state-resetautogcthreshold) | `self: *State` | `void` |  |
| [resetMarks](#fn-state-resetmarks) | `self: *State` | `void` |  |
| [markRoots](#fn-state-markroots) | `self: *State` | `void` |  |
| [markValue](#fn-state-markvalue) | `self: *State, value: Value` | `void` |  |
| [markRuntimeErrorPayload](#fn-state-markruntimeerrorpayload) | `self: *State, payload: ?RuntimeErrorPayload` | `void` |  |
| [markString](#fn-state-markstring) | `self: *State, bytes: []const u8` | `void` |  |
| [markTable](#fn-state-marktable) | `self: *State, table: *Table` | `void` |  |
| [markUserdata](#fn-state-markuserdata) | `self: *State, userdata: *Userdata` | `void` |  |
| [markWeakTableStrings](#fn-state-markweaktablestrings) | `self: *State, table: *Table, keys: bool, values: bool` | `void` |  |
| [markWeakString](#fn-state-markweakstring) | `self: *State, value: Value` | `void` |  |
| [markClosure](#fn-state-markclosure) | `self: *State, closure: *Closure` | `void` |  |
| [markCClosure](#fn-state-markcclosure) | `self: *State, closure: *CClosure` | `void` |  |
| [markUpvalue](#fn-state-markupvalue) | `self: *State, upvalue: *Upvalue` | `void` |  |
| [markCUpvalue](#fn-state-markcupvalue) | `self: *State, upvalue: *CUpvalue` | `void` |  |
| [markThread](#fn-state-markthread) | `self: *State, thread: *Thread` | `void` |  |
| [markThreadStack](#fn-state-markthreadstack) | `self: *State, thread: *Thread` | `void` |  |
| [markStackRange](#fn-state-markstackrange) | `self: *State, thread: *Thread, base: usize, count: usize` | `void` |  |
| [weakMode](#fn-state-weakmode) | `self: *State, table: *Table` | `WeakMode` |  |
| [hasWeakTables](#fn-state-hasweaktables) | `self: *State` | `bool` |  |
| [markEphemeronValues](#fn-state-markephemeronvalues) | `self: *State, table: *Table` | `bool` |  |
| [convergeEphemerons](#fn-state-convergeephemerons) | `self: *State` | `void` |  |
| [markValueChanged](#fn-state-markvaluechanged) | `self: *State, value: Value` | `bool` |  |
| [valueIsMarked](#fn-state-valueismarked) | `self: *State, value: Value` | `bool` |  |
| [valueIsWeaklyCleared](#fn-state-valueisweaklycleared) | `self: *State, value: Value` | `bool` |  |
| [valueIsCollectableUnmarked](#fn-state-valueiscollectableunmarked) | `self: *State, value: Value` | `bool` |  |
| [clearWeakValues](#fn-state-clearweakvalues) | `self: *State` | `void` |  |
| [clearWeakTables](#fn-state-clearweaktables) | `self: *State` | `void` |  |
| [clearDeadHashKeys](#fn-state-cleardeadhashkeys) | `self: *State` | `void` |  |
| [clearWeakTableValues](#fn-state-clearweaktablevalues) | `self: *State, table: *Table` | `void` |  |
| [clearWeakTableKeys](#fn-state-clearweaktablekeys) | `self: *State, table: *Table` | `void` |  |
| [writeTableBarrier](#fn-state-writetablebarrier) | `self: *State, table: *Table, key: Value, value: Value` | `void` |  |
| [writeBarrier](#fn-state-writebarrier) | `self: *State, parent_marked: bool, child: Value` | `void` |  |
| [runPendingFinalizers](#fn-state-runpendingfinalizers) | `self: *State, thread: ?*Thread` | `!void` |  |
| [runPendingUserdataFinalizers](#fn-state-runpendinguserdatafinalizers) | `self: *State` | `void` |  |
| [callableValue](#fn-state-callablevalue) | `self: *State, value: Value` | `bool` |  |
| [sweepStrings](#fn-state-sweepstrings) | `self: *State` | `void` |  |
| [sweepUserdata](#fn-state-sweepuserdata) | `self: *State` | `void` |  |
| [sweepTables](#fn-state-sweeptables) | `self: *State` | `void` |  |
| [sweepClosures](#fn-state-sweepclosures) | `self: *State` | `void` |  |
| [sweepCClosures](#fn-state-sweepcclosures) | `self: *State` | `void` |  |
| [sweepUpvalues](#fn-state-sweepupvalues) | `self: *State` | `void` |  |
| [sweepCUpvalues](#fn-state-sweepcupvalues) | `self: *State` | `void` |  |
| [sweepThreads](#fn-state-sweepthreads) | `self: *State` | `void` |  |
| [findStringAllocation](#fn-state-findstringallocation) | `self: *State, bytes: []const u8` | `?usize` |  |
| [isTrackedThread](#fn-state-istrackedthread) | `self: *State, thread: *Thread` | `bool` |  |
| [isTrackedTable](#fn-state-istrackedtable) | `self: *State, table: *Table` | `bool` |  |
| [isTrackedUserdata](#fn-state-istrackeduserdata) | `self: *State, userdata: *Userdata` | `bool` |  |
| [isTrackedClosure](#fn-state-istrackedclosure) | `self: *State, closure: *Closure` | `bool` |  |
| [isTrackedCClosure](#fn-state-istrackedcclosure) | `self: *State, closure: *CClosure` | `bool` |  |
| [isTrackedUpvalue](#fn-state-istrackedupvalue) | `self: *State, upvalue: *Upvalue` | `bool` |  |
| [isTrackedCUpvalue](#fn-state-istrackedcupvalue) | `self: *State, upvalue: *CUpvalue` | `bool` |  |
| [destroyTable](#fn-state-destroytable) | `self: *State, table: *Table` | `void` |  |
| [destroyUserdata](#fn-state-destroyuserdata) | `self: *State, userdata: *Userdata` | `void` |  |
| [destroyClosure](#fn-state-destroyclosure) | `self: *State, closure: *Closure` | `void` |  |
| [destroyCClosure](#fn-state-destroycclosure) | `self: *State, closure: *CClosure` | `void` |  |
| [destroyThread](#fn-state-destroythread) | `self: *State, thread: *Thread` | `void` |  |
| [allocationStats](#fn-state-allocationstats) | `self: State` | `RuntimeAllocationStats` |  |
| [failRuntimeDetail](#fn-state-failruntimedetail) | `self: *State, thread: ?*Thread, detail: []const u8` | `RuntimeError` |  |
| [errorDetailAlloc](#fn-state-errordetailalloc) | `self: *State, allocator: std.mem.Allocator, err: anyerror` | `![]const u8` |  |
| [fail](#fn-state-fail) | `self: *State, message: []const u8` | `RuntimeError` |  |
| [failArgument](#fn-state-failargument) | `self: *State, function_name: []const u8, index: u16, detail: errors.ArgumentErrorDetail` | `RuntimeError` |  |
| [failArgumentMessage](#fn-state-failargumentmessage) | `self: *State, function_name: []const u8, index: u16, message: []const u8` | `RuntimeError` |  |
| [failArgumentType](#fn-state-failargumenttype) | `self: *State, function_name: []const u8, index: u16, expected: []const u8, actual: Value` | `RuntimeError` |  |
| [expectArgumentString](#fn-state-expectargumentstring) | `self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16` | `![]const u8` |  |
| [argumentDisplayIndex](#fn-state-argumentdisplayindex) | `self: *State, thread: *Thread, function_name: []const u8, index: u16` | `u16` |  |
| [expectArgumentTable](#fn-state-expectargumenttable) | `self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16` | `!*Table` |  |
| [argumentInteger](#fn-state-argumentinteger) | `self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16` | `!i64` |  |
| [failValue](#fn-state-failvalue) | `self: *State, value: Value` | `RuntimeError` |  |
| [throwValue](#fn-state-throwvalue) | `self: *State, value: Value` | `RuntimeError` |  |
| [currentErrorValue](#fn-state-currenterrorvalue) | `self: *State` | `Value` |  |

<a id="fn-state-init"></a>

### State.init

```zig
pub fn init(allocator: std.mem.Allocator) !State
```

References: [`State`](#type-state)

<a id="fn-state-initwithoptions"></a>

### State.initWithOptions

```zig
pub fn initWithOptions(allocator: std.mem.Allocator, options: StateOptions) !State
```

References: [`StateOptions`](#type-stateoptions), [`State`](#type-state)

<a id="fn-state-stackvaluelimit"></a>

### State.stackValueLimit

```zig
pub fn stackValueLimit(self: *const State) usize
```

References: [`State`](#type-state)

<a id="fn-state-callframelimit"></a>

### State.callFrameLimit

```zig
pub fn callFrameLimit(self: *const State) usize
```

References: [`State`](#type-state)

<a id="fn-state-filemetatable"></a>

### State.fileMetatable

```zig
pub fn fileMetatable(state: *State) !*Table
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-deinit"></a>

### State.deinit

```zig
pub fn deinit(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-execute"></a>

### State.execute

```zig
pub fn execute(self: *State, proto: *const proto_mod.Proto) !void
```

References: [`State`](#type-state)

<a id="fn-state-callloadedclosure"></a>

### State.callLoadedClosure

```zig
pub fn callLoadedClosure(self: *State, closure: *Closure, args: []const Value) ![]Value
```

References: [`State`](#type-state), [`Closure`](#alias-closure), [`Value`](#alias-value)

<a id="fn-state-protectedcallloadedclosure"></a>

### State.protectedCallLoadedClosure

```zig
pub fn protectedCallLoadedClosure(self: *State, closure: *Closure, args: []const Value) !ProtectedCallResult
```

References: [`State`](#type-state), [`Closure`](#alias-closure), [`Value`](#alias-value), [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-state-executesourcechunk"></a>

### State.executeSourceChunk

```zig
pub fn executeSourceChunk(self: *State, source: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-executesourcechunknamed"></a>

### State.executeSourceChunkNamed

```zig
pub fn executeSourceChunkNamed(self: *State, source: []const u8, source_name: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-runthreaduntil"></a>

### State.runThreadUntil

```zig
pub fn runThreadUntil(self: *State, thread: *Thread, target_frame_count: usize) anyerror!void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-checkexecutionlimits"></a>

### State.checkExecutionLimits

```zig
pub fn checkExecutionLimits(self: *State, thread: *Thread) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-noteallocation"></a>

### State.noteAllocation

```zig
pub fn noteAllocation(self: *State, bytes: usize) void
```

References: [`State`](#type-state)

<a id="fn-state-noteallocationfreed"></a>

### State.noteAllocationFreed

```zig
pub fn noteAllocationFreed(self: *State, bytes: usize) void
```

References: [`State`](#type-state)

<a id="fn-state-refreshallocationtotal"></a>

### State.refreshAllocationTotal

```zig
pub fn refreshAllocationTotal(self: *State) usize
```

References: [`State`](#type-state)

<a id="fn-state-currentallocationtotal"></a>

### State.currentAllocationTotal

```zig
pub fn currentAllocationTotal(self: *State) usize
```

References: [`State`](#type-state)

<a id="fn-state-tablecapacitybytes"></a>

### State.tableCapacityBytes

```zig
pub fn tableCapacityBytes(table: *const Table) usize
```

References: [`Table`](#alias-table)

<a id="fn-state-tablegcbytes"></a>

### State.tableGcBytes

```zig
pub fn tableGcBytes(table: *const Table) usize
```

References: [`Table`](#alias-table)

<a id="fn-state-notetablecapacitydelta"></a>

### State.noteTableCapacityDelta

```zig
pub fn noteTableCapacityDelta(self: *State, table: *const Table, old_capacity_bytes: usize) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-getglobal"></a>

### State.getGlobal

```zig
pub fn getGlobal(self: *State, name: []const u8) Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-currentline"></a>

### State.currentLine

```zig
pub fn currentLine(self: *State, thread: *Thread, level: i64) ?usize
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-currentextraargs"></a>

### State.currentExtraArgs

```zig
pub fn currentExtraArgs(self: *State, thread: *Thread, level: i64) ?usize
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-currentwhat"></a>

### State.currentWhat

```zig
pub fn currentWhat(self: *State, thread: *Thread, level: i64) []const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-currentfunctionname"></a>

### State.currentFunctionName

```zig
pub fn currentFunctionName(self: *State, thread: *Thread, level: i64) ?[]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-currentfunctionnamewhat"></a>

### State.currentFunctionNameWhat

```zig
pub fn currentFunctionNameWhat(self: *State, thread: *Thread, level: i64) ?[]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-setthreadhook"></a>

### State.setThreadHook

```zig
pub fn setThreadHook(self: *State, target: *Thread, hook: Value, mask: []const u8, count: u32) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-threadhookmask"></a>

### State.threadHookMask

```zig
pub fn threadHookMask(self: *State, thread: *Thread) ![]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-callhook"></a>

### State.callHook

```zig
pub fn callHook(self: *State, thread: *Thread, event: []const u8) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-putglobal"></a>

### State.putGlobal

```zig
pub fn putGlobal(self: *State, name: []const u8, value: Value) !void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-rootvalue"></a>

### State.rootValue

```zig
pub fn rootValue(self: *State, value: Value) !usize
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-unrootvalue"></a>

### State.unrootValue

```zig
pub fn unrootValue(self: *State, index: usize) void
```

References: [`State`](#type-state)

<a id="fn-state-rootedvalue"></a>

### State.rootedValue

```zig
pub fn rootedValue(self: *State, index: usize) Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-activerootcount"></a>

### State.activeRootCount

```zig
pub fn activeRootCount(self: State) usize
```

References: [`State`](#type-state)

<a id="fn-state-setapicallbackdispatch"></a>

### State.setApiCallbackDispatch

```zig
pub fn setApiCallbackDispatch(self: *State, dispatch: ApiCallbackDispatchFn, user_data: *anyopaque) void
```

References: [`State`](#type-state), [`ApiCallbackDispatchFn`](#alias-apicallbackdispatchfn)

<a id="fn-state-setcclosuredispatch"></a>

### State.setCClosureDispatch

```zig
pub fn setCClosureDispatch(self: *State, dispatch: CClosureDispatchFn, user_data: *anyopaque) void
```

References: [`State`](#type-state), [`CClosureDispatchFn`](#alias-cclosuredispatchfn)

<a id="fn-state-setcclosureresumedispatch"></a>

### State.setCClosureResumeDispatch

```zig
pub fn setCClosureResumeDispatch(self: *State, dispatch: CClosureResumeDispatchFn) void
```

References: [`State`](#type-state), [`CClosureResumeDispatchFn`](#alias-cclosureresumedispatchfn)

<a id="fn-state-setcdebughookdispatch"></a>

### State.setCDebugHookDispatch

```zig
pub fn setCDebugHookDispatch(self: *State, dispatch: CDebugHookDispatchFn) void
```

References: [`State`](#type-state), [`CDebugHookDispatchFn`](#alias-cdebughookdispatchfn)

<a id="fn-state-newcclosure"></a>

### State.newCClosure

```zig
pub fn newCClosure(self: *State, function_id: usize, upvalue_values: []const Value) !*CClosure
```

References: [`State`](#type-state), [`Value`](#alias-value), [`CClosure`](#alias-cclosure)

<a id="fn-state-newcoroutine"></a>

### State.newCoroutine

```zig
pub fn newCoroutine(self: *State, entry: Value) !*Thread
```

References: [`State`](#type-state), [`Value`](#alias-value), [`Thread`](#alias-thread)

<a id="fn-state-resumethread"></a>

### State.resumeThread

```zig
pub fn resumeThread(self: *State, target: *Thread, args: []const Value) !ProtectedCallResult
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value), [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-state-closethread"></a>

### State.closeThread

```zig
pub fn closeThread(self: *State, target: *Thread) !?Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-threadwasyielded"></a>

### State.threadWasYielded

```zig
pub fn threadWasYielded(_: *State, target: *Thread) bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-callcclosuredispatch"></a>

### State.callCClosureDispatch

```zig
pub fn callCClosureDispatch(self: *State, thread: *Thread, op: bytecode.Call, closure: *CClosure) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`CClosure`](#alias-cclosure)

<a id="fn-state-resumecclosuredispatch"></a>

### State.resumeCClosureDispatch

```zig
pub fn resumeCClosureDispatch(self: *State, thread: *Thread, args: []const Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-callapicallbackdispatch"></a>

### State.callApiCallbackDispatch

```zig
pub fn callApiCallbackDispatch(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-readfilealloc"></a>

### State.readFileAlloc

```zig
pub fn readFileAlloc(self: *State, path: []const u8) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-writestdout"></a>

### State.writeStdout

```zig
pub fn writeStdout(self: *State, bytes: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-writestderr"></a>

### State.writeStderr

```zig
pub fn writeStderr(self: *State, bytes: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-flushstdout"></a>

### State.flushStdout

```zig
pub fn flushStdout(self: *State) !void
```

References: [`State`](#type-state)

<a id="fn-state-flushstderr"></a>

### State.flushStderr

```zig
pub fn flushStderr(self: *State) !void
```

References: [`State`](#type-state)

<a id="fn-state-writefile"></a>

### State.writeFile

```zig
pub fn writeFile(self: *State, path: []const u8, data: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-removefile"></a>

### State.removeFile

```zig
pub fn removeFile(self: *State, path: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-renamefile"></a>

### State.renameFile

```zig
pub fn renameFile(self: *State, old_path: []const u8, new_path: []const u8) !void
```

References: [`State`](#type-state)

<a id="fn-state-getenv"></a>

### State.getenv

```zig
pub fn getenv(self: *State, name: []const u8) ?[]const u8
```

References: [`State`](#type-state)

<a id="fn-state-currenttime"></a>

### State.currentTime

```zig
pub fn currentTime(self: *State) !i64
```

References: [`State`](#type-state)

<a id="fn-state-executeprocess"></a>

### State.executeProcess

```zig
pub fn executeProcess(self: *State, command: []const u8) !ProcessResult
```

References: [`State`](#type-state), [`ProcessResult`](#alias-processresult)

<a id="fn-state-requireio"></a>

### State.requireIo

```zig
pub fn requireIo(self: *State, unavailable_message: []const u8) RuntimeError!std.Io
```

References: [`State`](#type-state), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-processenabled"></a>

### State.processEnabled

```zig
pub fn processEnabled(self: *State) bool
```

References: [`State`](#type-state)

<a id="fn-state-readstdin"></a>

### State.readStdin

```zig
pub fn readStdin(self: *State, spec: []const u8) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadsourceasclosure"></a>

### State.loadSourceAsClosure

```zig
pub fn loadSourceAsClosure(self: *State, source: []const u8) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadsourceasclosurenamed"></a>

### State.loadSourceAsClosureNamed

```zig
pub fn loadSourceAsClosureNamed(self: *State, source: []const u8, source_name: ?[]const u8) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadsourceasclosurenamedenv"></a>

### State.loadSourceAsClosureNamedEnv

```zig
pub fn loadSourceAsClosureNamedEnv(self: *State, source: []const u8, source_name: ?[]const u8, environment: Value) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadbinarydump"></a>

### State.loadBinaryDump

```zig
pub fn loadBinaryDump(self: *State, source: []const u8, environment: Value) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadfileasclosure"></a>

### State.loadFileAsClosure

```zig
pub fn loadFileAsClosure(self: *State, path: []const u8) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-loadfileasclosurenamed"></a>

### State.loadFileAsClosureNamed

```zig
pub fn loadFileAsClosureNamed(self: *State, path: []const u8, source_name: ?[]const u8) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-callcollect"></a>

### State.callCollect

```zig
pub fn callCollect(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror![]Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-intern"></a>

### State.intern

```zig
pub fn intern(self: *State, bytes: []const u8) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-allocatestring"></a>

### State.allocateString

```zig
pub fn allocateString(self: *State, bytes: []const u8) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-newtablewithhints"></a>

### State.newTableWithHints

```zig
pub fn newTableWithHints(self: *State, array_hint: u32, hash_hint: u32) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-newuserdata"></a>

### State.newUserdata

```zig
pub fn newUserdata(self: *State, ptr: *anyopaque, type_id: usize, type_name: []const u8, finalizer: ?UserdataFinalizer, finalizer_data: ?*const anyopaque, deinit_fn: ?UserdataDeinit) !Value
```

References: [`State`](#type-state), [`UserdataFinalizer`](#alias-userdatafinalizer), [`UserdataDeinit`](#alias-userdatadeinit), [`Value`](#alias-value)

<a id="fn-state-closeupvalues"></a>

### State.closeUpvalues

```zig
pub fn closeUpvalues(self: *State, thread: *Thread, first_stack_index: usize) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-closeframesto"></a>

### State.closeFramesTo

```zig
pub fn closeFramesTo(self: *State, thread: *Thread, frame_count: usize, error_value: ?Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-gettablevalue"></a>

### State.getTableValue

```zig
pub fn getTableValue(self: *State, table_value: Value, key_value: Value) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-gettablefromthread"></a>

### State.getTableFromThread

```zig
pub fn getTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value) !Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-settablevalue"></a>

### State.setTableValue

```zig
pub fn setTableValue(self: *State, table_value: Value, key_value: Value, value: Value) !void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-settablefromthread"></a>

### State.setTableFromThread

```zig
pub fn setTableFromThread(self: *State, thread: *Thread, table_value: Value, key_value: Value, value: Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-lengthof"></a>

### State.lengthOf

```zig
pub fn lengthOf(self: *State, thread: *Thread, value: Value) !Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-invokevalue"></a>

### State.invokeValue

```zig
pub fn invokeValue(self: *State, thread: *Thread, resolved: bytecode.Call, depth: usize) anyerror!void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-calloneresult"></a>

### State.callOneResult

```zig
pub fn callOneResult(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-calloneresultwithcontinuation"></a>

### State.callOneResultWithContinuation

```zig
pub fn callOneResultWithContinuation(self: *State, thread: *Thread, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-callonemetamethodwithcontinuation"></a>

### State.callOneMetamethodWithContinuation

```zig
pub fn callOneMetamethodWithContinuation(self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-callonemetamethod"></a>

### State.callOneMetamethod

```zig
pub fn callOneMetamethod(self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value) anyerror!Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-metamethoddebugname"></a>

### State.metamethodDebugName

```zig
pub fn metamethodDebugName(name: []const u8) []const u8
```

<a id="fn-state-calloneresultmaybecontinuation"></a>

### State.callOneResultMaybeContinuation

```zig
pub fn callOneResultMaybeContinuation(self: *State, thread: *Thread, callable: Value, args: []const Value, continuation_result: ?CallOneContinuationResult) anyerror!Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-pushcallonecontinuation"></a>

### State.pushCallOneContinuation

```zig
pub fn pushCallOneContinuation(self: *State, thread: *Thread, frame_count: usize, result: CallOneContinuationResult) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-readycallonecontinuationindex"></a>

### State.readyCallOneContinuationIndex

```zig
pub fn readyCallOneContinuationIndex(thread: *Thread) ?usize
```

References: [`Thread`](#alias-thread)

<a id="fn-state-completereadycallonecontinuation"></a>

### State.completeReadyCallOneContinuation

```zig
pub fn completeReadyCallOneContinuation(self: *State, thread: *Thread) !bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-protectedcall"></a>

### State.protectedCall

```zig
pub fn protectedCall(self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!ProtectedCallResult
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value), [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-state-protectedcallcontext"></a>

### State.protectedCallContext

```zig
pub fn protectedCallContext(_: *State, thread: *Thread) ProtectedCallContext
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-protectedcallcontextwitherrors"></a>

### State.protectedCallContextWithErrors

```zig
pub fn protectedCallContextWithErrors(self: *State, thread: *Thread) ProtectedCallContext
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-runprotectedcall"></a>

### State.runProtectedCall

```zig
pub fn runProtectedCall(self: *State, thread: *Thread, context: ProtectedCallContext, callable: Value, args: []const Value) anyerror!ProtectedCallResult
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value), [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-state-restoreprotectedcall"></a>

### State.restoreProtectedCall

```zig
pub fn restoreProtectedCall(
        self: *State,
        thread: *Thread,
        context: ProtectedCallContext,
        error_value: Value,
    ) !Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-pushprotectedcontinuation"></a>

### State.pushProtectedContinuation

```zig
pub fn pushProtectedContinuation(self: *State, thread: *Thread, context: ProtectedCallContext, base: bytecode.Register, return_count: u16, kind: ProtectedContinuationKind, handler: Value, handler_depth: usize) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-readyprotectedcontinuationindex"></a>

### State.readyProtectedContinuationIndex

```zig
pub fn readyProtectedContinuationIndex(thread: *Thread) ?usize
```

References: [`Thread`](#alias-thread)

<a id="fn-state-errorprotectedcontinuationindex"></a>

### State.errorProtectedContinuationIndex

```zig
pub fn errorProtectedContinuationIndex(thread: *Thread) ?usize
```

References: [`Thread`](#alias-thread)

<a id="fn-state-completereadyprotectedcontinuation"></a>

### State.completeReadyProtectedContinuation

```zig
pub fn completeReadyProtectedContinuation(self: *State, thread: *Thread) !bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-completeprotectedcontinuationerror"></a>

### State.completeProtectedContinuationError

```zig
pub fn completeProtectedContinuationError(self: *State, thread: *Thread, error_value: Value) !bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-returnprotectedcontinuationsuccess"></a>

### State.returnProtectedContinuationSuccess

```zig
pub fn returnProtectedContinuationSuccess(self: *State, thread: *Thread, continuation: ProtectedContinuation, values: []Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-returnprotectedcontinuationfailure"></a>

### State.returnProtectedContinuationFailure

```zig
pub fn returnProtectedContinuationFailure(self: *State, thread: *Thread, continuation: ProtectedContinuation, failure: Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-valuetostring"></a>

### State.valueToString

```zig
pub fn valueToString(self: *State, thread: *Thread, value: Value) anyerror![]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-setdebugmetatablevalue"></a>

### State.setDebugMetatableValue

```zig
pub fn setDebugMetatableValue(self: *State, value: Value, metatable_value: Value) !void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-getmetamethod"></a>

### State.getMetamethod

```zig
pub fn getMetamethod(self: *State, value: Value, name: []const u8) !?Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-settablemetatableraw"></a>

### State.setTableMetatableRaw

```zig
pub fn setTableMetatableRaw(self: *State, table: *Table, metatable: ?*Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-notetablemetatablechanged"></a>

### State.noteTableMetatableChanged

```zig
pub fn noteTableMetatableChanged(self: *State, table: *Table, old_has_metatable: bool) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-unlinktablemetatable"></a>

### State.unlinkTableMetatable

```zig
pub fn unlinkTableMetatable(self: *State, table: *Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-luatypenameforerror"></a>

### State.luaTypeNameForError

```zig
pub fn luaTypeNameForError(self: *State, value: Value) []const u8
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-jumpifbranchresult"></a>

### State.jumpIfBranchResult

```zig
pub fn jumpIfBranchResult(self: *State, thread: *Thread, result: bool, jump_if_truthy: bool, offset: bytecode.JumpOffset) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-comparevalues"></a>

### State.compareValues

```zig
pub fn compareValues(self: *State, thread: *Thread, lhs: Value, rhs: Value, op: CompareOp) !bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value), [`CompareOp`](#type-compareop)

<a id="fn-state-returnvalues"></a>

### State.returnValues

```zig
pub fn returnValues(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, values: []const Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-prepareclosureframe"></a>

### State.prepareClosureFrame

```zig
pub fn prepareClosureFrame(self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Closure`](#alias-closure)

<a id="fn-state-capturevarargs"></a>

### State.captureVarargs

```zig
pub fn captureVarargs(self: *State, thread: *Thread, source_start: usize, count: usize) ![]const Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-namedvarargtable"></a>

### State.namedVarargTable

```zig
pub fn namedVarargTable(self: *State, varargs: []const Value) !Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-resolvereturncount"></a>

### State.resolveReturnCount

```zig
pub fn resolveReturnCount(self: *State, count: u16, available: usize) !usize
```

References: [`State`](#type-state)

<a id="fn-state-returnxpcallfailure"></a>

### State.returnXpcallFailure

```zig
pub fn returnXpcallFailure(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-returnxpcallfailurefromdepth"></a>

### State.returnXpcallFailureFromDepth

```zig
pub fn returnXpcallFailureFromDepth(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, handler: Value, error_value: Value, initial_depth: usize) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-snapshotcoroutineerrortraceback"></a>

### State.snapshotCoroutineErrorTraceback

```zig
pub fn snapshotCoroutineErrorTraceback(self: *State, target: *Thread) ![]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutinecreate"></a>

### State.coroutineCreate

```zig
pub fn coroutineCreate(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutineresume"></a>

### State.coroutineResume

```zig
pub fn coroutineResume(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutineyield"></a>

### State.coroutineYield

```zig
pub fn coroutineYield(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutinestatus"></a>

### State.coroutineStatus

```zig
pub fn coroutineStatus(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutinerunning"></a>

### State.coroutineRunning

```zig
pub fn coroutineRunning(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutineisyieldable"></a>

### State.coroutineIsYieldable

```zig
pub fn coroutineIsYieldable(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutineclose"></a>

### State.coroutineClose

```zig
pub fn coroutineClose(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-coroutinewrap"></a>

### State.coroutineWrap

```zig
pub fn coroutineWrap(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-callcoroutinewrapper"></a>

### State.callCoroutineWrapper

```zig
pub fn callCoroutineWrapper(self: *State, thread: *Thread, op: bytecode.Call, target: *Thread) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-callcoroutinewrapperwithargs"></a>

### State.callCoroutineWrapperWithArgs

```zig
pub fn callCoroutineWrapperWithArgs(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-newcoroutinethread"></a>

### State.newCoroutineThread

```zig
pub fn newCoroutineThread(self: *State, entry: Value) !*Thread
```

References: [`State`](#type-state), [`Value`](#alias-value), [`Thread`](#alias-thread)

<a id="fn-state-closecoroutine"></a>

### State.closeCoroutine

```zig
pub fn closeCoroutine(self: *State, target: *Thread, error_value: ?Value) !?Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-resumecoroutine"></a>

### State.resumeCoroutine

```zig
pub fn resumeCoroutine(self: *State, target: *Thread, args: []const Value) !CoroutineResumeResult
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-startcoroutine"></a>

### State.startCoroutine

```zig
pub fn startCoroutine(self: *State, target: *Thread, args: []const Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-callableentryclosure"></a>

### State.callableEntryClosure

```zig
pub fn callableEntryClosure(self: *State) !*Closure
```

References: [`State`](#type-state), [`Closure`](#alias-closure)

<a id="fn-state-setcoroutineresumevalues"></a>

### State.setCoroutineResumeValues

```zig
pub fn setCoroutineResumeValues(self: *State, target: *Thread, args: []const Value) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-returncoroutineresumeresult"></a>

### State.returnCoroutineResumeResult

```zig
pub fn returnCoroutineResumeResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-copyvalues"></a>

### State.copyValues

```zig
pub fn copyValues(self: *State, values: []const Value) ![]Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-copystackslice"></a>

### State.copyStackSlice

```zig
pub fn copyStackSlice(self: *State, thread: *Thread, base: usize, count: usize) ![]Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-collectargs"></a>

### State.collectArgs

```zig
pub fn collectArgs(self: *State, thread: *Thread, op: bytecode.Call, first: u16) ![]Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-state-returnprotectedresult"></a>

### State.returnProtectedResult

```zig
pub fn returnProtectedResult(self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-state-expecttable"></a>

### State.expectTable

```zig
pub fn expectTable(self: *State, value: Value) !*Table
```

References: [`State`](#type-state), [`Value`](#alias-value), [`Table`](#alias-table)

<a id="fn-state-expectstring"></a>

### State.expectString

```zig
pub fn expectString(self: *State, value: Value) ![]const u8
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-expectthread"></a>

### State.expectThread

```zig
pub fn expectThread(self: *State, value: Value) !*Thread
```

References: [`State`](#type-state), [`Value`](#alias-value), [`Thread`](#alias-thread)

<a id="fn-state-collectgarbagevalue"></a>

### State.collectGarbageValue

```zig
pub fn collectGarbageValue(self: *State, thread: *Thread, op: bytecode.Call) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-collectgarbageparam"></a>

### State.collectGarbageParam

```zig
pub fn collectGarbageParam(self: *State, value: Value) !GcParam
```

References: [`State`](#type-state), [`Value`](#alias-value), [`GcParam`](#alias-gcparam)

<a id="fn-state-collectgarbagestep"></a>

### State.collectGarbageStep

```zig
pub fn collectGarbageStep(self: *State, thread: ?*Thread, budget: i64) !bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-collectgarbage"></a>

### State.collectGarbage

```zig
pub fn collectGarbage(self: *State) !void
```

References: [`State`](#type-state)

<a id="fn-state-collectgarbagesteppublic"></a>

### State.collectGarbageStepPublic

```zig
pub fn collectGarbageStepPublic(self: *State, budget: i64) !bool
```

References: [`State`](#type-state)

<a id="fn-state-allocationbytecount"></a>

### State.allocationByteCount

```zig
pub fn allocationByteCount(self: State) usize
```

References: [`State`](#type-state)

<a id="fn-state-gcisrunning"></a>

### State.gcIsRunning

```zig
pub fn gcIsRunning(self: State) bool
```

References: [`State`](#type-state)

<a id="fn-state-stopgc"></a>

### State.stopGc

```zig
pub fn stopGc(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-restartgc"></a>

### State.restartGc

```zig
pub fn restartGc(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-switchgcmode"></a>

### State.switchGcMode

```zig
pub fn switchGcMode(self: *State, mode: GcMode) GcMode
```

References: [`State`](#type-state), [`GcMode`](#alias-gcmode)

<a id="fn-state-gcparam"></a>

### State.gcParam

```zig
pub fn gcParam(self: State, param: GcParam) i64
```

References: [`State`](#type-state), [`GcParam`](#alias-gcparam)

<a id="fn-state-setgcparam"></a>

### State.setGcParam

```zig
pub fn setGcParam(self: *State, param: GcParam, value: i64) void
```

References: [`State`](#type-state), [`GcParam`](#alias-gcparam)

<a id="fn-state-collectgarbageconservatively"></a>

### State.collectGarbageConservatively

```zig
pub fn collectGarbageConservatively(self: *State, thread: ?*Thread) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-collectgarbagewithfinalizers"></a>

### State.collectGarbageWithFinalizers

```zig
pub fn collectGarbageWithFinalizers(self: *State, thread: ?*Thread) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-collectgarbagewithfinalizersmode"></a>

### State.collectGarbageWithFinalizersMode

```zig
pub fn collectGarbageWithFinalizersMode(self: *State, thread: ?*Thread, mark_all_stack_registers: bool) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-shouldrunautogc"></a>

### State.shouldRunAutoGc

```zig
pub fn shouldRunAutoGc(self: *State) bool
```

References: [`State`](#type-state)

<a id="fn-state-resetautogcthreshold"></a>

### State.resetAutoGcThreshold

```zig
pub fn resetAutoGcThreshold(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-resetmarks"></a>

### State.resetMarks

```zig
pub fn resetMarks(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-markroots"></a>

### State.markRoots

```zig
pub fn markRoots(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-markvalue"></a>

### State.markValue

```zig
pub fn markValue(self: *State, value: Value) void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-markruntimeerrorpayload"></a>

### State.markRuntimeErrorPayload

```zig
pub fn markRuntimeErrorPayload(self: *State, payload: ?RuntimeErrorPayload) void
```

References: [`State`](#type-state), [`RuntimeErrorPayload`](#alias-runtimeerrorpayload)

<a id="fn-state-markstring"></a>

### State.markString

```zig
pub fn markString(self: *State, bytes: []const u8) void
```

References: [`State`](#type-state)

<a id="fn-state-marktable"></a>

### State.markTable

```zig
pub fn markTable(self: *State, table: *Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-markuserdata"></a>

### State.markUserdata

```zig
pub fn markUserdata(self: *State, userdata: *Userdata) void
```

References: [`State`](#type-state), [`Userdata`](#alias-userdata)

<a id="fn-state-markweaktablestrings"></a>

### State.markWeakTableStrings

```zig
pub fn markWeakTableStrings(self: *State, table: *Table, keys: bool, values: bool) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-markweakstring"></a>

### State.markWeakString

```zig
pub fn markWeakString(self: *State, value: Value) void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-markclosure"></a>

### State.markClosure

```zig
pub fn markClosure(self: *State, closure: *Closure) void
```

References: [`State`](#type-state), [`Closure`](#alias-closure)

<a id="fn-state-markcclosure"></a>

### State.markCClosure

```zig
pub fn markCClosure(self: *State, closure: *CClosure) void
```

References: [`State`](#type-state), [`CClosure`](#alias-cclosure)

<a id="fn-state-markupvalue"></a>

### State.markUpvalue

```zig
pub fn markUpvalue(self: *State, upvalue: *Upvalue) void
```

References: [`State`](#type-state), [`Upvalue`](#alias-upvalue)

<a id="fn-state-markcupvalue"></a>

### State.markCUpvalue

```zig
pub fn markCUpvalue(self: *State, upvalue: *CUpvalue) void
```

References: [`State`](#type-state), [`CUpvalue`](#alias-cupvalue)

<a id="fn-state-markthread"></a>

### State.markThread

```zig
pub fn markThread(self: *State, thread: *Thread) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-markthreadstack"></a>

### State.markThreadStack

```zig
pub fn markThreadStack(self: *State, thread: *Thread) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-markstackrange"></a>

### State.markStackRange

```zig
pub fn markStackRange(self: *State, thread: *Thread, base: usize, count: usize) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-weakmode"></a>

### State.weakMode

```zig
pub fn weakMode(self: *State, table: *Table) WeakMode
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-hasweaktables"></a>

### State.hasWeakTables

```zig
pub fn hasWeakTables(self: *State) bool
```

References: [`State`](#type-state)

<a id="fn-state-markephemeronvalues"></a>

### State.markEphemeronValues

```zig
pub fn markEphemeronValues(self: *State, table: *Table) bool
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-convergeephemerons"></a>

### State.convergeEphemerons

```zig
pub fn convergeEphemerons(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-markvaluechanged"></a>

### State.markValueChanged

```zig
pub fn markValueChanged(self: *State, value: Value) bool
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-valueismarked"></a>

### State.valueIsMarked

```zig
pub fn valueIsMarked(self: *State, value: Value) bool
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-valueisweaklycleared"></a>

### State.valueIsWeaklyCleared

```zig
pub fn valueIsWeaklyCleared(self: *State, value: Value) bool
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-valueiscollectableunmarked"></a>

### State.valueIsCollectableUnmarked

```zig
pub fn valueIsCollectableUnmarked(self: *State, value: Value) bool
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-clearweakvalues"></a>

### State.clearWeakValues

```zig
pub fn clearWeakValues(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-clearweaktables"></a>

### State.clearWeakTables

```zig
pub fn clearWeakTables(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-cleardeadhashkeys"></a>

### State.clearDeadHashKeys

```zig
pub fn clearDeadHashKeys(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-clearweaktablevalues"></a>

### State.clearWeakTableValues

```zig
pub fn clearWeakTableValues(self: *State, table: *Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-clearweaktablekeys"></a>

### State.clearWeakTableKeys

```zig
pub fn clearWeakTableKeys(self: *State, table: *Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-writetablebarrier"></a>

### State.writeTableBarrier

```zig
pub fn writeTableBarrier(self: *State, table: *Table, key: Value, value: Value) void
```

References: [`State`](#type-state), [`Table`](#alias-table), [`Value`](#alias-value)

<a id="fn-state-writebarrier"></a>

### State.writeBarrier

```zig
pub fn writeBarrier(self: *State, parent_marked: bool, child: Value) void
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-runpendingfinalizers"></a>

### State.runPendingFinalizers

```zig
pub fn runPendingFinalizers(self: *State, thread: ?*Thread) !void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-runpendinguserdatafinalizers"></a>

### State.runPendingUserdataFinalizers

```zig
pub fn runPendingUserdataFinalizers(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-callablevalue"></a>

### State.callableValue

```zig
pub fn callableValue(self: *State, value: Value) bool
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="fn-state-sweepstrings"></a>

### State.sweepStrings

```zig
pub fn sweepStrings(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepuserdata"></a>

### State.sweepUserdata

```zig
pub fn sweepUserdata(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweeptables"></a>

### State.sweepTables

```zig
pub fn sweepTables(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepclosures"></a>

### State.sweepClosures

```zig
pub fn sweepClosures(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepcclosures"></a>

### State.sweepCClosures

```zig
pub fn sweepCClosures(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepupvalues"></a>

### State.sweepUpvalues

```zig
pub fn sweepUpvalues(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepcupvalues"></a>

### State.sweepCUpvalues

```zig
pub fn sweepCUpvalues(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-sweepthreads"></a>

### State.sweepThreads

```zig
pub fn sweepThreads(self: *State) void
```

References: [`State`](#type-state)

<a id="fn-state-findstringallocation"></a>

### State.findStringAllocation

```zig
pub fn findStringAllocation(self: *State, bytes: []const u8) ?usize
```

References: [`State`](#type-state)

<a id="fn-state-istrackedthread"></a>

### State.isTrackedThread

```zig
pub fn isTrackedThread(self: *State, thread: *Thread) bool
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-istrackedtable"></a>

### State.isTrackedTable

```zig
pub fn isTrackedTable(self: *State, table: *Table) bool
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-istrackeduserdata"></a>

### State.isTrackedUserdata

```zig
pub fn isTrackedUserdata(self: *State, userdata: *Userdata) bool
```

References: [`State`](#type-state), [`Userdata`](#alias-userdata)

<a id="fn-state-istrackedclosure"></a>

### State.isTrackedClosure

```zig
pub fn isTrackedClosure(self: *State, closure: *Closure) bool
```

References: [`State`](#type-state), [`Closure`](#alias-closure)

<a id="fn-state-istrackedcclosure"></a>

### State.isTrackedCClosure

```zig
pub fn isTrackedCClosure(self: *State, closure: *CClosure) bool
```

References: [`State`](#type-state), [`CClosure`](#alias-cclosure)

<a id="fn-state-istrackedupvalue"></a>

### State.isTrackedUpvalue

```zig
pub fn isTrackedUpvalue(self: *State, upvalue: *Upvalue) bool
```

References: [`State`](#type-state), [`Upvalue`](#alias-upvalue)

<a id="fn-state-istrackedcupvalue"></a>

### State.isTrackedCUpvalue

```zig
pub fn isTrackedCUpvalue(self: *State, upvalue: *CUpvalue) bool
```

References: [`State`](#type-state), [`CUpvalue`](#alias-cupvalue)

<a id="fn-state-destroytable"></a>

### State.destroyTable

```zig
pub fn destroyTable(self: *State, table: *Table) void
```

References: [`State`](#type-state), [`Table`](#alias-table)

<a id="fn-state-destroyuserdata"></a>

### State.destroyUserdata

```zig
pub fn destroyUserdata(self: *State, userdata: *Userdata) void
```

References: [`State`](#type-state), [`Userdata`](#alias-userdata)

<a id="fn-state-destroyclosure"></a>

### State.destroyClosure

```zig
pub fn destroyClosure(self: *State, closure: *Closure) void
```

References: [`State`](#type-state), [`Closure`](#alias-closure)

<a id="fn-state-destroycclosure"></a>

### State.destroyCClosure

```zig
pub fn destroyCClosure(self: *State, closure: *CClosure) void
```

References: [`State`](#type-state), [`CClosure`](#alias-cclosure)

<a id="fn-state-destroythread"></a>

### State.destroyThread

```zig
pub fn destroyThread(self: *State, thread: *Thread) void
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-allocationstats"></a>

### State.allocationStats

```zig
pub fn allocationStats(self: State) RuntimeAllocationStats
```

References: [`State`](#type-state)

<a id="fn-state-failruntimedetail"></a>

### State.failRuntimeDetail

```zig
pub fn failRuntimeDetail(self: *State, thread: ?*Thread, detail: []const u8) RuntimeError
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-errordetailalloc"></a>

### State.errorDetailAlloc

```zig
pub fn errorDetailAlloc(self: *State, allocator: std.mem.Allocator, err: anyerror) ![]const u8
```

References: [`State`](#type-state)

<a id="fn-state-fail"></a>

### State.fail

```zig
pub fn fail(self: *State, message: []const u8) RuntimeError
```

References: [`State`](#type-state), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-failargument"></a>

### State.failArgument

```zig
pub fn failArgument(self: *State, function_name: []const u8, index: u16, detail: errors.ArgumentErrorDetail) RuntimeError
```

References: [`State`](#type-state), [`errors.ArgumentErrorDetail`](../errors.md#type-argumenterrordetail), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-failargumentmessage"></a>

### State.failArgumentMessage

```zig
pub fn failArgumentMessage(self: *State, function_name: []const u8, index: u16, message: []const u8) RuntimeError
```

References: [`State`](#type-state), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-failargumenttype"></a>

### State.failArgumentType

```zig
pub fn failArgumentType(self: *State, function_name: []const u8, index: u16, expected: []const u8, actual: Value) RuntimeError
```

References: [`State`](#type-state), [`Value`](#alias-value), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-expectargumentstring"></a>

### State.expectArgumentString

```zig
pub fn expectArgumentString(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) ![]const u8
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-argumentdisplayindex"></a>

### State.argumentDisplayIndex

```zig
pub fn argumentDisplayIndex(self: *State, thread: *Thread, function_name: []const u8, index: u16) u16
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-expectargumenttable"></a>

### State.expectArgumentTable

```zig
pub fn expectArgumentTable(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) !*Table
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Table`](#alias-table)

<a id="fn-state-argumentinteger"></a>

### State.argumentInteger

```zig
pub fn argumentInteger(self: *State, thread: *Thread, op: bytecode.Call, function_name: []const u8, index: u16) !i64
```

References: [`State`](#type-state), [`Thread`](#alias-thread)

<a id="fn-state-failvalue"></a>

### State.failValue

```zig
pub fn failValue(self: *State, value: Value) RuntimeError
```

References: [`State`](#type-state), [`Value`](#alias-value), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-throwvalue"></a>

### State.throwValue

```zig
pub fn throwValue(self: *State, value: Value) RuntimeError
```

References: [`State`](#type-state), [`Value`](#alias-value), [`RuntimeError`](#alias-runtimeerror)

<a id="fn-state-currenterrorvalue"></a>

### State.currentErrorValue

```zig
pub fn currentErrorValue(self: *State) Value
```

References: [`State`](#type-state), [`Value`](#alias-value)

<a id="type-compareop"></a>

## CompareOp

```zig
pub const CompareOp = enum {
    lt,
    le,
};
```

<a id="fn-valuesequal"></a>

## valuesEqual

```zig
pub fn valuesEqual(lhs: Value, rhs: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-truthy"></a>

## truthy

```zig
pub fn truthy(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-tointeger"></a>

## toInteger

```zig
pub fn toInteger(value: Value) ?i64
```

References: [`Value`](#alias-value)

<a id="fn-tonumber"></a>

## toNumber

```zig
pub fn toNumber(value: Value) !f64
```

References: [`Value`](#alias-value)

<a id="fn-appendluastring"></a>

## appendLuaString

```zig
pub fn appendLuaString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void
```

References: [`Value`](#alias-value)

<a id="fn-localactiveat"></a>

## localActiveAt

```zig
pub fn localActiveAt(local: proto_mod.LocalDebug, pc: usize) bool
```

<a id="fn-parseintegerstrict"></a>

## parseIntegerStrict

```zig
pub fn parseIntegerStrict(text: []const u8) ?i64
```

<a id="fn-parseluanumber"></a>

## parseLuaNumber

```zig
pub fn parseLuaNumber(text: []const u8) !f64
```

<a id="fn-floattointeger"></a>

## floatToInteger

```zig
pub fn floatToInteger(number: f64) ?i64
```

<a id="fn-trimascii"></a>

## trimAscii

```zig
pub fn trimAscii(text: []const u8) []const u8
```

<a id="fn-runtimeargvalue"></a>

## runtimeArgValue

```zig
pub fn runtimeArgValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-argvalue"></a>

## argValue

```zig
pub fn argValue(state: *State, thread: *Thread, op: bytecode.Call, index: u16) Value
```

References: [`State`](#type-state), [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-appendvalue"></a>

## appendValue

```zig
pub fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void
```

References: [`Value`](#alias-value)

<a id="fn-isfilevalue"></a>

## isFileValue

```zig
pub fn isFileValue(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-isclosedfilevalue"></a>

## isClosedFileValue

```zig
pub fn isClosedFileValue(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-appendnumber"></a>

## appendNumber

```zig
pub fn appendNumber(allocator: std.mem.Allocator, out: *std.ArrayList(u8), number: f64) !void
```

<a id="fn-appendfmt"></a>

## appendFmt

```zig
pub fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void
```

