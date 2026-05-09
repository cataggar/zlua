# frontend.ast

## Navigation

- [API Index](../README.md)
- Previous: [frontend.lexer](../frontend/lexer.md)
- Next: [frontend.parser](../frontend/parser.md)
- Parent: [frontend](../frontend.md)

## Types

- [Ast](#type-ast)
- [Identifier](#type-identifier)
- [Binding](#type-binding)
- [Stmt](#type-stmt)
- [Assignment](#type-assignment)
- [LocalDecl](#type-localdecl)
- [GlobalDecl](#type-globaldecl)
- [FunctionName](#type-functionname)
- [FunctionDecl](#type-functiondecl)
- [LocalFunctionDecl](#type-localfunctiondecl)
- [IfStmt](#type-ifstmt)
- [IfBranch](#type-ifbranch)
- [WhileStmt](#type-whilestmt)
- [RepeatStmt](#type-repeatstmt)
- [NumericFor](#type-numericfor)
- [GenericFor](#type-genericfor)
- [ReturnStmt](#type-returnstmt)
- [FunctionBody](#type-functionbody)
- [Expr](#type-expr)
- [BoolLiteral](#type-boolliteral)
- [TokenLiteral](#type-tokenliteral)
- [TableConstructor](#type-tableconstructor)
- [TableField](#type-tablefield)
- [KeyedField](#type-keyedfield)
- [NamedField](#type-namedfield)
- [IndexExpr](#type-indexexpr)
- [FieldExpr](#type-fieldexpr)
- [CallExpr](#type-callexpr)
- [MethodCallExpr](#type-methodcallexpr)
- [UnaryOp](#type-unaryop)
- [UnaryExpr](#type-unaryexpr)
- [BinaryOp](#type-binaryop)
- [BinaryExpr](#type-binaryexpr)

## Constants

- [Block](#const-block)

<a id="type-ast"></a>

## Ast

```zig
pub const Ast = struct { ... };
```

### Fields

- `arena`
- `source`
- `statements`

### Nested Declarations

- [deinit](#fn-ast-deinit)

<a id="fn-ast-deinit"></a>

### Ast.deinit

```zig
pub fn deinit(self: *Ast) void
```

References: [`Ast`](#type-ast)

<a id="type-identifier"></a>

## Identifier

```zig
pub const Identifier = struct { ... };
```

### Fields

- `name`
- `span`

<a id="type-binding"></a>

## Binding

```zig
pub const Binding = struct { ... };
```

### Fields

- `name`
- `attribute`

<a id="const-block"></a>

## Block

```zig
pub const Block = []const Stmt;
```

References: [`Stmt`](#type-stmt)

<a id="type-stmt"></a>

## Stmt

```zig
pub const Stmt = union(enum) { ... };
```

### Fields

- `empty`
- `assignment`
- `local_decl`
- `global_decl`
- `function_decl`
- `local_function_decl`
- `if_stmt`
- `while_stmt`
- `repeat_stmt`
- `numeric_for`
- `generic_for`
- `break_stmt`
- `goto_stmt`
- `label_stmt`
- `do_block`
- `return_stmt`
- `call_stmt`

<a id="type-assignment"></a>

## Assignment

```zig
pub const Assignment = struct { ... };
```

### Fields

- `targets`
- `values`

<a id="type-localdecl"></a>

## LocalDecl

```zig
pub const LocalDecl = struct { ... };
```

### Fields

- `bindings`
- `values`

<a id="type-globaldecl"></a>

## GlobalDecl

```zig
pub const GlobalDecl = struct { ... };
```

### Fields

- `attribute`
- `all`
- `names`
- `values`

<a id="type-functionname"></a>

## FunctionName

```zig
pub const FunctionName = struct { ... };
```

### Fields

- `root`
- `fields`
- `method`

<a id="type-functiondecl"></a>

## FunctionDecl

```zig
pub const FunctionDecl = struct { ... };
```

### Fields

- `name`
- `body`

<a id="type-localfunctiondecl"></a>

## LocalFunctionDecl

```zig
pub const LocalFunctionDecl = struct { ... };
```

### Fields

- `name`
- `body`

<a id="type-ifstmt"></a>

## IfStmt

```zig
pub const IfStmt = struct { ... };
```

### Fields

- `branches`
- `else_block`

<a id="type-ifbranch"></a>

## IfBranch

```zig
pub const IfBranch = struct { ... };
```

### Fields

- `condition`
- `body`

<a id="type-whilestmt"></a>

## WhileStmt

```zig
pub const WhileStmt = struct { ... };
```

### Fields

- `condition`
- `body`
- `end_line`

<a id="type-repeatstmt"></a>

## RepeatStmt

```zig
pub const RepeatStmt = struct { ... };
```

### Fields

- `body`
- `condition`

<a id="type-numericfor"></a>

## NumericFor

```zig
pub const NumericFor = struct { ... };
```

### Fields

- `name`
- `start`
- `limit`
- `step`
- `body`
- `end_line`

<a id="type-genericfor"></a>

## GenericFor

```zig
pub const GenericFor = struct { ... };
```

### Fields

- `names`
- `iterators`
- `body`
- `end_line`

<a id="type-returnstmt"></a>

## ReturnStmt

```zig
pub const ReturnStmt = struct { ... };
```

### Fields

- `line`
- `values`

<a id="type-functionbody"></a>

## FunctionBody

```zig
pub const FunctionBody = struct { ... };
```

### Fields

- `params`
- `is_vararg`
- `vararg_name`
- `body`
- `defined_line`
- `end_line`

<a id="type-expr"></a>

## Expr

```zig
pub const Expr = union(enum) { ... };
```

### Fields

- `nil`
- `boolean`
- `integer`
- `float`
- `string`
- `vararg`
- `identifier`
- `table_constructor`
- `function_literal`
- `grouped`
- `index`
- `field`
- `call`
- `method_call`
- `unary`
- `binary`

<a id="type-boolliteral"></a>

## BoolLiteral

```zig
pub const BoolLiteral = struct { ... };
```

### Fields

- `value`
- `span`

<a id="type-tokenliteral"></a>

## TokenLiteral

```zig
pub const TokenLiteral = struct { ... };
```

### Fields

- `lexeme`
- `span`

<a id="type-tableconstructor"></a>

## TableConstructor

```zig
pub const TableConstructor = struct { ... };
```

### Fields

- `fields`

<a id="type-tablefield"></a>

## TableField

```zig
pub const TableField = union(enum) { ... };
```

### Fields

- `array`
- `keyed`
- `named`

<a id="type-keyedfield"></a>

## KeyedField

```zig
pub const KeyedField = struct { ... };
```

### Fields

- `key`
- `value`

<a id="type-namedfield"></a>

## NamedField

```zig
pub const NamedField = struct { ... };
```

### Fields

- `name`
- `value`

<a id="type-indexexpr"></a>

## IndexExpr

```zig
pub const IndexExpr = struct { ... };
```

### Fields

- `receiver`
- `key`

<a id="type-fieldexpr"></a>

## FieldExpr

```zig
pub const FieldExpr = struct { ... };
```

### Fields

- `receiver`
- `name`

<a id="type-callexpr"></a>

## CallExpr

```zig
pub const CallExpr = struct { ... };
```

### Fields

- `callee`
- `call_line`
- `args`

<a id="type-methodcallexpr"></a>

## MethodCallExpr

```zig
pub const MethodCallExpr = struct { ... };
```

### Fields

- `receiver`
- `method`
- `call_line`
- `args`

<a id="type-unaryop"></a>

## UnaryOp

```zig
pub const UnaryOp = enum { ... };
```

<a id="type-unaryexpr"></a>

## UnaryExpr

```zig
pub const UnaryExpr = struct { ... };
```

### Fields

- `op`
- `op_line`
- `operand`

<a id="type-binaryop"></a>

## BinaryOp

```zig
pub const BinaryOp = enum { ... };
```

<a id="type-binaryexpr"></a>

## BinaryExpr

```zig
pub const BinaryExpr = struct { ... };
```

### Fields

- `op`
- `op_line`
- `left`
- `right`

