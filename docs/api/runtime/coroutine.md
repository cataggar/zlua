# runtime.coroutine

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

- [newCoroutine](#fn-newcoroutine)
- [resumeThread](#fn-resumethread)
- [closeThread](#fn-closethread)
- [threadWasYielded](#fn-threadwasyielded)
- [resumeCClosureDispatch](#fn-resumecclosuredispatch)
- [coroutineCreate](#fn-coroutinecreate)
- [coroutineResume](#fn-coroutineresume)
- [coroutineYield](#fn-coroutineyield)
- [coroutineStatus](#fn-coroutinestatus)
- [coroutineRunning](#fn-coroutinerunning)
- [coroutineIsYieldable](#fn-coroutineisyieldable)
- [coroutineClose](#fn-coroutineclose)
- [coroutineWrap](#fn-coroutinewrap)
- [callCoroutineWrapper](#fn-callcoroutinewrapper)
- [callCoroutineWrapperWithArgs](#fn-callcoroutinewrapperwithargs)
- [newCoroutineThread](#fn-newcoroutinethread)
- [closeCoroutine](#fn-closecoroutine)
- [resumeCoroutine](#fn-resumecoroutine)
- [startCoroutine](#fn-startcoroutine)
- [callableEntryClosure](#fn-callableentryclosure)
- [setCoroutineResumeValues](#fn-setcoroutineresumevalues)
- [returnCoroutineResumeResult](#fn-returncoroutineresumeresult)
- [copyValues](#fn-copyvalues)
- [copyStackSlice](#fn-copystackslice)

<a id="fn-newcoroutine"></a>

## newCoroutine

```zig
pub fn newCoroutine(comptime State: type, self: *State, entry: Value) !*Thread
```

<a id="fn-resumethread"></a>

## resumeThread

```zig
pub fn resumeThread(comptime State: type, self: *State, target: *Thread, args: []const Value) !ProtectedCallResult
```

<a id="fn-closethread"></a>

## closeThread

```zig
pub fn closeThread(comptime State: type, self: *State, target: *Thread) !?Value
```

<a id="fn-threadwasyielded"></a>

## threadWasYielded

```zig
pub fn threadWasYielded(comptime State: type, _: *State, target: *Thread) bool
```

<a id="fn-resumecclosuredispatch"></a>

## resumeCClosureDispatch

```zig
pub fn resumeCClosureDispatch(comptime State: type, self: *State, thread: *Thread, args: []const Value) !void
```

<a id="fn-coroutinecreate"></a>

## coroutineCreate

```zig
pub fn coroutineCreate(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutineresume"></a>

## coroutineResume

```zig
pub fn coroutineResume(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutineyield"></a>

## coroutineYield

```zig
pub fn coroutineYield(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutinestatus"></a>

## coroutineStatus

```zig
pub fn coroutineStatus(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutinerunning"></a>

## coroutineRunning

```zig
pub fn coroutineRunning(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutineisyieldable"></a>

## coroutineIsYieldable

```zig
pub fn coroutineIsYieldable(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutineclose"></a>

## coroutineClose

```zig
pub fn coroutineClose(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-coroutinewrap"></a>

## coroutineWrap

```zig
pub fn coroutineWrap(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-callcoroutinewrapper"></a>

## callCoroutineWrapper

```zig
pub fn callCoroutineWrapper(comptime State: type, self: *State, thread: *Thread, op: bytecode.Call, target: *Thread) !void
```

<a id="fn-callcoroutinewrapperwithargs"></a>

## callCoroutineWrapperWithArgs

```zig
pub fn callCoroutineWrapperWithArgs(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, target: *Thread, args: []const Value) !void
```

<a id="fn-newcoroutinethread"></a>

## newCoroutineThread

```zig
pub fn newCoroutineThread(comptime State: type, self: *State, entry: Value) !*Thread
```

<a id="fn-closecoroutine"></a>

## closeCoroutine

```zig
pub fn closeCoroutine(comptime State: type, self: *State, target: *Thread, error_value: ?Value) !?Value
```

<a id="fn-resumecoroutine"></a>

## resumeCoroutine

```zig
pub fn resumeCoroutine(comptime State: type, self: *State, target: *Thread, args: []const Value) !CoroutineResumeResult
```

<a id="fn-startcoroutine"></a>

## startCoroutine

```zig
pub fn startCoroutine(comptime State: type, self: *State, target: *Thread, args: []const Value) !void
```

<a id="fn-callableentryclosure"></a>

## callableEntryClosure

```zig
pub fn callableEntryClosure(comptime State: type, self: *State) !*Closure
```

<a id="fn-setcoroutineresumevalues"></a>

## setCoroutineResumeValues

```zig
pub fn setCoroutineResumeValues(comptime State: type, self: *State, target: *Thread, args: []const Value) !void
```

<a id="fn-returncoroutineresumeresult"></a>

## returnCoroutineResumeResult

```zig
pub fn returnCoroutineResumeResult(comptime State: type, self: *State, thread: *Thread, base: bytecode.Register, return_count: u16, result: CoroutineResumeResult) !void
```

<a id="fn-copyvalues"></a>

## copyValues

```zig
pub fn copyValues(comptime State: type, self: *State, values: []const Value) ![]Value
```

<a id="fn-copystackslice"></a>

## copyStackSlice

```zig
pub fn copyStackSlice(comptime State: type, self: *State, thread: *Thread, base: usize, count: usize) ![]Value
```

