# runtime.debug

## Navigation

- [API Index](../README.md)
- Previous: [runtime.coroutine](../runtime/coroutine.md)
- Next: [runtime.gc](../runtime/gc.md)
- Parent: [runtime](../runtime.md)

## Functions

- [appendUnhandledErrorDebugDump](#fn-appendunhandlederrordebugdump)
- [appendDebugFrames](#fn-appenddebugframes)
- [appendDebugLocals](#fn-appenddebuglocals)
- [appendDebugVarargs](#fn-appenddebugvarargs)
- [appendDebugUpvalues](#fn-appenddebugupvalues)
- [appendDebugStack](#fn-appenddebugstack)
- [appendDebugValue](#fn-appenddebugvalue)

<a id="fn-appendunhandlederrordebugdump"></a>

## appendUnhandledErrorDebugDump

```zig
pub fn appendUnhandledErrorDebugDump(comptime State: type, self: *State, thread: *Thread, err: anyerror) !void
```

<a id="fn-appenddebugframes"></a>

## appendDebugFrames

```zig
pub fn appendDebugFrames(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread) !void
```

<a id="fn-appenddebuglocals"></a>

## appendDebugLocals

```zig
pub fn appendDebugLocals(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread, frame: CallFrame) !void
```

<a id="fn-appenddebugvarargs"></a>

## appendDebugVarargs

```zig
pub fn appendDebugVarargs(comptime State: type, self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void
```

<a id="fn-appenddebugupvalues"></a>

## appendDebugUpvalues

```zig
pub fn appendDebugUpvalues(comptime State: type, self: *State, out: *std.ArrayList(u8), frame: CallFrame) !void
```

<a id="fn-appenddebugstack"></a>

## appendDebugStack

```zig
pub fn appendDebugStack(comptime State: type, self: *State, out: *std.ArrayList(u8), thread: *Thread) !void
```

<a id="fn-appenddebugvalue"></a>

## appendDebugValue

```zig
pub fn appendDebugValue(comptime State: type, self: *State, out: *std.ArrayList(u8), value: Value) !void
```

