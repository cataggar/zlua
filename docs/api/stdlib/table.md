# stdlib.table

## Navigation

- [API Index](../README.md)
- Parent: [stdlib](../stdlib.md)

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

- [concat](#fn-concat)
- [insert](#fn-insert)
- [move](#fn-move)
- [pack](#fn-pack)
- [remove](#fn-remove)
- [sort](#fn-sort)
- [unpack](#fn-unpack)

<a id="fn-concat"></a>

## concat

```zig
pub fn concat(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-insert"></a>

## insert

```zig
pub fn insert(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-move"></a>

## move

```zig
pub fn move(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-pack"></a>

## pack

```zig
pub fn pack(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-remove"></a>

## remove

```zig
pub fn remove(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sort"></a>

## sort

```zig
pub fn sort(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-unpack"></a>

## unpack

```zig
pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void
```

