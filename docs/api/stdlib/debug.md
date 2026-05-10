# stdlib.debug

## Navigation

- [API Index](../README.md)
- Previous: [stdlib.coroutine](../stdlib/coroutine.md)
- Next: [stdlib.package](../stdlib/package.md)
- Parent: [stdlib](../stdlib.md)

## Functions

- [getinfo](#fn-getinfo)
- [getupvalue](#fn-getupvalue)
- [setupvalue](#fn-setupvalue)
- [upvalueid](#fn-upvalueid)
- [upvaluejoin](#fn-upvaluejoin)
- [getlocal](#fn-getlocal)
- [setlocal](#fn-setlocal)
- [getregistry](#fn-getregistry)
- [sethook](#fn-sethook)
- [gethook](#fn-gethook)
- [setmetatable](#fn-setmetatable)
- [setuservalue](#fn-setuservalue)
- [getuservalue](#fn-getuservalue)

<a id="fn-getinfo"></a>

## getinfo

```zig
pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getupvalue"></a>

## getupvalue

```zig
pub fn getupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setupvalue"></a>

## setupvalue

```zig
pub fn setupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-upvalueid"></a>

## upvalueid

```zig
pub fn upvalueid(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-upvaluejoin"></a>

## upvaluejoin

```zig
pub fn upvaluejoin(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getlocal"></a>

## getlocal

```zig
pub fn getlocal(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setlocal"></a>

## setlocal

```zig
pub fn setlocal(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getregistry"></a>

## getregistry

```zig
pub fn getregistry(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sethook"></a>

## sethook

```zig
pub fn sethook(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-gethook"></a>

## gethook

```zig
pub fn gethook(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setmetatable"></a>

## setmetatable

```zig
pub fn setmetatable(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setuservalue"></a>

## setuservalue

```zig
pub fn setuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getuservalue"></a>

## getuservalue

```zig
pub fn getuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

