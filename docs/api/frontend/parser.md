# frontend.parser

## Navigation

- [API Index](../README.md)
- Previous: [frontend.ast](../frontend/ast.md)
- Next: [compile](../compile.md)
- Parent: [frontend](../frontend.md)

## Functions

- [parse](#fn-parse)
- [parseWithDiagnostic](#fn-parsewithdiagnostic)

<a id="fn-parse"></a>

## parse

```zig
pub fn parse(allocator: std.mem.Allocator, source: []const u8) !ast.Ast
```

<a id="fn-parsewithdiagnostic"></a>

## parseWithDiagnostic

```zig
pub fn parseWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) !ast.Ast
```

References: [`errors.Diagnostic`](../errors.md#type-diagnostic)

