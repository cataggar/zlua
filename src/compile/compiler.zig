const std = @import("std");
const frontend = @import("../frontend.zig");
const ast = frontend.ast;
const bytecode = @import("bytecode.zig");
const proto_mod = @import("proto.zig");

pub const CompileError = error{
    CompileError,
    RegisterOverflow,
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
};

const PendingLocal = struct {
    name: []const u8,
    register: bytecode.Register,
    debug_index: usize,
};

const Scope = struct {
    local_start: usize,
    next_register: bytecode.Register,
};

const Label = struct {
    name: []const u8,
    pc: usize,
};

const PendingGoto = struct {
    name: []const u8,
    pc: usize,
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
        try self.enterScope();
        try self.compileBlock(block);
        if (!blockEndsWithReturn(block)) {
            _ = try self.emit(.{ .ret = .{ .first = 0, .count = 0 } });
        }
        try self.patchPendingGotos();
        try self.leaveScope();
    }

    fn compileFunctionBody(self: *FunctionCompiler, body: ast.FunctionBody, method: bool) !*proto_mod.Proto {
        const child = try self.allocator.create(proto_mod.Proto);
        errdefer self.allocator.destroy(child);
        child.* = proto_mod.Proto.init(self.allocator);
        errdefer child.deinit();

        var child_context = FunctionCompiler.init(self.allocator, child, self);
        errdefer child_context.deinit();
        try child_context.enterScope();
        if (method) _ = try child_context.declareLocal("self");
        for (body.params) |param| _ = try child_context.declareLocal(param.name);
        if (body.is_vararg) {
            const name = if (body.vararg_name) |vararg_name| vararg_name.name else "...";
            _ = try child_context.declareLocal(name);
        }
        try child_context.compileBlock(body.body);
        if (!blockEndsWithReturn(body.body)) {
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
                _ = try self.compileCallInto(call, 0, base);
                self.release(mark);
            },
        }
    }

    fn compileAssignment(self: *FunctionCompiler, assignment: ast.Assignment) anyerror!void {
        const mark = self.registerMark();
        var values = std.ArrayList(bytecode.Register).empty;
        defer values.deinit(self.allocator);

        for (assignment.values) |value| {
            const reg = try self.allocReg();
            try self.compileExpr(value, reg);
            try values.append(self.allocator, reg);
        }

        for (assignment.targets, 0..) |target, index| {
            const value_reg = if (index < values.items.len) values.items[index] else blk: {
                const nil_reg = try self.allocReg();
                _ = try self.emit(.{ .load_nil = nil_reg });
                break :blk nil_reg;
            };
            try self.assignTarget(target, value_reg);
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
            });
            try pending.append(self.allocator, .{ .name = binding.name.name, .register = register, .debug_index = debug_index });
        }

        for (pending.items, 0..) |local, index| {
            if (index < decl.values.len) {
                try self.compileExpr(decl.values[index], local.register);
            } else {
                _ = try self.emit(.{ .load_nil = local.register });
            }
        }

        if (decl.values.len > pending.items.len) {
            const mark = self.registerMark();
            for (decl.values[pending.items.len..]) |value| {
                const reg = try self.allocReg();
                try self.compileExpr(value, reg);
            }
            self.release(mark);
        }

        for (pending.items) |local| try self.locals.append(self.allocator, .{
            .name = local.name,
            .register = local.register,
            .debug_index = local.debug_index,
        });
    }

    fn compileGlobalDecl(self: *FunctionCompiler, decl: ast.GlobalDecl) anyerror!void {
        if (decl.values.len == 0) return;
        const mark = self.registerMark();
        var values = std.ArrayList(bytecode.Register).empty;
        defer values.deinit(self.allocator);

        for (decl.values) |value| {
            const reg = try self.allocReg();
            try self.compileExpr(value, reg);
            try values.append(self.allocator, reg);
        }

        for (decl.names, 0..) |binding, index| {
            if (index >= values.items.len) break;
            const name = try self.nameConstant(binding.name.name);
            _ = try self.emit(.{ .set_global = .{ .register = values.items[index], .name = name } });
        }
        self.release(mark);
    }

    fn compileFunctionDecl(self: *FunctionCompiler, decl: ast.FunctionDecl) anyerror!void {
        const mark = self.registerMark();
        const closure_reg = try self.allocReg();
        const child = try self.compileFunctionBody(decl.body, decl.name.method != null);
        const child_index = try self.proto.addChild(child);
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
        const child = try self.compileFunctionBody(decl.body, false);
        const child_index = try self.proto.addChild(child);
        _ = try self.emit(.{ .closure = .{ .dest = register, .proto = child_index } });
    }

    fn compileIf(self: *FunctionCompiler, stmt: ast.IfStmt) anyerror!void {
        var end_jumps = std.ArrayList(usize).empty;
        defer end_jumps.deinit(self.allocator);

        for (stmt.branches) |branch| {
            const mark = self.registerMark();
            const condition = try self.allocReg();
            try self.compileExpr(branch.condition, condition);
            const skip = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
            self.release(mark);

            try self.compileScopedBlock(branch.body);
            try end_jumps.append(self.allocator, try self.emit(.{ .jmp = 0 }));
            try self.proto.patchJump(skip, self.proto.pc());
        }

        if (stmt.else_block) |else_block| try self.compileScopedBlock(else_block);
        for (end_jumps.items) |jump| try self.proto.patchJump(jump, self.proto.pc());
    }

    fn compileWhile(self: *FunctionCompiler, stmt: ast.WhileStmt) anyerror!void {
        const loop_start = self.proto.pc();
        const mark = self.registerMark();
        const condition = try self.allocReg();
        try self.compileExpr(stmt.condition, condition);
        const done = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
        self.release(mark);

        try self.enterLoop();
        try self.compileScopedBlock(stmt.body);
        try self.leaveLoop(self.proto.pc() + 1);

        const back = try self.emit(.{ .jmp = 0 });
        try self.proto.patchJump(back, loop_start);
        try self.proto.patchJump(done, self.proto.pc());
    }

    fn compileRepeat(self: *FunctionCompiler, stmt: ast.RepeatStmt) anyerror!void {
        const loop_start = self.proto.pc();
        try self.enterLoop();
        try self.enterScope();
        try self.compileBlock(stmt.body);
        const mark = self.registerMark();
        const condition = try self.allocReg();
        try self.compileExpr(stmt.condition, condition);
        const repeat_jump = try self.emit(.{ .test_op = .{ .register = condition, .jump_if_truthy = false, .offset = 0 } });
        self.release(mark);
        try self.leaveScope();
        try self.proto.patchJump(repeat_jump, loop_start);
        try self.leaveLoop(self.proto.pc());
    }

    fn compileNumericFor(self: *FunctionCompiler, stmt: ast.NumericFor) anyerror!void {
        try self.enterScope();
        const base = try self.declareLocal(stmt.name.name);
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

        const prep = try self.emit(.{ .for_prep = .{ .base = base, .offset = 0 } });
        const body_start = self.proto.pc();
        try self.enterLoop();
        try self.compileBlock(stmt.body);
        try self.leaveLoop(self.proto.pc() + 1);
        const loop = try self.emit(.{ .for_loop = .{ .base = base, .offset = 0 } });
        try self.proto.patchJump(loop, body_start);
        try self.proto.patchJump(prep, self.proto.pc());
        try self.leaveScope();
    }

    fn compileGenericFor(self: *FunctionCompiler, stmt: ast.GenericFor) anyerror!void {
        try self.enterScope();
        const base = self.registerMark();

        if (stmt.iterators.len == 1 and isCallExpr(stmt.iterators[0])) {
            const call_base = try self.allocReg();
            std.debug.assert(call_base == base);
            _ = try self.compileCallInto(stmt.iterators[0], 3, call_base);
            try self.reserveRegistersUntil(base + 3);
        } else {
            for (stmt.iterators) |iterator| {
                const reg = try self.allocReg();
                try self.compileExpr(iterator, reg);
            }
            while (self.next_register < base + 3) {
                const reg = try self.allocReg();
                _ = try self.emit(.{ .load_nil = reg });
            }
        }
        self.release(base + 3);

        for (stmt.names) |name| _ = try self.declareLocal(name.name);

        const loop_start = self.proto.pc();
        const prep = try self.emit(.{ .tfor_prep = .{ .base = base, .variable_count = @intCast(stmt.names.len), .offset = 0 } });
        try self.enterLoop();
        try self.compileBlock(stmt.body);
        try self.leaveLoop(self.proto.pc() + 1);
        const loop = try self.emit(.{ .tfor_loop = .{ .base = base, .variable_count = @intCast(stmt.names.len), .offset = 0 } });
        try self.proto.patchJump(loop, loop_start);
        try self.proto.patchJump(prep, self.proto.pc());
        try self.leaveScope();
    }

    fn compileBreak(self: *FunctionCompiler) !void {
        if (self.loops.items.len == 0) return error.CompileError;
        try self.breaks.append(self.allocator, try self.emit(.{ .jmp = 0 }));
    }

    fn compileGoto(self: *FunctionCompiler, name: ast.Identifier) !void {
        const pc = try self.emit(.{ .jmp = 0 });
        try self.gotos.append(self.allocator, .{ .name = name.name, .pc = pc });
    }

    fn compileLabel(self: *FunctionCompiler, name: ast.Identifier) !void {
        try self.labels.append(self.allocator, .{ .name = name.name, .pc = self.proto.pc() });
        var index: usize = 0;
        while (index < self.gotos.items.len) {
            if (std.mem.eql(u8, self.gotos.items[index].name, name.name)) {
                try self.proto.patchJump(self.gotos.items[index].pc, self.proto.pc());
                _ = self.gotos.swapRemove(index);
            } else {
                index += 1;
            }
        }
    }

    fn compileReturn(self: *FunctionCompiler, stmt: ast.ReturnStmt) anyerror!void {
        const first = self.registerMark();
        for (stmt.values) |value| {
            const reg = try self.allocReg();
            try self.compileExpr(value, reg);
        }
        _ = try self.emit(.{ .ret = .{ .first = first, .count = @intCast(stmt.values.len) } });
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
            .vararg => _ = try self.emit(.{ .vararg = .{ .dest = dest, .count = 1 } }),
            .identifier => |identifier| try self.loadName(identifier.name, dest),
            .table_constructor => |constructor| try self.compileTableConstructor(constructor, dest),
            .function_literal => |body| {
                const child = try self.compileFunctionBody(body, false);
                const child_index = try self.proto.addChild(child);
                _ = try self.emit(.{ .closure = .{ .dest = dest, .proto = child_index } });
            },
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
            .call, .method_call => _ = try self.compileCallInto(expr, 1, dest),
            .unary => |unary| try self.compileUnary(unary, dest),
            .binary => |binary| try self.compileBinary(binary, dest),
        }
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
        for (constructor.fields) |field| {
            const mark = self.registerMark();
            switch (field) {
                .array => |value| {
                    const key = try self.allocReg();
                    const key_const = try self.proto.addConstant(.{ .integer = try std.fmt.allocPrint(self.proto.arena.allocator(), "{d}", .{array_index}) });
                    _ = try self.emit(.{ .load_const = .{ .dest = key, .constant = key_const } });
                    const value_reg = try self.allocReg();
                    try self.compileExpr(value, value_reg);
                    _ = try self.emit(.{ .set_table = .{ .table = dest, .key = key, .value = value_reg } });
                    array_index += 1;
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
                    try self.compileExpr(named.value, value);
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
        try self.compileExpr(binary.left, left);
        try self.compileExpr(binary.right, right);
        if (binary.op == .ne) {
            _ = try self.emit(.{ .eq = .{ .dest = dest, .left = left, .right = right } });
            _ = try self.emit(.{ .not = .{ .dest = dest, .source = dest } });
        } else {
            _ = try self.emit(binaryInstruction(binary.op, dest, left, right));
        }
        self.release(mark);
    }

    fn compileCallInto(self: *FunctionCompiler, expr: *const ast.Expr, returns: u16, dest: bytecode.Register) anyerror!bytecode.Register {
        switch (expr.*) {
            .call => |call| {
                try self.compileExpr(call.callee, dest);
                for (call.args) |arg| {
                    const reg = try self.allocReg();
                    try self.compileExpr(arg, reg);
                    self.release(reg + 1);
                }
                _ = try self.emit(.{ .call = .{ .base = dest, .arg_count = @intCast(call.args.len), .return_count = returns } });
                return dest;
            },
            .method_call => |call| {
                const receiver = try self.allocReg();
                try self.compileExpr(call.receiver, receiver);
                _ = try self.emit(.{ .get_field = .{ .dest = dest, .table = receiver, .name = try self.nameConstant(call.method.name) } });
                for (call.args) |arg| {
                    const reg = try self.allocReg();
                    try self.compileExpr(arg, reg);
                    self.release(reg + 1);
                }
                _ = try self.emit(.{ .call = .{ .base = dest, .arg_count = @intCast(call.args.len + 1), .return_count = returns } });
                return dest;
            },
            else => return error.CompileError,
        }
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

    fn loadName(self: *FunctionCompiler, name: []const u8, dest: bytecode.Register) !void {
        if (self.lookupLocal(name)) |local| {
            _ = try self.emit(.{ .move = .{ .dest = dest, .source = local.register } });
        } else if (try self.lookupUpvalue(name)) |upvalue| {
            _ = try self.emit(.{ .get_upvalue = .{ .register = dest, .upvalue = upvalue } });
        } else {
            _ = try self.emit(.{ .get_global = .{ .register = dest, .name = try self.nameConstant(name) } });
        }
    }

    fn assignName(self: *FunctionCompiler, name: []const u8, value_reg: bytecode.Register) !void {
        if (self.lookupLocal(name)) |local| {
            _ = try self.emit(.{ .move = .{ .dest = local.register, .source = value_reg } });
        } else if (try self.lookupUpvalue(name)) |upvalue| {
            _ = try self.emit(.{ .set_upvalue = .{ .register = value_reg, .upvalue = upvalue } });
        } else {
            _ = try self.emit(.{ .set_global = .{ .register = value_reg, .name = try self.nameConstant(name) } });
        }
    }

    fn lookupLocal(self: *FunctionCompiler, name: []const u8) ?Local {
        var index = self.locals.items.len;
        while (index > 0) {
            index -= 1;
            const local = self.locals.items[index];
            if (std.mem.eql(u8, local.name, name)) return local;
        }
        return null;
    }

    fn lookupUpvalue(self: *FunctionCompiler, name: []const u8) !?bytecode.UpvalueIndex {
        if (self.parent) |parent| {
            if (parent.lookupLocal(name)) |local| {
                return try self.proto.addUpvalue(.{ .name = name, .in_stack = true, .index = local.register });
            }
            if (try parent.lookupUpvalue(name)) |parent_upvalue| {
                return try self.proto.addUpvalue(.{ .name = name, .in_stack = false, .index = parent_upvalue });
            }
        }
        return null;
    }

    fn enterScope(self: *FunctionCompiler) !void {
        try self.scopes.append(self.allocator, .{ .local_start = self.locals.items.len, .next_register = self.next_register });
    }

    fn leaveScope(self: *FunctionCompiler) !void {
        const scope = self.scopes.items[self.scopes.items.len - 1];
        for (self.locals.items[scope.local_start..]) |local| {
            self.proto.locals.items[local.debug_index].end_pc = self.proto.pc();
        }
        self.locals.items.len = scope.local_start;
        self.next_register = scope.next_register;
        self.scopes.items.len -= 1;
    }

    fn declareLocal(self: *FunctionCompiler, name: []const u8) !bytecode.Register {
        const register = try self.allocReg();
        const debug_index = try self.proto.addLocal(.{ .name = name, .register = register, .start_pc = self.proto.pc() });
        try self.locals.append(self.allocator, .{ .name = name, .register = register, .debug_index = debug_index });
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
        return self.proto.emit(instruction, self.current_line);
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
        .return_stmt => |stmt| if (stmt.values.len > 0) exprLine(stmt.values[0].*) else 1,
        .call_stmt => |call| exprLine(call.*),
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
        .function_literal => 1,
        .grouped => |inner| exprLine(inner.*),
        .index => |index| exprLine(index.receiver.*),
        .field => |field| exprLine(field.receiver.*),
        .call => |call| exprLine(call.callee.*),
        .method_call => |call| exprLine(call.receiver.*),
        .unary => |unary| exprLine(unary.operand.*),
        .binary => |binary| exprLine(binary.left.*),
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
