# testing.diff_runner

## Navigation

- [API Index](../README.md)
- Previous: [testing.c_api_runner](../testing/c_api_runner.md)
- Next: [testing.expected_failures](../testing/expected_failures.md)
- Parent: [testing](../testing.md)

## Functions

- [runCli](#fn-runcli)

<a id="fn-runcli"></a>

## runCli

```zig
pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    args: []const []const u8,
) !u8
```

