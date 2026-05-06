const std = @import("std");
const frontend = @import("../frontend.zig");
const ast = frontend.ast;
const bytecode = @import("bytecode.zig");
const proto_mod = @import("proto.zig");

pub const CompileError = error{
    CompileError,
    RegisterOverflow,
    TooManyReturns,
};

pub fn compile(allocator: std.mem.Allocator, tree: *const ast.Ast) !proto_mod.Proto {
    var root = proto_mod.Proto.init(allocator);
    errdefer root.deinit();

    var context = FunctionCompiler.init(allocator, &root, null);
    try context.compileChunk(tree.statements);
    return root;
}

const Local = struct {
    name: []const u8,
    register: bytecode.Register,
    debug_index: usize,
    captured: bool = false,
    to_close: bool = false,
};

const PendingLocal = struct {
    name: []const u8,
    register: bytecode.Register,
    debug_index: usize,
    to_close: bool = false,
};

const PreparedTarget = union(enum) {
    expr: *const ast.Expr,
    field: struct { table: bytecode.Register, name: bytecode.ConstantIndex },
    index: struct { table: bytecode.Register, key: bytecode.Register },
};

const Scope = struct {
    local_start: usize,
    label_start: usize,
    next_register: bytecode.Register,
};

const Label = struct {
    name: []const u8,
    pc: usize,
    scope_depth: usize,
};

const PendingGoto = struct {
    name: []const u8,
    pc: usize,
    scope_depth: usize,
};

const Loop = struct {
    break_start: usize,
};

