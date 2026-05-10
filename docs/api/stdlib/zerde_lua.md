# stdlib.zerde_lua

## Navigation

- [API Index](../README.md)
- Previous: [stdlib.json](../stdlib/json.md)
- Next: [stdlib.toml](../stdlib/toml.md)
- Parent: [stdlib](../stdlib.md)

## Functions

- [ensureSupportTables](#fn-ensuresupporttables)
- [nullValue](#fn-nullvalue)
- [source](#fn-source)
- [LuaSource](#fn-luasource)

## Types

- [LuaSink](#type-luasink)

<a id="fn-ensuresupporttables"></a>

## ensureSupportTables

```zig
pub fn ensureSupportTables(state: *State) !void
```

<a id="fn-nullvalue"></a>

## nullValue

```zig
pub fn nullValue(state: *State) !Value
```

<a id="type-luasink"></a>

## LuaSink

```zig
pub const LuaSink = struct { ... };
```

### Fields

```zig
    state: *State
    stack: std.ArrayList(Frame) = .empty
    root: Value = .nil
    has_root: bool = false
```


### Nested Declarations

- [init](#fn-luasink-init)
- [deinit](#fn-luasink-deinit)
- [emitNull](#fn-luasink-emitnull)
- [emitBool](#fn-luasink-emitbool)
- [emitInt](#fn-luasink-emitint)
- [emitFloat](#fn-luasink-emitfloat)
- [emitString](#fn-luasink-emitstring)
- [emitBytes](#fn-luasink-emitbytes)
- [emitDateTimeRaw](#fn-luasink-emitdatetimeraw)
- [beginSeq](#fn-luasink-beginseq)
- [endSeq](#fn-luasink-endseq)
- [beginStruct](#fn-luasink-beginstruct)
- [emitFieldName](#fn-luasink-emitfieldname)
- [endStruct](#fn-luasink-endstruct)

<a id="fn-luasink-init"></a>

### LuaSink.init

```zig
pub fn init(state: *State) LuaSink
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-deinit"></a>

### LuaSink.deinit

```zig
pub fn deinit(self: *LuaSink) void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitnull"></a>

### LuaSink.emitNull

```zig
pub fn emitNull(self: *LuaSink) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitbool"></a>

### LuaSink.emitBool

```zig
pub fn emitBool(self: *LuaSink, value: bool) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitint"></a>

### LuaSink.emitInt

```zig
pub fn emitInt(self: *LuaSink, value: i128) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitfloat"></a>

### LuaSink.emitFloat

```zig
pub fn emitFloat(self: *LuaSink, value: f64) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitstring"></a>

### LuaSink.emitString

```zig
pub fn emitString(self: *LuaSink, value: []const u8) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitbytes"></a>

### LuaSink.emitBytes

```zig
pub fn emitBytes(self: *LuaSink, value: []const u8) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitdatetimeraw"></a>

### LuaSink.emitDateTimeRaw

```zig
pub fn emitDateTimeRaw(self: *LuaSink, value: []const u8) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-beginseq"></a>

### LuaSink.beginSeq

```zig
pub fn beginSeq(self: *LuaSink, len: ?usize) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-endseq"></a>

### LuaSink.endSeq

```zig
pub fn endSeq(self: *LuaSink) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-beginstruct"></a>

### LuaSink.beginStruct

```zig
pub fn beginStruct(self: *LuaSink, len: ?usize) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-emitfieldname"></a>

### LuaSink.emitFieldName

```zig
pub fn emitFieldName(self: *LuaSink, name: []const u8) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-luasink-endstruct"></a>

### LuaSink.endStruct

```zig
pub fn endStruct(self: *LuaSink) !void
```

References: [`LuaSink`](#type-luasink)

<a id="fn-source"></a>

## source

```zig
pub fn source(state: *State, encoder: anytype, operation: []const u8) LuaSource(@TypeOf(encoder.*))
```

<a id="fn-luasource"></a>

## LuaSource

```zig
pub fn LuaSource(comptime Encoder: type) type
```

