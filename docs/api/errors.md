# errors

## Navigation

- [API Index](README.md)
- Previous: [compile.disasm](compile/disasm.md)
- Next: [api](api.md)

## Functions

- [tokenRef](#fn-tokenref)
- [eofToken](#fn-eoftoken)
- [renderLoadDiagnostic](#fn-renderloaddiagnostic)
- [renderArgumentError](#fn-renderargumenterror)

## Types

- [ZluaError](#type-zluaerror)
- [HostError](#type-hosterror)
- [Diagnostic](#type-diagnostic)
- [ArgumentError](#type-argumenterror)
- [ArgumentErrorDetail](#type-argumenterrordetail)
- [SyntaxError](#type-syntaxerror)
- [TokenRef](#type-tokenref)
- [UnexpectedSyntax](#type-unexpectedsyntax)
- [SyntaxMessage](#type-syntaxmessage)
- [ExpectedSyntax](#type-expectedsyntax)
- [ExpectedClose](#type-expectedclose)
- [ResolveError](#type-resolveerror)
- [CompileError](#type-compileerror)

<a id="type-zluaerror"></a>

## ZluaError

```zig
pub const ZluaError = union(enum) { ... };
```

### Fields

```zig
    diagnostic: Diagnostic
    host: HostError
```


<a id="type-hosterror"></a>

## HostError

```zig
pub const HostError = union(enum) { ... };
```

<a id="type-diagnostic"></a>

## Diagnostic

```zig
pub const Diagnostic = union(enum) { ... };
```

### Fields

```zig
    syntax: SyntaxError
    resolve: ResolveError
    compile: CompileError
    argument: ArgumentError
```


<a id="type-argumenterror"></a>

## ArgumentError

```zig
pub const ArgumentError = struct { ... };
```

### Fields

```zig
    function_name: []const u8
    index: u16
    detail: ArgumentErrorDetail
```


<a id="type-argumenterrordetail"></a>

## ArgumentErrorDetail

```zig
pub const ArgumentErrorDetail = union(enum) { ... };
```

### Fields

```zig
    message: []const u8
    expected: struct {
        expected: []const u8,
        actual: []const u8,
    }
```


<a id="type-syntaxerror"></a>

## SyntaxError

```zig
pub const SyntaxError = union(enum) { ... };
```

### Fields

```zig
    unexpected: UnexpectedSyntax
    expected: ExpectedSyntax
    expected_close: ExpectedClose
```


<a id="type-tokenref"></a>

## TokenRef

```zig
pub const TokenRef = struct { ... };
```

### Fields

```zig
    tag: token_mod.Tag
    lexeme: []const u8
    span: source.Span
    unquoted: bool = false
```


<a id="type-unexpectedsyntax"></a>

## UnexpectedSyntax

```zig
pub const UnexpectedSyntax = struct { ... };
```

### Fields

```zig
    token: TokenRef
    message: SyntaxMessage = .syntax_error
```


<a id="type-syntaxmessage"></a>

## SyntaxMessage

```zig
pub const SyntaxMessage = enum { ... };
```

<a id="type-expectedsyntax"></a>

## ExpectedSyntax

```zig
pub const ExpectedSyntax = struct { ... };
```

### Fields

```zig
    expected: []const u8
    near: TokenRef
```


<a id="type-expectedclose"></a>

## ExpectedClose

```zig
pub const ExpectedClose = struct { ... };
```

### Fields

```zig
    expected: []const u8
    opener: []const u8
    opener_line: usize
    near: TokenRef
```


<a id="type-resolveerror"></a>

## ResolveError

```zig
pub const ResolveError = union(enum) { ... };
```

### Fields

```zig
    duplicate_label: struct { name: []const u8, span: source.Span, previous_line: usize }
    missing_label: struct { name: []const u8, span: source.Span }
    goto_into_scope: struct { label: []const u8, decl: []const u8, span: source.Span }
    break_outside_loop: source.Span
    assign_const: struct { name: []const u8, span: source.Span }
    undeclared_global: struct { name: []const u8, span: source.Span }
    invalid_close: struct { span: source.Span, global: bool = false, multiple: bool = false }
    unknown_attribute: struct { name: []const u8, span: source.Span }
    invalid_assignment_target: source.Span
    invalid_environment: struct { name: []const u8, span: source.Span }
```


<a id="type-compileerror"></a>

## CompileError

```zig
pub const CompileError = union(enum) { ... };
```

### Fields

```zig
    too_many_returns: source.Span
    register_overflow: struct { line: usize }
    too_many_local_variables: struct { line: usize }
    too_many_upvalues: struct { line: usize }
    jump_out_of_range: struct { line: usize }
    invalid_ast: struct { line: usize }
```


<a id="fn-tokenref"></a>

## tokenRef

```zig
pub fn tokenRef(token: token_mod.Token) TokenRef
```

References: [`TokenRef`](#type-tokenref)

<a id="fn-eoftoken"></a>

## eofToken

```zig
pub fn eofToken(source_text: []const u8, line: usize, column: usize) TokenRef
```

References: [`TokenRef`](#type-tokenref)

<a id="fn-renderloaddiagnostic"></a>

## renderLoadDiagnostic

```zig
pub fn renderLoadDiagnostic(
    allocator: std.mem.Allocator,
    source_name: ?[]const u8,
    source_text: []const u8,
    diagnostic: Diagnostic,
) ![]u8
```

References: [`Diagnostic`](#type-diagnostic)

<a id="fn-renderargumenterror"></a>

## renderArgumentError

```zig
pub fn renderArgumentError(allocator: std.mem.Allocator, argument: ArgumentError) ![]u8
```

References: [`ArgumentError`](#type-argumenterror)

