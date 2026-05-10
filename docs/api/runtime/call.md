# runtime.call

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

