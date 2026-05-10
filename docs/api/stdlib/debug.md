# stdlib.debug

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

- [getinfo](#fn-getinfo)
- [getupvalue](#fn-getupvalue)
- [setupvalue](#fn-setupvalue)
- [upvalueid](#fn-upvalueid)
- [upvaluejoin](#fn-upvaluejoin)
- [getlocal](#fn-getlocal)
- [setlocal](#fn-setlocal)
- [getregistry](#fn-getregistry)
- [sethook](#fn-sethook)
- [gethook](#fn-gethook)
- [setmetatable](#fn-setmetatable)
- [setuservalue](#fn-setuservalue)
- [getuservalue](#fn-getuservalue)

<a id="fn-getinfo"></a>

## getinfo

```zig
pub fn getinfo(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getupvalue"></a>

## getupvalue

```zig
pub fn getupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setupvalue"></a>

## setupvalue

```zig
pub fn setupvalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-upvalueid"></a>

## upvalueid

```zig
pub fn upvalueid(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-upvaluejoin"></a>

## upvaluejoin

```zig
pub fn upvaluejoin(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getlocal"></a>

## getlocal

```zig
pub fn getlocal(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setlocal"></a>

## setlocal

```zig
pub fn setlocal(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getregistry"></a>

## getregistry

```zig
pub fn getregistry(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sethook"></a>

## sethook

```zig
pub fn sethook(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-gethook"></a>

## gethook

```zig
pub fn gethook(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setmetatable"></a>

## setmetatable

```zig
pub fn setmetatable(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-setuservalue"></a>

## setuservalue

```zig
pub fn setuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-getuservalue"></a>

## getuservalue

```zig
pub fn getuservalue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

