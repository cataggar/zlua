# runtime.host

## Navigation

- [API Index](../README.md)
- Parent: [runtime](../runtime.md)

<details>
<summary>All documents</summary>

- [root](../root.md)
- [frontend](../frontend.md)
- [errors](../errors.md)
- [frontend.source](../frontend/source.md)
- [frontend.token](../frontend/token.md)
- [frontend.diagnostic](../frontend/diagnostic.md)
- [frontend.lexer](../frontend/lexer.md)
- [frontend.ast](../frontend/ast.md)
- [frontend.parser](../frontend/parser.md)
- [compile](../compile.md)
- [compile.resolver](../compile/resolver.md)
- [compile.bytecode](../compile/bytecode.md)
- [compile.proto](../compile/proto.md)
- [compile.compiler](../compile/compiler.md)
- [compile.disasm](../compile/disasm.md)
- [api](../api.md)
- [runtime](../runtime.md)
- [runtime.chunk](../runtime/chunk.md)
- [runtime.types](../runtime/types.md)
- [runtime.value](../runtime/value.md)
- [runtime.execute](../runtime/execute.md)
- [testing.process](../testing/process.md)
- [runtime.state](../runtime/state.md)
- [runtime.call](../runtime/call.md)
- [runtime.coroutine](../runtime/coroutine.md)
- [runtime.debug](../runtime/debug.md)
- [runtime.gc](../runtime/gc.md)
- [runtime.host](../runtime/host.md)
- [stdlib](../stdlib.md)
- [stdlib.base](../stdlib/base.md)
- [stdlib.table](../stdlib/table.md)
- [stdlib.string](../stdlib/string.md)
- [stdlib.math](../stdlib/math.md)
- [stdlib.utf8](../stdlib/utf8.md)
- [stdlib.coroutine](../stdlib/coroutine.md)
- [stdlib.debug](../stdlib/debug.md)
- [stdlib.package](../stdlib/package.md)
- [stdlib.io](../stdlib/io.md)
- [stdlib.os](../stdlib/os.md)
- [stdlib.json](../stdlib/json.md)
- [stdlib.zerde_lua](../stdlib/zerde_lua.md)
- [stdlib.toml](../stdlib/toml.md)
- [stdlib.msgpack](../stdlib/msgpack.md)
- [stdlib.csv](../stdlib/csv.md)
- [runtime.vm](../runtime/vm.md)
- [runtime.tests](../runtime/tests.md)
- [runtime.internal](../runtime/internal.md)
- [testing](../testing.md)
- [testing.clua](../testing/clua.md)
- [testing.bench_runner](../testing/bench_runner.md)
- [testing.c_api_runner](../testing/c_api_runner.md)
- [testing.diff_runner](../testing/diff_runner.md)
- [testing.expected_failures](../testing/expected_failures.md)
- [testing.metadata](../testing/metadata.md)
- [testing.normalizer](../testing/normalizer.md)
- [testing.extension_runner](../testing/extension_runner.md)
- [testing.official_suite](../testing/official_suite.md)

</details>

## Types

- [MemoryFile](#type-memoryfile)
- [MemoryFilesystem](#type-memoryfilesystem)
- [FilesystemCapability](#type-filesystemcapability)
- [ClockCapability](#type-clockcapability)
- [ProcessCapability](#type-processcapability)

<a id="type-memoryfile"></a>

## MemoryFile

```zig
pub const MemoryFile = struct {
    path: []const u8,
    contents: []const u8,
};
```

<a id="type-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayList(MemoryFile) = .empty,
    options: Options = .{},
    bytes_used: usize = 0,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [default_max_path_len](#const-memoryfilesystem-default_max_path_len) |  |  |  |
| [Options](#type-memoryfilesystem-options) |  |  |  |
| [init](#fn-memoryfilesystem-init) | `allocator: std.mem.Allocator` | `MemoryFilesystem` |  |
| [initWithOptions](#fn-memoryfilesystem-initwithoptions) | `allocator: std.mem.Allocator, options: Options` | `MemoryFilesystem` |  |
| [initWithFiles](#fn-memoryfilesystem-initwithfiles) | `allocator: std.mem.Allocator, files: []const MemoryFile` | `!MemoryFilesystem` |  |
| [initWithFilesAndOptions](#fn-memoryfilesystem-initwithfilesandoptions) | `allocator: std.mem.Allocator, files: []const MemoryFile, options: Options` | `!MemoryFilesystem` |  |
| [deinit](#fn-memoryfilesystem-deinit) | `self: *MemoryFilesystem` | `void` |  |
| [readFileAlloc](#fn-memoryfilesystem-readfilealloc) | `self: *const MemoryFilesystem, allocator: std.mem.Allocator, path: []const u8` | `![]const u8` |  |
| [writeFile](#fn-memoryfilesystem-writefile) | `self: *MemoryFilesystem, path: []const u8, contents: []const u8` | `!void` |  |
| [removeFile](#fn-memoryfilesystem-removefile) | `self: *MemoryFilesystem, path: []const u8` | `!void` |  |
| [renameFile](#fn-memoryfilesystem-renamefile) | `self: *MemoryFilesystem, old_path: []const u8, new_path: []const u8` | `!void` |  |
| [normalizePathAlloc](#fn-memoryfilesystem-normalizepathalloc) | `allocator: std.mem.Allocator, path: []const u8, max_path_len: usize` | `![]u8` |  |

<a id="const-memoryfilesystem-default_max_path_len"></a>

### MemoryFilesystem.default_max_path_len

```zig
pub const default_max_path_len: usize = 4096;
```

<a id="type-memoryfilesystem-options"></a>

### MemoryFilesystem.Options

```zig
pub const Options = struct {
    max_path_len: usize = default_max_path_len,
    max_bytes: ?usize = null,
};
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
pub const FilesystemCapability = union(enum) {
    disabled,
    memory: []const MemoryFile,
    memory_rw: *MemoryFilesystem,
    host_cwd,
};
```

<a id="type-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = union(enum) {
    disabled,
    fixed: i64,
    system,
};
```

<a id="type-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = enum {
    disabled,
    enabled,
};
```

