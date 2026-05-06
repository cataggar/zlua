const std = @import("std");
const errors = @import("../errors.zig");
const frontend = @import("../frontend.zig");
const ast = frontend.ast;
const source = frontend.source;

pub const Error = error{ResolveError};

const DeclKind = enum {
    local,
    global_name,
    global_all,
};

const Decl = struct {
    name: []const u8,
    span: source.Span,
    kind: DeclKind,
    read_only: bool = false,
};

const Scope = struct {
    decl_start: usize,
    label_start: usize,
    goto_start: usize,
};

const Label = struct {
    name: []const u8,
    span: source.Span,
    decl_count: usize,
    scope_depth: usize,
};

const PendingGoto = struct {
    name: []const u8,
    span: source.Span,
    decl_count: usize,
    scope_depth: usize,
};

const Attribute = enum {
    regular,
    constant,
    to_close,
};

const zero_span: source.Span = .{ .start = .{}, .end = .{} };

const Lookup = union(enum) {
    local: Decl,
    global: Decl,
    undeclared,
};

pub fn resolve(allocator: std.mem.Allocator, tree: *const ast.Ast) !void {
    var context = FunctionContext.init(allocator, null, null);
    defer context.deinit();

    try context.enterScope();
    try context.declareLocal(.{ .name = "_ENV", .span = zero_span }, .regular, false);
    try context.resolveBlock(tree.statements, true);
    try context.leaveScope();
}

pub fn resolveWithDiagnostic(allocator: std.mem.Allocator, tree: *const ast.Ast, error_diagnostic: *?errors.Diagnostic) !void {
    var context = FunctionContext.init(allocator, null, error_diagnostic);
    defer context.deinit();

    try context.enterScope();
    try context.declareLocal(.{ .name = "_ENV", .span = zero_span }, .regular, false);
    try context.resolveBlock(tree.statements, true);
    try context.leaveScope();
}

