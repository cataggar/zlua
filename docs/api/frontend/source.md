# frontend.source

## Navigation

- [API Index](../README.md)
- Previous: [frontend](../frontend.md)
- Next: [frontend.diagnostic](../frontend/diagnostic.md)
- Parent: [frontend](../frontend.md)

## Types

- [Position](#type-position)
- [Span](#type-span)

<a id="type-position"></a>

## Position

```zig
pub const Position = struct { ... };
```

### Fields

- `offset`
- `line`
- `column`

<a id="type-span"></a>

## Span

```zig
pub const Span = struct { ... };
```

### Fields

- `start`
- `end`

### Nested Declarations

- [slice](#fn-span-slice)

<a id="fn-span-slice"></a>

### Span.slice

```zig
pub fn slice(self: Span, source: []const u8) []const u8
```

References: [`Span`](#type-span)

