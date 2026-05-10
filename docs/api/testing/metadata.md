# testing.metadata

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

- [parse](#fn-parse)
- [parseStage](#fn-parsestage)

## Types

- [Expect](#type-expect)
- [Stage](#type-stage)
- [Normalize](#type-normalize)
- [Metadata](#type-metadata)

<a id="type-expect"></a>

## Expect

```zig
pub const Expect = enum {
    pass,
    fail,
    skip,
};
```

<a id="type-stage"></a>

## Stage

```zig
pub const Stage = enum {
    lex,
    parse,
    resolve,
    compile,
    runtime,
    stdlib,
    official,
};
```

<a id="type-normalize"></a>

## Normalize

```zig
pub const Normalize = enum {
    none,
    paths,
};
```

<a id="type-metadata"></a>

## Metadata

```zig
pub const Metadata = struct {
    expect: Expect = .pass,
    stage: Stage = .runtime,
    feature: []const u8 = "uncategorized",
    normalize: Normalize = .none,
    reason: []const u8 = "",
    issue: []const u8 = "",
};
```

<a id="fn-parse"></a>

## parse

```zig
pub fn parse(source: []const u8) !Metadata
```

References: [`Metadata`](#type-metadata)

<a id="fn-parsestage"></a>

## parseStage

```zig
pub fn parseStage(value: []const u8) !Stage
```

References: [`Stage`](#type-stage)