const FunctionCompiler = struct {
    allocator: std.mem.Allocator,
    proto: *proto_mod.Proto,
    parent: ?*FunctionCompiler,
    locals: std.ArrayList(Local) = .empty,
    scopes: std.ArrayList(Scope) = .empty,
    labels: std.ArrayList(Label) = .empty,
    gotos: std.ArrayList(PendingGoto) = .empty,
    breaks: std.ArrayList(usize) = .empty,
    loops: std.ArrayList(Loop) = .empty,
    next_register: bytecode.Register = 0,
    current_line: usize = 1,
    forced_line: ?usize = null,

    fn init(allocator: std.mem.Allocator, proto: *proto_mod.Proto, parent: ?*FunctionCompiler) FunctionCompiler {
        return .{ .allocator = allocator, .proto = proto, .parent = parent };
    }

    fn deinit(self: *FunctionCompiler) void {
        self.loops.deinit(self.allocator);
        self.breaks.deinit(self.allocator);
        self.gotos.deinit(self.allocator);
        self.labels.deinit(self.allocator);
        self.scopes.deinit(self.allocator);
        self.locals.deinit(self.allocator);
    }

    fn compileChunk(self: *FunctionCompiler, block: ast.Block) !void {
        defer self.deinit();
        self.proto.is_vararg = true;
        try self.enterScope();
        const env = try self.declareLocal("_ENV");
        const env_upvalue = try self.proto.addUpvalue(.{ .name = "_ENV", .in_stack = false, .index = 0 });
        self.current_line = 0;
        _ = try self.emit(.{ .get_upvalue = .{ .register = env, .upvalue = env_upvalue } });
        try self.compileBlock(block);
        if (!blockEndsWithReturn(block)) {
            self.current_line = 0;
            _ = try self.emit(.{ .ret = .{ .first = 0, .count = 0 } });
        }
        try self.patchPendingGotos();
        try self.leaveScope();
    }

    fn compileFunctionBody(self: *FunctionCompiler, body: ast.FunctionBody, method: bool, debug_name: ?[]const u8) !*proto_mod.Proto {
        const child = try self.allocator.create(proto_mod.Proto);
        errdefer self.allocator.destroy(child);
        child.* = proto_mod.Proto.init(self.allocator);
        errdefer child.deinit();
        if (debug_name) |name| try child.setDebugName(name);
        child.defined_line = body.defined_line;
        child.last_defined_line = body.end_line;

        var child_context = FunctionCompiler.init(self.allocator, child, self);
        errdefer child_context.deinit();
        try child_context.enterScope();
        if (method) _ = try child_context.declareLocal("self");
        for (body.params) |param| _ = try child_context.declareLocal(param.name);
        child.param_count = @intCast(body.params.len + @as(usize, if (method) 1 else 0));
        child.is_vararg = body.is_vararg;
        if (body.is_vararg) {
            const name = if (body.vararg_name) |vararg_name| vararg_name.name else "...";
            _ = try child_context.declareLocal(name);
        }
        try child_context.compileBlock(body.body);
        if (!blockEndsWithReturn(body.body)) {
            child_context.current_line = body.end_line;
            _ = try child_context.emit(.{ .ret = .{ .first = 0, .count = 0 } });
        }
        try child_context.patchPendingGotos();
        try child_context.leaveScope();
        child_context.deinit();

        return child;
    }

    fn compileBlock(self: *FunctionCompiler, block: ast.Block) !void {
        for (block) |statement| try self.compileStatement(statement);
    }

    fn compileScopedBlock(self: *FunctionCompiler, block: ast.Block) !void {
        try self.enterScope();
        try self.compileBlock(block);
        try self.leaveScope();
    }

    fn compileStatement(self: *FunctionCompiler, statement: ast.Stmt) anyerror!void {
        self.current_line = stmtLine(statement);
        switch (statement) {
            .empty => {},
            .assignment => |assignment| try self.compileAssignment(assignment),
            .local_decl => |decl| try self.compileLocalDecl(decl),
            .global_decl => |decl| try self.compileGlobalDecl(decl),
            .function_decl => |decl| try self.compileFunctionDecl(decl),
            .local_function_decl => |decl| try self.compileLocalFunctionDecl(decl),
            .if_stmt => |stmt| try self.compileIf(stmt),
            .while_stmt => |stmt| try self.compileWhile(stmt),
            .repeat_stmt => |stmt| try self.compileRepeat(stmt),
            .numeric_for => |stmt| try self.compileNumericFor(stmt),
            .generic_for => |stmt| try self.compileGenericFor(stmt),
            .break_stmt => try self.compileBreak(),
            .goto_stmt => |name| try self.compileGoto(name),
            .label_stmt => |name| try self.compileLabel(name),
            .do_block => |block| try self.compileScopedBlock(block),
            .return_stmt => |stmt| try self.compileReturn(stmt),
            .call_stmt => |call| {
                const mark = self.registerMark();
                const base = try self.allocReg();
                _ = try self.compileCallInto(call, 0, base, false);
                self.release(mark);
            },
        }
    }

    fn compileAssignment(self: *FunctionCompiler, assignment: ast.Assignment) anyerror!void {
        const mark = self.registerMark();
        var targets = std.ArrayList(PreparedTarget).empty;
        defer targets.deinit(self.allocator);
        for (assignment.targets) |target| try targets.append(self.allocator, try self.prepareAssignmentTarget(target));

        const first_value = try self.allocRegs(@intCast(assignment.targets.len));
        if (assignment.targets.len == 1 and assignment.values.len == 1 and assignment.values[0].* == .function_literal) {
            try self.compileFunctionLiteral(assignment.values[0].function_literal, first_value, assignmentTargetDebugName(assignment.targets[0]));
        } else {
            try self.compileExprListAdjusted(assignment.values, first_value, @intCast(assignment.targets.len));
        }

        for (targets.items, 0..) |target, index| {
            try self.assignPreparedTarget(target, first_value + @as(bytecode.Register, @intCast(index)));
        }

        self.release(mark);
    }

    fn compileLocalDecl(self: *FunctionCompiler, decl: ast.LocalDecl) anyerror!void {
        var pending = std.ArrayList(PendingLocal).empty;
        defer pending.deinit(self.allocator);

        for (decl.bindings) |binding| {
            const register = try self.allocReg();
            const debug_index = try self.proto.addLocal(.{
                .name = binding.name.name,
                .register = register,
                .start_pc = self.proto.pc(),
                .to_close = isCloseAttribute(binding.attribute),
            });
            try pending.append(self.allocator, .{ .name = binding.name.name, .register = register, .debug_index = debug_index, .to_close = isCloseAttribute(binding.attribute) });
        }

        if (pending.items.len == 1 and decl.values.len == 1 and decl.values[0].* == .function_literal) {
            try self.compileFunctionLiteral(decl.values[0].function_literal, pending.items[0].register, pending.items[0].name);
        } else if (pending.items.len > 0) try self.compileExprListAdjusted(decl.values, pending.items[0].register, @intCast(pending.items.len));
        if (pending.items.len == 0) try self.compileExprListAdjusted(decl.values, self.registerMark(), 0);

        for (pending.items) |local| try self.locals.append(self.allocator, .{
            .name = local.name,
            .register = local.register,
            .debug_index = local.debug_index,
            .to_close = local.to_close,
        });

        for (pending.items) |local| {
            if (local.to_close) _ = try self.emit(.{ .check_close = local.register });
        }
    }

    fn compileGlobalDecl(self: *FunctionCompiler, decl: ast.GlobalDecl) anyerror!void {
        if (decl.values.len == 0) return;
        const mark = self.registerMark();
        const first_value = try self.allocRegs(@intCast(decl.names.len));
        try self.compileExprListAdjusted(decl.values, first_value, @intCast(decl.names.len));

        for (decl.names, 0..) |binding, index| {
            const name = try self.nameConstant(binding.name.name);
            _ = try self.emit(.{ .set_global = .{ .register = first_value + @as(bytecode.Register, @intCast(index)), .name = name } });
        }
        self.release(mark);
    }

    fn compileFunctionDecl(self: *FunctionCompiler, decl: ast.FunctionDecl) anyerror!void {
        const mark = self.registerMark();
        const closure_reg = try self.allocReg();
        const child = try self.compileFunctionBody(decl.body, decl.name.method != null, functionDeclDebugName(decl.name));
        const child_index = try self.proto.addChild(child);
        self.current_line = decl.body.end_line;
        _ = try self.emit(.{ .closure = .{ .dest = closure_reg, .proto = child_index } });

        if (decl.name.fields.len == 0 and decl.name.method == null) {
            try self.assignName(decl.name.root.name, closure_reg);
        } else {
            var receiver = try self.allocReg();
            try self.loadName(decl.name.root.name, receiver);
            const prefix_len = if (decl.name.method != null) decl.name.fields.len else decl.name.fields.len - 1;
            for (decl.name.fields[0..prefix_len]) |field| {
                const next = try self.allocReg();
                const name = try self.nameConstant(field.name);
                _ = try self.emit(.{ .get_field = .{ .dest = next, .table = receiver, .name = name } });
                receiver = next;
            }
            const final_name = if (decl.name.method) |method| method.name else decl.name.fields[decl.name.fields.len - 1].name;
            const field = try self.nameConstant(final_name);
            _ = try self.emit(.{ .set_field = .{ .table = receiver, .name = field, .value = closure_reg } });
        }

        self.release(mark);
    }

    fn compileLocalFunctionDecl(self: *FunctionCompiler, decl: ast.LocalFunctionDecl) anyerror!void {
        const register = try self.declareLocal(decl.name.name);
        const child = try self.compileFunctionBody(decl.body, false, decl.name.name);
        const child_index = try self.proto.addChild(child);
        self.current_line = decl.body.end_line;
        _ = try self.emit(.{ .closure = .{ .dest = register, .proto = child_index } });
    }

    fn compileIf(self: *FunctionCompiler, stmt: ast.IfStmt) anyerror!void {
        var end_jumps = std.ArrayList(usize).empty;
        defer end_jumps.deinit(self.allocator);
        const end_line = ifEndLine(stmt);

        for (stmt.branches) |branch| {
            const mark = self.registerMark();
            const condition = try self.allocReg();
            try self.compileExpr(branch.condition, condition);
            const skip = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
            self.release(mark);

            try self.compileScopedBlock(branch.body);
            self.current_line = end_line;
            try end_jumps.append(self.allocator, try self.emit(.{ .jmp = 0 }));
            try self.proto.patchJump(skip, self.proto.pc());
        }

        if (stmt.else_block) |else_block| try self.compileScopedBlock(else_block);
        self.current_line = end_line;
        _ = try self.emit(.{ .jmp = 0 });
        for (end_jumps.items) |jump| try self.proto.patchJump(jump, self.proto.pc());
    }

    fn compileWhile(self: *FunctionCompiler, stmt: ast.WhileStmt) anyerror!void {
        const end_line = stmt.end_line;
        const loop_start = self.proto.pc();
        const mark = self.registerMark();
        const condition = try self.allocReg();
        try self.compileExpr(stmt.condition, condition);
        const done = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
        self.release(mark);

        try self.enterLoop();
        try self.compileScopedBlock(stmt.body);
        try self.leaveLoop(self.proto.pc() + 2);

        const back = try self.emit(.{ .jmp = 0 });
        try self.proto.patchJump(back, loop_start);
        const end_marker = self.proto.pc();
        self.current_line = end_line;
        _ = try self.emit(.{ .jmp = 0 });
        try self.proto.patchJump(done, end_marker);
    }

    fn compileRepeat(self: *FunctionCompiler, stmt: ast.RepeatStmt) anyerror!void {
        const loop_start = self.proto.pc();
        try self.enterLoop();
        try self.enterScope();
        try self.compileBlock(stmt.body);
        const mark = self.registerMark();
        const condition = try self.allocReg();
        try self.compileExpr(stmt.condition, condition);
        const scope = self.scopes.items[self.scopes.items.len - 1];
        _ = try self.emit(.{ .close = scope.next_register });
        const repeat_jump = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
        self.release(mark);
        try self.leaveScope();
        try self.proto.patchJump(repeat_jump, loop_start);
        try self.leaveLoop(self.proto.pc());
    }

    fn compileNumericFor(self: *FunctionCompiler, stmt: ast.NumericFor) anyerror!void {
        const loop_line = stmt.name.span.start.line;
        const end_line = stmt.end_line;
        try self.enterScope();
        const base = try self.allocReg();
        try self.compileExpr(stmt.start, base);
        const limit = try self.allocReg();
        try self.compileExpr(stmt.limit, limit);
        const step = try self.allocReg();
        if (stmt.step) |step_expr| {
            try self.compileExpr(step_expr, step);
        } else {
            const one = try self.proto.addConstant(.{ .integer = "1" });
            _ = try self.emit(.{ .load_const = .{ .dest = step, .constant = one } });
        }

        const debug_index = try self.proto.addLocal(.{ .name = stmt.name.name, .register = base, .start_pc = self.proto.pc() });
        try self.locals.append(self.allocator, .{ .name = stmt.name.name, .register = base, .debug_index = debug_index });

        const prep = try self.emit(.{ .for_prep = .{ .base = base, .offset = 0 } });
        const body_start = self.proto.pc();
        try self.enterLoop();
        try self.compileScopedBlock(stmt.body);
        _ = try self.emit(.{ .close = base });
        try self.leaveLoop(self.proto.pc() + 2);
        self.current_line = loop_line;
        const loop = try self.emit(.{ .for_loop = .{ .base = base, .offset = 0 } });
        try self.proto.patchJump(loop, body_start);
        const end_marker = self.proto.pc();
        self.current_line = end_line;
        _ = try self.emit(.{ .jmp = 0 });
        try self.proto.patchJump(prep, end_marker);
        try self.leaveScope();
    }

    fn compileGenericFor(self: *FunctionCompiler, stmt: ast.GenericFor) anyerror!void {
        const end_line = stmt.end_line;
        try self.enterScope();
        const base = self.registerMark();

        if (stmt.iterators.len == 1 and isCallExpr(stmt.iterators[0])) {
            const call_base = try self.allocReg();
            std.debug.assert(call_base == base);
            _ = try self.compileCallInto(stmt.iterators[0], 4, call_base, false);
            try self.reserveRegistersUntil(base + 4);
        } else {
            for (stmt.iterators) |iterator| {
                const reg = try self.allocReg();
                try self.compileExpr(iterator, reg);
            }
            while (self.next_register < base + 4) {
                const reg = try self.allocReg();
                _ = try self.emit(.{ .load_nil = reg });
            }
        }
        self.release(base + 4);

        const close_register = try self.declareLocalAt("(for state)", base + 3, true);
        _ = try self.emit(.{ .check_close = close_register });
        for (stmt.names) |name| _ = try self.declareLocal(name.name);

        const loop_start = self.proto.pc();
        const prep = try self.emit(.{ .tfor_prep = .{ .base = base, .variable_count = @intCast(stmt.names.len), .offset = 0 } });
        try self.enterLoop();
        try self.compileScopedBlock(stmt.body);
        if (stmt.names.len != 0) _ = try self.emit(.{ .close = base + 4 });
        try self.leaveLoop(self.proto.pc() + 2);
        self.current_line = 0;
        const loop = try self.emit(.{ .tfor_loop = .{ .base = base, .variable_count = @intCast(stmt.names.len), .offset = 0 } });
        try self.proto.patchJump(loop, loop_start);
        const end_marker = self.proto.pc();
        self.current_line = end_line;
        _ = try self.emit(.{ .jmp = 0 });
        try self.proto.patchJump(prep, end_marker);
        try self.leaveScope();
    }

    fn compileBreak(self: *FunctionCompiler) !void {
        if (self.loops.items.len == 0) return error.CompileError;
        _ = try self.emit(.{ .close = 0 });
        try self.breaks.append(self.allocator, try self.emit(.{ .jmp = 0 }));
    }

    fn compileGoto(self: *FunctionCompiler, name: ast.Identifier) !void {
        _ = try self.emit(.{ .close = 0 });
        const pc = try self.emit(.{ .jmp = 0 });
        var label_index = self.labels.items.len;
        while (label_index > 0) {
            label_index -= 1;
            const label = self.labels.items[label_index];
            if (label.scope_depth <= self.scopes.items.len and std.mem.eql(u8, label.name, name.name)) {
                try self.proto.patchJump(pc, label.pc);
                return;
            }
        }
        try self.gotos.append(self.allocator, .{ .name = name.name, .pc = pc, .scope_depth = self.scopes.items.len });
    }

    fn compileLabel(self: *FunctionCompiler, name: ast.Identifier) !void {
        const label: Label = .{ .name = name.name, .pc = self.proto.pc(), .scope_depth = self.scopes.items.len };
        try self.labels.append(self.allocator, label);
        var index: usize = 0;
        while (index < self.gotos.items.len) {
            if (self.gotos.items[index].scope_depth >= label.scope_depth and std.mem.eql(u8, self.gotos.items[index].name, name.name)) {
                try self.proto.patchJump(self.gotos.items[index].pc, self.proto.pc());
                _ = self.gotos.swapRemove(index);
            } else {
                index += 1;
            }
        }
    }

    fn compileReturn(self: *FunctionCompiler, stmt: ast.ReturnStmt) anyerror!void {
        const first = self.registerMark();
        if (stmt.values.len == 1 and isCallExpr(stmt.values[0]) and !self.hasActiveToCloseLocal()) {
            const base = try self.allocReg();
            _ = try self.compileCallInto(stmt.values[0], bytecode.multret_count, base, true);
            self.release(first);
            return;
        }
        const count = try self.compileExprListMultret(stmt.values, first);
        if (count != bytecode.multret_count and count > 254) return error.TooManyReturns;
        _ = try self.emit(.{ .ret = .{ .first = first, .count = count } });
        self.release(first);
    }

    fn compileExpr(self: *FunctionCompiler, expr: *const ast.Expr, dest: bytecode.Register) anyerror!void {
        self.current_line = exprLine(expr.*);
        switch (expr.*) {
            .nil => _ = try self.emit(.{ .load_nil = dest }),
            .boolean => |literal| _ = try self.emit(.{ .load_bool = .{ .dest = dest, .value = literal.value } }),
            .integer => |literal| _ = try self.emit(.{ .load_const = .{ .dest = dest, .constant = try self.proto.addConstant(.{ .integer = literal.lexeme }) } }),
            .float => |literal| _ = try self.emit(.{ .load_const = .{ .dest = dest, .constant = try self.proto.addConstant(.{ .number = literal.lexeme }) } }),
            .string => |literal| _ = try self.emit(.{ .load_const = .{ .dest = dest, .constant = try self.proto.addConstant(.{ .string = literal.lexeme }) } }),
            .vararg => try self.compileExprCount(expr, dest, 1),
            .identifier => |identifier| try self.loadName(identifier.name, dest),
            .table_constructor => |constructor| try self.compileTableConstructor(constructor, dest),
            .function_literal => |body| try self.compileFunctionLiteral(body, dest, null),
            .grouped => |inner| try self.compileExpr(inner, dest),
            .index => |index| {
                const mark = self.registerMark();
                const table = try self.allocReg();
                const key = try self.allocReg();
                try self.compileExpr(index.receiver, table);
                try self.compileExpr(index.key, key);
                _ = try self.emit(.{ .get_table = .{ .dest = dest, .table = table, .key = key } });
                self.release(mark);
            },
            .field => |field| {
                const mark = self.registerMark();
                const table = try self.allocReg();
                try self.compileExpr(field.receiver, table);
                _ = try self.emit(.{ .get_field = .{ .dest = dest, .table = table, .name = try self.nameConstant(field.name.name) } });
                self.release(mark);
            },
            .call, .method_call => {
                if (dest + 1 == self.registerMark()) {
                    _ = try self.compileCallInto(expr, 1, dest, false);
                } else {
                    const mark = self.registerMark();
                    const base = try self.allocReg();
                    _ = try self.compileCallInto(expr, 1, base, false);
                    _ = try self.emit(.{ .move = .{ .dest = dest, .source = base } });
                    self.release(mark);
                }
            },
            .unary => |unary| try self.compileUnary(unary, dest),
            .binary => |binary| try self.compileBinary(binary, dest),
        }
    }

    fn compileFunctionLiteral(self: *FunctionCompiler, body: ast.FunctionBody, dest: bytecode.Register, debug_name: ?[]const u8) !void {
        const child = try self.compileFunctionBody(body, false, debug_name);
        const child_index = try self.proto.addChild(child);
        self.current_line = body.end_line;
        _ = try self.emit(.{ .closure = .{ .dest = dest, .proto = child_index } });
    }

    fn compileTableConstructor(self: *FunctionCompiler, constructor: ast.TableConstructor, dest: bytecode.Register) anyerror!void {
        var array_count: u32 = 0;
        var hash_count: u32 = 0;
        for (constructor.fields) |field| switch (field) {
            .array => array_count += 1,
            .keyed, .named => hash_count += 1,
        };
        _ = try self.emit(.{ .new_table = .{ .dest = dest, .array_hint = array_count, .hash_hint = hash_count } });

        var array_index: u32 = 1;
        for (constructor.fields, 0..) |field, field_index| {
            const mark = self.registerMark();
            switch (field) {
                .array => |value| {
                    const value_reg = try self.allocReg();
                    if (field_index == constructor.fields.len - 1 and isMultiResultExpr(value)) {
                        try self.compileExprCount(value, value_reg, bytecode.multret_count);
                        _ = try self.emit(.{ .set_list = .{ .table = dest, .first = value_reg, .count = bytecode.multret_count, .start_index = array_index } });
                    } else {
                        const key = try self.allocReg();
                        const key_const = try self.proto.addConstant(.{ .integer = try std.fmt.allocPrint(self.proto.arena.allocator(), "{d}", .{array_index}) });
                        _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = key_const } });
                        try self.compileExpr(value, value_reg);
                        _ = try self.emit(.{ .set_table = .{ .table = dest, .key = key, .value = value_reg } });
                        array_index += 1;
                    }
                },
                .keyed => |keyed| {
                    const key = try self.allocReg();
                    const value = try self.allocReg();
                    try self.compileExpr(keyed.key, key);
                    try self.compileExpr(keyed.value, value);
                    _ = try self.emit(.{ .set_table = .{ .table = dest, .key = key, .value = value } });
                },
                .named => |named| {
                    const value = try self.allocReg();
                    if (named.value.* == .function_literal) {
                        try self.compileFunctionLiteral(named.value.function_literal, value, named.name.name);
                    } else {
                        try self.compileExpr(named.value, value);
                    }
                    _ = try self.emit(.{ .set_field = .{ .table = dest, .name = try self.nameConstant(named.name.name), .value = value } });
                },
            }
            self.release(mark);
        }
    }

    fn compileUnary(self: *FunctionCompiler, unary: ast.UnaryExpr, dest: bytecode.Register) anyerror!void {
        const mark = self.registerMark();
        const source = try self.allocReg();
        try self.compileExpr(unary.operand, source);
        const instruction: bytecode.Instruction = switch (unary.op) {
            .negate => .{ .unm = .{ .dest = dest, .source = source } },
            .not => .{ .not = .{ .dest = dest, .source = source } },
            .length => .{ .len = .{ .dest = dest, .source = source } },
            .bit_not => .{ .bnot = .{ .dest = dest, .source = source } },
        };
        _ = try self.emit(instruction);
        self.release(mark);
    }

    fn compileBinary(self: *FunctionCompiler, binary: ast.BinaryExpr, dest: bytecode.Register) anyerror!void {
        if (binary.op == .or_op or binary.op == .and_op) {
            try self.compileExpr(binary.left, dest);
            const skip = try self.emit(.{ .test_set = .{ .dest = dest, .source = dest, .jump_if_truthy = binary.op == .or_op, .offset = 0 } });
            try self.compileExpr(binary.right, dest);
            try self.proto.patchJump(skip, self.proto.pc());
            return;
        }

        const mark = self.registerMark();
        const left = try self.allocReg();
        const right = try self.allocReg();
        try self.compileExprForcedLine(binary.left, left, binary.op_line);
        try self.compileExpr(binary.right, right);
        const right_line = exprLine(binary.right.*);
        self.current_line = binary.op_line;
        if (binary.op == .ne) {
            _ = try self.emit(.{ .eq = .{ .dest = dest, .left = left, .right = right } });
            _ = try self.emit(.{ .not = .{ .dest = dest, .source = dest } });
        } else {
            _ = try self.emit(binaryInstruction(binary.op, dest, left, right));
        }
        self.current_line = right_line;
        self.release(mark);
    }

    fn compileExprForcedLine(self: *FunctionCompiler, expr: *const ast.Expr, dest: bytecode.Register, line: usize) anyerror!void {
        const previous = self.forced_line;
        self.forced_line = line;
        defer self.forced_line = previous;
        try self.compileExpr(expr, dest);
    }

    fn compileCallInto(self: *FunctionCompiler, expr: *const ast.Expr, returns: u16, dest: bytecode.Register, tail: bool) anyerror!bytecode.Register {
        switch (expr.*) {
            .call => |call| {
                try self.reserveRegistersUntil(dest + 1);
                try self.compileExpr(call.callee, dest);
                const arg_count = try self.compileCallArgs(call.args, dest + 1, 0);
                _ = try self.emit(if (tail) .{ .tail_call = .{ .base = dest, .arg_count = arg_count, .return_count = returns } } else .{ .call = .{ .base = dest, .arg_count = arg_count, .return_count = returns } });
                self.release(callReleaseMark(dest, returns));
                return dest;
            },
            .method_call => |call| {
                const receiver = dest + 1;
                try self.reserveRegistersUntil(dest + 2);
                try self.compileExpr(call.receiver, receiver);
                _ = try self.emit(.{ .get_field = .{ .dest = dest, .table = receiver, .name = try self.nameConstant(call.method.name) } });
                const arg_count = try self.compileCallArgs(call.args, dest + 2, 1);
                _ = try self.emit(if (tail) .{ .tail_call = .{ .base = dest, .arg_count = arg_count, .return_count = returns } } else .{ .call = .{ .base = dest, .arg_count = arg_count, .return_count = returns } });
                self.release(callReleaseMark(dest, returns));
                return dest;
            },
            else => return error.CompileError,
        }
    }

    fn compileExprListAdjusted(self: *FunctionCompiler, values: []const *ast.Expr, dest: bytecode.Register, needed: u16) anyerror!void {
        try self.reserveRegistersUntil(dest + needed);
        var value_index: usize = 0;
        var out_index: u16 = 0;
        while (out_index < needed) : (out_index += 1) {
            const out = dest + out_index;
            if (value_index >= values.len) {
                _ = try self.emit(.{ .load_nil = out });
                continue;
            }
            const remaining = needed - out_index;
            const value = values[value_index];
            if (value_index == values.len - 1 and isMultiResultExpr(value)) {
                try self.compileExprCount(value, out, remaining);
                out_index = needed;
                value_index += 1;
                break;
            }
            try self.compileExpr(value, out);
            value_index += 1;
        }

        while (value_index < values.len) : (value_index += 1) {
            try self.compileDiscardedExpr(values[value_index], dest + needed);
        }
    }

    fn compileExprListMultret(self: *FunctionCompiler, values: []const *ast.Expr, dest: bytecode.Register) anyerror!u16 {
        if (values.len == 0) return 0;
        for (values[0 .. values.len - 1], 0..) |value, index| {
            const out = dest + @as(bytecode.Register, @intCast(index));
            try self.reserveRegistersUntil(out + 1);
            try self.compileExpr(value, out);
        }

        const last = values[values.len - 1];
        const last_dest = dest + @as(bytecode.Register, @intCast(values.len - 1));
        if (isMultiResultExpr(last)) {
            try self.compileExprCount(last, last_dest, bytecode.multret_count);
            return bytecode.multret_count;
        }

        try self.reserveRegistersUntil(last_dest + 1);
        try self.compileExpr(last, last_dest);
        return @intCast(values.len);
    }

    fn compileExprCount(self: *FunctionCompiler, expr: *const ast.Expr, dest: bytecode.Register, count: u16) anyerror!void {
        switch (expr.*) {
            .call, .method_call => _ = try self.compileCallInto(expr, count, dest, false),
            .vararg => {
                if (count != bytecode.multret_count) try self.reserveRegistersUntil(dest + count) else try self.reserveRegistersUntil(dest + 1);
                _ = try self.emit(.{ .vararg = .{ .dest = dest, .count = count } });
                self.release(callReleaseMark(dest, count));
            },
            else => {
                if (count == 0) {
                    const mark = self.registerMark();
                    const scratch = try self.allocReg();
                    try self.compileExpr(expr, scratch);
                    self.release(mark);
                    return;
                }
                try self.reserveRegistersUntil(dest + count);
                try self.compileExpr(expr, dest);
                var index: u16 = 1;
                while (index < count) : (index += 1) _ = try self.emit(.{ .load_nil = dest + index });
            },
        }
    }

    fn compileDiscardedExpr(self: *FunctionCompiler, expr: *const ast.Expr, scratch: bytecode.Register) anyerror!void {
        if (isCallExpr(expr)) {
            _ = try self.compileCallInto(expr, 0, scratch, false);
        } else if (expr.* != .vararg) {
            try self.compileExprCount(expr, scratch, 0);
        }
    }

    fn compileCallArgs(self: *FunctionCompiler, args: []const *ast.Expr, first_arg: bytecode.Register, fixed_prefix: u16) anyerror!u16 {
        if (args.len == 0) return fixed_prefix;
        for (args[0 .. args.len - 1], 0..) |arg, index| {
            const reg = first_arg + @as(bytecode.Register, @intCast(index));
            try self.reserveRegistersUntil(reg + 1);
            try self.compileExpr(arg, reg);
        }

        const last = args[args.len - 1];
        const last_reg = first_arg + @as(bytecode.Register, @intCast(args.len - 1));
        if (isMultiResultExpr(last)) {
            try self.compileExprCount(last, last_reg, bytecode.multret_count);
            return bytecode.multret_count;
        }

        try self.reserveRegistersUntil(last_reg + 1);
        try self.compileExpr(last, last_reg);
        return fixed_prefix + @as(u16, @intCast(args.len));
    }

    fn assignTarget(self: *FunctionCompiler, target: *const ast.Expr, value_reg: bytecode.Register) anyerror!void {
        switch (target.*) {
            .identifier => |identifier| try self.assignName(identifier.name, value_reg),
            .field => |field| {
                const mark = self.registerMark();
                const table = try self.allocReg();
                try self.compileExpr(field.receiver, table);
                _ = try self.emit(.{ .set_field = .{ .table = table, .name = try self.nameConstant(field.name.name), .value = value_reg } });
                self.release(mark);
            },
            .index => |index| {
                const mark = self.registerMark();
                const table = try self.allocReg();
                const key = try self.allocReg();
                try self.compileExpr(index.receiver, table);
                try self.compileExpr(index.key, key);
                _ = try self.emit(.{ .set_table = .{ .table = table, .key = key, .value = value_reg } });
                self.release(mark);
            },
            else => return error.CompileError,
        }
    }

    fn prepareAssignmentTarget(self: *FunctionCompiler, target: *const ast.Expr) anyerror!PreparedTarget {
        return switch (target.*) {
            .identifier => |identifier| blk: {
                if (self.lookupLocal(identifier.name) == null) _ = try self.lookupUpvalue(identifier.name);
                break :blk .{ .expr = target };
            },
            .field => |field| blk: {
                const table = try self.allocReg();
                try self.compileExpr(field.receiver, table);
                break :blk .{ .field = .{ .table = table, .name = try self.nameConstant(field.name.name) } };
            },
            .index => |index| blk: {
                const table = try self.allocReg();
                const key = try self.allocReg();
                try self.compileExpr(index.receiver, table);
                try self.compileExpr(index.key, key);
                break :blk .{ .index = .{ .table = table, .key = key } };
            },
            else => error.CompileError,
        };
    }

    fn assignPreparedTarget(self: *FunctionCompiler, target: PreparedTarget, value_reg: bytecode.Register) anyerror!void {
        switch (target) {
            .expr => |expr| try self.assignTarget(expr, value_reg),
            .field => |field| _ = try self.emit(.{ .set_field = .{ .table = field.table, .name = field.name, .value = value_reg } }),
            .index => |index| _ = try self.emit(.{ .set_table = .{ .table = index.table, .key = index.key, .value = value_reg } }),
        }
    }

    fn loadName(self: *FunctionCompiler, name: []const u8, dest: bytecode.Register) !void {
        if (self.lookupLocal(name)) |local| {
            _ = try self.emit(.{ .move = .{ .dest = dest, .source = local.register } });
        } else if (try self.lookupUpvalue(name)) |upvalue| {
            _ = try self.emit(.{ .get_upvalue = .{ .register = dest, .upvalue = upvalue } });
        } else if (!std.mem.eql(u8, name, "_ENV") and try self.loadFromEnvironment(name, dest)) {
            return;
        } else {
            _ = try self.emit(.{ .get_global = .{ .register = dest, .name = try self.nameConstant(name) } });
        }
    }

    fn assignName(self: *FunctionCompiler, name: []const u8, value_reg: bytecode.Register) !void {
        if (self.lookupLocal(name)) |local| {
            _ = try self.emit(.{ .move = .{ .dest = local.register, .source = value_reg } });
        } else if (try self.lookupUpvalue(name)) |upvalue| {
            _ = try self.emit(.{ .set_upvalue = .{ .register = value_reg, .upvalue = upvalue } });
        } else if (!std.mem.eql(u8, name, "_ENV") and try self.storeInEnvironment(name, value_reg)) {
            return;
        } else {
            _ = try self.emit(.{ .set_global = .{ .register = value_reg, .name = try self.nameConstant(name) } });
        }
    }

    fn loadFromEnvironment(self: *FunctionCompiler, name: []const u8, dest: bytecode.Register) !bool {
        const mark = self.registerMark();
        const key = try self.allocReg();
        if (self.lookupLocal("_ENV")) |local| {
            _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = try self.nameConstant(name) } });
            _ = try self.emit(.{ .get_table = .{ .dest = dest, .table = local.register, .key = key } });
            self.release(mark);
            return true;
        }
        if (try self.lookupUpvalue("_ENV")) |upvalue| {
            const env = try self.allocReg();
            _ = try self.emit(.{ .get_upvalue = .{ .register = env, .upvalue = upvalue } });
            _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = try self.nameConstant(name) } });
            _ = try self.emit(.{ .get_table = .{ .dest = dest, .table = env, .key = key } });
            self.release(mark);
            return true;
        }
        self.release(mark);
        return false;
    }

    fn storeInEnvironment(self: *FunctionCompiler, name: []const u8, value_reg: bytecode.Register) !bool {
        const mark = self.registerMark();
        const key = try self.allocReg();
        if (self.lookupLocal("_ENV")) |local| {
            _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = try self.nameConstant(name) } });
            _ = try self.emit(.{ .set_table = .{ .table = local.register, .key = key, .value = value_reg } });
            self.release(mark);
            return true;
        }
        if (try self.lookupUpvalue("_ENV")) |upvalue| {
            const env = try self.allocReg();
            _ = try self.emit(.{ .get_upvalue = .{ .register = env, .upvalue = upvalue } });
            _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = try self.nameConstant(name) } });
            _ = try self.emit(.{ .set_table = .{ .table = env, .key = key, .value = value_reg } });
            self.release(mark);
            return true;
        }
        self.release(mark);
        return false;
    }

    fn lookupLocal(self: *FunctionCompiler, name: []const u8) ?Local {
        const index = self.lookupLocalIndex(name) orelse return null;
        return self.locals.items[index];
    }

    fn lookupLocalIndex(self: *FunctionCompiler, name: []const u8) ?usize {
        var index = self.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = self.locals.items[index];
            if (std.mem.eql(u8, local.name, name)) return index;
        }
        return null;
    }

    fn hasActiveToCloseLocal(self: FunctionCompiler) bool {
        for (self.locals.items) |local| {
            if (local.to_close) return true;
        }
        return false;
    }

    fn lookupUpvalue(self: *FunctionCompiler, name: []const u8) !?bytecode.UpvalueIndex {
        if (self.parent) |parent| {
            if (parent.lookupLocalIndex(name)) |local_index| {
                parent.locals.items[local_index].captured = true;
                const local = parent.locals.items[local_index];
                return try self.proto.addUpvalue(.{ .name = name, .in_stack = true, .index = local.register });
            }
            if (try parent.lookupUpvalue(name)) |parent_upvalue| {
                return try self.proto.addUpvalue(.{ .name = name, .in_stack = false, .index = parent_upvalue });
            }
        }
        return null;
    }

    fn enterScope(self: *FunctionCompiler) !void {
        try self.scopes.append(self.allocator, .{ .local_start = self.locals.items.len, .label_start = self.labels.items.len, .next_register = self.next_register });
    }

    fn leaveScope(self: *FunctionCompiler) !void {
        const scope = self.scopes.items[self.scopes.items.len - 1];
        var has_captured = false;
        for (self.locals.items[scope.local_start..]) |local| {
            has_captured = has_captured or local.captured;
            self.proto.locals.items[local.debug_index].end_pc = self.proto.pc();
        }
        var index = self.locals.items.len;
        while (index > scope.local_start) {
            index -= 1;
            const local = self.locals.items[index];
            if (local.to_close) _ = try self.emit(.{ .close_tbc = local.register });
        }
        if (has_captured) _ = try self.emit(.{ .close = scope.next_register });
        self.locals.items.len = scope.local_start;
        self.labels.items.len = scope.label_start;
        self.next_register = scope.next_register;
        self.scopes.items.len -= 1;
    }

    fn declareLocal(self: *FunctionCompiler, name: []const u8) !bytecode.Register {
        const register = try self.allocReg();
        return self.declareLocalAt(name, register, false);
    }

    fn declareLocalAt(self: *FunctionCompiler, name: []const u8, register: bytecode.Register, to_close: bool) !bytecode.Register {
        const debug_index = try self.proto.addLocal(.{ .name = name, .register = register, .start_pc = self.proto.pc() });
        self.proto.locals.items[debug_index].to_close = to_close;
        try self.locals.append(self.allocator, .{ .name = name, .register = register, .debug_index = debug_index, .to_close = to_close });
        return register;
    }

    fn enterLoop(self: *FunctionCompiler) !void {
        try self.loops.append(self.allocator, .{ .break_start = self.breaks.items.len });
    }

    fn leaveLoop(self: *FunctionCompiler, target_pc: usize) !void {
        const loop = self.loops.items[self.loops.items.len - 1];
        for (self.breaks.items[loop.break_start..]) |break_pc| try self.proto.patchJump(break_pc, target_pc);
        self.breaks.items.len = loop.break_start;
        self.loops.items.len -= 1;
    }

    fn patchPendingGotos(self: *FunctionCompiler) !void {
        for (self.gotos.items) |pending| {
            for (self.labels.items) |label| {
                if (std.mem.eql(u8, label.name, pending.name)) {
                    try self.proto.patchJump(pending.pc, label.pc);
                    break;
                }
            } else return error.CompileError;
        }
        self.gotos.items.len = 0;
    }

    fn allocReg(self: *FunctionCompiler) !bytecode.Register {
        if (self.next_register == std.math.maxInt(bytecode.Register)) return error.RegisterOverflow;
        const register = self.next_register;
        self.next_register += 1;
        self.proto.max_registers = @max(self.proto.max_registers, self.next_register);
        return register;
    }

    fn allocRegs(self: *FunctionCompiler, count: u16) !bytecode.Register {
        const first = self.next_register;
        var index: u16 = 0;
        while (index < count) : (index += 1) _ = try self.allocReg();
        return first;
    }

    fn registerMark(self: FunctionCompiler) bytecode.Register {
        return self.next_register;
    }

    fn release(self: *FunctionCompiler, mark_register: bytecode.Register) void {
        self.next_register = mark_register;
    }

    fn reserveRegistersUntil(self: *FunctionCompiler, end_register: bytecode.Register) !void {
        while (self.next_register < end_register) _ = try self.allocReg();
    }

    fn emit(self: *FunctionCompiler, instruction: bytecode.Instruction) !usize {
        return self.proto.emit(instruction, self.forced_line orelse self.current_line);
    }

    fn nameConstant(self: *FunctionCompiler, name: []const u8) !bytecode.ConstantIndex {
        return self.proto.addConstant(.{ .string = name });
    }
};

