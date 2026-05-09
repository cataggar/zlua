# stdlib.io

## Navigation

- [API Index](../README.md)
- Previous: [stdlib.package](../stdlib/package.md)
- Next: [stdlib.os](../stdlib/os.md)
- Parent: [stdlib](../stdlib.md)

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

