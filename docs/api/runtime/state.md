# runtime.state

## Navigation

- [API Index](../README.md)
- Previous: [testing.process](../testing/process.md)
- Next: [runtime.call](../runtime/call.md)
- Parent: [runtime](../runtime.md)

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
- [ClockCapability](#alias-clockcapability)
- [ProcessCapability](#alias-processcapability)
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
    environment: ?*const std.process.Environ.Map = null,
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

- [init](#fn-state-init)
- [initWithOptions](#fn-state-initwithoptions)
- [stackValueLimit](#fn-state-stackvaluelimit)
- [callFrameLimit](#fn-state-callframelimit)
- [fileMetatable](#fn-state-filemetatable)
- [deinit](#fn-state-deinit)
- [execute](#fn-state-execute)
- [callLoadedClosure](#fn-state-callloadedclosure)
- [protectedCallLoadedClosure](#fn-state-protectedcallloadedclosure)
- [executeSourceChunk](#fn-state-executesourcechunk)
- [executeSourceChunkNamed](#fn-state-executesourcechunknamed)
- [runThreadUntil](#fn-state-runthreaduntil)
- [checkExecutionLimits](#fn-state-checkexecutionlimits)
- [noteAllocation](#fn-state-noteallocation)
- [noteAllocationFreed](#fn-state-noteallocationfreed)
- [refreshAllocationTotal](#fn-state-refreshallocationtotal)
- [currentAllocationTotal](#fn-state-currentallocationtotal)
- [tableCapacityBytes](#fn-state-tablecapacitybytes)
- [tableGcBytes](#fn-state-tablegcbytes)
- [noteTableCapacityDelta](#fn-state-notetablecapacitydelta)
- [getGlobal](#fn-state-getglobal)
- [currentLine](#fn-state-currentline)
- [currentExtraArgs](#fn-state-currentextraargs)
- [currentWhat](#fn-state-currentwhat)
- [currentFunctionName](#fn-state-currentfunctionname)
- [currentFunctionNameWhat](#fn-state-currentfunctionnamewhat)
- [setThreadHook](#fn-state-setthreadhook)
- [threadHookMask](#fn-state-threadhookmask)
- [callHook](#fn-state-callhook)
- [putGlobal](#fn-state-putglobal)
- [rootValue](#fn-state-rootvalue)
- [unrootValue](#fn-state-unrootvalue)
- [rootedValue](#fn-state-rootedvalue)
- [activeRootCount](#fn-state-activerootcount)
- [setApiCallbackDispatch](#fn-state-setapicallbackdispatch)
- [setCClosureDispatch](#fn-state-setcclosuredispatch)
- [setCClosureResumeDispatch](#fn-state-setcclosureresumedispatch)
- [setCDebugHookDispatch](#fn-state-setcdebughookdispatch)
- [newCClosure](#fn-state-newcclosure)
- [newCoroutine](#fn-state-newcoroutine)
- [resumeThread](#fn-state-resumethread)
- [closeThread](#fn-state-closethread)
- [threadWasYielded](#fn-state-threadwasyielded)
- [callCClosureDispatch](#fn-state-callcclosuredispatch)
- [resumeCClosureDispatch](#fn-state-resumecclosuredispatch)
- [callApiCallbackDispatch](#fn-state-callapicallbackdispatch)
- [readFileAlloc](#fn-state-readfilealloc)
- [writeStdout](#fn-state-writestdout)
- [writeStderr](#fn-state-writestderr)
- [flushStdout](#fn-state-flushstdout)
- [flushStderr](#fn-state-flushstderr)
- [writeFile](#fn-state-writefile)
- [removeFile](#fn-state-removefile)
- [renameFile](#fn-state-renamefile)
- [getenv](#fn-state-getenv)
- [currentTime](#fn-state-currenttime)
- [requireIo](#fn-state-requireio)
- [processEnabled](#fn-state-processenabled)
- [readStdin](#fn-state-readstdin)
- [loadSourceAsClosure](#fn-state-loadsourceasclosure)
- [loadSourceAsClosureNamed](#fn-state-loadsourceasclosurenamed)
- [loadSourceAsClosureNamedEnv](#fn-state-loadsourceasclosurenamedenv)
- [loadBinaryDump](#fn-state-loadbinarydump)
- [loadFileAsClosure](#fn-state-loadfileasclosure)
- [loadFileAsClosureNamed](#fn-state-loadfileasclosurenamed)
- [callCollect](#fn-state-callcollect)
- [intern](#fn-state-intern)
- [allocateString](#fn-state-allocatestring)
- [newTableWithHints](#fn-state-newtablewithhints)
- [newUserdata](#fn-state-newuserdata)
- [closeUpvalues](#fn-state-closeupvalues)
- [closeFramesTo](#fn-state-closeframesto)
- [getTableValue](#fn-state-gettablevalue)
- [getTableFromThread](#fn-state-gettablefromthread)
- [setTableValue](#fn-state-settablevalue)
- [setTableFromThread](#fn-state-settablefromthread)
- [lengthOf](#fn-state-lengthof)
- [invokeValue](#fn-state-invokevalue)
- [callOneResult](#fn-state-calloneresult)
- [callOneResultWithContinuation](#fn-state-calloneresultwithcontinuation)
- [callOneMetamethodWithContinuation](#fn-state-callonemetamethodwithcontinuation)
- [callOneMetamethod](#fn-state-callonemetamethod)
- [metamethodDebugName](#fn-state-metamethoddebugname)
- [callOneResultMaybeContinuation](#fn-state-calloneresultmaybecontinuation)
- [pushCallOneContinuation](#fn-state-pushcallonecontinuation)
- [readyCallOneContinuationIndex](#fn-state-readycallonecontinuationindex)
- [completeReadyCallOneContinuation](#fn-state-completereadycallonecontinuation)
- [protectedCall](#fn-state-protectedcall)
- [protectedCallContext](#fn-state-protectedcallcontext)
- [protectedCallContextWithErrors](#fn-state-protectedcallcontextwitherrors)
- [runProtectedCall](#fn-state-runprotectedcall)
- [restoreProtectedCall](#fn-state-restoreprotectedcall)
- [pushProtectedContinuation](#fn-state-pushprotectedcontinuation)
- [readyProtectedContinuationIndex](#fn-state-readyprotectedcontinuationindex)
- [errorProtectedContinuationIndex](#fn-state-errorprotectedcontinuationindex)
- [completeReadyProtectedContinuation](#fn-state-completereadyprotectedcontinuation)
- [completeProtectedContinuationError](#fn-state-completeprotectedcontinuationerror)
- [returnProtectedContinuationSuccess](#fn-state-returnprotectedcontinuationsuccess)
- [returnProtectedContinuationFailure](#fn-state-returnprotectedcontinuationfailure)
- [valueToString](#fn-state-valuetostring)
- [setDebugMetatableValue](#fn-state-setdebugmetatablevalue)
- [getMetamethod](#fn-state-getmetamethod)
- [setTableMetatableRaw](#fn-state-settablemetatableraw)
- [noteTableMetatableChanged](#fn-state-notetablemetatablechanged)
- [unlinkTableMetatable](#fn-state-unlinktablemetatable)
- [luaTypeNameForError](#fn-state-luatypenameforerror)
- [jumpIfBranchResult](#fn-state-jumpifbranchresult)
- [compareValues](#fn-state-comparevalues)
- [returnValues](#fn-state-returnvalues)
- [prepareClosureFrame](#fn-state-prepareclosureframe)
- [captureVarargs](#fn-state-capturevarargs)
- [namedVarargTable](#fn-state-namedvarargtable)
- [resolveReturnCount](#fn-state-resolvereturncount)
- [returnXpcallFailure](#fn-state-returnxpcallfailure)
- [returnXpcallFailureFromDepth](#fn-state-returnxpcallfailurefromdepth)
- [snapshotCoroutineErrorTraceback](#fn-state-snapshotcoroutineerrortraceback)
- [coroutineCreate](#fn-state-coroutinecreate)
- [coroutineResume](#fn-state-coroutineresume)
- [coroutineYield](#fn-state-coroutineyield)
- [coroutineStatus](#fn-state-coroutinestatus)
- [coroutineRunning](#fn-state-coroutinerunning)
- [coroutineIsYieldable](#fn-state-coroutineisyieldable)
- [coroutineClose](#fn-state-coroutineclose)
- [coroutineWrap](#fn-state-coroutinewrap)
- [callCoroutineWrapper](#fn-state-callcoroutinewrapper)
- [callCoroutineWrapperWithArgs](#fn-state-callcoroutinewrapperwithargs)
- [newCoroutineThread](#fn-state-newcoroutinethread)
- [closeCoroutine](#fn-state-closecoroutine)
- [resumeCoroutine](#fn-state-resumecoroutine)
- [startCoroutine](#fn-state-startcoroutine)
- [callableEntryClosure](#fn-state-callableentryclosure)
- [setCoroutineResumeValues](#fn-state-setcoroutineresumevalues)
- [returnCoroutineResumeResult](#fn-state-returncoroutineresumeresult)
- [copyValues](#fn-state-copyvalues)
- [copyStackSlice](#fn-state-copystackslice)
- [collectArgs](#fn-state-collectargs)
- [returnProtectedResult](#fn-state-returnprotectedresult)
- [expectTable](#fn-state-expecttable)
- [expectString](#fn-state-expectstring)
- [expectThread](#fn-state-expectthread)
- [collectGarbageValue](#fn-state-collectgarbagevalue)
- [collectGarbageParam](#fn-state-collectgarbageparam)
- [collectGarbageStep](#fn-state-collectgarbagestep)
- [collectGarbage](#fn-state-collectgarbage)
- [collectGarbageStepPublic](#fn-state-collectgarbagesteppublic)
- [allocationByteCount](#fn-state-allocationbytecount)
- [gcIsRunning](#fn-state-gcisrunning)
- [stopGc](#fn-state-stopgc)
- [restartGc](#fn-state-restartgc)
- [switchGcMode](#fn-state-switchgcmode)
- [gcParam](#fn-state-gcparam)
- [setGcParam](#fn-state-setgcparam)
- [collectGarbageConservatively](#fn-state-collectgarbageconservatively)
- [collectGarbageWithFinalizers](#fn-state-collectgarbagewithfinalizers)
- [collectGarbageWithFinalizersMode](#fn-state-collectgarbagewithfinalizersmode)
- [shouldRunAutoGc](#fn-state-shouldrunautogc)
- [resetAutoGcThreshold](#fn-state-resetautogcthreshold)
- [resetMarks](#fn-state-resetmarks)
- [markRoots](#fn-state-markroots)
- [markValue](#fn-state-markvalue)
- [markRuntimeErrorPayload](#fn-state-markruntimeerrorpayload)
- [markString](#fn-state-markstring)
- [markTable](#fn-state-marktable)
- [markUserdata](#fn-state-markuserdata)
- [markWeakTableStrings](#fn-state-markweaktablestrings)
- [markWeakString](#fn-state-markweakstring)
- [markClosure](#fn-state-markclosure)
- [markCClosure](#fn-state-markcclosure)
- [markUpvalue](#fn-state-markupvalue)
- [markCUpvalue](#fn-state-markcupvalue)
- [markThread](#fn-state-markthread)
- [markThreadStack](#fn-state-markthreadstack)
- [markStackRange](#fn-state-markstackrange)
- [weakMode](#fn-state-weakmode)
- [hasWeakTables](#fn-state-hasweaktables)
- [markEphemeronValues](#fn-state-markephemeronvalues)
- [convergeEphemerons](#fn-state-convergeephemerons)
- [markValueChanged](#fn-state-markvaluechanged)
- [valueIsMarked](#fn-state-valueismarked)
- [valueIsWeaklyCleared](#fn-state-valueisweaklycleared)
- [valueIsCollectableUnmarked](#fn-state-valueiscollectableunmarked)
- [clearWeakValues](#fn-state-clearweakvalues)
- [clearWeakTables](#fn-state-clearweaktables)
- [clearDeadHashKeys](#fn-state-cleardeadhashkeys)
- [clearWeakTableValues](#fn-state-clearweaktablevalues)
- [clearWeakTableKeys](#fn-state-clearweaktablekeys)
- [writeTableBarrier](#fn-state-writetablebarrier)
- [writeBarrier](#fn-state-writebarrier)
- [runPendingFinalizers](#fn-state-runpendingfinalizers)
- [runPendingUserdataFinalizers](#fn-state-runpendinguserdatafinalizers)
- [callableValue](#fn-state-callablevalue)
- [sweepStrings](#fn-state-sweepstrings)
- [sweepUserdata](#fn-state-sweepuserdata)
- [sweepTables](#fn-state-sweeptables)
- [sweepClosures](#fn-state-sweepclosures)
- [sweepCClosures](#fn-state-sweepcclosures)
- [sweepUpvalues](#fn-state-sweepupvalues)
- [sweepCUpvalues](#fn-state-sweepcupvalues)
- [sweepThreads](#fn-state-sweepthreads)
- [findStringAllocation](#fn-state-findstringallocation)
- [isTrackedThread](#fn-state-istrackedthread)
- [isTrackedTable](#fn-state-istrackedtable)
- [isTrackedUserdata](#fn-state-istrackeduserdata)
- [isTrackedClosure](#fn-state-istrackedclosure)
- [isTrackedCClosure](#fn-state-istrackedcclosure)
- [isTrackedUpvalue](#fn-state-istrackedupvalue)
- [isTrackedCUpvalue](#fn-state-istrackedcupvalue)
- [destroyTable](#fn-state-destroytable)
- [destroyUserdata](#fn-state-destroyuserdata)
- [destroyClosure](#fn-state-destroyclosure)
- [destroyCClosure](#fn-state-destroycclosure)
- [destroyThread](#fn-state-destroythread)
- [allocationStats](#fn-state-allocationstats)
- [failRuntimeDetail](#fn-state-failruntimedetail)
- [errorDetailAlloc](#fn-state-errordetailalloc)
- [fail](#fn-state-fail)
- [failArgument](#fn-state-failargument)
- [failArgumentMessage](#fn-state-failargumentmessage)
- [failArgumentType](#fn-state-failargumenttype)
- [expectArgumentString](#fn-state-expectargumentstring)
- [argumentDisplayIndex](#fn-state-argumentdisplayindex)
- [expectArgumentTable](#fn-state-expectargumenttable)
- [argumentInteger](#fn-state-argumentinteger)
- [failValue](#fn-state-failvalue)
- [throwValue](#fn-state-throwvalue)
- [currentErrorValue](#fn-state-currenterrorvalue)

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
pub const CompareOp = enum { ... };
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

