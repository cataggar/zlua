# testing.extension_runner

## Navigation

- [API Index](../README.md)
- Previous: [testing.normalizer](../testing/normalizer.md)
- Next: [testing.official_suite](../testing/official_suite.md)
- Parent: [testing](../testing.md)

## Functions

- [runCli](#fn-runcli)

<a id="fn-runcli"></a>

## runCli

```zig
pub fn runCli(
    allocator: std.mem.Allocator,
    io: std.Io,
    default_zlua: []const u8,
    args: []const []const u8,
) !u8
```