const FunctionContext = struct {
    allocator: std.mem.Allocator,
    parent: ?*FunctionContext,
    error_diagnostic: ?*?errors.Diagnostic = null,
    decls: std.ArrayList(Decl) = .empty,
    scopes: std.ArrayList(Scope) = .empty,
    labels: std.ArrayList(Label) = .empty,
    gotos: std.ArrayList(PendingGoto) = .empty,
    loop_depth: usize = 0,
    upvalues: std.ArrayList([]const u8) = .empty,

    fn init(allocator: std.mem.Allocator, parent: ?*FunctionContext, error_diagnostic: ?*?errors.Diagnostic) FunctionContext {
        return .{ .allocator = allocator, .parent = parent, .error_diagnostic = error_diagnostic };
    }

    fn deinit(self: *FunctionContext) void {
        self.decls.deinit(self.allocator);
        self.scopes.deinit(self.allocator);
        self.labels.deinit(self.allocator);
        self.gotos.deinit(self.allocator);
        self.upvalues.deinit(self.allocator);
    }

    fn enterScope(self: *FunctionContext) !void {
        try self.scopes.append(self.allocator, .{
            .decl_start = self.decls.items.len,
            .label_start = self.labels.items.len,
            .goto_start = self.gotos.items.len,
        });
    }

    fn leaveScope(self: *FunctionContext) !void {
        const scope = self.scopes.items[self.scopes.items.len - 1];
        const depth = self.scopes.items.len;

        var index = scope.goto_start;
        while (index < self.gotos.items.len) : (index += 1) {
            if (self.gotos.items[index].scope_depth != depth) continue;
            if (depth == 1) return self.fail(.{ .missing_label = .{ .name = self.gotos.items[index].name, .span = self.gotos.items[index].span } });
            self.gotos.items[index].scope_depth = depth - 1;
            self.gotos.items[index].decl_count = scope.decl_start;
        }

        self.decls.items.len = scope.decl_start;
        self.labels.items.len = scope.label_start;
        self.scopes.items.len -= 1;
    }

    fn resolveBlock(self: *FunctionContext, block: ast.Block, allow_trailing_label_scope_reset: bool) anyerror!void {
        for (block, 0..) |statement, index| {
            try self.resolveStatement(statement, allow_trailing_label_scope_reset and labelIsLastNoOp(block, index));
        }
    }

    fn resolveScopedBlock(self: *FunctionContext, block: ast.Block) anyerror!void {
        try self.enterScope();
        try self.resolveBlock(block, true);
        try self.leaveScope();
    }

    fn resolveStatement(self: *FunctionContext, statement: ast.Stmt, label_last_noop: bool) anyerror!void {
        switch (statement) {
            .empty => {},
            .assignment => |assignment| {
                for (assignment.targets) |target| try self.resolveAssignmentTarget(target);
                for (assignment.values) |value| try self.resolveExpr(value);
            },
            .local_decl => |decl| try self.resolveLocalDecl(decl),
            .global_decl => |decl| try self.resolveGlobalDecl(decl),
            .function_decl => |decl| try self.resolveFunctionDecl(decl),
            .local_function_decl => |decl| {
                try self.declareLocal(decl.name, .regular, false);
                try self.resolveFunctionBody(decl.body, false);
            },
            .if_stmt => |stmt| {
                for (stmt.branches) |branch| {
                    try self.resolveExpr(branch.condition);
                    try self.resolveScopedBlock(branch.body);
                }
                if (stmt.else_block) |else_block| try self.resolveScopedBlock(else_block);
            },
            .while_stmt => |stmt| {
                try self.resolveExpr(stmt.condition);
                self.loop_depth += 1;
                try self.resolveScopedBlock(stmt.body);
                self.loop_depth -= 1;
            },
            .repeat_stmt => |stmt| {
                self.loop_depth += 1;
                try self.enterScope();
                try self.resolveBlock(stmt.body, false);
                try self.resolveExpr(stmt.condition);
                try self.leaveScope();
                self.loop_depth -= 1;
            },
            .numeric_for => |stmt| {
                try self.resolveExpr(stmt.start);
                try self.resolveExpr(stmt.limit);
                if (stmt.step) |step| try self.resolveExpr(step);
                self.loop_depth += 1;
                try self.enterScope();
                try self.declareLocal(stmt.name, .regular, true);
                try self.resolveBlock(stmt.body, true);
                try self.leaveScope();
                self.loop_depth -= 1;
            },
            .generic_for => |stmt| {
                for (stmt.iterators) |iterator| try self.resolveExpr(iterator);
                self.loop_depth += 1;
                try self.enterScope();
                for (stmt.names, 0..) |name, index| try self.declareLocal(name, .regular, index == 0);
                try self.resolveBlock(stmt.body, true);
                try self.leaveScope();
                self.loop_depth -= 1;
            },
            .break_stmt => |span| {
                if (self.loop_depth == 0) return self.fail(.{ .break_outside_loop = span });
            },
            .goto_stmt => |name| try self.resolveGoto(name),
            .label_stmt => |name| try self.resolveLabel(name, label_last_noop),
            .do_block => |block| try self.resolveScopedBlock(block),
            .return_stmt => |stmt| for (stmt.values) |value| try self.resolveExpr(value),
            .call_stmt => |call| try self.resolveExpr(call),
        }
    }

    fn resolveLocalDecl(self: *FunctionContext, decl: ast.LocalDecl) anyerror!void {
        for (decl.values) |value| try self.resolveExpr(value);

        var close_count: usize = 0;
        for (decl.bindings) |binding| {
            const attr = try self.parseAttribute(binding.attribute);
            if (attr == .to_close) close_count += 1;
            if (close_count > 1) return self.fail(.{ .invalid_close = .{ .span = binding.name.span, .multiple = true } });
            try self.declareLocal(binding.name, attr, false);
        }
    }

    fn resolveGlobalDecl(self: *FunctionContext, decl: ast.GlobalDecl) anyerror!void {
        const default_attr = try self.parseAttribute(decl.attribute);
        if (default_attr == .to_close) return self.fail(.{ .invalid_close = .{ .span = if (decl.attribute) |attribute| attribute.span else zero_span, .global = true } });

        if (decl.all) {
            try self.decls.append(self.allocator, .{
                .name = "*",
                .span = if (decl.attribute) |attribute| attribute.span else zero_span,
                .kind = .global_all,
                .read_only = default_attr == .constant,
            });
            return;
        }

        for (decl.values) |value| try self.resolveExpr(value);
        for (decl.names) |binding| {
            const attr = if (binding.attribute) |_| try self.parseAttribute(binding.attribute) else default_attr;
            if (attr == .to_close) return self.fail(.{ .invalid_close = .{ .span = binding.name.span, .global = true } });
            try self.decls.append(self.allocator, .{
                .name = binding.name.name,
                .span = binding.name.span,
                .kind = .global_name,
                .read_only = attr == .constant,
            });
        }
    }

    fn resolveFunctionDecl(self: *FunctionContext, decl: ast.FunctionDecl) anyerror!void {
        if (decl.name.fields.len == 0 and decl.name.method == null) {
            try self.resolveNameAssignment(decl.name.root);
        } else {
            _ = try self.lookupName(decl.name.root.name, true);
        }
        try self.resolveFunctionBody(decl.body, decl.name.method != null);
    }

    fn resolveFunctionBody(self: *FunctionContext, body: ast.FunctionBody, method: bool) anyerror!void {
        var child = FunctionContext.init(self.allocator, self, self.error_diagnostic);
        defer child.deinit();

        try child.enterScope();
        if (method) {
            try child.declareLocal(.{ .name = "self", .span = zero_span }, .regular, false);
        }
        for (body.params) |param| try child.declareLocal(param, .regular, false);
        if (body.vararg_name) |name| try child.declareLocal(name, .constant, false);
        try child.resolveBlock(body.body, true);
        try child.leaveScope();
    }

    fn declareLocal(self: *FunctionContext, name: ast.Identifier, attr: Attribute, force_read_only: bool) !void {
        try self.decls.append(self.allocator, .{
            .name = name.name,
            .span = name.span,
            .kind = .local,
            .read_only = force_read_only or attr == .constant or attr == .to_close,
        });
    }

    fn resolveExpr(self: *FunctionContext, expr: *const ast.Expr) anyerror!void {
        switch (expr.*) {
            .nil, .boolean, .integer, .float, .string, .vararg => {},
            .identifier => |name| {
                const lookup = try self.lookupName(name.name, true);
                switch (lookup) {
                    .global => try self.ensureEnvironmentIsLocal(name.name, name.span),
                    .local => {},
                    .undeclared => return self.fail(.{ .undeclared_global = .{ .name = name.name, .span = name.span } }),
                }
            },
            .table_constructor => |constructor| {
                for (constructor.fields) |field| switch (field) {
                    .array => |value| try self.resolveExpr(value),
                    .keyed => |keyed| {
                        try self.resolveExpr(keyed.key);
                        try self.resolveExpr(keyed.value);
                    },
                    .named => |named| try self.resolveExpr(named.value),
                };
            },
            .function_literal => |body| try self.resolveFunctionBody(body, false),
            .grouped => |inner| try self.resolveExpr(inner),
            .index => |index| {
                try self.resolveExpr(index.receiver);
                try self.resolveExpr(index.key);
            },
            .field => |field| try self.resolveExpr(field.receiver),
            .call => |call| {
                try self.resolveExpr(call.callee);
                for (call.args) |arg| try self.resolveExpr(arg);
            },
            .method_call => |call| {
                try self.resolveExpr(call.receiver);
                for (call.args) |arg| try self.resolveExpr(arg);
            },
            .unary => |unary| try self.resolveExpr(unary.operand),
            .binary => |binary| {
                try self.resolveExpr(binary.left);
                try self.resolveExpr(binary.right);
            },
        }
    }

    fn resolveAssignmentTarget(self: *FunctionContext, expr: *const ast.Expr) anyerror!void {
        switch (expr.*) {
            .identifier => |name| try self.resolveNameAssignment(name),
            .index => |index| {
                try self.resolveExpr(index.receiver);
                try self.resolveExpr(index.key);
            },
            .field => |field| try self.resolveExpr(field.receiver),
            else => return self.fail(.{ .invalid_assignment_target = exprSpan(expr) }),
        }
    }

    fn resolveNameAssignment(self: *FunctionContext, name: ast.Identifier) !void {
        const lookup = try self.lookupName(name.name, true);
        switch (lookup) {
            .local => |decl| if (decl.read_only) return self.fail(.{ .assign_const = .{ .name = name.name, .span = name.span } }),
            .global => |decl| {
                try self.ensureEnvironmentIsLocal(name.name, name.span);
                if (decl.read_only) return self.fail(.{ .assign_const = .{ .name = name.name, .span = name.span } });
            },
            .undeclared => return self.fail(.{ .undeclared_global = .{ .name = name.name, .span = name.span } }),
        }
    }

    fn lookupName(self: *FunctionContext, name: []const u8, mark_upvalue: bool) anyerror!Lookup {
        const current = self.localLookup(name);
        if (current.lookup) |lookup| return lookup;

        var parent_lookup: Lookup = .undeclared;
        if (self.parent) |parent| {
            parent_lookup = try parent.lookupName(name, false);
            switch (parent_lookup) {
                .local => |decl| {
                    if (mark_upvalue) try self.noteUpvalue(name);
                    return .{ .local = decl };
                },
                .global => return parent_lookup,
                .undeclared => {},
            }
        }

        if (current.blocked) return .undeclared;
        switch (parent_lookup) {
            .undeclared => if (self.parent != null) return .undeclared,
            else => {},
        }

        const global = Decl{ .name = name, .span = zero_span, .kind = .global_name };
        try self.ensureEnvironmentIsLocal(name, zero_span);
        return .{ .global = global };
    }

    const LocalLookup = struct {
        lookup: ?Lookup = null,
        blocked: bool = false,
    };

    fn localLookup(self: *FunctionContext, name: []const u8) LocalLookup {
        var result: LocalLookup = .{};
        var star: ?Decl = null;
        const looking_for_env = std.mem.eql(u8, name, "_ENV");

        var index = self.decls.items.len;
        while (index > 0) {
            index -= 1;
            const decl = self.decls.items[index];
            switch (decl.kind) {
                .local => if (std.mem.eql(u8, decl.name, name)) return .{ .lookup = .{ .local = decl } },
                .global_name => if (std.mem.eql(u8, decl.name, name)) {
                    return .{ .lookup = .{ .global = decl } };
                } else if (!looking_for_env) {
                    result.blocked = true;
                },
                .global_all => {
                    if (!looking_for_env and star == null) star = decl;
                },
            }
        }

        if (star) |decl| return .{ .lookup = .{ .global = decl } };
        return result;
    }

    fn ensureEnvironmentIsLocal(self: *FunctionContext, name: []const u8, span: source.Span) anyerror!void {
        if (std.mem.eql(u8, name, "_ENV")) return;
        const env = try self.lookupName("_ENV", false);
        switch (env) {
            .local => {},
            .global, .undeclared => return self.fail(.{ .invalid_environment = .{ .name = name, .span = span } }),
        }
    }

    fn noteUpvalue(self: *FunctionContext, name: []const u8) !void {
        for (self.upvalues.items) |existing| {
            if (std.mem.eql(u8, existing, name)) return;
        }
        try self.upvalues.append(self.allocator, name);
    }

    fn resolveGoto(self: *FunctionContext, name: ast.Identifier) !void {
        var index = self.labels.items.len;
        while (index > 0) {
            index -= 1;
            const label = self.labels.items[index];
            if (!std.mem.eql(u8, label.name, name.name)) continue;
            if (label.scope_depth <= self.scopes.items.len) {
                if (self.decls.items.len < label.decl_count) return self.fail(.{ .goto_into_scope = .{ .label = name.name, .decl = self.firstDeclAfter(self.decls.items.len, label.decl_count), .span = name.span } });
                return;
            }
        }

        try self.gotos.append(self.allocator, .{
            .name = name.name,
            .span = name.span,
            .decl_count = self.decls.items.len,
            .scope_depth = self.scopes.items.len,
        });
    }

    fn resolveLabel(self: *FunctionContext, name: ast.Identifier, last_noop: bool) !void {
        for (self.labels.items) |label| {
            if (std.mem.eql(u8, label.name, name.name)) return self.fail(.{ .duplicate_label = .{ .name = name.name, .span = name.span, .previous_line = label.span.start.line } });
        }

        const decl_count = if (last_noop) self.scopes.items[self.scopes.items.len - 1].decl_start else self.decls.items.len;
        const label: Label = .{
            .name = name.name,
            .span = name.span,
            .decl_count = decl_count,
            .scope_depth = self.scopes.items.len,
        };
        try self.labels.append(self.allocator, label);

        var index: usize = 0;
        while (index < self.gotos.items.len) {
            const pending = self.gotos.items[index];
            if (std.mem.eql(u8, pending.name, name.name) and pending.scope_depth >= label.scope_depth) {
                if (pending.decl_count < label.decl_count) return self.fail(.{ .goto_into_scope = .{ .label = pending.name, .decl = self.firstDeclAfter(pending.decl_count, label.decl_count), .span = pending.span } });
                self.removeGoto(index);
            } else {
                index += 1;
            }
        }
    }

    fn removeGoto(self: *FunctionContext, index: usize) void {
        var move = index;
        while (move + 1 < self.gotos.items.len) : (move += 1) {
            self.gotos.items[move] = self.gotos.items[move + 1];
        }
        self.gotos.items.len -= 1;
    }

    fn parseAttribute(self: *FunctionContext, attribute: ?ast.Identifier) !Attribute {
        const attr = attribute orelse return .regular;
        if (std.mem.eql(u8, attr.name, "const")) return .constant;
        if (std.mem.eql(u8, attr.name, "close")) return .to_close;
        return self.fail(.{ .unknown_attribute = .{ .name = attr.name, .span = attr.span } });
    }

    fn firstDeclAfter(self: FunctionContext, start: usize, end: usize) []const u8 {
        if (start < end and start < self.decls.items.len) return self.decls.items[start].name;
        return "?";
    }

    fn fail(self: *FunctionContext, diagnostic: errors.ResolveError) Error {
        if (self.error_diagnostic) |slot| {
            if (slot.* == null) slot.* = .{ .resolve = diagnostic };
        }
        return error.ResolveError;
    }
};

