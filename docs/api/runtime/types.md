# runtime.types

## Navigation

- [API Index](../README.md)
- Previous: [runtime.chunk](../runtime/chunk.md)
- Next: [runtime.value](../runtime/value.md)
- Parent: [runtime](../runtime.md)

## Types

- [Value](#type-value)
- [NativeFn](#type-nativefn)
- [ProtectedCallResult](#type-protectedcallresult)
- [DebugHookEvent](#type-debughookevent)
- [CDebugHookContext](#type-cdebughookcontext)
- [CClosureContext](#type-cclosurecontext)
- [CClosureResumeContext](#type-cclosureresumecontext)
- [ApiCallbackContext](#type-apicallbackcontext)
- [RuntimeErrorPayload](#type-runtimeerrorpayload)
- [ProtectedCallContext](#type-protectedcallcontext)
- [ProtectedContinuationKind](#type-protectedcontinuationkind)
- [ProtectedContinuation](#type-protectedcontinuation)
- [GenericForContinuation](#type-genericforcontinuation)
- [BranchContinuation](#type-branchcontinuation)
- [TailCallContinuation](#type-tailcallcontinuation)
- [CallOneContinuationResult](#type-callonecontinuationresult)
- [CallOneContinuation](#type-callonecontinuation)
- [CoroutineResumeResult](#type-coroutineresumeresult)
- [Closure](#type-closure)
- [CClosure](#type-cclosure)
- [CUpvalue](#type-cupvalue)
- [Upvalue](#type-upvalue)
- [TableEntry](#type-tableentry)
- [Table](#type-table)
- [Userdata](#type-userdata)
- [Thread](#type-thread)
- [ThreadStatus](#type-threadstatus)
- [CallFrame](#type-callframe)
- [StringAllocation](#type-stringallocation)
- [GcMode](#type-gcmode)
- [GcParam](#type-gcparam)
- [GcParams](#type-gcparams)
- [WeakMode](#type-weakmode)
- [RuntimeAllocationStats](#type-runtimeallocationstats)

## Constants

- [RuntimeError](#const-runtimeerror)
- [UserdataFinalizer](#const-userdatafinalizer)
- [UserdataDeinit](#const-userdatadeinit)
- [ApiCallbackDispatchFn](#const-apicallbackdispatchfn)
- [CClosureDispatchFn](#const-cclosuredispatchfn)
- [CClosureResumeDispatchFn](#const-cclosureresumedispatchfn)
- [CDebugHookDispatchFn](#const-cdebughookdispatchfn)
- [TableEntryIndex](#const-tableentryindex)
- [PointerAllocationIndex](#const-pointerallocationindex)

<a id="const-runtimeerror"></a>

## RuntimeError

```zig
pub const RuntimeError =...;
```

<a id="type-value"></a>

## Value

```zig
pub const Value = union(enum) {
    boolean: bool,
    integer: i64,
    number: f64,
    string: []const u8,
    table: *Table,
    userdata: *Userdata,
    closure: *Closure,
    c_closure: *CClosure,
    thread: *Thread,
    coroutine_wrapper: *Thread,
    gmatch_iterator: *Table,
    native: NativeFn,
};
```

<a id="type-nativefn"></a>

## NativeFn

```zig
pub const NativeFn = enum { ... };
```

### Nested Declarations

- [name](#fn-nativefn-name)

<a id="fn-nativefn-name"></a>

### NativeFn.name

```zig
pub fn name(self: NativeFn) []const u8
```

References: [`NativeFn`](#type-nativefn)

<a id="const-userdatafinalizer"></a>

## UserdataFinalizer

```zig
pub const UserdataFinalizer = *const fn (*anyopaque, ?*const anyopaque) void;
```

<a id="const-userdatadeinit"></a>

## UserdataDeinit

```zig
pub const UserdataDeinit = *const fn (std.mem.Allocator, *anyopaque) void;
```

<a id="type-protectedcallresult"></a>

## ProtectedCallResult

```zig
pub const ProtectedCallResult = union(enum) {
    success: []Value,
    failure: Value,
};
```

<a id="const-apicallbackdispatchfn"></a>

## ApiCallbackDispatchFn

```zig
pub const ApiCallbackDispatchFn = *const fn (*ApiCallbackContext) anyerror!void;
```

References: [`ApiCallbackContext`](#type-apicallbackcontext)

<a id="const-cclosuredispatchfn"></a>

## CClosureDispatchFn

```zig
pub const CClosureDispatchFn = *const fn (*CClosureContext) anyerror!void;
```

References: [`CClosureContext`](#type-cclosurecontext)

<a id="const-cclosureresumedispatchfn"></a>

## CClosureResumeDispatchFn

```zig
pub const CClosureResumeDispatchFn = *const fn (*CClosureResumeContext) anyerror!void;
```

References: [`CClosureResumeContext`](#type-cclosureresumecontext)

<a id="const-cdebughookdispatchfn"></a>

## CDebugHookDispatchFn

```zig
pub const CDebugHookDispatchFn = *const fn (*CDebugHookContext) anyerror!void;
```

References: [`CDebugHookContext`](#type-cdebughookcontext)

<a id="type-debughookevent"></a>

## DebugHookEvent

```zig
pub const DebugHookEvent = enum { ... };
```

<a id="type-cdebughookcontext"></a>

## CDebugHookContext

```zig
pub const CDebugHookContext = struct {
    state: *State,
    thread: *Thread,
    event: DebugHookEvent,
    currentline: ?usize = null,
    ftransfer: i64 = 0,
    ntransfer: usize = 0,
    user_data: ?*anyopaque,
};
```

<a id="type-cclosurecontext"></a>

## CClosureContext

```zig
pub const CClosureContext = struct {
    state: *State,
    thread: *Thread,
    op: bytecode.Call,
    closure: *CClosure,
    user_data: ?*anyopaque,
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,
};
```

### Nested Declarations

- [deinit](#fn-cclosurecontext-deinit)
- [argCount](#fn-cclosurecontext-argcount)
- [argValue](#fn-cclosurecontext-argvalue)
- [appendReturn](#fn-cclosurecontext-appendreturn)
- [raise](#fn-cclosurecontext-raise)
- [yieldWithReturns](#fn-cclosurecontext-yieldwithreturns)

<a id="fn-cclosurecontext-deinit"></a>

### CClosureContext.deinit

```zig
pub fn deinit(self: *CClosureContext) void
```

References: [`CClosureContext`](#type-cclosurecontext)

<a id="fn-cclosurecontext-argcount"></a>

### CClosureContext.argCount

```zig
pub fn argCount(self: *CClosureContext) usize
```

References: [`CClosureContext`](#type-cclosurecontext)

<a id="fn-cclosurecontext-argvalue"></a>

### CClosureContext.argValue

```zig
pub fn argValue(self: *CClosureContext, index: usize) Value
```

References: [`CClosureContext`](#type-cclosurecontext), [`Value`](#type-value)

<a id="fn-cclosurecontext-appendreturn"></a>

### CClosureContext.appendReturn

```zig
pub fn appendReturn(self: *CClosureContext, value: Value) !void
```

References: [`CClosureContext`](#type-cclosurecontext), [`Value`](#type-value)

<a id="fn-cclosurecontext-raise"></a>

### CClosureContext.raise

```zig
pub fn raise(self: *CClosureContext, value: Value) error{LuaError}
```

References: [`CClosureContext`](#type-cclosurecontext), [`Value`](#type-value)

<a id="fn-cclosurecontext-yieldwithreturns"></a>

### CClosureContext.yieldWithReturns

```zig
pub fn yieldWithReturns(self: *CClosureContext, values: []const Value) !void
```

References: [`CClosureContext`](#type-cclosurecontext), [`Value`](#type-value)

<a id="type-cclosureresumecontext"></a>

## CClosureResumeContext

```zig
pub const CClosureResumeContext = struct {
    state: *State,
    thread: *Thread,
    args: []const Value,
    user_data: ?*anyopaque,
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,
};
```

### Nested Declarations

- [deinit](#fn-cclosureresumecontext-deinit)
- [appendReturn](#fn-cclosureresumecontext-appendreturn)
- [raise](#fn-cclosureresumecontext-raise)
- [yieldWithReturns](#fn-cclosureresumecontext-yieldwithreturns)

<a id="fn-cclosureresumecontext-deinit"></a>

### CClosureResumeContext.deinit

```zig
pub fn deinit(self: *CClosureResumeContext) void
```

References: [`CClosureResumeContext`](#type-cclosureresumecontext)

<a id="fn-cclosureresumecontext-appendreturn"></a>

### CClosureResumeContext.appendReturn

```zig
pub fn appendReturn(self: *CClosureResumeContext, value: Value) !void
```

References: [`CClosureResumeContext`](#type-cclosureresumecontext), [`Value`](#type-value)

<a id="fn-cclosureresumecontext-raise"></a>

### CClosureResumeContext.raise

```zig
pub fn raise(self: *CClosureResumeContext, value: Value) error{LuaError}
```

References: [`CClosureResumeContext`](#type-cclosureresumecontext), [`Value`](#type-value)

<a id="fn-cclosureresumecontext-yieldwithreturns"></a>

### CClosureResumeContext.yieldWithReturns

```zig
pub fn yieldWithReturns(self: *CClosureResumeContext, values: []const Value) !void
```

References: [`CClosureResumeContext`](#type-cclosureresumecontext), [`Value`](#type-value)

<a id="type-apicallbackcontext"></a>

## ApiCallbackContext

```zig
pub const ApiCallbackContext = struct {
    state: *State,
    thread: *Thread,
    op: bytecode.Call,
    callback_id: usize,
    user_data: ?*anyopaque,
    function_name: []const u8 = "host callback",
    returns: std.ArrayList(Value) = .empty,
    error_value: ?Value = null,
};
```

### Nested Declarations

- [deinit](#fn-apicallbackcontext-deinit)
- [argCount](#fn-apicallbackcontext-argcount)
- [callbackArgValue](#fn-apicallbackcontext-callbackargvalue)
- [clearReturns](#fn-apicallbackcontext-clearreturns)
- [appendReturn](#fn-apicallbackcontext-appendreturn)
- [fail](#fn-apicallbackcontext-fail)
- [failArgumentMessage](#fn-apicallbackcontext-failargumentmessage)
- [failArgumentType](#fn-apicallbackcontext-failargumenttype)
- [raise](#fn-apicallbackcontext-raise)

<a id="fn-apicallbackcontext-deinit"></a>

### ApiCallbackContext.deinit

```zig
pub fn deinit(self: *ApiCallbackContext) void
```

References: [`ApiCallbackContext`](#type-apicallbackcontext)

<a id="fn-apicallbackcontext-argcount"></a>

### ApiCallbackContext.argCount

```zig
pub fn argCount(self: *ApiCallbackContext) usize
```

References: [`ApiCallbackContext`](#type-apicallbackcontext)

<a id="fn-apicallbackcontext-callbackargvalue"></a>

### ApiCallbackContext.callbackArgValue

```zig
pub fn callbackArgValue(self: *ApiCallbackContext, index: usize) Value
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`Value`](#type-value)

<a id="fn-apicallbackcontext-clearreturns"></a>

### ApiCallbackContext.clearReturns

```zig
pub fn clearReturns(self: *ApiCallbackContext) void
```

References: [`ApiCallbackContext`](#type-apicallbackcontext)

<a id="fn-apicallbackcontext-appendreturn"></a>

### ApiCallbackContext.appendReturn

```zig
pub fn appendReturn(self: *ApiCallbackContext, value: Value) !void
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`Value`](#type-value)

<a id="fn-apicallbackcontext-fail"></a>

### ApiCallbackContext.fail

```zig
pub fn fail(self: *ApiCallbackContext, message: []const u8) RuntimeError
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`RuntimeError`](#const-runtimeerror)

<a id="fn-apicallbackcontext-failargumentmessage"></a>

### ApiCallbackContext.failArgumentMessage

```zig
pub fn failArgumentMessage(self: *ApiCallbackContext, index: usize, message: []const u8) RuntimeError
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`RuntimeError`](#const-runtimeerror)

<a id="fn-apicallbackcontext-failargumenttype"></a>

### ApiCallbackContext.failArgumentType

```zig
pub fn failArgumentType(self: *ApiCallbackContext, index: usize, expected: []const u8, actual: Value) RuntimeError
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`Value`](#type-value), [`RuntimeError`](#const-runtimeerror)

<a id="fn-apicallbackcontext-raise"></a>

### ApiCallbackContext.raise

```zig
pub fn raise(self: *ApiCallbackContext, value: Value) error{LuaError}
```

References: [`ApiCallbackContext`](#type-apicallbackcontext), [`Value`](#type-value)

<a id="type-runtimeerrorpayload"></a>

## RuntimeErrorPayload

```zig
pub const RuntimeErrorPayload = union(enum) {
    diagnostic: []const u8,
    argument: errors.ArgumentError,
    lua_value: Value,
};
```

### Nested Declarations

- [luaValue](#fn-runtimeerrorpayload-luavalue)

<a id="fn-runtimeerrorpayload-luavalue"></a>

### RuntimeErrorPayload.luaValue

```zig
pub fn luaValue(self: RuntimeErrorPayload, state: anytype) Value
```

References: [`RuntimeErrorPayload`](#type-runtimeerrorpayload), [`Value`](#type-value)

<a id="type-protectedcallcontext"></a>

## ProtectedCallContext

```zig
pub const ProtectedCallContext = struct {
    frame_count: usize,
    relative_base: bytecode.Register,
    absolute_base: usize,
    stack_len: usize,
    last_result_base: usize,
    last_result_count: usize,
    last_error: ?RuntimeErrorPayload,
};
```

<a id="type-protectedcontinuationkind"></a>

## ProtectedContinuationKind

```zig
pub const ProtectedContinuationKind = enum { ... };
```

<a id="type-protectedcontinuation"></a>

## ProtectedContinuation

```zig
pub const ProtectedContinuation = struct {
    context: ProtectedCallContext,
    base: bytecode.Register,
    return_count: u16,
    kind: ProtectedContinuationKind,
    handler: Value = .nil,
    handler_depth: usize = 0,
};
```

<a id="type-genericforcontinuation"></a>

## GenericForContinuation

```zig
pub const GenericForContinuation = struct {
    frame_count: usize,
    op: bytecode.GenericFor,
    jump_on_nil: bool,
};
```

<a id="type-branchcontinuation"></a>

## BranchContinuation

```zig
pub const BranchContinuation = struct {
    jump_if_truthy: bool,
    offset: bytecode.JumpOffset,
};
```

<a id="type-tailcallcontinuation"></a>

## TailCallContinuation

```zig
pub const TailCallContinuation = struct {
    frame_count: usize,
    base: bytecode.Register,
    return_count: u16,
};
```

<a id="type-callonecontinuationresult"></a>

## CallOneContinuationResult

```zig
pub const CallOneContinuationResult = union(enum) {
    value: usize,
    truthy: usize,
    inverted_truthy: usize,
    branch_truthy: BranchContinuation,
    branch_inverted_truthy: BranchContinuation,
};
```

<a id="type-callonecontinuation"></a>

## CallOneContinuation

```zig
pub const CallOneContinuation = struct {
    frame_count: usize,
    result: CallOneContinuationResult,
};
```

<a id="type-coroutineresumeresult"></a>

## CoroutineResumeResult

```zig
pub const CoroutineResumeResult = union(enum) {
    success: []Value,
    failure: Value,
};
```

<a id="type-closure"></a>

## Closure

```zig
pub const Closure = struct {
    proto: *const proto_mod.Proto,
    upvalues: []*Upvalue,
    constants: ?[]?Value = null,
    stripped_debug: bool = false,
    marked: bool = false,
};
```

<a id="type-cclosure"></a>

## CClosure

```zig
pub const CClosure = struct {
    function_id: usize,
    upvalues: []*CUpvalue,
    marked: bool = false,
};
```

<a id="type-cupvalue"></a>

## CUpvalue

```zig
pub const CUpvalue = struct {
    value: Value = .nil,
    marked: bool = false,
};
```

<a id="type-upvalue"></a>

## Upvalue

```zig
pub const Upvalue = struct {
    owner: *Thread,
    stack_index: usize,
    closed: Value = .nil,
    is_open: bool = true,
    next: ?*Upvalue = null,
    marked: bool = false,
};
```

<a id="type-tableentry"></a>

## TableEntry

```zig
pub const TableEntry = struct {
    key: Value,
    value: Value,
};
```

<a id="const-tableentryindex"></a>

## TableEntryIndex

```zig
pub const TableEntryIndex = std.HashMap(Value, usize, ValueHashContext, std.hash_map.default_max_load_percentage);
```

References: [`Value`](#type-value)

<a id="type-table"></a>

## Table

```zig
pub const Table = struct {
    array: std.ArrayList(Value) = .empty,
    entries: std.ArrayList(TableEntry) = .empty,
    entry_index: TableEntryIndex,
    metatable: ?*Table = null,
    metatable_prev: ?*Table = null,
    metatable_next: ?*Table = null,
    counts_for_gc_count: bool = true,
    marked: bool = false,
    finalized: bool = false,
};
```

### Nested Declarations

- [init](#fn-table-init)
- [deinit](#fn-table-deinit)
- [get](#fn-table-get)
- [set](#fn-table-set)
- [setExistingNonNil](#fn-table-setexistingnonnil)
- [len](#fn-table-len)
- [next](#fn-table-next)
- [removeHashKey](#fn-table-removehashkey)
- [removeEntryAt](#fn-table-removeentryat)

<a id="fn-table-init"></a>

### Table.init

```zig
pub fn init(allocator: std.mem.Allocator, array_hint: u32, hash_hint: u32) !Table
```

References: [`Table`](#type-table)

<a id="fn-table-deinit"></a>

### Table.deinit

```zig
pub fn deinit(self: *Table, allocator: std.mem.Allocator) void
```

References: [`Table`](#type-table)

<a id="fn-table-get"></a>

### Table.get

```zig
pub fn get(self: Table, key: Value) Value
```

References: [`Table`](#type-table), [`Value`](#type-value)

<a id="fn-table-set"></a>

### Table.set

```zig
pub fn set(self: *Table, allocator: std.mem.Allocator, key: Value, value: Value) !void
```

References: [`Table`](#type-table), [`Value`](#type-value)

<a id="fn-table-setexistingnonnil"></a>

### Table.setExistingNonNil

```zig
pub fn setExistingNonNil(self: *Table, key: Value, value: Value) bool
```

References: [`Table`](#type-table), [`Value`](#type-value)

<a id="fn-table-len"></a>

### Table.len

```zig
pub fn len(self: Table) i64
```

References: [`Table`](#type-table)

<a id="fn-table-next"></a>

### Table.next

```zig
pub fn next(self: Table, key: Value) ![2]Value
```

References: [`Table`](#type-table), [`Value`](#type-value)

<a id="fn-table-removehashkey"></a>

### Table.removeHashKey

```zig
pub fn removeHashKey(self: *Table, key: Value) void
```

References: [`Table`](#type-table), [`Value`](#type-value)

<a id="fn-table-removeentryat"></a>

### Table.removeEntryAt

```zig
pub fn removeEntryAt(self: *Table, index: usize) void
```

References: [`Table`](#type-table)

<a id="type-userdata"></a>

## Userdata

```zig
pub const Userdata = struct {
    ptr: *anyopaque,
    type_id: usize,
    type_name: []const u8,
    metatable: ?*Table = null,
    finalizer: ?UserdataFinalizer = null,
    finalizer_data: ?*const anyopaque = null,
    deinit_fn: ?UserdataDeinit = null,
    marked: bool = false,
    finalized: bool = false,
};
```

<a id="type-thread"></a>

## Thread

```zig
pub const Thread = struct {
    stack: std.ArrayList(Value) = .empty,
    frames: std.ArrayList(CallFrame) = .empty,
    yield_values: std.ArrayList(Value) = .empty,
    protected_continuations: std.ArrayList(ProtectedContinuation) = .empty,
    generic_for_continuations: std.ArrayList(GenericForContinuation) = .empty,
    tail_call_continuations: std.ArrayList(TailCallContinuation) = .empty,
    call_one_continuations: std.ArrayList(CallOneContinuation) = .empty,
    open_upvalues: ?*Upvalue = null,
    hook: Value = .nil,
    hook_call: bool = false,
    hook_line: bool = false,
    hook_return: bool = false,
    hook_count: u32 = 0,
    hook_count_remaining: u32 = 0,
    hook_running: bool = false,
    hook_return_name: ?[]const u8 = null,
    hook_level2_func: Value = .nil,
    hook_transfer_index_base: i64 = 0,
    hook_transfer_stack_base: usize = 0,
    hook_transfer_count: usize = 0,
    hook_transfer_values: []const Value = &.{},
    next_call_name: ?[]const u8 = null,
    next_call_namewhat: ?[]const u8 = null,
    pending_yield_hook_return: bool = false,
    last_result_base: usize = 0,
    last_result_count: usize = 0,
    last_transfer_base: usize = 0,
    last_transfer_count: usize = 0,
    yield_result_base: usize = 0,
    yield_result_count: u16 = 0,
    native_call_depth: usize = 0,
    traceback_native_name: ?[]const u8 = null,
    protected_close_depth: usize = 0,
    close_error_value: ?Value = null,
    error_traceback: ?[]const u8 = null,
    pending_unwind_error: ?Value = null,
    pending_unwind_resume_frame_count: usize = 0,
    pending_unwind_target_frame_count: usize = 0,
    pending_c_continuation: bool = false,
    resume_parent: ?*Thread = null,
    entry: Value = .nil,
    marked: bool = false,
    started: bool = false,
    is_main: bool = false,
    closing: bool = false,
    status: ThreadStatus = .suspended,
};
```

### Nested Declarations

- [initRoot](#fn-thread-initroot)
- [initCoroutine](#fn-thread-initcoroutine)
- [deinit](#fn-thread-deinit)
- [ensureStack](#fn-thread-ensurestack)

<a id="fn-thread-initroot"></a>

### Thread.initRoot

```zig
pub fn initRoot(allocator: std.mem.Allocator, closure: *Closure, stack_value_limit: usize) !Thread
```

References: [`Closure`](#type-closure), [`Thread`](#type-thread)

<a id="fn-thread-initcoroutine"></a>

### Thread.initCoroutine

```zig
pub fn initCoroutine(entry: Value) Thread
```

References: [`Value`](#type-value), [`Thread`](#type-thread)

<a id="fn-thread-deinit"></a>

### Thread.deinit

```zig
pub fn deinit(self: *Thread, allocator: std.mem.Allocator) void
```

References: [`Thread`](#type-thread)

<a id="fn-thread-ensurestack"></a>

### Thread.ensureStack

```zig
pub fn ensureStack(self: *Thread, allocator: std.mem.Allocator, size: usize, limit: usize) !void
```

References: [`Thread`](#type-thread)

<a id="type-threadstatus"></a>

## ThreadStatus

```zig
pub const ThreadStatus = enum { ... };
```

<a id="type-callframe"></a>

## CallFrame

```zig
pub const CallFrame = struct {
    closure: *Closure,
    proto: *const proto_mod.Proto,
    base: usize,
    pc: usize,
    return_start: usize,
    return_count: u16,
    varargs: []const Value,
    owns_varargs: bool = false,
    vararg_table_local: Value = .nil,
    last_hook_line: ?usize = null,
    debug_name_override: ?[]const u8 = null,
    debug_namewhat_override: ?[]const u8 = null,
    is_tail_call: bool = false,
    pending_returns: ?[]Value = null,
};
```

### Nested Declarations

- [deinit](#fn-callframe-deinit)

<a id="fn-callframe-deinit"></a>

### CallFrame.deinit

```zig
pub fn deinit(self: *CallFrame, allocator: std.mem.Allocator) void
```

References: [`CallFrame`](#type-callframe)

<a id="type-stringallocation"></a>

## StringAllocation

```zig
pub const StringAllocation = struct {
    bytes: []const u8,
    marked: bool = false,
};
```

<a id="const-pointerallocationindex"></a>

## PointerAllocationIndex

```zig
pub const PointerAllocationIndex = std.AutoHashMap(usize, usize);
```

<a id="type-gcmode"></a>

## GcMode

```zig
pub const GcMode = enum { ... };
```

### Nested Declarations

- [name](#fn-gcmode-name)

<a id="fn-gcmode-name"></a>

### GcMode.name

```zig
pub fn name(self: GcMode) []const u8
```

References: [`GcMode`](#type-gcmode)

<a id="type-gcparam"></a>

## GcParam

```zig
pub const GcParam = enum { ... };
```

<a id="type-gcparams"></a>

## GcParams

```zig
pub const GcParams = struct {
    minormul: i64 = 20,
    majorminor: i64 = 50,
    minormajor: i64 = 70,
    pause: i64 = 250,
    stepmul: i64 = 200,
    stepsize: i64 = 200,
};
```

### Nested Declarations

- [get](#fn-gcparams-get)
- [set](#fn-gcparams-set)

<a id="fn-gcparams-get"></a>

### GcParams.get

```zig
pub fn get(self: GcParams, param: GcParam) i64
```

References: [`GcParams`](#type-gcparams), [`GcParam`](#type-gcparam)

<a id="fn-gcparams-set"></a>

### GcParams.set

```zig
pub fn set(self: *GcParams, param: GcParam, value: i64) void
```

References: [`GcParams`](#type-gcparams), [`GcParam`](#type-gcparam)

<a id="type-weakmode"></a>

## WeakMode

```zig
pub const WeakMode = struct {
    keys: bool = false,
    values: bool = false,
};
```

<a id="type-runtimeallocationstats"></a>

## RuntimeAllocationStats

```zig
pub const RuntimeAllocationStats = struct {
    strings: usize,
    tables: usize,
    closures: usize,
    upvalues: usize,
    threads: usize,
    bytes: usize,
};
```

### Nested Declarations

- [total](#fn-runtimeallocationstats-total)

<a id="fn-runtimeallocationstats-total"></a>

### RuntimeAllocationStats.total

```zig
pub fn total(self: RuntimeAllocationStats) usize
```

References: [`RuntimeAllocationStats`](#type-runtimeallocationstats)

