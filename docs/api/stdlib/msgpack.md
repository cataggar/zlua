# stdlib.msgpack

## Navigation

- [API Index](../README.md)
- Previous: [stdlib.toml](../stdlib/toml.md)
- Next: [stdlib.csv](../stdlib/csv.md)
- Parent: [stdlib](../stdlib.md)

## Functions

- [nullValue](#fn-nullvalue)
- [read](#fn-read)
- [write](#fn-write)

<a id="fn-nullvalue"></a>

## nullValue

```zig
pub fn nullValue(state: *State) !Value
```

<a id="fn-read"></a>

## read

```zig
pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-write"></a>

## write

```zig
pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void
```

