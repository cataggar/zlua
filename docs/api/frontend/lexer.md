# frontend.lexer

## Navigation

- [API Index](../README.md)
- Previous: [frontend.token](../frontend/token.md)
- Next: [frontend.ast](../frontend/ast.md)
- Parent: [frontend](../frontend.md)

## Functions

- [lex](#fn-lex)
- [lexWithDiagnostic](#fn-lexwithdiagnostic)

## Types

- [Lexer](#type-lexer)

<a id="type-lexer"></a>

## Lexer

```zig
pub const Lexer = struct { ... };
```

### Fields

```zig
    allocator: std.mem.Allocator
    source: []const u8
    error_diagnostic: ?*?errors.Diagnostic = null
    index: usize = 0
    line: usize = 1
    column: usize = 1
    diagnostics: std.ArrayList(diagnostic.Diagnostic) = .empty
```


### Nested Declarations

- [init](#fn-lexer-init)
- [initWithDiagnostic](#fn-lexer-initwithdiagnostic)
- [deinit](#fn-lexer-deinit)
- [next](#fn-lexer-next)

<a id="fn-lexer-init"></a>

### Lexer.init

```zig
pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer
```

References: [`Lexer`](#type-lexer)

<a id="fn-lexer-initwithdiagnostic"></a>

### Lexer.initWithDiagnostic

```zig
pub fn initWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) Lexer
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic), [`Lexer`](#type-lexer)

<a id="fn-lexer-deinit"></a>

### Lexer.deinit

```zig
pub fn deinit(self: *Lexer) void
```

References: [`Lexer`](#type-lexer)

<a id="fn-lexer-next"></a>

### Lexer.next

```zig
pub fn next(self: *Lexer) !token_mod.Token
```

References: [`Lexer`](#type-lexer)

<a id="fn-lex"></a>

## lex

```zig
pub fn lex(allocator: std.mem.Allocator, source: []const u8) ![]token_mod.Token
```

<a id="fn-lexwithdiagnostic"></a>

## lexWithDiagnostic

```zig
pub fn lexWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) ![]token_mod.Token
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic)

