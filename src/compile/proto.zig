const std = @import("std");
const bytecode = @import("bytecode.zig");

pub const LineInfo = struct {
    line: usize,
};

pub const LocalDebug = struct {
    name: []const u8,
    register: bytecode.Register,
    start_pc: usize,
    end_pc: usize = 0,
};

pub const UpvalueDesc = struct {
    name: []const u8,
    in_stack: bool,
    index: u16,
};

pub const Proto = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    constants: std.ArrayList(bytecode.Constant) = .empty,
    instructions: std.ArrayList(bytecode.Instruction) = .empty,
    line_info: std.ArrayList(LineInfo) = .empty,
    locals: std.ArrayList(LocalDebug) = .empty,
    upvalues: std.ArrayList(UpvalueDesc) = .empty,
    children: std.ArrayList(*Proto) = .empty,
    max_registers: u16 = 0,
    param_count: u16 = 0,
    is_vararg: bool = false,

    pub fn init(allocator: std.mem.Allocator) Proto {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Proto) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
        self.upvalues.deinit(self.allocator);
        self.locals.deinit(self.allocator);
        self.line_info.deinit(self.allocator);
        self.instructions.deinit(self.allocator);
        self.constants.deinit(self.allocator);
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn pc(self: Proto) usize {
        return self.instructions.items.len;
    }

    pub fn emit(self: *Proto, instruction: bytecode.Instruction, line: usize) !usize {
        const index = self.instructions.items.len;
        try self.instructions.append(self.allocator, instruction);
        try self.line_info.append(self.allocator, .{ .line = line });
        return index;
    }

    pub fn patchJump(self: *Proto, index: usize, target_pc: usize) !void {
        const offset = try jumpOffset(index, target_pc);
        switch (self.instructions.items[index]) {
            .jmp => self.instructions.items[index].jmp = offset,
            .test_op => self.instructions.items[index].test_op.offset = offset,
            .test_set => self.instructions.items[index].test_set.offset = offset,
            .for_prep => self.instructions.items[index].for_prep.offset = offset,
            .for_loop => self.instructions.items[index].for_loop.offset = offset,
            .tfor_prep => self.instructions.items[index].tfor_prep.offset = offset,
            .tfor_loop => self.instructions.items[index].tfor_loop.offset = offset,
            else => return error.InvalidJumpPatch,
        }
    }

    pub fn addConstant(self: *Proto, constant: bytecode.Constant) !bytecode.ConstantIndex {
        const owned = try self.ownConstant(constant);
        for (self.constants.items, 0..) |existing, index| {
            if (bytecode.constantEql(existing, owned)) return @intCast(index);
        }
        try self.constants.append(self.allocator, owned);
        return @intCast(self.constants.items.len - 1);
    }

    pub fn addLocal(self: *Proto, local: LocalDebug) !usize {
        try self.locals.append(self.allocator, .{
            .name = try self.dupe(local.name),
            .register = local.register,
            .start_pc = local.start_pc,
            .end_pc = local.end_pc,
        });
        return self.locals.items.len - 1;
    }

    pub fn addUpvalue(self: *Proto, upvalue: UpvalueDesc) !bytecode.UpvalueIndex {
        for (self.upvalues.items, 0..) |existing, index| {
            if (existing.in_stack == upvalue.in_stack and existing.index == upvalue.index and std.mem.eql(u8, existing.name, upvalue.name)) {
                return @intCast(index);
            }
        }
        try self.upvalues.append(self.allocator, .{
            .name = try self.dupe(upvalue.name),
            .in_stack = upvalue.in_stack,
            .index = upvalue.index,
        });
        return @intCast(self.upvalues.items.len - 1);
    }

    pub fn addChild(self: *Proto, child: *Proto) !bytecode.ProtoIndex {
        try self.children.append(self.allocator, child);
        return @intCast(self.children.items.len - 1);
    }

    fn ownConstant(self: *Proto, constant: bytecode.Constant) !bytecode.Constant {
        return switch (constant) {
            .nil => .nil,
            .boolean => |value| .{ .boolean = value },
            .integer => |value| .{ .integer = try self.dupe(value) },
            .number => |value| .{ .number = try self.dupe(value) },
            .string => |value| .{ .string = try self.dupe(value) },
        };
    }

    fn dupe(self: *Proto, value: []const u8) ![]const u8 {
        return self.arena.allocator().dupe(u8, value);
    }
};

fn jumpOffset(index: usize, target_pc: usize) !bytecode.JumpOffset {
    const from: isize = @intCast(index + 1);
    const to: isize = @intCast(target_pc);
    return std.math.cast(bytecode.JumpOffset, to - from) orelse error.JumpOutOfRange;
}
