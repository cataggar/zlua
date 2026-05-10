# testing.process

## Navigation

- [API Index](../README.md)
- Previous: [runtime.execute](../runtime/execute.md)
- Next: [runtime.state](../runtime/state.md)
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
pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: ?u8,
    signal: ?u32,
    timed_out: bool,
};
```

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
pub const RunOptions = struct {
    cwd: ?[]const u8 = null,
    timeout_ms: u64 = 5000,
    max_output_bytes: usize = 1024 * 1024,
    expand_arg0: bool = false,
    memory_limit_mb: u64 = 0,
};
```

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

