# frontend

## Navigation

- [API Index](README.md)
- Submodules: [frontend.source](frontend/source.md), [frontend.token](frontend/token.md), [frontend.diagnostic](frontend/diagnostic.md), [frontend.lexer](frontend/lexer.md), [frontend.ast](frontend/ast.md), [frontend.parser](frontend/parser.md)

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

## Functions

- [lex](#fn-lex)
- [parse](#fn-parse)
- [parseWithDiagnostic](#fn-parsewithdiagnostic)

## Aliases

- [Lexer](#alias-lexer)
- [Token](#alias-token)
- [TokenTag](#alias-tokentag)
- [Ast](#alias-ast)

## Imports

- [source](#import-source) `@import("frontend/source.zig")`
- [diagnostic](#import-diagnostic) `@import("frontend/diagnostic.zig")`
- [token](#import-token) `@import("frontend/token.zig")`
- [lexer](#import-lexer) `@import("frontend/lexer.zig")`
- [ast](#import-ast) `@import("frontend/ast.zig")`
- [parser](#import-parser) `@import("frontend/parser.zig")`

<a id="import-source"></a>

## source

```zig
pub const source = @import("frontend/source.zig");
```

<a id="import-diagnostic"></a>

## diagnostic

```zig
pub const diagnostic = @import("frontend/diagnostic.zig");
```

<a id="import-token"></a>

## token

```zig
pub const token = @import("frontend/token.zig");
```

<a id="import-lexer"></a>

## lexer

```zig
pub const lexer = @import("frontend/lexer.zig");
```

<a id="import-ast"></a>

## ast

```zig
pub const ast = @import("frontend/ast.zig");
```

<a id="import-parser"></a>

## parser

```zig
pub const parser = @import("frontend/parser.zig");
```

<a id="alias-lexer"></a>

## Lexer

```zig
pub const Lexer = lexer.Lexer;
```

References: [`lexer.Lexer`](frontend/lexer.md#type-lexer)

<a id="alias-token"></a>

## Token

```zig
pub const Token = token.Token;
```

References: [`token.Token`](frontend/token.md#type-token)

<a id="alias-tokentag"></a>

## TokenTag

```zig
pub const TokenTag = token.Tag;
```

References: [`token.Tag`](frontend/token.md#type-tag)

<a id="alias-ast"></a>

## Ast

```zig
pub const Ast = ast.Ast;
```

References: [`ast.Ast`](frontend/ast.md#type-ast)

<a id="fn-lex"></a>

## lex

```zig
pub fn lex(allocator: std.mem.Allocator, source_text: []const u8) ![]Token
```

References: [`Token`](#alias-token)

<a id="fn-parse"></a>

## parse

```zig
pub fn parse(allocator: std.mem.Allocator, source_text: []const u8) !Ast
```

References: [`Ast`](#alias-ast)

<a id="fn-parsewithdiagnostic"></a>

## parseWithDiagnostic

```zig
pub fn parseWithDiagnostic(allocator: std.mem.Allocator, source_text: []const u8, error_diagnostic: *?errors.Diagnostic) !Ast
```

References: [`errors.Diagnostic`](errors.md#type-diagnostic), [`Ast`](#alias-ast)

