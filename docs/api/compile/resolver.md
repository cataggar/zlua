# compile.resolver

## Navigation

- [API Index](../README.md)
- Previous: [compile](../compile.md)
- Next: [compile.bytecode](../compile/bytecode.md)
- Parent: [compile](../compile.md)

## Functions

- [resolve](#fn-resolve)
- [resolveWithDiagnostic](#fn-resolvewithdiagnostic)

## Constants

- [Error](#const-error)

<a id="const-error"></a>

## Error

```zig
pub const Error = error{ResolveError};
```

References: [`ResolveError`](../errors.md#type-resolveerror)

<a id="fn-resolve"></a>

## resolve

```zig
pub fn resolve(allocator: std.mem.Allocator, tree: *const ast.Ast) !void
```

<a id="fn-resolvewithdiagnostic"></a>

## resolveWithDiagnostic

```zig
pub fn resolveWithDiagnostic(allocator: std.mem.Allocator, tree: *const ast.Ast, error_diagnostic: *?errors.Diagnostic) !void
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic)

