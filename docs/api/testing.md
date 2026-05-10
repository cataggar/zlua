# testing

## Navigation

- [API Index](README.md)
- Submodules: [testing.process](testing/process.md), [testing.clua](testing/clua.md), [testing.bench_runner](testing/bench_runner.md), [testing.c_api_runner](testing/c_api_runner.md), [testing.diff_runner](testing/diff_runner.md), [testing.expected_failures](testing/expected_failures.md), [testing.metadata](testing/metadata.md), [testing.normalizer](testing/normalizer.md), [testing.extension_runner](testing/extension_runner.md), [testing.official_suite](testing/official_suite.md)

<details>
<summary>All documents</summary>

- [root](root.md)
- [frontend](frontend.md)
- [errors](errors.md)
- [frontend.source](frontend/source.md)
- [frontend.token](frontend/token.md)
- [frontend.diagnostic](frontend/diagnostic.md)
- [frontend.lexer](frontend/lexer.md)
- [frontend.ast](frontend/ast.md)
- [frontend.parser](frontend/parser.md)
- [compile](compile.md)
- [compile.resolver](compile/resolver.md)
- [compile.bytecode](compile/bytecode.md)
- [compile.proto](compile/proto.md)
- [compile.compiler](compile/compiler.md)
- [compile.disasm](compile/disasm.md)
- [api](api.md)
- [runtime](runtime.md)
- [runtime.chunk](runtime/chunk.md)
- [runtime.types](runtime/types.md)
- [runtime.value](runtime/value.md)
- [runtime.execute](runtime/execute.md)
- [testing.process](testing/process.md)
- [runtime.state](runtime/state.md)
- [runtime.call](runtime/call.md)
- [runtime.coroutine](runtime/coroutine.md)
- [runtime.debug](runtime/debug.md)
- [runtime.gc](runtime/gc.md)
- [runtime.host](runtime/host.md)
- [stdlib](stdlib.md)
- [stdlib.base](stdlib/base.md)
- [stdlib.table](stdlib/table.md)
- [stdlib.string](stdlib/string.md)
- [stdlib.math](stdlib/math.md)
- [stdlib.utf8](stdlib/utf8.md)
- [stdlib.coroutine](stdlib/coroutine.md)
- [stdlib.debug](stdlib/debug.md)
- [stdlib.package](stdlib/package.md)
- [stdlib.io](stdlib/io.md)
- [stdlib.os](stdlib/os.md)
- [stdlib.json](stdlib/json.md)
- [stdlib.zerde_lua](stdlib/zerde_lua.md)
- [stdlib.toml](stdlib/toml.md)
- [stdlib.msgpack](stdlib/msgpack.md)
- [stdlib.csv](stdlib/csv.md)
- [runtime.vm](runtime/vm.md)
- [runtime.tests](runtime/tests.md)
- [runtime.internal](runtime/internal.md)
- [testing](testing.md)
- [testing.clua](testing/clua.md)
- [testing.bench_runner](testing/bench_runner.md)
- [testing.c_api_runner](testing/c_api_runner.md)
- [testing.diff_runner](testing/diff_runner.md)
- [testing.expected_failures](testing/expected_failures.md)
- [testing.metadata](testing/metadata.md)
- [testing.normalizer](testing/normalizer.md)
- [testing.extension_runner](testing/extension_runner.md)
- [testing.official_suite](testing/official_suite.md)

</details>

## Imports

- [clua](#import-clua) `@import("testing/clua.zig")`
- [bench_runner](#import-bench_runner) `@import("testing/bench_runner.zig")`
- [c_api_runner](#import-c_api_runner) `@import("testing/c_api_runner.zig")`
- [diff_runner](#import-diff_runner) `@import("testing/diff_runner.zig")`
- [extension_runner](#import-extension_runner) `@import("testing/extension_runner.zig")`
- [expected_failures](#import-expected_failures) `@import("testing/expected_failures.zig")`
- [metadata](#import-metadata) `@import("testing/metadata.zig")`
- [normalizer](#import-normalizer) `@import("testing/normalizer.zig")`
- [official_suite](#import-official_suite) `@import("testing/official_suite.zig")`
- [process](#import-process) `@import("testing/process.zig")`

<a id="import-clua"></a>

## clua

```zig
pub const clua = @import("testing/clua.zig");
```

<a id="import-bench_runner"></a>

## bench_runner

```zig
pub const bench_runner = @import("testing/bench_runner.zig");
```

<a id="import-c_api_runner"></a>

## c_api_runner

```zig
pub const c_api_runner = @import("testing/c_api_runner.zig");
```

<a id="import-diff_runner"></a>

## diff_runner

```zig
pub const diff_runner = @import("testing/diff_runner.zig");
```

<a id="import-extension_runner"></a>

## extension_runner

```zig
pub const extension_runner = @import("testing/extension_runner.zig");
```

<a id="import-expected_failures"></a>

## expected_failures

```zig
pub const expected_failures = @import("testing/expected_failures.zig");
```

<a id="import-metadata"></a>

## metadata

```zig
pub const metadata = @import("testing/metadata.zig");
```

<a id="import-normalizer"></a>

## normalizer

```zig
pub const normalizer = @import("testing/normalizer.zig");
```

<a id="import-official_suite"></a>

## official_suite

```zig
pub const official_suite = @import("testing/official_suite.zig");
```

<a id="import-process"></a>

## process

```zig
pub const process = @import("testing/process.zig");
```