fn labelIsLastNoOp(block: ast.Block, index: usize) bool {
    var cursor = index + 1;
    while (cursor < block.len) : (cursor += 1) {
        switch (block[cursor]) {
            .empty, .label_stmt => {},
            else => return false,
        }
    }
    return true;
}

fn exprSpan(expr: *const ast.Expr) source.Span {
    return switch (expr.*) {
        .nil => |span| span,
        .boolean => |value| value.span,
        .integer => |value| value.span,
        .float => |value| value.span,
        .string => |value| value.span,
        .vararg => |span| span,
        .identifier => |name| name.span,
        .table_constructor => |constructor| if (constructor.fields.len > 0) fieldSpan(constructor.fields[0]) else zero_span,
        .function_literal => |body| .{ .start = .{ .line = body.defined_line }, .end = .{ .line = body.defined_line } },
        .grouped => |inner| exprSpan(inner),
        .index => |index| exprSpan(index.receiver),
        .field => |field| field.name.span,
        .call => |call| exprSpan(call.callee),
        .method_call => |call| call.method.span,
        .unary => |unary| exprSpan(unary.operand),
        .binary => |binary| exprSpan(binary.left),
    };
}

fn fieldSpan(field: ast.TableField) source.Span {
    return switch (field) {
        .array => |expr| exprSpan(expr),
        .keyed => |keyed| exprSpan(keyed.key),
        .named => |named| named.name.span,
    };
}

