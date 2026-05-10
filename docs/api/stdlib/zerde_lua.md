# stdlib.zerde_lua

## Navigation

- [API Index](../README.md)
- Parent: [stdlib](../stdlib.md)

<details>
<summary>All documents</summary>

- [root](../root.md)
- [frontend](../frontend.md)
- [errors](../errors.md)
- [frontend.source](../frontend/source.md)
- [frontend.token](../frontend/token.md)
- [frontend.diagnostic](../frontend/diagnostic.md)
- [frontend.lexer](../frontend/lexer.md)
- [frontend.ast](../frontend/ast.md)
- [frontend.parser](../frontend/parser.md)
- [compile](../compile.md)
- [compile.resolver](../compile/resolver.md)
- [compile.bytecode](../compile/bytecode.md)
- [compile.proto](../compile/proto.md)
- [compile.compiler](../compile/compiler.md)
- [compile.disasm](../compile/disasm.md)
- [api](../api.md)
- [runtime](../runtime.md)
- [runtime.chunk](../runtime/chunk.md)
- [runtime.types](../runtime/types.md)
- [runtime.value](../runtime/value.md)
- [runtime.execute](../runtime/execute.md)
- [testing.process](../testing/process.md)
- [runtime.state](../runtime/state.md)
- [runtime.call](../runtime/call.md)
- [runtime.coroutine](../runtime/coroutine.md)
- [runtime.debug](../runtime/debug.md)
- [runtime.gc](../runtime/gc.md)
- [runtime.host](../runtime/host.md)
- [stdlib](../stdlib.md)
- [stdlib.base](../stdlib/base.md)
- [stdlib.table](../stdlib/table.md)
- [stdlib.string](../stdlib/string.md)
- [stdlib.math](../stdlib/math.md)
- [stdlib.utf8](../stdlib/utf8.md)
- [stdlib.coroutine](../stdlib/coroutine.md)
- [stdlib.debug](../stdlib/debug.md)
- [stdlib.package](../stdlib/package.md)
- [stdlib.io](../stdlib/io.md)
- [stdlib.os](../stdlib/os.md)
- [stdlib.json](../stdlib/json.md)
- [stdlib.zerde_lua](../stdlib/zerde_lua.md)
- [stdlib.toml](../stdlib/toml.md)
- [stdlib.msgpack](../stdlib/msgpack.md)
- [stdlib.csv](../stdlib/csv.md)
- [runtime.vm](../runtime/vm.md)
- [runtime.tests](../runtime/tests.md)
- [runtime.internal](../runtime/internal.md)
- [testing](../testing.md)
- [testing.clua](../testing/clua.md)
- [testing.bench_runner](../testing/bench_runner.md)
- [testing.c_api_runner](../testing/c_api_runner.md)
- [testing.diff_runner](../testing/diff_runner.md)
- [testing.expected_failures](../testing/expected_failures.md)
- [testing.metadata](../testing/metadata.md)
- [testing.normalizer](../testing/normalizer.md)
- [testing.extension_runner](../testing/extension_runner.md)
- [testing.official_suite](../testing/official_suite.md)

</details>

## Functions

- [ensureSupportTables](#fn-ensuresupporttables)
- [nullValue](#fn-nullvalue)
- [inputBytes](#fn-inputbytes)
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

<a id="fn-inputbytes"></a>

## inputBytes

```zig
pub fn inputBytes(state: *State, value: Value, function_name: []const u8) ![]const u8
```

<a id="type-luasink"></a>

## LuaSink

```zig
pub const LuaSink = struct {
    state: *State,
    stack: std.ArrayList(Frame) = .empty,
    root: Value = .nil,
    has_root: bool = false,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [init](#fn-luasink-init) | `state: *State` | `LuaSink` |  |
| [deinit](#fn-luasink-deinit) | `self: *LuaSink` | `void` |  |
| [emitNull](#fn-luasink-emitnull) | `self: *LuaSink` | `!void` |  |
| [emitBool](#fn-luasink-emitbool) | `self: *LuaSink, value: bool` | `!void` |  |
| [emitInt](#fn-luasink-emitint) | `self: *LuaSink, value: i128` | `!void` |  |
| [emitFloat](#fn-luasink-emitfloat) | `self: *LuaSink, value: f64` | `!void` |  |
| [emitString](#fn-luasink-emitstring) | `self: *LuaSink, value: []const u8` | `!void` |  |
| [emitBytes](#fn-luasink-emitbytes) | `self: *LuaSink, value: []const u8` | `!void` |  |
| [emitDateTimeRaw](#fn-luasink-emitdatetimeraw) | `self: *LuaSink, value: []const u8` | `!void` |  |
| [beginSeq](#fn-luasink-beginseq) | `self: *LuaSink, len: ?usize` | `!void` |  |
| [endSeq](#fn-luasink-endseq) | `self: *LuaSink` | `!void` |  |
| [beginStruct](#fn-luasink-beginstruct) | `self: *LuaSink, len: ?usize` | `!void` |  |
| [emitFieldName](#fn-luasink-emitfieldname) | `self: *LuaSink, name: []const u8` | `!void` |  |
| [endStruct](#fn-luasink-endstruct) | `self: *LuaSink` | `!void` |  |

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