fn binaryInstruction(op: ast.BinaryOp, dest: bytecode.Register, left: bytecode.Register, right: bytecode.Register) bytecode.Instruction {
    const binary: bytecode.Binary = .{ .dest = dest, .left = left, .right = right };
    return switch (op) {
        .or_op, .and_op => unreachable,
        .eq => .{ .eq = binary },
        .ne => unreachable,
        .lt => .{ .lt = binary },
        .le => .{ .le = binary },
        .gt => .{ .lt = .{ .dest = dest, .left = right, .right = left } },
        .ge => .{ .le = .{ .dest = dest, .left = right, .right = left } },
        .bit_or => .{ .bor = binary },
        .bit_xor => .{ .bxor = binary },
        .bit_and => .{ .band = binary },
        .shift_left => .{ .shl = binary },
        .shift_right => .{ .shr = binary },
        .concat => .{ .concat = binary },
        .add => .{ .add = binary },
        .sub => .{ .sub = binary },
        .mul => .{ .mul = binary },
        .div => .{ .div = binary },
        .idiv => .{ .idiv = binary },
        .mod => .{ .mod = binary },
        .pow => .{ .pow = binary },
    };
}

fn blockEndsWithReturn(block: ast.Block) bool {
    if (block.len == 0) return false;
    return block[block.len - 1] == .return_stmt;
}

