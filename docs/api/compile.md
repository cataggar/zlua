# compile

## Navigation

- [API Index](README.md)
- Previous: [frontend.parser](frontend/parser.md)
- Next: [compile.resolver](compile/resolver.md)
- Submodules: [compile.resolver](compile/resolver.md), [compile.bytecode](compile/bytecode.md), [compile.proto](compile/proto.md), [compile.compiler](compile/compiler.md), [compile.disasm](compile/disasm.md)

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

