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

- `arena: std.heap.ArenaAllocator`
- `source: []const u8`
- `statements: []const Stmt`

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

- `name: []const u8`
- `span: source.Span`

<a id="type-binding"></a>

## Binding

```zig
pub const Binding = struct { ... };
```

### Fields

- `name: Identifier`
- `attribute: ?Identifier = null`

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

- `empty: source.Span`
- `assignment: Assignment`
- `local_decl: LocalDecl`
- `global_decl: GlobalDecl`
- `function_decl: FunctionDecl`
- `local_function_decl: LocalFunctionDecl`
- `if_stmt: IfStmt`
- `while_stmt: WhileStmt`
- `repeat_stmt: RepeatStmt`
- `numeric_for: NumericFor`
- `generic_for: GenericFor`
- `break_stmt: source.Span`
- `goto_stmt: Identifier`
- `label_stmt: Identifier`
- `do_block: Block`
- `return_stmt: ReturnStmt`
- `call_stmt: *Expr`

<a id="type-assignment"></a>

## Assignment

```zig
pub const Assignment = struct { ... };
```

### Fields

- `targets: []const *Expr`
- `values: []const *Expr`

<a id="type-localdecl"></a>

## LocalDecl

```zig
pub const LocalDecl = struct { ... };
```

### Fields

- `bindings: []const Binding`
- `values: []const *Expr`

<a id="type-globaldecl"></a>

## GlobalDecl

```zig
pub const GlobalDecl = struct { ... };
```

### Fields

- `attribute: ?Identifier`
- `all: bool`
- `names: []const Binding`
- `values: []const *Expr`

<a id="type-functionname"></a>

## FunctionName

```zig
pub const FunctionName = struct { ... };
```

### Fields

- `root: Identifier`
- `fields: []const Identifier`
- `method: ?Identifier`

<a id="type-functiondecl"></a>

## FunctionDecl

```zig
pub const FunctionDecl = struct { ... };
```

### Fields

- `name: FunctionName`
- `body: FunctionBody`

<a id="type-localfunctiondecl"></a>

## LocalFunctionDecl

```zig
pub const LocalFunctionDecl = struct { ... };
```

### Fields

- `name: Identifier`
- `body: FunctionBody`

<a id="type-ifstmt"></a>

## IfStmt

```zig
pub const IfStmt = struct { ... };
```

### Fields

- `branches: []const IfBranch`
- `else_block: ?Block`

<a id="type-ifbranch"></a>

## IfBranch

```zig
pub const IfBranch = struct { ... };
```

### Fields

- `condition: *Expr`
- `body: Block`

<a id="type-whilestmt"></a>

## WhileStmt

```zig
pub const WhileStmt = struct { ... };
```

### Fields

- `condition: *Expr`
- `body: Block`
- `end_line: usize`

<a id="type-repeatstmt"></a>

## RepeatStmt

```zig
pub const RepeatStmt = struct { ... };
```

### Fields

- `body: Block`
- `condition: *Expr`

<a id="type-numericfor"></a>

## NumericFor

```zig
pub const NumericFor = struct { ... };
```

### Fields

- `name: Identifier`
- `start: *Expr`
- `limit: *Expr`
- `step: ?*Expr`
- `body: Block`
- `end_line: usize`

<a id="type-genericfor"></a>

## GenericFor

```zig
pub const GenericFor = struct { ... };
```

### Fields

- `names: []const Identifier`
- `iterators: []const *Expr`
- `body: Block`
- `end_line: usize`

<a id="type-returnstmt"></a>

## ReturnStmt

```zig
pub const ReturnStmt = struct { ... };
```

### Fields

- `line: usize`
- `values: []const *Expr`

<a id="type-functionbody"></a>

## FunctionBody

```zig
pub const FunctionBody = struct { ... };
```

### Fields

- `params: []const Identifier`
- `is_vararg: bool`
- `vararg_name: ?Identifier`
- `body: Block`
- `defined_line: usize`
- `end_line: usize`

<a id="type-expr"></a>

## Expr

```zig
pub const Expr = union(enum) { ... };
```

### Fields

- `nil: source.Span`
- `boolean: BoolLiteral`
- `integer: TokenLiteral`
- `float: TokenLiteral`
- `string: TokenLiteral`
- `vararg: source.Span`
- `identifier: Identifier`
- `table_constructor: TableConstructor`
- `function_literal: FunctionBody`
- `grouped: *Expr`
- `index: IndexExpr`
- `field: FieldExpr`
- `call: CallExpr`
- `method_call: MethodCallExpr`
- `unary: UnaryExpr`
- `binary: BinaryExpr`

<a id="type-boolliteral"></a>

## BoolLiteral

```zig
pub const BoolLiteral = struct { ... };
```

### Fields

- `value: bool`
- `span: source.Span`

<a id="type-tokenliteral"></a>

## TokenLiteral

```zig
pub const TokenLiteral = struct { ... };
```

### Fields

- `lexeme: []const u8`
- `span: source.Span`

<a id="type-tableconstructor"></a>

## TableConstructor

```zig
pub const TableConstructor = struct { ... };
```

### Fields

- `fields: []const TableField`

<a id="type-tablefield"></a>

## TableField

```zig
pub const TableField = union(enum) { ... };
```

### Fields

- `array: *Expr`
- `keyed: KeyedField`
- `named: NamedField`

<a id="type-keyedfield"></a>

## KeyedField

```zig
pub const KeyedField = struct { ... };
```

### Fields

- `key: *Expr`
- `value: *Expr`

<a id="type-namedfield"></a>

## NamedField

```zig
pub const NamedField = struct { ... };
```

### Fields

- `name: Identifier`
- `value: *Expr`

<a id="type-indexexpr"></a>

## IndexExpr

```zig
pub const IndexExpr = struct { ... };
```

### Fields

- `receiver: *Expr`
- `key: *Expr`

<a id="type-fieldexpr"></a>

## FieldExpr

```zig
pub const FieldExpr = struct { ... };
```

### Fields

- `receiver: *Expr`
- `name: Identifier`

<a id="type-callexpr"></a>

## CallExpr

```zig
pub const CallExpr = struct { ... };
```

### Fields

- `callee: *Expr`
- `call_line: usize`
- `args: []const *Expr`

<a id="type-methodcallexpr"></a>

## MethodCallExpr

```zig
pub const MethodCallExpr = struct { ... };
```

### Fields

- `receiver: *Expr`
- `method: Identifier`
- `call_line: usize`
- `args: []const *Expr`

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

- `op: UnaryOp`
- `op_line: usize`
- `operand: *Expr`

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

- `op: BinaryOp`
- `op_line: usize`
- `left: *Expr`
- `right: *Expr`

