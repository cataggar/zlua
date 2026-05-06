const std = @import("std");
const ast = @import("ast.zig");
const errors = @import("../errors.zig");
const lexer = @import("lexer.zig");
const source_mod = @import("source.zig");
const token_mod = @import("token.zig");

const Tag = token_mod.Tag;

const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []const token_mod.Token,
    error_diagnostic: ?*?errors.Diagnostic = null,
    index: usize = 0,

    fn parseChunk(self: *Parser) anyerror![]const ast.Stmt {
        return self.parseBlock(&.{});
    }

    fn parseBlock(self: *Parser, end_tags: []const Tag) anyerror!ast.Block {
        var statements = std.ArrayList(ast.Stmt).empty;
        while (!self.atBlockEnd(end_tags)) {
            const statement = try self.parseStatement(end_tags);
            try statements.append(self.allocator, statement);
            if (statement == .return_stmt) {
                if (!self.atBlockEnd(end_tags)) return self.failUnexpected(.syntax_error);
            }
        }
        return statements.toOwnedSlice(self.allocator);
    }

    fn parseStatement(self: *Parser, end_tags: []const Tag) anyerror!ast.Stmt {
        _ = end_tags;
        if (self.match(.semicolon)) |tok| return .{ .empty = tok.span };
        if (self.match(.keyword_break)) |tok| return .{ .break_stmt = tok.span };
        if (self.match(.keyword_goto)) |_| return .{ .goto_stmt = try self.expectIdentifier() };
        if (self.match(.double_colon)) |_| return self.parseLabel();
        if (self.match(.keyword_do)) |_| return self.parseDoBlock();
        if (self.match(.keyword_while)) |_| return self.parseWhile();
        if (self.match(.keyword_repeat)) |_| return self.parseRepeat();
        if (self.match(.keyword_if)) |_| return self.parseIf();
        if (self.match(.keyword_for)) |_| return self.parseFor();
        if (self.match(.keyword_function)) |_| return self.parseFunctionDeclaration();
        if (self.match(.keyword_local)) |_| return self.parseLocalStatement();
        if (self.check(.keyword_global)) {
            if (self.peekN(1).tag == .equal) return self.parseAssignmentOrCallStatement();
            _ = self.advance();
            return self.parseGlobalDeclaration();
        }
        if (self.match(.keyword_return)) |tok| return self.parseReturn(tok.span.start.line);
        return self.parseAssignmentOrCallStatement();
    }

    fn parseLabel(self: *Parser) anyerror!ast.Stmt {
        const name = try self.expectIdentifier();
        _ = try self.expect(.double_colon);
        return .{ .label_stmt = name };
    }

    fn parseDoBlock(self: *Parser) anyerror!ast.Stmt {
        const block = try self.parseBlock(&.{.keyword_end});
        _ = try self.expect(.keyword_end);
        return .{ .do_block = block };
    }

    fn parseWhile(self: *Parser) anyerror!ast.Stmt {
        const condition = try self.parseExpression(0);
        _ = try self.expect(.keyword_do);
        const body = try self.parseBlock(&.{.keyword_end});
        const end = try self.expect(.keyword_end);
        return .{ .while_stmt = .{ .condition = condition, .body = body, .end_line = end.span.start.line } };
    }

    fn parseRepeat(self: *Parser) anyerror!ast.Stmt {
        const body = try self.parseBlock(&.{.keyword_until});
        _ = try self.expect(.keyword_until);
        const condition = try self.parseExpression(0);
        return .{ .repeat_stmt = .{ .body = body, .condition = condition } };
    }

    fn parseIf(self: *Parser) anyerror!ast.Stmt {
        var branches = std.ArrayList(ast.IfBranch).empty;
        const first_condition = try self.parseExpression(0);
        _ = try self.expect(.keyword_then);
        const first_body = try self.parseBlock(&.{ .keyword_elseif, .keyword_else, .keyword_end });
        try branches.append(self.allocator, .{ .condition = first_condition, .body = first_body });

        while (self.match(.keyword_elseif)) |_| {
            const condition = try self.parseExpression(0);
            _ = try self.expect(.keyword_then);
            const body = try self.parseBlock(&.{ .keyword_elseif, .keyword_else, .keyword_end });
            try branches.append(self.allocator, .{ .condition = condition, .body = body });
        }

        const else_block = if (self.match(.keyword_else)) |_| try self.parseBlock(&.{.keyword_end}) else null;
        _ = try self.expect(.keyword_end);
        return .{ .if_stmt = .{ .branches = try branches.toOwnedSlice(self.allocator), .else_block = else_block } };
    }

    fn parseFor(self: *Parser) anyerror!ast.Stmt {
        const first_name = try self.expectIdentifier();
        if (self.match(.equal)) |_| {
            const start = try self.parseExpression(0);
            _ = try self.expect(.comma);
            const limit = try self.parseExpression(0);
            const step = if (self.match(.comma)) |_| try self.parseExpression(0) else null;
            _ = try self.expect(.keyword_do);
            const body = try self.parseBlock(&.{.keyword_end});
            const end = try self.expect(.keyword_end);
            return .{ .numeric_for = .{ .name = first_name, .start = start, .limit = limit, .step = step, .body = body, .end_line = end.span.start.line } };
        }

        var names = std.ArrayList(ast.Identifier).empty;
        try names.append(self.allocator, first_name);
        while (self.match(.comma)) |_| try names.append(self.allocator, try self.expectIdentifier());
        _ = try self.expect(.keyword_in);
        const iterators = try self.parseExpressionList();
        _ = try self.expect(.keyword_do);
        const body = try self.parseBlock(&.{.keyword_end});
        const end = try self.expect(.keyword_end);
        return .{ .generic_for = .{ .names = try names.toOwnedSlice(self.allocator), .iterators = iterators, .body = body, .end_line = end.span.start.line } };
    }

    fn parseFunctionDeclaration(self: *Parser) anyerror!ast.Stmt {
        const name = try self.parseFunctionName();
        const body = try self.parseFunctionBody(name.root.span.start.line);
        return .{ .function_decl = .{ .name = name, .body = body } };
    }

    fn parseFunctionName(self: *Parser) anyerror!ast.FunctionName {
        const root = try self.expectIdentifier();
        var fields = std.ArrayList(ast.Identifier).empty;
        while (self.match(.dot)) |_| try fields.append(self.allocator, try self.expectIdentifier());
        const method = if (self.match(.colon)) |_| try self.expectIdentifier() else null;
        return .{ .root = root, .fields = try fields.toOwnedSlice(self.allocator), .method = method };
    }

    fn parseLocalStatement(self: *Parser) anyerror!ast.Stmt {
        if (self.match(.keyword_function)) |_| {
            const name = try self.expectIdentifier();
            const body = try self.parseFunctionBody(name.span.start.line);
            return .{ .local_function_decl = .{ .name = name, .body = body } };
        }

        const default_attribute = try self.parseOptionalAttribute();
        var bindings = std.ArrayList(ast.Binding).empty;
        try bindings.append(self.allocator, try self.parseBinding(default_attribute));
        while (self.match(.comma)) |_| try bindings.append(self.allocator, try self.parseBinding(default_attribute));
        const values = if (self.match(.equal)) |_| try self.parseExpressionList() else &.{};
        return .{ .local_decl = .{ .bindings = try bindings.toOwnedSlice(self.allocator), .values = values } };
    }

    fn parseBinding(self: *Parser, default_attribute: ?ast.Identifier) anyerror!ast.Binding {
        const name = try self.expectIdentifier();
        const attribute = if (try self.parseOptionalAttribute()) |attr| attr else default_attribute;
        return .{ .name = name, .attribute = attribute };
    }

    fn parseOptionalAttribute(self: *Parser) anyerror!?ast.Identifier {
        return if (self.match(.less)) |_| blk: {
            const attr = try self.expectIdentifier();
            _ = try self.expect(.greater);
            break :blk attr;
        } else null;
    }

    fn parseGlobalDeclaration(self: *Parser) anyerror!ast.Stmt {
        const attribute = try self.parseOptionalAttribute();

        if (self.match(.keyword_function)) |_| {
            const name = try self.expectIdentifier();
            const body = try self.parseFunctionBody(name.span.start.line);
            const binding = ast.Binding{ .name = name, .attribute = attribute };
            const value = try self.newExpr(.{ .function_literal = body });
            return .{ .global_decl = .{
                .attribute = attribute,
                .all = false,
                .names = try self.singleBindingSlice(binding),
                .values = try self.singleExprSlice(value),
            } };
        }

        if (self.match(.star)) |_| {
            return .{ .global_decl = .{ .attribute = attribute, .all = true, .names = &.{}, .values = &.{} } };
        }

        var names = std.ArrayList(ast.Binding).empty;
        try names.append(self.allocator, try self.parseBinding(attribute));
        while (self.match(.comma)) |_| try names.append(self.allocator, try self.parseBinding(attribute));
        const values = if (self.match(.equal)) |_| try self.parseExpressionList() else &.{};
        return .{ .global_decl = .{ .attribute = attribute, .all = false, .names = try names.toOwnedSlice(self.allocator), .values = values } };
    }

    fn parseReturn(self: *Parser, line: usize) anyerror!ast.Stmt {
        const values = if (self.canStartExpression()) try self.parseExpressionList() else &.{};
        _ = self.match(.semicolon);
        return .{ .return_stmt = .{ .line = line, .values = values } };
    }

    fn parseAssignmentOrCallStatement(self: *Parser) anyerror!ast.Stmt {
        const first = try self.parsePrefixExpression();
        if (self.match(.comma)) |_| {
            var targets = std.ArrayList(*ast.Expr).empty;
            try targets.append(self.allocator, first);
            try targets.append(self.allocator, try self.parsePrefixExpression());
            while (self.match(.comma)) |_| try targets.append(self.allocator, try self.parsePrefixExpression());
            _ = try self.expect(.equal);
            return .{ .assignment = .{ .targets = try targets.toOwnedSlice(self.allocator), .values = try self.parseExpressionList() } };
        }
        if (self.match(.equal)) |_| {
            return .{ .assignment = .{ .targets = try self.singleExprSlice(first), .values = try self.parseExpressionList() } };
        }
        if (first.* == .call or first.* == .method_call) return .{ .call_stmt = first };
        return self.failUnexpected(.syntax_error);
    }

    fn parseExpressionList(self: *Parser) anyerror![]const *ast.Expr {
        var expressions = std.ArrayList(*ast.Expr).empty;
        try expressions.append(self.allocator, try self.parseExpression(0));
        while (self.match(.comma)) |_| try expressions.append(self.allocator, try self.parseExpression(0));
        return expressions.toOwnedSlice(self.allocator);
    }

    fn parseExpression(self: *Parser, min_prec: u8) anyerror!*ast.Expr {
        var left = if (unaryOp(self.peek().tag)) |op| blk: {
            _ = self.advance();
            const operand = try self.parseExpression(unary_precedence);
            break :blk try self.newExpr(.{ .unary = .{ .op = op, .operand = operand } });
        } else try self.parsePrimaryExpression();

        while (binaryInfo(self.peek().tag)) |info| {
            if (info.precedence < min_prec) break;
            const op = self.advance();
            const rhs_min = if (info.right_assoc) info.precedence else info.precedence + 1;
            const right = try self.parseExpression(rhs_min);
            left = try self.newExpr(.{ .binary = .{ .op = info.op, .op_line = op.span.start.line, .left = left, .right = right } });
        }
        return left;
    }

    fn parsePrimaryExpression(self: *Parser) anyerror!*ast.Expr {
        if (self.check(.identifier) or self.check(.keyword_global) or self.check(.left_paren)) return self.parsePrefixExpression();
        if (self.match(.keyword_nil)) |tok| return self.newExpr(.{ .nil = tok.span });
        if (self.match(.keyword_false)) |tok| return self.newExpr(.{ .boolean = .{ .value = false, .span = tok.span } });
        if (self.match(.keyword_true)) |tok| return self.newExpr(.{ .boolean = .{ .value = true, .span = tok.span } });
        if (self.match(.integer_literal)) |tok| return self.newExpr(.{ .integer = .{ .lexeme = tok.lexeme, .span = tok.span } });
        if (self.match(.float_literal)) |tok| return self.newExpr(.{ .float = .{ .lexeme = tok.lexeme, .span = tok.span } });
        if (self.match(.string_literal)) |tok| return self.newExpr(.{ .string = .{ .lexeme = tok.lexeme, .span = tok.span } });
        if (self.match(.ellipsis)) |tok| return self.newExpr(.{ .vararg = tok.span });
        if (self.match(.left_brace)) |tok| return self.newExpr(.{ .table_constructor = try self.parseTableConstructorAfterLeftBrace(tok) });
        if (self.match(.keyword_function)) |tok| return self.newExpr(.{ .function_literal = try self.parseFunctionBody(tok.span.start.line) });
        return self.failUnexpected(.syntax_error);
    }

    fn parsePrefixExpression(self: *Parser) anyerror!*ast.Expr {
        var expr = if (self.match(.identifier) orelse self.match(.keyword_global)) |tok|
            try self.newExpr(.{ .identifier = .{ .name = tok.lexeme, .span = tok.span } })
        else if (self.match(.left_paren)) |_| blk: {
            const inner = try self.parseExpression(0);
            _ = try self.expect(.right_paren);
            break :blk try self.newExpr(.{ .grouped = inner });
        } else return self.failUnexpected(.syntax_error);

        while (true) {
            if (self.match(.left_bracket)) |_| {
                const key = try self.parseExpression(0);
                _ = try self.expect(.right_bracket);
                expr = try self.newExpr(.{ .index = .{ .receiver = expr, .key = key } });
            } else if (self.match(.dot)) |_| {
                expr = try self.newExpr(.{ .field = .{ .receiver = expr, .name = try self.expectIdentifier() } });
            } else if (self.match(.colon)) |_| {
                const method = try self.expectIdentifier();
                const args = try self.parseArgs();
                expr = try self.newExpr(.{ .method_call = .{ .receiver = expr, .method = method, .args = args } });
            } else if (self.startsArgs()) {
                expr = try self.newExpr(.{ .call = .{ .callee = expr, .args = try self.parseArgs() } });
            } else break;
        }
        return expr;
    }

    fn parseArgs(self: *Parser) anyerror![]const *ast.Expr {
        if (self.match(.left_paren)) |_| {
            if (self.match(.right_paren)) |_| return &.{};
            const args = try self.parseExpressionList();
            _ = try self.expect(.right_paren);
            return args;
        }
        if (self.match(.left_brace)) |tok| return self.singleExprSlice(try self.newExpr(.{ .table_constructor = try self.parseTableConstructorAfterLeftBrace(tok) }));
        if (self.match(.string_literal)) |tok| return self.singleExprSlice(try self.newExpr(.{ .string = .{ .lexeme = tok.lexeme, .span = tok.span } }));
        return self.failUnexpected(.syntax_error);
    }

    fn parseTableConstructorAfterLeftBrace(self: *Parser, open: token_mod.Token) anyerror!ast.TableConstructor {
        var fields = std.ArrayList(ast.TableField).empty;
        while (!self.check(.right_brace)) {
            if (self.check(.eof)) return self.failExpectedClose("}", "{", open, self.peek());
            try fields.append(self.allocator, try self.parseTableField());
            if (self.match(.comma) == null and self.match(.semicolon) == null) break;
            if (self.check(.right_brace)) break;
        }
        if (!self.check(.right_brace)) return self.failExpectedClose("}", "{", open, self.peek());
        _ = self.advance();
        return .{ .fields = try fields.toOwnedSlice(self.allocator) };
    }

    fn parseTableField(self: *Parser) anyerror!ast.TableField {
        if (self.match(.left_bracket)) |_| {
            const key = try self.parseExpression(0);
            _ = try self.expect(.right_bracket);
            _ = try self.expect(.equal);
            const value = try self.parseExpression(0);
            return .{ .keyed = .{ .key = key, .value = value } };
        }
        if (self.check(.identifier) and self.peekN(1).tag == .equal) {
            const name = try self.expectIdentifier();
            _ = try self.expect(.equal);
            return .{ .named = .{ .name = name, .value = try self.parseExpression(0) } };
        }
        return .{ .array = try self.parseExpression(0) };
    }

    fn parseFunctionBody(self: *Parser, defined_line: usize) anyerror!ast.FunctionBody {
        _ = try self.expect(.left_paren);
        const params = try self.parseParams();
        _ = try self.expect(.right_paren);
        const body = try self.parseBlock(&.{.keyword_end});
        const end = try self.expect(.keyword_end);
        return params.withBody(body, defined_line, end.span.start.line);
    }

    const ParsedParams = struct {
        params: []const ast.Identifier,
        is_vararg: bool,
        vararg_name: ?ast.Identifier,

        fn withBody(self: ParsedParams, body: ast.Block, defined_line: usize, end_line: usize) ast.FunctionBody {
            return .{ .params = self.params, .is_vararg = self.is_vararg, .vararg_name = self.vararg_name, .body = body, .defined_line = defined_line, .end_line = end_line };
        }
    };

    fn parseParams(self: *Parser) anyerror!ParsedParams {
        if (self.check(.right_paren)) return .{ .params = &.{}, .is_vararg = false, .vararg_name = null };
        var params = std.ArrayList(ast.Identifier).empty;
        var is_vararg = false;
        var vararg_name: ?ast.Identifier = null;
        while (true) {
            if (self.match(.ellipsis)) |_| {
                is_vararg = true;
                if (self.check(.identifier)) vararg_name = try self.expectIdentifier();
                break;
            }
            try params.append(self.allocator, try self.expectIdentifier());
            if (self.match(.comma) == null) break;
            if (self.check(.right_paren)) return self.failUnexpected(.syntax_error);
        }
        return .{ .params = try params.toOwnedSlice(self.allocator), .is_vararg = is_vararg, .vararg_name = vararg_name };
    }

    fn singleExprSlice(self: *Parser, expr: *ast.Expr) anyerror![]const *ast.Expr {
        const slice = try self.allocator.alloc(*ast.Expr, 1);
        slice[0] = expr;
        return slice;
    }

    fn singleBindingSlice(self: *Parser, binding: ast.Binding) anyerror![]const ast.Binding {
        const slice = try self.allocator.alloc(ast.Binding, 1);
        slice[0] = binding;
        return slice;
    }

    fn newExpr(self: *Parser, expr: ast.Expr) anyerror!*ast.Expr {
        const node = try self.allocator.create(ast.Expr);
        node.* = expr;
        return node;
    }

    fn expectIdentifier(self: *Parser) anyerror!ast.Identifier {
        const tok = try self.expect(.identifier);
        return .{ .name = tok.lexeme, .span = tok.span };
    }

    fn expect(self: *Parser, tag: Tag) anyerror!token_mod.Token {
        if (!self.check(tag)) return self.failExpected(tag);
        return self.advance();
    }

    fn failExpected(self: *Parser, tag: Tag) error{ParseError} {
        _ = tag;
        return self.failUnexpected(.syntax_error);
    }

    fn failExpectedClose(self: *Parser, expected: []const u8, opener: []const u8, open: token_mod.Token, near: token_mod.Token) error{ParseError} {
        if (self.error_diagnostic) |slot| if (slot.* == null) {
            slot.* = .{ .syntax = .{ .expected_close = .{
                .expected = expected,
                .opener = opener,
                .opener_line = open.span.start.line,
                .near = errors.tokenRef(near),
            } } };
        };
        return error.ParseError;
    }

    fn failUnexpected(self: *Parser, message: errors.SyntaxMessage) error{ParseError} {
        if (self.error_diagnostic) |slot| if (slot.* == null) {
            slot.* = .{ .syntax = .{ .unexpected = .{ .token = errors.tokenRef(self.peek()), .message = message } } };
        };
        return error.ParseError;
    }

    fn match(self: *Parser, tag: Tag) ?token_mod.Token {
        if (!self.check(tag)) return null;
        return self.advance();
    }

    fn advance(self: *Parser) token_mod.Token {
        const tok = self.peek();
        if (self.index < self.tokens.len) self.index += 1;
        return tok;
    }

    fn check(self: Parser, tag: Tag) bool {
        return self.peek().tag == tag;
    }

    fn peek(self: Parser) token_mod.Token {
        return self.tokens[@min(self.index, self.tokens.len - 1)];
    }

    fn peekN(self: Parser, offset: usize) token_mod.Token {
        return self.tokens[@min(self.index + offset, self.tokens.len - 1)];
    }

    fn atBlockEnd(self: Parser, end_tags: []const Tag) bool {
        if (self.check(.eof)) return true;
        for (end_tags) |tag| if (self.check(tag)) return true;
        return false;
    }

    fn startsArgs(self: Parser) bool {
        return self.check(.left_paren) or self.check(.left_brace) or self.check(.string_literal);
    }

    fn canStartExpression(self: Parser) bool {
        return switch (self.peek().tag) {
            .identifier,
            .keyword_global,
            .left_paren,
            .keyword_nil,
            .keyword_false,
            .keyword_true,
            .integer_literal,
            .float_literal,
            .string_literal,
            .ellipsis,
            .left_brace,
            .keyword_function,
            .minus,
            .keyword_not,
            .hash,
            .tilde,
            => true,
            else => false,
        };
    }
};