fn isCallExpr(expr: *const ast.Expr) bool {
    return switch (expr.*) {
        .call, .method_call => true,
        else => false,
    };
}

fn isMultiResultExpr(expr: *const ast.Expr) bool {
    return switch (expr.*) {
        .call, .method_call, .vararg => true,
        else => false,
    };
}

fn isCloseAttribute(attribute: ?ast.Identifier) bool {
    return if (attribute) |attr| std.mem.eql(u8, attr.name, "close") else false;
}

fn functionDeclDebugName(name: ast.FunctionName) []const u8 {
    if (name.method) |method| return method.name;
    if (name.fields.len != 0) return name.fields[name.fields.len - 1].name;
    return name.root.name;
}

fn assignmentTargetDebugName(target: *const ast.Expr) ?[]const u8 {
    return switch (target.*) {
        .identifier => |identifier| identifier.name,
        .field => |field| field.name.name,
        else => null,
    };
}

fn callReleaseMark(dest: bytecode.Register, count: u16) bytecode.Register {
    return if (count == bytecode.multret_count) dest + 1 else dest + count;
}

fn stmtLine(statement: ast.Stmt) usize {
    return switch (statement) {
        .empty => |span| span.start.line,
        .assignment => |assignment| if (assignment.targets.len > 0) exprLine(assignment.targets[0].*) else 1,
        .local_decl => |decl| if (decl.bindings.len > 0) decl.bindings[0].name.span.start.line else 1,
        .global_decl => |decl| if (decl.names.len > 0) decl.names[0].name.span.start.line else if (decl.attribute) |attr| attr.span.start.line else 1,
        .function_decl => |decl| decl.name.root.span.start.line,
        .local_function_decl => |decl| decl.name.span.start.line,
        .if_stmt => |stmt| if (stmt.branches.len > 0) exprLine(stmt.branches[0].condition.*) else 1,
        .while_stmt => |stmt| exprLine(stmt.condition.*),
        .repeat_stmt => |stmt| exprLine(stmt.condition.*),
        .numeric_for => |stmt| stmt.name.span.start.line,
        .generic_for => |stmt| if (stmt.names.len > 0) stmt.names[0].span.start.line else 1,
        .break_stmt => |span| span.start.line,
        .goto_stmt => |name| name.span.start.line,
        .label_stmt => |name| name.span.start.line,
        .do_block => |block| if (block.len > 0) stmtLine(block[0]) else 1,
        .return_stmt => |stmt| if (stmt.values.len > 0) exprLine(stmt.values[0].*) else stmt.line,
        .call_stmt => |call| exprLine(call.*),
    };
}

