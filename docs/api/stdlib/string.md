# stdlib.string

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

- [byte](#fn-byte)
- [char](#fn-char)
- [dump](#fn-dump)
- [find](#fn-find)
- [format](#fn-format)
- [gmatch](#fn-gmatch)
- [gmatchIter](#fn-gmatchiter)
- [gmatchNext](#fn-gmatchnext)
- [gsub](#fn-gsub)
- [len](#fn-len)
- [lower](#fn-lower)
- [match](#fn-match)
- [pack](#fn-pack)
- [packsize](#fn-packsize)
- [rep](#fn-rep)
- [reverse](#fn-reverse)
- [sub](#fn-sub)
- [unpack](#fn-unpack)
- [upper](#fn-upper)

<a id="fn-byte"></a>

## byte

```zig
pub fn byte(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-char"></a>

## char

```zig
pub fn char(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-dump"></a>

## dump

```zig
pub fn dump(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-find"></a>

## find

```zig
pub fn find(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-format"></a>

## format

```zig
pub fn format(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-gmatch"></a>

## gmatch

```zig
pub fn gmatch(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-gmatchiter"></a>

## gmatchIter

```zig
pub fn gmatchIter(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-gmatchnext"></a>

## gmatchNext

```zig
pub fn gmatchNext(state: *State, state_value: Value) ![2]Value
```

<a id="fn-gsub"></a>

## gsub

```zig
pub fn gsub(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-len"></a>

## len

```zig
pub fn len(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-lower"></a>

## lower

```zig
pub fn lower(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-match"></a>

## match

```zig
pub fn match(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-pack"></a>

## pack

```zig
pub fn pack(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-packsize"></a>

## packsize

```zig
pub fn packsize(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-rep"></a>

## rep

```zig
pub fn rep(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-reverse"></a>

## reverse

```zig
pub fn reverse(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-sub"></a>

## sub

```zig
pub fn sub(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-unpack"></a>

## unpack

```zig
pub fn unpack(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-upper"></a>

## upper

```zig
pub fn upper(state: *State, thread: *Thread, op: bytecode.Call) !void
```

