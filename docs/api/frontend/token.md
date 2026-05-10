# frontend.token

## Navigation

- [API Index](../README.md)
- Previous: [frontend.source](../frontend/source.md)
- Next: [frontend.diagnostic](../frontend/diagnostic.md)
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

```zig
    tag: Tag
    lexeme: []const u8
    span: source.Span
```


<a id="fn-keywordtag"></a>

## keywordTag

```zig
pub fn keywordTag(identifier: []const u8) ?Tag
```

References: [`Tag`](#type-tag)