fn ifEndLine(stmt: ast.IfStmt) usize {
    var last_line: usize = if (stmt.branches.len > 0) exprLine(stmt.branches[0].condition.*) else 1;
    for (stmt.branches) |branch| {
        last_line = @max(last_line, exprLine(branch.condition.*));
        last_line = @max(last_line, blockLastLine(branch.body));
    }
    if (stmt.else_block) |else_block| last_line = @max(last_line, blockLastLine(else_block));
    return last_line + 1;
}

fn blockLastLine(block: ast.Block) usize {
    if (block.len == 0) return 1;
    var last_line: usize = 1;
    for (block) |statement| last_line = @max(last_line, stmtApproxEndLine(statement));
    return last_line;
}

fn stmtApproxEndLine(statement: ast.Stmt) usize {
    return switch (statement) {
        .if_stmt => |stmt| ifEndLine(stmt),
        .while_stmt => |stmt| stmt.end_line,
        .repeat_stmt => |stmt| @max(blockLastLine(stmt.body), exprLine(stmt.condition.*)),
        .numeric_for => |stmt| stmt.end_line,
        .generic_for => |stmt| stmt.end_line,
        .function_decl => |decl| decl.body.end_line,
        .local_function_decl => |decl| decl.body.end_line,
        .do_block => |block| blockLastLine(block) + 1,
        else => stmtLine(statement),
    };
}

