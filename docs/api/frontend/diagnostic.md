# frontend.diagnostic

## Navigation

- [API Index](../README.md)
- Previous: [frontend.token](../frontend/token.md)
- Next: [frontend.lexer](../frontend/lexer.md)
- Parent: [frontend](../frontend.md)

## Types

- [Code](#type-code)
- [Diagnostic](#type-diagnostic)

<a id="type-code"></a>

## Code

```zig
pub const Code = enum {};
```

<a id="type-diagnostic"></a>

## Diagnostic

```zig
pub const Diagnostic = struct {
    code: Code,
    span: source.Span,
    message: []const u8,
};
```

