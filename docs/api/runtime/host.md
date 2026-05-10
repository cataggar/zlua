# runtime.host

## Navigation

- [API Index](../README.md)
- Previous: [runtime.gc](../runtime/gc.md)
- Next: [stdlib](../stdlib.md)
- Parent: [runtime](../runtime.md)

## Types

- [MemoryFile](#type-memoryfile)
- [MemoryFilesystem](#type-memoryfilesystem)
- [FilesystemCapability](#type-filesystemcapability)
- [ClockCapability](#type-clockcapability)
- [ProcessCapability](#type-processcapability)

<a id="type-memoryfile"></a>

## MemoryFile

```zig
pub const MemoryFile = struct { ... };
```

### Fields

```zig
    path: []const u8
    contents: []const u8
```


<a id="type-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = struct { ... };
```

### Fields

```zig
    allocator: std.mem.Allocator
    files: std.ArrayList(MemoryFile) = .empty
    options: Options = .{}
    bytes_used: usize = 0
```


### Nested Declarations

- [default_max_path_len](#const-memoryfilesystem-default_max_path_len)
- [Options](#type-memoryfilesystem-options)
- [init](#fn-memoryfilesystem-init)
- [initWithOptions](#fn-memoryfilesystem-initwithoptions)
- [initWithFiles](#fn-memoryfilesystem-initwithfiles)
- [initWithFilesAndOptions](#fn-memoryfilesystem-initwithfilesandoptions)
- [deinit](#fn-memoryfilesystem-deinit)
- [readFileAlloc](#fn-memoryfilesystem-readfilealloc)
- [writeFile](#fn-memoryfilesystem-writefile)
- [removeFile](#fn-memoryfilesystem-removefile)
- [renameFile](#fn-memoryfilesystem-renamefile)
- [normalizePathAlloc](#fn-memoryfilesystem-normalizepathalloc)

<a id="const-memoryfilesystem-default_max_path_len"></a>

### MemoryFilesystem.default_max_path_len

```zig
pub const default_max_path_len: usize = 4096;
```

<a id="type-memoryfilesystem-options"></a>

### MemoryFilesystem.Options

```zig
pub const Options = struct { ... };
```

#### Fields

```zig
    max_path_len: usize = default_max_path_len
    max_bytes: ?usize = null
```


<a id="fn-memoryfilesystem-init"></a>

### MemoryFilesystem.init

```zig
pub fn init(allocator: std.mem.Allocator) MemoryFilesystem
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-initwithoptions"></a>

### MemoryFilesystem.initWithOptions

```zig
pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) MemoryFilesystem
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-initwithfiles"></a>

### MemoryFilesystem.initWithFiles

```zig
pub fn initWithFiles(allocator: std.mem.Allocator, files: []const MemoryFile) !MemoryFilesystem
```

References: [`MemoryFile`](#type-memoryfile), [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-initwithfilesandoptions"></a>

### MemoryFilesystem.initWithFilesAndOptions

```zig
pub fn initWithFilesAndOptions(allocator: std.mem.Allocator, files: []const MemoryFile, options: Options) !MemoryFilesystem
```

References: [`MemoryFile`](#type-memoryfile), [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-deinit"></a>

### MemoryFilesystem.deinit

```zig
pub fn deinit(self: *MemoryFilesystem) void
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-readfilealloc"></a>

### MemoryFilesystem.readFileAlloc

```zig
pub fn readFileAlloc(self: *const MemoryFilesystem, allocator: std.mem.Allocator, path: []const u8) ![]const u8
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-writefile"></a>

### MemoryFilesystem.writeFile

```zig
pub fn writeFile(self: *MemoryFilesystem, path: []const u8, contents: []const u8) !void
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-removefile"></a>

### MemoryFilesystem.removeFile

```zig
pub fn removeFile(self: *MemoryFilesystem, path: []const u8) !void
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-renamefile"></a>

### MemoryFilesystem.renameFile

```zig
pub fn renameFile(self: *MemoryFilesystem, old_path: []const u8, new_path: []const u8) !void
```

References: [`MemoryFilesystem`](#type-memoryfilesystem)

<a id="fn-memoryfilesystem-normalizepathalloc"></a>

### MemoryFilesystem.normalizePathAlloc

```zig
pub fn normalizePathAlloc(allocator: std.mem.Allocator, path: []const u8, max_path_len: usize) ![]u8
```

<a id="type-filesystemcapability"></a>

## FilesystemCapability

```zig
pub const FilesystemCapability = union(enum) { ... };
```

### Fields

```zig
    memory: []const MemoryFile
    memory_rw: *MemoryFilesystem
```


<a id="type-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = union(enum) { ... };
```

### Fields

```zig
    fixed: i64
```


<a id="type-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = enum { ... };
```

