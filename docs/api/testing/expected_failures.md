# testing.expected_failures

## Navigation

- [API Index](../README.md)
- Previous: [testing.diff_runner](../testing/diff_runner.md)
- Next: [testing.metadata](../testing/metadata.md)
- Parent: [testing](../testing.md)

## Functions

- [load](#fn-load)

## Types

- [Registry](#type-registry)

<a id="type-registry"></a>

## Registry

```zig
pub const Registry = struct { ... };
```

### Fields

```zig
    failures: std.StringHashMap([]u8)
```


### Nested Declarations

- [init](#fn-registry-init)
- [deinit](#fn-registry-deinit)
- [contains](#fn-registry-contains)
- [reason](#fn-registry-reason)

<a id="fn-registry-init"></a>

### Registry.init

```zig
pub fn init(allocator: std.mem.Allocator) Registry
```

References: [`Registry`](#type-registry)

<a id="fn-registry-deinit"></a>

### Registry.deinit

```zig
pub fn deinit(self: *Registry) void
```

References: [`Registry`](#type-registry)

<a id="fn-registry-contains"></a>

### Registry.contains

```zig
pub fn contains(self: Registry, path: []const u8) bool
```

References: [`Registry`](#type-registry)

<a id="fn-registry-reason"></a>

### Registry.reason

```zig
pub fn reason(self: Registry, path: []const u8) ?[]const u8
```

References: [`Registry`](#type-registry)

<a id="fn-load"></a>

## load

```zig
pub fn load(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Registry
```

References: [`Registry`](#type-registry)

