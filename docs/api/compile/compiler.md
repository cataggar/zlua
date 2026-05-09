# compile.compiler

## Navigation

- [API Index](../README.md)
- Previous: [compile.proto](../compile/proto.md)
- Next: [compile.disasm](../compile/disasm.md)
- Parent: [compile](../compile.md)

## Functions

- [compile](#fn-compile)
- [compileWithDiagnostic](#fn-compilewithdiagnostic)

## Constants

- [CompileError](#const-compileerror)

<a id="const-compileerror"></a>

## CompileError

```zig
pub const CompileError =...;
```

<a id="fn-compile"></a>

## compile

```zig
pub fn compile(allocator: std.mem.Allocator, tree: *const ast.Ast) !proto_mod.Proto
```

<a id="fn-compilewithdiagnostic"></a>

## compileWithDiagnostic

```zig
pub fn compileWithDiagnostic(allocator: std.mem.Allocator, tree: *const ast.Ast, error_diagnostic: *?errors.Diagnostic) !proto_mod.Proto
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic)

