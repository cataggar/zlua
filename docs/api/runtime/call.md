# runtime.call

## Navigation

- [API Index](../README.md)
- Previous: [runtime.state](../runtime/state.md)
- Next: [runtime.coroutine](../runtime/coroutine.md)
- Parent: [runtime](../runtime.md)

## Functions

- [callOneResult](#fn-calloneresult)
- [callOneResultWithContinuation](#fn-calloneresultwithcontinuation)
- [callOneMetamethodWithContinuation](#fn-callonemetamethodwithcontinuation)
- [callOneMetamethod](#fn-callonemetamethod)
- [metamethodDebugName](#fn-metamethoddebugname)
- [callOneResultMaybeContinuation](#fn-calloneresultmaybecontinuation)
- [pushCallOneContinuation](#fn-pushcallonecontinuation)
- [readyCallOneContinuationIndex](#fn-readycallonecontinuationindex)
- [completeReadyCallOneContinuation](#fn-completereadycallonecontinuation)
- [protectedCall](#fn-protectedcall)
- [protectedCallContext](#fn-protectedcallcontext)
- [protectedCallContextWithErrors](#fn-protectedcallcontextwitherrors)
- [runProtectedCall](#fn-runprotectedcall)
- [pushProtectedContinuation](#fn-pushprotectedcontinuation)
- [readyProtectedContinuationIndex](#fn-readyprotectedcontinuationindex)
- [errorProtectedContinuationIndex](#fn-errorprotectedcontinuationindex)
- [completeReadyProtectedContinuation](#fn-completereadyprotectedcontinuation)
- [completeProtectedContinuationError](#fn-completeprotectedcontinuationerror)
- [returnProtectedContinuationSuccess](#fn-returnprotectedcontinuationsuccess)
- [returnProtectedContinuationFailure](#fn-returnprotectedcontinuationfailure)
- [returnProtectedResult](#fn-returnprotectedresult)
- [collectArgs](#fn-collectargs)
- [resolveReturnCount](#fn-resolvereturncount)
- [prepareClosureFrame](#fn-prepareclosureframe)

<a id="fn-calloneresult"></a>

## callOneResult

```zig
pub fn callOneResult(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!Value
```

<a id="fn-calloneresultwithcontinuation"></a>

## callOneResultWithContinuation

```zig
pub fn callOneResultWithContinuation(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value
```

<a id="fn-callonemetamethodwithcontinuation"></a>

## callOneMetamethodWithContinuation

```zig
pub fn callOneMetamethodWithContinuation(comptime State: type, self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value, result: CallOneContinuationResult) anyerror!Value
```

<a id="fn-callonemetamethod"></a>

## callOneMetamethod

```zig
pub fn callOneMetamethod(comptime State: type, self: *State, thread: *Thread, name: []const u8, callable: Value, args: []const Value) anyerror!Value
```

<a id="fn-metamethoddebugname"></a>

## metamethodDebugName

```zig
pub fn metamethodDebugName(name: []const u8) []const u8
```

<a id="fn-calloneresultmaybecontinuation"></a>

## callOneResultMaybeContinuation

```zig
pub fn callOneResultMaybeContinuation(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value, continuation_result: ?CallOneContinuationResult) anyerror!Value
```

<a id="fn-pushcallonecontinuation"></a>

## pushCallOneContinuation

```zig
pub fn pushCallOneContinuation(comptime State: type, self: *State, thread: *Thread, frame_count: usize, result: CallOneContinuationResult) !void
```

<a id="fn-readycallonecontinuationindex"></a>

## readyCallOneContinuationIndex

```zig
pub fn readyCallOneContinuationIndex(thread: *Thread) ?usize
```

<a id="fn-completereadycallonecontinuation"></a>

## completeReadyCallOneContinuation

```zig
pub fn completeReadyCallOneContinuation(comptime State: type, self: *State, thread: *Thread) !bool
```

<a id="fn-protectedcall"></a>

## protectedCall

```zig
pub fn protectedCall(comptime State: type, self: *State, thread: *Thread, callable: Value, args: []const Value) anyerror!ProtectedCallResult
```

<a id="fn-protectedcallcontext"></a>

## protectedCallContext

```zig
pub fn protectedCallContext(comptime State: type, _: *State, thread: *Thread) ProtectedCallContext
```

<a id="fn-protectedcallcontextwitherrors"></a>

## protectedCallContextWithErrors

```zig
pub fn protectedCallContextWithErrors(comptime State: type, self: *State, thread: *Thread) ProtectedCallContext
```

<a id="fn-runprotectedcall"></a>

## runProtectedCall

```zig
pub fn runProtectedCall(comptime State: type, self: *State, thread: *Thread, context: ProtectedCallContext, callable: Value, args: []const Value) anyerror!ProtectedCallResult
```

<a id="fn-pushprotectedcontinuation"></a>

## pushProtectedContinuation

```zig
pub fn pushProtectedContinuation(comptime State: type, self: *State, thread: *Thread, context: ProtectedCallContext, base: bytecode.Register, return_count: u16, kind: ProtectedContinuationKind, handler: Value, handler_depth: usize) !void
```

<a id="fn-readyprotectedcontinuationindex"></a>

## readyProtectedContinuationIndex

```zig
pub fn readyProtectedContinuationIndex(thread: *Thread) ?usize
```

<a id="fn-errorprotectedcontinuationindex"></a>

## errorProtectedContinuationIndex

```zig
pub fn errorProtectedContinuationIndex(thread: *Thread) ?usize
```

<a id="fn-completereadyprotectedcontinuation"></a>

## completeReadyProtectedContinuation

```zig
pub fn completeReadyProtectedContinuation(comptime State: type, self: *State, thread: *Thread) !bool
```

<a id="fn-completeprotectedcontinuationerror"></a>

## completeProtectedContinuationError

```zig
pub fn completeProtectedContinuationError(comptime State: type, self: *State, thread: *Thread, error_value: Value) !bool
```

<a id="fn-returnprotectedcontinuationsuccess"></a>

## returnProtectedContinuationSuccess

```zig
pub fn returnProtectedContinuationSuccess(comptime State: type, self: *State, thread: *Thread, continuation: ProtectedContinuation, values: []Value) !void
```

<a id="fn-returnprotectedcontinuationfailure"></a>

## returnProtectedContinuationFailure

```zig
pub fn returnProtectedContinuationFailure(comptime State: type, self: *State, thread: *Thread, continuation: ProtectedContinuation, failure: Value) !void
```

<a id="fn-returnprotectedresult"></a>

## returnProtectedResult

```zig
pub fn returnProtectedResult(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: ProtectedCallResult) !void
```

<a id="fn-collectargs"></a>

## collectArgs

```zig
pub fn collectArgs(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call, first: u16) ![]Value
```

<a id="fn-resolvereturncount"></a>

## resolveReturnCount

```zig
pub fn resolveReturnCount(comptime State: type, self: *State, count: u16, available: usize) !usize
```

<a id="fn-prepareclosureframe"></a>

## prepareClosureFrame

```zig
pub fn prepareClosureFrame(comptime State: type, self: *State, thread: *Thread, closure: *Closure, source_base: usize, frame_base: usize, arg_count: usize, return_start: usize, return_count: u16) !CallFrame
```

