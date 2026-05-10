# testing.process

## Navigation

- [API Index](../README.md)
- Parent: [testing](../testing.md)

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

- [runProcess](#fn-runprocess)
- [ownedResult](#fn-ownedresult)

## Types

- [ProcessResult](#type-processresult)
- [RunOptions](#type-runoptions)

<a id="type-processresult"></a>

## ProcessResult

```zig
pub const ProcessResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: ?u8,
    signal: ?u32,
    timed_out: bool,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-processresult-deinit) | `self: *ProcessResult, allocator: std.mem.Allocator` | `void` |  |
| [success](#fn-processresult-success) | `self: ProcessResult` | `bool` |  |

<a id="fn-processresult-deinit"></a>

### ProcessResult.deinit

```zig
pub fn deinit(self: *ProcessResult, allocator: std.mem.Allocator) void
```

References: [`ProcessResult`](#type-processresult)

<a id="fn-processresult-success"></a>

### ProcessResult.success

```zig
pub fn success(self: ProcessResult) bool
```

References: [`ProcessResult`](#type-processresult)

<a id="type-runoptions"></a>

## RunOptions

```zig
pub const RunOptions = struct {
    cwd: ?[]const u8 = null,
    timeout_ms: u64 = 5000,
    max_output_bytes: usize = 1024 * 1024,
    expand_arg0: bool = false,
    memory_limit_mb: u64 = 0,
};
```

<a id="fn-runprocess"></a>

## runProcess

```zig
pub fn runProcess(
    allocator: std.mem.Allocator,
    io: std.Io,
    argv: []const []const u8,
    options: RunOptions,
) !ProcessResult
```

References: [`RunOptions`](#type-runoptions), [`ProcessResult`](#type-processresult)

<a id="fn-ownedresult"></a>

## ownedResult

```zig
pub fn ownedResult(
    allocator: std.mem.Allocator,
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,
) !ProcessResult
```

References: [`ProcessResult`](#type-processresult)

