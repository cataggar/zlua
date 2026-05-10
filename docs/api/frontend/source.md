# frontend.source

## Navigation

- [API Index](../README.md)
- Previous: [errors](../errors.md)
- Next: [frontend.token](../frontend/token.md)
- Parent: [frontend](../frontend.md)

## Types

- [Position](#type-position)
- [Span](#type-span)

<a id="type-position"></a>

## Position

```zig
pub const Position = struct {
    offset: usize = 0,
    line: usize = 1,
    column: usize = 1,
};
```

<a id="type-span"></a>

## Span

```zig
pub const Span = struct {
    start: Position,
    end: Position,
};
```

### Nested Declarations

- [slice](#fn-span-slice)

<a id="fn-span-slice"></a>

### Span.slice

```zig
pub fn slice(self: Span, source: []const u8) []const u8
```

References: [`Span`](#type-span)

