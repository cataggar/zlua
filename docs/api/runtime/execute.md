# runtime.execute

## Navigation

- [API Index](../README.md)
- Previous: [runtime.value](../runtime/value.md)
- Next: [testing.process](../testing/process.md)
- Parent: [runtime](../runtime.md)

## Functions

- [executeSource](#fn-executesource)
- [executeSourceWithOptions](#fn-executesourcewithoptions)

## Types

- [ExecuteOptions](#type-executeoptions)

<a id="type-executeoptions"></a>

## ExecuteOptions

```zig
pub const ExecuteOptions = struct { ... };
```

### Fields

```zig
    collect_after_instruction: bool = false
    state: state_mod.StateOptions = .{}
```


<a id="fn-executesource"></a>

## executeSource

```zig
pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult
```

<a id="fn-executesourcewithoptions"></a>

## executeSourceWithOptions

```zig
pub fn executeSourceWithOptions(allocator: std.mem.Allocator, source: []const u8, options: ExecuteOptions) !process.ProcessResult
```

References: [`ExecuteOptions`](#type-executeoptions)

