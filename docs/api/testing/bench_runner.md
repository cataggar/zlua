# testing.bench_runner

## Navigation

- [API Index](../README.md)
- Previous: [testing.clua](../testing/clua.md)
- Next: [testing.c_api_runner](../testing/c_api_runner.md)
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
    zlua_exe: []const u8,
    args: []const []const u8,
) !u8
```