fn exprLine(expr: ast.Expr) usize {
    return switch (expr) {
        .nil => |span| span.start.line,
        .boolean => |literal| literal.span.start.line,
        .integer => |literal| literal.span.start.line,
        .float => |literal| literal.span.start.line,
        .string => |literal| literal.span.start.line,
        .vararg => |span| span.start.line,
        .identifier => |identifier| identifier.span.start.line,
        .table_constructor => 1,
        .function_literal => |body| body.end_line,
        .grouped => |inner| exprLine(inner.*),
        .index => |index| exprLine(index.receiver.*),
        .field => |field| exprLine(field.receiver.*),
        .call => |call| exprLine(call.callee.*),
        .method_call => |call| exprLine(call.receiver.*),
        .unary => |unary| exprLine(unary.operand.*),
        .binary => |binary| binary.op_line,
    };
}

test "compiles a simple chunk" {
    var tree = try frontend.parse(std.testing.allocator,
        \\local x = 1 + 2
        \\return x
    );
    defer tree.deinit();

    var proto = try compile(std.testing.allocator, &tree);
    defer proto.deinit();

    try std.testing.expect(proto.instructions.items.len > 0);
    try std.testing.expect(proto.constants.items.len >= 2);
    try std.testing.expect(proto.max_registers > 0);
}

test "compiles nested function with upvalue descriptor" {
    var tree = try frontend.parse(std.testing.allocator,
        \\local x = 1
        \\local function f() return x end
    );
    defer tree.deinit();

    var proto = try compile(std.testing.allocator, &tree);
    defer proto.deinit();

    try std.testing.expectEqual(@as(usize, 1), proto.children.items.len);
    try std.testing.expectEqual(@as(usize, 1), proto.children.items[0].upvalues.items.len);
}
