# runtime.value

## Navigation

- [API Index](../README.md)
- Previous: [runtime.types](../runtime/types.md)
- Next: [runtime.execute](../runtime/execute.md)
- Parent: [runtime](../runtime.md)

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

