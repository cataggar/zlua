# frontend.ast

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
pub const Ast = struct {
    arena: std.heap.ArenaAllocator,
    source: []const u8,
    statements: []const Stmt,
};
```

### Nested Declarations

| Name | Parameters | Return Type | Description |
| --- | --- | --- | --- |
| [deinit](#fn-ast-deinit) | `self: *Ast` | `void` |  |

<a id="fn-ast-deinit"></a>

### Ast.deinit

```zig
pub fn deinit(self: *Ast) void
```

References: [`Ast`](#type-ast)

<a id="type-identifier"></a>

## Identifier

```zig
pub const Identifier = struct {
    name: []const u8,
    span: source.Span,
};
```

<a id="type-binding"></a>

## Binding

```zig
pub const Binding = struct {
    name: Identifier,
    attribute: ?Identifier = null,
};
```

<a id="const-block"></a>

## Block

```zig
pub const Block = []const Stmt;
```

References: [`Stmt`](#type-stmt)

<a id="type-stmt"></a>

## Stmt

```zig
pub const Stmt = union(enum) {
    empty: source.Span,
    assignment: Assignment,
    local_decl: LocalDecl,
    global_decl: GlobalDecl,
    function_decl: FunctionDecl,
    local_function_decl: LocalFunctionDecl,
    if_stmt: IfStmt,
    while_stmt: WhileStmt,
    repeat_stmt: RepeatStmt,
    numeric_for: NumericFor,
    generic_for: GenericFor,
    break_stmt: source.Span,
    goto_stmt: Identifier,
    label_stmt: Identifier,
    do_block: Block,
    return_stmt: ReturnStmt,
    call_stmt: *Expr,
};
```

<a id="type-assignment"></a>

## Assignment

```zig
pub const Assignment = struct {
    targets: []const *Expr,
    values: []const *Expr,
};
```

<a id="type-localdecl"></a>

## LocalDecl

```zig
pub const LocalDecl = struct {
    bindings: []const Binding,
    values: []const *Expr,
};
```

<a id="type-globaldecl"></a>

## GlobalDecl

```zig
pub const GlobalDecl = struct {
    attribute: ?Identifier,
    all: bool,
    names: []const Binding,
    values: []const *Expr,
};
```

<a id="type-functionname"></a>

## FunctionName

```zig
pub const FunctionName = struct {
    root: Identifier,
    fields: []const Identifier,
    method: ?Identifier,
};
```

<a id="type-functiondecl"></a>

## FunctionDecl

```zig
pub const FunctionDecl = struct {
    name: FunctionName,
    body: FunctionBody,
};
```

<a id="type-localfunctiondecl"></a>

## LocalFunctionDecl

```zig
pub const LocalFunctionDecl = struct {
    name: Identifier,
    body: FunctionBody,
};
```

<a id="type-ifstmt"></a>

## IfStmt

```zig
pub const IfStmt = struct {
    branches: []const IfBranch,
    else_block: ?Block,
};
```

<a id="type-ifbranch"></a>

## IfBranch

```zig
pub const IfBranch = struct {
    condition: *Expr,
    body: Block,
};
```

<a id="type-whilestmt"></a>

## WhileStmt

```zig
pub const WhileStmt = struct {
    condition: *Expr,
    body: Block,
    end_line: usize,
};
```

<a id="type-repeatstmt"></a>

## RepeatStmt

```zig
pub const RepeatStmt = struct {
    body: Block,
    condition: *Expr,
};
```

<a id="type-numericfor"></a>

## NumericFor

```zig
pub const NumericFor = struct {
    name: Identifier,
    start: *Expr,
    limit: *Expr,
    step: ?*Expr,
    body: Block,
    end_line: usize,
};
```

<a id="type-genericfor"></a>

## GenericFor

```zig
pub const GenericFor = struct {
    names: []const Identifier,
    iterators: []const *Expr,
    body: Block,
    end_line: usize,
};
```

<a id="type-returnstmt"></a>

## ReturnStmt

```zig
pub const ReturnStmt = struct {
    line: usize,
    values: []const *Expr,
};
```

<a id="type-functionbody"></a>

## FunctionBody

```zig
pub const FunctionBody = struct {
    params: []const Identifier,
    is_vararg: bool,
    vararg_name: ?Identifier,
    body: Block,
    defined_line: usize,
    end_line: usize,
};
```

<a id="type-expr"></a>

## Expr

```zig
pub const Expr = union(enum) {
    nil: source.Span,
    boolean: BoolLiteral,
    integer: TokenLiteral,
    float: TokenLiteral,
    string: TokenLiteral,
    vararg: source.Span,
    identifier: Identifier,
    table_constructor: TableConstructor,
    function_literal: FunctionBody,
    grouped: *Expr,
    index: IndexExpr,
    field: FieldExpr,
    call: CallExpr,
    method_call: MethodCallExpr,
    unary: UnaryExpr,
    binary: BinaryExpr,
};
```

<a id="type-boolliteral"></a>

## BoolLiteral

```zig
pub const BoolLiteral = struct {
    value: bool,
    span: source.Span,
};
```

<a id="type-tokenliteral"></a>

## TokenLiteral

```zig
pub const TokenLiteral = struct {
    lexeme: []const u8,
    span: source.Span,
};
```

<a id="type-tableconstructor"></a>

## TableConstructor

```zig
pub const TableConstructor = struct {
    fields: []const TableField,
};
```

<a id="type-tablefield"></a>

## TableField

```zig
pub const TableField = union(enum) {
    array: *Expr,
    keyed: KeyedField,
    named: NamedField,
};
```

<a id="type-keyedfield"></a>

## KeyedField

```zig
pub const KeyedField = struct {
    key: *Expr,
    value: *Expr,
};
```

<a id="type-namedfield"></a>

## NamedField

```zig
pub const NamedField = struct {
    name: Identifier,
    value: *Expr,
};
```

<a id="type-indexexpr"></a>

## IndexExpr

```zig
pub const IndexExpr = struct {
    receiver: *Expr,
    key: *Expr,
};
```

<a id="type-fieldexpr"></a>

## FieldExpr

```zig
pub const FieldExpr = struct {
    receiver: *Expr,
    name: Identifier,
};
```

<a id="type-callexpr"></a>

## CallExpr

```zig
pub const CallExpr = struct {
    callee: *Expr,
    call_line: usize,
    args: []const *Expr,
};
```

<a id="type-methodcallexpr"></a>

## MethodCallExpr

```zig
pub const MethodCallExpr = struct {
    receiver: *Expr,
    method: Identifier,
    call_line: usize,
    args: []const *Expr,
};
```

<a id="type-unaryop"></a>

## UnaryOp

```zig
pub const UnaryOp = enum {
    negate,
    not,
    length,
    bit_not,
};
```

<a id="type-unaryexpr"></a>

## UnaryExpr

```zig
pub const UnaryExpr = struct {
    op: UnaryOp,
    op_line: usize,
    operand: *Expr,
};
```

<a id="type-binaryop"></a>

## BinaryOp

```zig
pub const BinaryOp = enum {
    or_op,
    and_op,
    eq,
    ne,
    lt,
    le,
    gt,
    ge,
    bit_or,
    bit_xor,
    bit_and,
    shift_left,
    shift_right,
    concat,
    add,
    sub,
    mul,
    div,
    idiv,
    mod,
    pow,
};
```

<a id="type-binaryexpr"></a>

## BinaryExpr

```zig
pub const BinaryExpr = struct {
    op: BinaryOp,
    op_line: usize,
    left: *Expr,
    right: *Expr,
};
```

