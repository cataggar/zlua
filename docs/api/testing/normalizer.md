# testing.normalizer

## Navigation

- [API Index](../README.md)
- Previous: [testing.metadata](../testing/metadata.md)
- Next: [testing.official_suite](../testing/official_suite.md)
- Parent: [testing](../testing.md)

## Functions

- [normalizeText](#fn-normalizetext)

<a id="fn-normalizetext"></a>

## normalizeText

```zig
pub fn normalizeText(
    allocator: std.mem.Allocator,
    input: []const u8,
    mode: metadata.Normalize,
    cwd: []const u8,
) ![]u8
```

