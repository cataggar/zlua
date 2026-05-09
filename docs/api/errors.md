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

- `diagnostic`
- `host`

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

- `syntax`
- `resolve`
- `compile`
- `argument`

<a id="type-argumenterror"></a>

## ArgumentError

```zig
pub const ArgumentError = struct { ... };
```

### Fields

- `function_name`
- `index`
- `detail`

<a id="type-argumenterrordetail"></a>

## ArgumentErrorDetail

```zig
pub const ArgumentErrorDetail = union(enum) { ... };
```

### Fields

- `message`
- `expected`

<a id="type-syntaxerror"></a>

## SyntaxError

```zig
pub const SyntaxError = union(enum) { ... };
```

### Fields

- `unexpected`
- `expected`
- `expected_close`

<a id="type-tokenref"></a>

## TokenRef

```zig
pub const TokenRef = struct { ... };
```

### Fields

- `tag`
- `lexeme`
- `span`
- `unquoted`

<a id="type-unexpectedsyntax"></a>

## UnexpectedSyntax

```zig
pub const UnexpectedSyntax = struct { ... };
```

### Fields

- `token`
- `message`

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

- `expected`
- `near`

<a id="type-expectedclose"></a>

## ExpectedClose

```zig
pub const ExpectedClose = struct { ... };
```

### Fields

- `expected`
- `opener`
- `opener_line`
- `near`

<a id="type-resolveerror"></a>

## ResolveError

```zig
pub const ResolveError = union(enum) { ... };
```

### Fields

- `duplicate_label`
- `missing_label`
- `goto_into_scope`
- `break_outside_loop`
- `assign_const`
- `undeclared_global`
- `invalid_close`
- `unknown_attribute`
- `invalid_assignment_target`
- `invalid_environment`

<a id="type-compileerror"></a>

## CompileError

```zig
pub const CompileError = union(enum) { ... };
```

### Fields

- `too_many_returns`
- `register_overflow`
- `too_many_local_variables`
- `too_many_upvalues`
- `jump_out_of_range`
- `invalid_ast`

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

