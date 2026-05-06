const std = @import("std");
const source = @import("source.zig");

pub const Ast = struct {
    arena: std.heap.ArenaAllocator,
    source: []const u8,
    statements: []const Stmt,

    pub fn deinit(self: *Ast) void {
        self.arena.deinit();
    }
};

pub const Identifier = struct {
    name: []const u8,
    span: source.Span,
};

pub const Binding = struct {
    name: Identifier,
    attribute: ?Identifier = null,
};

pub const Block = []const Stmt;

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

pub const Assignment = struct {
    targets: []const *Expr,
    values: []const *Expr,
};

pub const LocalDecl = struct {
    bindings: []const Binding,
    values: []const *Expr,
};

pub const GlobalDecl = struct {
    attribute: ?Identifier,
    all: bool,
    names: []const Binding,
    values: []const *Expr,
};

pub const FunctionName = struct {
    root: Identifier,
    fields: []const Identifier,
    method: ?Identifier,
};

pub const FunctionDecl = struct {
    name: FunctionName,
    body: FunctionBody,
};

pub const LocalFunctionDecl = struct {
    name: Identifier,
    body: FunctionBody,
};

pub const IfStmt = struct {
    branches: []const IfBranch,
    else_block: ?Block,
};

pub const IfBranch = struct {
    condition: *Expr,
    body: Block,
};

pub const WhileStmt = struct {
    condition: *Expr,
    body: Block,
    end_line: usize,
};

pub const RepeatStmt = struct {
    body: Block,
    condition: *Expr,
};

pub const NumericFor = struct {
    name: Identifier,
    start: *Expr,
    limit: *Expr,
    step: ?*Expr,
    body: Block,
    end_line: usize,
};

pub const GenericFor = struct {
    names: []const Identifier,
    iterators: []const *Expr,
    body: Block,
    end_line: usize,
};

pub const ReturnStmt = struct {
    line: usize,
    values: []const *Expr,
};

pub const FunctionBody = struct {
    params: []const Identifier,
    is_vararg: bool,
    vararg_name: ?Identifier,
    body: Block,
    defined_line: usize,
    end_line: usize,
};

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

pub const BoolLiteral = struct {
    value: bool,
    span: source.Span,
};

pub const TokenLiteral = struct {
    lexeme: []const u8,
    span: source.Span,
};

pub const TableConstructor = struct {
    fields: []const TableField,
};

pub const TableField = union(enum) {
    array: *Expr,
    keyed: KeyedField,
    named: NamedField,
};

pub const KeyedField = struct {
    key: *Expr,
    value: *Expr,
};

pub const NamedField = struct {
    name: Identifier,
    value: *Expr,
};

pub const IndexExpr = struct {
    receiver: *Expr,
    key: *Expr,
};

pub const FieldExpr = struct {
    receiver: *Expr,
    name: Identifier,
};

pub const CallExpr = struct {
    callee: *Expr,
    args: []const *Expr,
};

pub const MethodCallExpr = struct {
    receiver: *Expr,
    method: Identifier,
    args: []const *Expr,
};

pub const UnaryOp = enum {
    negate,
    not,
    length,
    bit_not,
};

pub const UnaryExpr = struct {
    op: UnaryOp,
    operand: *Expr,
};

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

pub const BinaryExpr = struct {
    op: BinaryOp,
    op_line: usize,
    left: *Expr,
    right: *Expr,
};
