# stdlib.package

## Navigation

- [API Index](../README.md)
- Previous: [stdlib.debug](../stdlib/debug.md)
- Next: [stdlib.io](../stdlib/io.md)
- Parent: [stdlib](../stdlib.md)

## Functions

- [loadfile](#fn-loadfile)
- [dofile](#fn-dofile)
- [require](#fn-require)
- [searchpath](#fn-searchpath)
- [searcherPreload](#fn-searcherpreload)
- [searcherLua](#fn-searcherlua)

<a id="fn-loadfile"></a>

## loadfile

```zig
pub fn loadfile(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-dofile"></a>

## dofile

```zig
pub fn dofile(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-require"></a>

## require

```zig
pub fn require(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-searchpath"></a>

## searchpath

```zig
pub fn searchpath(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-searcherpreload"></a>

## searcherPreload

```zig
pub fn searcherPreload(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-searcherlua"></a>

## searcherLua

```zig
pub fn searcherLua(state: *State, thread: *Thread, op: bytecode.Call) !void
```

