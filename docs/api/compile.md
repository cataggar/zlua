# compile

## Navigation

- [API Index](README.md)
- Submodules: [compile.resolver](compile/resolver.md), [compile.bytecode](compile/bytecode.md), [compile.proto](compile/proto.md), [compile.compiler](compile/compiler.md), [compile.disasm](compile/disasm.md)

<details>
<summary>All documents</summary>

- [root](root.md)
- [frontend](frontend.md)
- [errors](errors.md)
- [frontend.source](frontend/source.md)
- [frontend.token](frontend/token.md)
- [frontend.diagnostic](frontend/diagnostic.md)
- [frontend.lexer](frontend/lexer.md)
- [frontend.ast](frontend/ast.md)
- [frontend.parser](frontend/parser.md)
- [compile](compile.md)
- [compile.resolver](compile/resolver.md)
- [compile.bytecode](compile/bytecode.md)
- [compile.proto](compile/proto.md)
- [compile.compiler](compile/compiler.md)
- [compile.disasm](compile/disasm.md)
- [api](api.md)
- [runtime](runtime.md)
- [runtime.chunk](runtime/chunk.md)
- [runtime.types](runtime/types.md)
- [runtime.value](runtime/value.md)
- [runtime.execute](runtime/execute.md)
- [testing.process](testing/process.md)
- [runtime.state](runtime/state.md)
- [runtime.call](runtime/call.md)
- [runtime.coroutine](runtime/coroutine.md)
- [runtime.debug](runtime/debug.md)
- [runtime.gc](runtime/gc.md)
- [runtime.host](runtime/host.md)
- [stdlib](stdlib.md)
- [stdlib.base](stdlib/base.md)
- [stdlib.table](stdlib/table.md)
- [stdlib.string](stdlib/string.md)
- [stdlib.math](stdlib/math.md)
- [stdlib.utf8](stdlib/utf8.md)
- [stdlib.coroutine](stdlib/coroutine.md)
- [stdlib.debug](stdlib/debug.md)
- [stdlib.package](stdlib/package.md)
- [stdlib.io](stdlib/io.md)
- [stdlib.os](stdlib/os.md)
- [stdlib.json](stdlib/json.md)
- [stdlib.zerde_lua](stdlib/zerde_lua.md)
- [stdlib.toml](stdlib/toml.md)
- [stdlib.msgpack](stdlib/msgpack.md)
- [stdlib.csv](stdlib/csv.md)
- [runtime.vm](runtime/vm.md)
- [runtime.tests](runtime/tests.md)
- [runtime.internal](runtime/internal.md)
- [testing](testing.md)
- [testing.clua](testing/clua.md)
- [testing.bench_runner](testing/bench_runner.md)
- [testing.c_api_runner](testing/c_api_runner.md)
- [testing.diff_runner](testing/diff_runner.md)
- [testing.expected_failures](testing/expected_failures.md)
- [testing.metadata](testing/metadata.md)
- [testing.normalizer](testing/normalizer.md)
- [testing.extension_runner](testing/extension_runner.md)
- [testing.official_suite](testing/official_suite.md)

</details>

## Functions

- [compile](#fn-compile)
- [compileWithDiagnostic](#fn-compilewithdiagnostic)

## Aliases

- [Proto](#alias-proto)

## Imports

- [resolver](#import-resolver) `@import("compile/resolver.zig")`
- [bytecode](#import-bytecode) `@import("compile/bytecode.zig")`
- [proto](#import-proto) `@import("compile/proto.zig")`
- [compiler](#import-compiler) `@import("compile/compiler.zig")`
- [disasm](#import-disasm) `@import("compile/disasm.zig")`

<a id="import-resolver"></a>

## resolver

```zig
pub const resolver = @import("compile/resolver.zig");
```

<a id="import-bytecode"></a>

## bytecode

```zig
pub const bytecode = @import("compile/bytecode.zig");
```

<a id="import-proto"></a>

## proto

```zig
pub const proto = @import("compile/proto.zig");
```

<a id="import-compiler"></a>

## compiler

```zig
pub const compiler = @import("compile/compiler.zig");
```

<a id="import-disasm"></a>

## disasm

```zig
pub const disasm = @import("compile/disasm.zig");
```

<a id="alias-proto"></a>

## Proto

```zig
pub const Proto = proto.Proto;
```

References: [`proto.Proto`](compile/proto.md#type-proto)

<a id="fn-compile"></a>

## compile

```zig
pub fn compile(allocator: std.mem.Allocator, tree: *const frontend.ast.Ast) !Proto
```

References: [`frontend.ast.Ast`](frontend/ast.md#type-ast), [`Proto`](#alias-proto)

<a id="fn-compilewithdiagnostic"></a>

## compileWithDiagnostic

```zig
pub fn compileWithDiagnostic(allocator: std.mem.Allocator, tree: *const frontend.ast.Ast, error_diagnostic: *?errors.Diagnostic) !Proto
```

References: [`frontend.ast.Ast`](frontend/ast.md#type-ast), [`errors.Diagnostic`](errors.md#type-diagnostic), [`Proto`](#alias-proto)

