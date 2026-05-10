# frontend

## Navigation

- [API Index](README.md)
- Previous: [root](root.md)
- Next: [errors](errors.md)
- Submodules: [frontend.source](frontend/source.md), [frontend.token](frontend/token.md), [frontend.diagnostic](frontend/diagnostic.md), [frontend.lexer](frontend/lexer.md), [frontend.ast](frontend/ast.md), [frontend.parser](frontend/parser.md)

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

