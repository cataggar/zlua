# runtime.coroutine

## Navigation

- [API Index](../README.md)
- Previous: [runtime.call](../runtime/call.md)
- Next: [runtime.debug](../runtime/debug.md)
- Parent: [runtime](../runtime.md)

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

