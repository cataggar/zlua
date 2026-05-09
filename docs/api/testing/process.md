# testing.process

## Navigation

- [API Index](../README.md)
- Previous: [testing.official_suite](../testing/official_suite.md)
- Parent: [testing](../testing.md)

## Functions

- [runProcess](#fn-runprocess)
- [ownedResult](#fn-ownedresult)

## Types

- [ProcessResult](#type-processresult)
- [RunOptions](#type-runoptions)

<a id="type-processresult"></a>

## ProcessResult

```zig
pub const ProcessResult = struct { ... };
```

### Fields

- `stdout`
- `stderr`
- `exit_code`
- `signal`
- `timed_out`

### Nested Declarations

- [deinit](#fn-processresult-deinit)
- [success](#fn-processresult-success)

<a id="fn-processresult-deinit"></a>

### ProcessResult.deinit

```zig
pub fn deinit(self: *ProcessResult, allocator: std.mem.Allocator) void
```

References: [`ProcessResult`](#type-processresult)

<a id="fn-processresult-success"></a>

### ProcessResult.success

```zig
pub fn success(self: ProcessResult) bool
```

References: [`ProcessResult`](#type-processresult)

<a id="type-runoptions"></a>

## RunOptions

```zig
pub const RunOptions = struct { ... };
```

### Fields

- `cwd`
- `timeout_ms`
- `max_output_bytes`
- `expand_arg0`
- `memory_limit_mb`

<a id="fn-runprocess"></a>

## runProcess

```zig
pub fn runProcess(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    options: RunOptions,
) !ProcessResult
```

References: [`RunOptions`](#type-runoptions), [`ProcessResult`](#type-processresult)

<a id="fn-ownedresult"></a>

## ownedResult

```zig
pub fn ownedResult(
    allocator: std.mem.Allocator,
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
) !ProcessResult
```

References: [`ProcessResult`](#type-processresult)