const unary_precedence = 11;

const BinaryInfo = struct {
    op: ast.BinaryOp,
    precedence: u8,
    right_assoc: bool = false,
};

fn unaryOp(tag: Tag) ?ast.UnaryOp {
    return switch (tag) {
        .minus => .negate,
        .keyword_not => .not,
        .hash => .length,
        .tilde => .bit_not,
        else => null,
    };
}

fn binaryInfo(tag: Tag) ?BinaryInfo {
    return switch (tag) {
        .keyword_or => .{ .op = .or_op, .precedence = 1 },
        .keyword_and => .{ .op = .and_op, .precedence = 2 },
        .double_equal => .{ .op = .eq, .precedence = 3 },
        .tilde_equal => .{ .op = .ne, .precedence = 3 },
        .less => .{ .op = .lt, .precedence = 3 },
        .less_equal => .{ .op = .le, .precedence = 3 },
        .greater => .{ .op = .gt, .precedence = 3 },
        .greater_equal => .{ .op = .ge, .precedence = 3 },
        .pipe => .{ .op = .bit_or, .precedence = 4 },
        .tilde => .{ .op = .bit_xor, .precedence = 5 },
        .ampersand => .{ .op = .bit_and, .precedence = 6 },
        .double_less => .{ .op = .shift_left, .precedence = 7 },
        .double_greater => .{ .op = .shift_right, .precedence = 7 },
        .double_dot => .{ .op = .concat, .precedence = 8, .right_assoc = true },
        .plus => .{ .op = .add, .precedence = 9 },
        .minus => .{ .op = .sub, .precedence = 9 },
        .star => .{ .op = .mul, .precedence = 10 },
        .slash => .{ .op = .div, .precedence = 10 },
        .double_slash => .{ .op = .idiv, .precedence = 10 },
        .percent => .{ .op = .mod, .precedence = 10 },
        .caret => .{ .op = .pow, .precedence = 12, .right_assoc = true },
        else => null,
    };
}

