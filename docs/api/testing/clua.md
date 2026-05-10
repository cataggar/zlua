# testing.clua

## Navigation

- [API Index](../README.md)
- Parent: [testing](../testing.md)

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

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-discovery-deinit) | `self: Discovery, allocator: std.mem.Allocator` | `void` |  |

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