fn expectResolve(source_text: []const u8) !void {
    var tree = try frontend.parse(std.testing.allocator, source_text);
    defer tree.deinit();
    try resolve(std.testing.allocator, &tree);
}

fn expectResolveError(source_text: []const u8) !void {
    var tree = try frontend.parse(std.testing.allocator, source_text);
    defer tree.deinit();
    try std.testing.expectError(error.ResolveError, resolve(std.testing.allocator, &tree));
}

test "resolver accepts declarations and upvalues" {
    try expectResolve(
        \\global x, f
        \\global<const> obj = {}
        \\x = 1
        \\local y<const> = 2
        \\function obj.inner() return y end
        \\function f(a, ... rest)
        \\  local z = y + a
        \\  return rest[1], z
        \\end
    );
}

test "resolver accepts non-control generic for variable reassignment" {
    try expectResolve(
        \\for _, value in pairs{1} do
        \\  value = value + 1
        \\end
    );
}

test "resolver rejects first generic for variable reassignment" {
    try expectResolveError(
        \\for key, value in pairs{1} do
        \\  key = key + 1
        \\end
    );
}

test "resolver rejects numeric for variable reassignment" {
    try expectResolveError(
        \\for i = 1, 1 do
        \\  i = i + 1
        \\end
    );
}

test "resolver rejects read-only assignments" {
    try expectResolveError("local x<const> = 1\nx = 2");
    try expectResolveError("global<const> x\nx = 2");
    try expectResolveError("for i = 1, 2 do i = 3 end");
    try expectResolveError("function f(... rest) rest = 1 end");
}

test "resolver validates global declarations" {
    try expectResolve("global x\nx = 1");
    try expectResolve("global x\nglobal *\ny = 1");
    try expectResolve("global *\n_ENV.x = 1");
    try expectResolveError("global x\ny = 1");
    try expectResolveError("global<close> x");
    try expectResolveError("global<const> *\ny = 1");
    try expectResolveError("global _ENV, a\na = 1");
}

test "resolver validates gotos and labels" {
    try expectResolve("goto label\nlocal x = 1\n::label::");
    try expectResolve("::label::\ngoto label");
    try expectResolveError("goto label\nlocal x = 1\n::label::\nx = 2");
    try expectResolveError("goto missing");
    try expectResolveError("::a:: ::a::");
}

test "resolver validates assignment targets and break placement" {
    try expectResolve("while true do break end");
    try expectResolveError("break");
    try expectResolveError("f() = 1");
    try expectResolveError("(x) = 1");
}
