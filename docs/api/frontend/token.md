# frontend.token

## Navigation

- [API Index](../README.md)
- Previous: [frontend.diagnostic](../frontend/diagnostic.md)
- Next: [frontend.lexer](../frontend/lexer.md)
- Parent: [frontend](../frontend.md)

## Functions

- [keywordTag](#fn-keywordtag)

## Types

- [Tag](#type-tag)
- [Token](#type-token)

<a id="type-tag"></a>

## Tag

```zig
pub const Tag = enum { ... };
```

<a id="type-token"></a>

## Token

```zig
pub const Token = struct { ... };
```

### Fields

- `tag`
- `lexeme`
- `span`

<a id="fn-keywordtag"></a>

## keywordTag

```zig
pub fn keywordTag(identifier: []const u8) ?Tag
```

References: [`Tag`](#type-tag)

