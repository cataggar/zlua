# testing.clua

## Navigation

- [API Index](../README.md)
- Previous: [testing](../testing.md)
- Next: [testing.bench_runner](../testing/bench_runner.md)
- Parent: [testing](../testing.md)

## Functions

- [detect](#fn-detect)
- [runLoadfile](#fn-runloadfile)
- [runFile](#fn-runfile)

## Types

- [Discovery](#type-discovery)

<a id="type-discovery"></a>

## Discovery

```zig
pub const Discovery = union(enum) {
    found: []u8,
    missing: []u8,
};
```

### Nested Declarations

- [deinit](#fn-discovery-deinit)

<a id="fn-discovery-deinit"></a>

### Discovery.deinit

```zig
pub fn deinit(self: Discovery, allocator: std.mem.Allocator) void
```

References: [`Discovery`](#type-discovery)

<a id="fn-detect"></a>

## detect

```zig
pub fn detect(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ_map: *const std.process.Environ.Map,
    explicit_path: ?[]const u8,
) !Discovery
```

References: [`Discovery`](#type-discovery)

<a id="fn-runloadfile"></a>

## runLoadfile

```zig
pub fn runLoadfile(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    timeout_ms: u64,
) !process.ProcessResult
```

<a id="fn-runfile"></a>

## runFile

```zig
pub fn runFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    exe: []const u8,
    path: []const u8,
    timeout_ms: u64,
) !process.ProcessResult
```

