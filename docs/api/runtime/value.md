# runtime.value

## Navigation

- [API Index](../README.md)
- Parent: [runtime](../runtime.md)

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

- [valuesEqual](#fn-valuesequal)
- [hashValue](#fn-hashvalue)
- [truthy](#fn-truthy)
- [toInteger](#fn-tointeger)
- [toNumber](#fn-tonumber)
- [toNumberMaybe](#fn-tonumbermaybe)
- [luaStringLike](#fn-luastringlike)
- [indexErrorMessage](#fn-indexerrormessage)
- [callErrorMessage](#fn-callerrormessage)
- [nativeHookName](#fn-nativehookname)
- [shortNativeName](#fn-shortnativename)
- [debugValueTypeName](#fn-debugvaluetypename)
- [appendLuaString](#fn-appendluastring)
- [localActiveAt](#fn-localactiveat)
- [parseIntegerLiteral](#fn-parseintegerliteral)
- [parseIntegerStrict](#fn-parseintegerstrict)
- [parseLuaNumber](#fn-parseluanumber)
- [floatToInteger](#fn-floattointeger)
- [isHex](#fn-ishex)
- [trimAscii](#fn-trimascii)
- [arrayIndex](#fn-arrayindex)
- [runtimeArgValue](#fn-runtimeargvalue)
- [argValue](#fn-argvalue)
- [appendValue](#fn-appendvalue)
- [isFileValue](#fn-isfilevalue)
- [isClosedFileValue](#fn-isclosedfilevalue)
- [appendNamedValue](#fn-appendnamedvalue)
- [freeProtectedResult](#fn-freeprotectedresult)
- [appendNumber](#fn-appendnumber)
- [appendFmt](#fn-appendfmt)
- [hexValue](#fn-hexvalue)

## Aliases

- [Value](#alias-value)
- [Thread](#alias-thread)
- [ProtectedCallResult](#alias-protectedcallresult)

<a id="alias-value"></a>

## Value

```zig
pub const Value = types.Value;
```

<a id="alias-thread"></a>

## Thread

```zig
pub const Thread = types.Thread;
```

<a id="alias-protectedcallresult"></a>

## ProtectedCallResult

```zig
pub const ProtectedCallResult = types.ProtectedCallResult;
```

<a id="fn-valuesequal"></a>

## valuesEqual

```zig
pub fn valuesEqual(lhs: Value, rhs: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-hashvalue"></a>

## hashValue

```zig
pub fn hashValue(value: Value) u64
```

References: [`Value`](#alias-value)

<a id="fn-truthy"></a>

## truthy

```zig
pub fn truthy(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-tointeger"></a>

## toInteger

```zig
pub fn toInteger(value: Value) ?i64
```

References: [`Value`](#alias-value)

<a id="fn-tonumber"></a>

## toNumber

```zig
pub fn toNumber(value: Value) !f64
```

References: [`Value`](#alias-value)

<a id="fn-tonumbermaybe"></a>

## toNumberMaybe

```zig
pub fn toNumberMaybe(value: Value) ?f64
```

References: [`Value`](#alias-value)

<a id="fn-luastringlike"></a>

## luaStringLike

```zig
pub fn luaStringLike(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-indexerrormessage"></a>

## indexErrorMessage

```zig
pub fn indexErrorMessage(value: Value) []const u8
```

References: [`Value`](#alias-value)

<a id="fn-callerrormessage"></a>

## callErrorMessage

```zig
pub fn callErrorMessage(value: Value) []const u8
```

References: [`Value`](#alias-value)

<a id="fn-nativehookname"></a>

## nativeHookName

```zig
pub fn nativeHookName(value: Value) ?[]const u8
```

References: [`Value`](#alias-value)

<a id="fn-shortnativename"></a>

## shortNativeName

```zig
pub fn shortNativeName(name: []const u8) []const u8
```

<a id="fn-debugvaluetypename"></a>

## debugValueTypeName

```zig
pub fn debugValueTypeName(value: Value) []const u8
```

References: [`Value`](#alias-value)

<a id="fn-appendluastring"></a>

## appendLuaString

```zig
pub fn appendLuaString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void
```

References: [`Value`](#alias-value)

<a id="fn-localactiveat"></a>

## localActiveAt

```zig
pub fn localActiveAt(local: proto_mod.LocalDebug, pc: usize) bool
```

<a id="fn-parseintegerliteral"></a>

## parseIntegerLiteral

```zig
pub fn parseIntegerLiteral(lexeme: []const u8) !Value
```

References: [`Value`](#alias-value)

<a id="fn-parseintegerstrict"></a>

## parseIntegerStrict

```zig
pub fn parseIntegerStrict(text: []const u8) ?i64
```

<a id="fn-parseluanumber"></a>

## parseLuaNumber

```zig
pub fn parseLuaNumber(text: []const u8) !f64
```

<a id="fn-floattointeger"></a>

## floatToInteger

```zig
pub fn floatToInteger(number: f64) ?i64
```

<a id="fn-ishex"></a>

## isHex

```zig
pub fn isHex(text: []const u8) bool
```

<a id="fn-trimascii"></a>

## trimAscii

```zig
pub fn trimAscii(text: []const u8) []const u8
```

<a id="fn-arrayindex"></a>

## arrayIndex

```zig
pub fn arrayIndex(value: Value) ?usize
```

References: [`Value`](#alias-value)

<a id="fn-runtimeargvalue"></a>

## runtimeArgValue

```zig
pub fn runtimeArgValue(state: anytype, thread: *Thread, op: bytecode.Call, index: u16) Value
```

References: [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-argvalue"></a>

## argValue

```zig
pub fn argValue(state: anytype, thread: *Thread, op: bytecode.Call, index: u16) Value
```

References: [`Thread`](#alias-thread), [`Value`](#alias-value)

<a id="fn-appendvalue"></a>

## appendValue

```zig
pub fn appendValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: Value) !void
```

References: [`Value`](#alias-value)

<a id="fn-isfilevalue"></a>

## isFileValue

```zig
pub fn isFileValue(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-isclosedfilevalue"></a>

## isClosedFileValue

```zig
pub fn isClosedFileValue(value: Value) bool
```

References: [`Value`](#alias-value)

<a id="fn-appendnamedvalue"></a>

## appendNamedValue

```zig
pub fn appendNamedValue(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, value: Value) !void
```

References: [`Value`](#alias-value)

<a id="fn-freeprotectedresult"></a>

## freeProtectedResult

```zig
pub fn freeProtectedResult(allocator: std.mem.Allocator, result: ProtectedCallResult) void
```

References: [`ProtectedCallResult`](#alias-protectedcallresult)

<a id="fn-appendnumber"></a>

## appendNumber

```zig
pub fn appendNumber(allocator: std.mem.Allocator, out: *std.ArrayList(u8), number: f64) !void
```

<a id="fn-appendfmt"></a>

## appendFmt

```zig
pub fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void
```

<a id="fn-hexvalue"></a>

## hexValue

```zig
pub fn hexValue(byte: u8) u32
```