pub fn parse(allocator: std.mem.Allocator, source: []const u8) !ast.Ast {
    const tokens = try lexer.lex(allocator, source);
    defer allocator.free(tokens);

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var parser: Parser = .{ .allocator = arena.allocator(), .tokens = tokens };
    const statements = try parser.parseChunk();
    _ = try parser.expect(.eof);
    return .{ .arena = arena, .source = source, .statements = statements };
}

pub fn parseWithDiagnostic(allocator: std.mem.Allocator, source: []const u8, error_diagnostic: *?errors.Diagnostic) !ast.Ast {
    const tokens = try lexer.lexWithDiagnostic(allocator, source, error_diagnostic);
    defer allocator.free(tokens);

    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();

    var parser: Parser = .{ .allocator = arena.allocator(), .tokens = tokens, .error_diagnostic = error_diagnostic };
    const statements = try parser.parseChunk();
    _ = try parser.expect(.eof);
    return .{ .arena = arena, .source = source, .statements = statements };
}

fn expectParse(source: []const u8) !ast.Ast {
    return parse(std.testing.allocator, source);
}

test "parses milestone statement families" {
    var tree = try expectParse(
        \\global<const> *
        \\global x, y<const> = 1, 2
        \\global function gf() return 1 end
        \\local a<const>, b<close> = 1, 2
        \\function t.u:v(a, b, ... rest)
        \\  if a then b = b + 1 elseif b then b = 2 else b = 3 end
        \\  while b do break end
        \\  repeat b = b - 1 until b == 0
        \\  for i = 1, 3, 1 do ; end
        \\  for k, v in pairs({}) do do end end
        \\  ::again:: goto again
        \\  return b
        \\end
        \\local function f() return end
    );
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, 6), tree.statements.len);
    try std.testing.expect(tree.statements[0] == .global_decl);
    try std.testing.expect(tree.statements[2] == .global_decl);
    try std.testing.expect(tree.statements[3] == .local_decl);
    try std.testing.expect(tree.statements[4] == .function_decl);
}

test "parses expression and table syntax" {
    var tree = try expectParse(
        \\local x = {1, name = "n", [1 + 2] = function(a) return a end}
        \\x.y:z(1 + 2 * 3 ^ -4, not false, ...)
    );
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, 2), tree.statements.len);
    try std.testing.expect(tree.statements[0] == .local_decl);
    try std.testing.expect(tree.statements[1] == .call_stmt);
}

test "rejects incomplete syntax" {
    try std.testing.expectError(error.ParseError, parse(std.testing.allocator, "local = 1"));
    try std.testing.expectError(error.ParseError, parse(std.testing.allocator, "if true then"));
    try std.testing.expectError(error.ParseError, parse(std.testing.allocator, "return 1; local x = 2"));
}
