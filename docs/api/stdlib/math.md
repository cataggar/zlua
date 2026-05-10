# stdlib.math

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

- [abs](#fn-abs)
- [acos](#fn-acos)
- [asin](#fn-asin)
- [atan](#fn-atan)
- [ceil](#fn-ceil)
- [cos](#fn-cos)
- [deg](#fn-deg)
- [exp](#fn-exp)
- [floor](#fn-floor)
- [fmod](#fn-fmod)
- [frexp](#fn-frexp)
- [ldexp](#fn-ldexp)
- [log](#fn-log)
- [max](#fn-max)
- [min](#fn-min)
- [modf](#fn-modf)
- [rad](#fn-rad)
- [random](#fn-random)
- [randomseed](#fn-randomseed)
- [sin](#fn-sin)
- [sqrt](#fn-sqrt)
- [tan](#fn-tan)
- [tointeger](#fn-tointeger)
- [typeValue](#fn-typevalue)
- [ult](#fn-ult)

<a id="fn-abs"></a>

## abs

```zig
pub fn abs(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-acos"></a>

## acos

```zig
pub fn acos(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-asin"></a>

## asin

```zig
pub fn asin(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-atan"></a>

## atan

```zig
pub fn atan(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-ceil"></a>

## ceil

```zig
pub fn ceil(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-cos"></a>

## cos

```zig
pub fn cos(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-deg"></a>

## deg

```zig
pub fn deg(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-exp"></a>

## exp

```zig
pub fn exp(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-floor"></a>

## floor

```zig
pub fn floor(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-fmod"></a>

## fmod

```zig
pub fn fmod(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-frexp"></a>

## frexp

```zig
pub fn frexp(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-ldexp"></a>

## ldexp

```zig
pub fn ldexp(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-log"></a>

## log

```zig
pub fn log(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-max"></a>

## max

```zig
pub fn max(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-min"></a>

## min

```zig
pub fn min(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-modf"></a>

## modf

```zig
pub fn modf(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-rad"></a>

## rad

```zig
pub fn rad(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-random"></a>

## random

```zig
pub fn random(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-randomseed"></a>

## randomseed

```zig
pub fn randomseed(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sin"></a>

## sin

```zig
pub fn sin(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sqrt"></a>

## sqrt

```zig
pub fn sqrt(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-tan"></a>

## tan

```zig
pub fn tan(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-tointeger"></a>

## tointeger

```zig
pub fn tointeger(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-typevalue"></a>

## typeValue

```zig
pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-ult"></a>

## ult

```zig
pub fn ult(state: *State, thread: *Thread, op: bytecode.Call) !void
```

