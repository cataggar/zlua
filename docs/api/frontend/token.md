# frontend.token

## Navigation

- [API Index](../README.md)
- Parent: [frontend](../frontend.md)

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

- [keywordTag](#fn-keywordtag)

## Types

- [Tag](#type-tag)
- [Token](#type-token)

<a id="type-tag"></a>

## Tag

```zig
pub const Tag = enum {
    eof,
    identifier,
    integer_literal,
    float_literal,
    string_literal,
    keyword_and,
    keyword_break,
    keyword_do,
    keyword_else,
    keyword_elseif,
    keyword_end,
    keyword_false,
    keyword_for,
    keyword_function,
    keyword_global,
    keyword_goto,
    keyword_if,
    keyword_in,
    keyword_local,
    keyword_nil,
    keyword_not,
    keyword_or,
    keyword_repeat,
    keyword_return,
    keyword_then,
    keyword_true,
    keyword_until,
    keyword_while,
    plus,
    minus,
    star,
    slash,
    double_slash,
    percent,
    caret,
    hash,
    ampersand,
    pipe,
    tilde,
    double_less,
    double_greater,
    double_equal,
    tilde_equal,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    semicolon,
    colon,
    double_colon,
    comma,
    dot,
    double_dot,
    ellipsis,
};
```

<a id="type-token"></a>

## Token

```zig
pub const Token = struct {
    tag: Tag,
    lexeme: []const u8,
    span: source.Span,
};
```

<a id="fn-keywordtag"></a>

## keywordTag

```zig
pub fn keywordTag(identifier: []const u8) ?Tag
```

References: [`Tag`](#type-tag)

