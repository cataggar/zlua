# runtime.chunk

## Navigation

- [API Index](../README.md)
- Previous: [runtime](../runtime.md)
- Next: [runtime.types](../runtime/types.md)
- Parent: [runtime](../runtime.md)

## Functions

- [appendBinaryChunkHeader](#fn-appendbinarychunkheader)
- [dumpClosureBinary](#fn-dumpclosurebinary)
- [BinaryChunkReader](#fn-binarychunkreader)

## Constants

- [binary_chunk_signature](#const-binary_chunk_signature)
- [binary_chunk_payload_magic](#const-binary_chunk_payload_magic)

<a id="const-binary_chunk_signature"></a>

## binary_chunk_signature

```zig
pub const binary_chunk_signature = "\x1bLua";
```

<a id="const-binary_chunk_payload_magic"></a>

## binary_chunk_payload_magic

```zig
pub const binary_chunk_payload_magic = "zlua\x00bc1";
```

<a id="fn-appendbinarychunkheader"></a>

## appendBinaryChunkHeader

```zig
pub fn appendBinaryChunkHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !void
```

<a id="fn-dumpclosurebinary"></a>

## dumpClosureBinary

```zig
pub fn dumpClosureBinary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), closure: *const types.Closure, strip_debug: bool) !void
```

<a id="fn-binarychunkreader"></a>

## BinaryChunkReader

```zig
pub fn BinaryChunkReader(comptime State: type) type
```

