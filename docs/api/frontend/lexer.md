# frontend.lexer

## Navigation

- [API Index](../README.md)
- Parent: [frontend](../frontend.md)

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

- [lex](#fn-lex)
- [lexWithDiagnostic](#fn-lexwithdiagnostic)

## Types

- [Lexer](#type-lexer)

<a id="type-lexer"></a>

## Lexer

```zig
pub const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    error_diagnostic: ?*?errors.Diagnostic = null,
    index: usize = 0,
    line: usize = 1,
    column: usize = 1,
    diagnostics: std.ArrayList(diagnostic.Diagnostic) = .empty,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [init](#fn-lexer-init) | `allocator: std.mem.Allocator, source: []const u8` | `Lexer` |  |
| [initWithDiagnostic](#fn-lexer-initwithdiagnostic) | `allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic` | `Lexer` |  |
| [deinit](#fn-lexer-deinit) | `self: *Lexer` | `void` |  |
| [next](#fn-lexer-next) | `self: *Lexer` | `!token_mod.Token` |  |

<a id="fn-lexer-init"></a>

### Lexer.init

```zig
pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer
```

References: [`Lexer`](#type-lexer)

<a id="fn-lexer-initwithdiagnostic"></a>

### Lexer.initWithDiagnostic

```zig
pub fn initWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) Lexer
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic), [`Lexer`](#type-lexer)

<a id="fn-lexer-deinit"></a>

### Lexer.deinit

```zig
pub fn deinit(self: *Lexer) void
```

References: [`Lexer`](#type-lexer)

<a id="fn-lexer-next"></a>

### Lexer.next

```zig
pub fn next(self: *Lexer) !token_mod.Token
```

References: [`Lexer`](#type-lexer)

<a id="fn-lex"></a>

## lex

```zig
pub fn lex(allocator: std.mem.Allocator, source: []const u8) ![]token_mod.Token
```

<a id="fn-lexwithdiagnostic"></a>

## lexWithDiagnostic

```zig
pub fn lexWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) ![]token_mod.Token
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic)

