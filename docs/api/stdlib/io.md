# stdlib.io

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

- [read](#fn-read)
- [write](#fn-write)
- [open](#fn-open)
- [input](#fn-input)
- [output](#fn-output)
- [close](#fn-close)
- [flush](#fn-flush)
- [lines](#fn-lines)
- [tmpfile](#fn-tmpfile)
- [typeValue](#fn-typevalue)
- [fileRead](#fn-fileread)
- [fileWrite](#fn-filewrite)
- [fileClose](#fn-fileclose)
- [fileSeek](#fn-fileseek)
- [fileFlush](#fn-fileflush)
- [fileLines](#fn-filelines)
- [fileSetvbuf](#fn-filesetvbuf)
- [linesIter](#fn-linesiter)
- [linesNext](#fn-linesnext)

<a id="fn-read"></a>

## read

```zig
pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-write"></a>

## write

```zig
pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-open"></a>

## open

```zig
pub fn open(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-input"></a>

## input

```zig
pub fn input(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-output"></a>

## output

```zig
pub fn output(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-close"></a>

## close

```zig
pub fn close(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-flush"></a>

## flush

```zig
pub fn flush(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-lines"></a>

## lines

```zig
pub fn lines(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-tmpfile"></a>

## tmpfile

```zig
pub fn tmpfile(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-typevalue"></a>

## typeValue

```zig
pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-fileread"></a>

## fileRead

```zig
pub fn fileRead(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-filewrite"></a>

## fileWrite

```zig
pub fn fileWrite(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-fileclose"></a>

## fileClose

```zig
pub fn fileClose(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-fileseek"></a>

## fileSeek

```zig
pub fn fileSeek(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-fileflush"></a>

## fileFlush

```zig
pub fn fileFlush(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-filelines"></a>

## fileLines

```zig
pub fn fileLines(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-filesetvbuf"></a>

## fileSetvbuf

```zig
pub fn fileSetvbuf(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-linesiter"></a>

## linesIter

```zig
pub fn linesIter(state: *State, thread: *Thread, op: bytecode.Call) !void
```

<a id="fn-linesnext"></a>

## linesNext

```zig
pub fn linesNext(state: *State, iterator: Value) ![]const Value
```

