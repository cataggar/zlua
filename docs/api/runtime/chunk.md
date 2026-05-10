# runtime.chunk

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

## Functions

- [appendBinaryChunkHeader](#fn-appendbinarychunkheader)
- [dumpClosureBinary](#fn-dumpclosurebinary)
- [BinaryChunkReader](#fn-binarychunkreader)

## Constants

- [binary_chunk_signature](#const-binary_chunk_signature)
- [binary_chunk_payload_magic](#const-binary_chunk_payload_magic)

<a id="const-binary_chunk_signature"></a>

## binary_chunk_signature

```zig
pub const binary_chunk_signature = "\x1bLua";
```

<a id="const-binary_chunk_payload_magic"></a>

## binary_chunk_payload_magic

```zig
pub const binary_chunk_payload_magic = "zlua\x00bc1";
```

<a id="fn-appendbinarychunkheader"></a>

## appendBinaryChunkHeader

```zig
pub fn appendBinaryChunkHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !void
```

<a id="fn-dumpclosurebinary"></a>

## dumpClosureBinary

```zig
pub fn dumpClosureBinary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), closure: *const types.Closure, strip_debug: bool) !void
```

<a id="fn-binarychunkreader"></a>

## BinaryChunkReader

```zig
pub fn BinaryChunkReader(comptime State: type) type
```

