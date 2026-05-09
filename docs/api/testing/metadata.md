# testing.metadata

## Navigation

- [API Index](../README.md)
- Previous: [testing.expected_failures](../testing/expected_failures.md)
- Next: [testing.normalizer](../testing/normalizer.md)
- Parent: [testing](../testing.md)

## Functions

- [parse](#fn-parse)
- [parseStage](#fn-parsestage)

## Types

- [Expect](#type-expect)
- [Stage](#type-stage)
- [Normalize](#type-normalize)
- [Metadata](#type-metadata)

<a id="type-expect"></a>

## Expect

```zig
pub const Expect = enum { ... };
```

<a id="type-stage"></a>

## Stage

```zig
pub const Stage = enum { ... };
```

<a id="type-normalize"></a>

## Normalize

```zig
pub const Normalize = enum { ... };
```

<a id="type-metadata"></a>

## Metadata

```zig
pub const Metadata = struct { ... };
```

### Fields

- `expect`
- `stage`
- `feature`
- `normalize`
- `reason`
- `issue`

<a id="fn-parse"></a>

## parse

```zig
pub fn parse(source: []const u8) !Metadata
```

References: [`Metadata`](#type-metadata)

<a id="fn-parsestage"></a>

## parseStage

```zig
pub fn parseStage(value: []const u8) !Stage
```

References: [`Stage`](#type-stage)

