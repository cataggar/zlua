const std = @import("std");
const compile = @import("../compile.zig");
const types = @import("types.zig");

const bytecode = compile.bytecode;
const proto_mod = compile.proto;

pub const binary_chunk_signature = "\x1bLua";
pub const binary_chunk_payload_magic = "zlua\x00bc1";

pub fn appendBinaryChunkHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8)) !void {
    try out.appendSlice(allocator, binary_chunk_signature);
    try out.append(allocator, 0x55);
    try out.append(allocator, 0);
    try out.appendSlice(allocator, "\x19\x93\r\n\x1a\n");
    try out.append(allocator, @sizeOf(c_int));
    try appendHeaderInt(allocator, out, -0x5678, @sizeOf(c_int));
    try out.append(allocator, 4);
    try appendHeaderInt(allocator, out, 0x12345678, 4);
    try out.append(allocator, @sizeOf(i64));
    try appendHeaderInt(allocator, out, -0x5678, @sizeOf(i64));
    try out.append(allocator, @sizeOf(f64));
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], @bitCast(@as(f64, -370.5)), nativeEndian());
    try out.appendSlice(allocator, bytes[0..8]);
}

pub fn dumpClosureBinary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), closure: *const types.Closure, strip_debug: bool) !void {
    const strip = strip_debug or closure.stripped_debug;
    try appendBinaryChunkHeader(allocator, out);
    try out.appendSlice(allocator, binary_chunk_payload_magic);
    try appendBinaryBool(allocator, out, strip);
    try appendBinaryProto(allocator, out, closure.proto, null, strip);
}

fn appendBinaryProto(allocator: std.mem.Allocator, out: *std.ArrayList(u8), proto: *const proto_mod.Proto, parent_source_name: ?[]const u8, strip_debug: bool) !void {
    const source_name = if (strip_debug) "?" else proto.source_name;
    const source_matches_parent = if (parent_source_name) |parent| std.mem.eql(u8, source_name, parent) else false;
    try appendBinaryBool(allocator, out, !source_matches_parent);
    if (!source_matches_parent) try appendBinaryString(allocator, out, source_name);

    const debug_name = if (strip_debug) null else proto.debug_name;
    try appendBinaryBool(allocator, out, debug_name != null);
    if (debug_name) |name| try appendBinaryString(allocator, out, name);
    try appendBinaryU64(allocator, out, proto.defined_line);
    try appendBinaryU64(allocator, out, proto.last_defined_line);
    try appendBinaryU16(allocator, out, proto.max_registers);
    try appendBinaryU16(allocator, out, proto.param_count);
    try appendBinaryBool(allocator, out, proto.is_vararg);
    try appendBinaryBool(allocator, out, proto.named_vararg);

    try appendBinaryU32(allocator, out, proto.constants.items.len);
    for (proto.constants.items) |constant| try appendBinaryConstant(allocator, out, constant);

    try appendBinaryU32(allocator, out, proto.instructions.items.len);
    for (proto.instructions.items, 0..) |instruction, index| {
        try appendBinaryInstruction(allocator, out, instruction);
        const line = if (index < proto.line_info.items.len) proto.line_info.items[index].line else 0;
        try appendBinaryU64(allocator, out, line);
    }

    try appendBinaryU32(allocator, out, proto.locals.items.len);
    for (proto.locals.items) |local| {
        try appendBinaryString(allocator, out, local.name);
        try appendBinaryU16(allocator, out, local.register);
        try appendBinaryU64(allocator, out, local.start_pc);
        try appendBinaryU64(allocator, out, local.end_pc);
        try appendBinaryBool(allocator, out, local.to_close);
    }

    try appendBinaryU32(allocator, out, proto.upvalues.items.len);
    for (proto.upvalues.items) |upvalue| {
        try appendBinaryString(allocator, out, upvalue.name);
        try appendBinaryBool(allocator, out, upvalue.in_stack);
        try appendBinaryU16(allocator, out, upvalue.index);
    }

    try appendBinaryU32(allocator, out, proto.error_sites.items.len);
    for (proto.error_sites.items) |entry| {
        try appendBinaryU64(allocator, out, entry.pc);
        try appendBinaryErrorSite(allocator, out, entry.site);
    }

    try appendBinaryU32(allocator, out, proto.children.items.len);
    for (proto.children.items) |child| try appendBinaryProto(allocator, out, child, source_name, strip_debug);
}

fn appendBinaryConstant(allocator: std.mem.Allocator, out: *std.ArrayList(u8), constant: bytecode.Constant) !void {
    try out.append(allocator, @intCast(@intFromEnum(std.meta.activeTag(constant))));
    switch (constant) {
        .nil => {},
        .boolean => |value| try appendBinaryBool(allocator, out, value),
        .integer => |value| try appendBinaryString(allocator, out, value),
        .number => |value| try appendBinaryString(allocator, out, value),
        .string => |value| try appendBinaryString(allocator, out, value),
    }
}

fn appendBinaryInstruction(allocator: std.mem.Allocator, out: *std.ArrayList(u8), instruction: bytecode.Instruction) !void {
    try out.append(allocator, @intCast(@intFromEnum(std.meta.activeTag(instruction))));
    switch (instruction) {
        .load_nil => |dest| try appendBinaryU16(allocator, out, dest),
        .load_bool => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryBool(allocator, out, op.value);
        },
        .load_const => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU32(allocator, out, op.constant);
        },
        .move => |op| try appendBinaryMove(allocator, out, op),
        .get_global, .set_global => |op| {
            try appendBinaryU16(allocator, out, op.register);
            try appendBinaryU32(allocator, out, op.name);
        },
        .declare_global => |op| {
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU16(allocator, out, op.value);
            try appendBinaryU32(allocator, out, op.name);
        },
        .get_upvalue, .set_upvalue => |op| {
            try appendBinaryU16(allocator, out, op.register);
            try appendBinaryU16(allocator, out, op.upvalue);
        },
        .get_table => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU16(allocator, out, op.key);
        },
        .set_table => |op| {
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU16(allocator, out, op.key);
            try appendBinaryU16(allocator, out, op.value);
        },
        .set_array => |op| {
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU32(allocator, out, op.index);
            try appendBinaryU16(allocator, out, op.value);
        },
        .get_field => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU32(allocator, out, op.name);
        },
        .set_field => |op| {
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU32(allocator, out, op.name);
            try appendBinaryU16(allocator, out, op.value);
        },
        .new_table => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU32(allocator, out, op.array_hint);
            try appendBinaryU32(allocator, out, op.hash_hint);
        },
        .set_list => |op| {
            try appendBinaryU16(allocator, out, op.table);
            try appendBinaryU16(allocator, out, op.first);
            try appendBinaryU32(allocator, out, op.count);
            try appendBinaryU32(allocator, out, op.start_index);
        },
        .add, .sub, .mul, .div, .idiv, .mod, .pow, .band, .bor, .bxor, .shl, .shr, .eq, .lt, .le, .concat => |op| try appendBinaryBinary(allocator, out, op),
        .unm, .bnot, .not, .len => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU16(allocator, out, op.source);
        },
        .jmp => |offset| try appendBinaryI32(allocator, out, offset),
        .compare_branch => |op| {
            try appendBinaryU16(allocator, out, op.left);
            try appendBinaryU16(allocator, out, op.right);
            try out.append(allocator, @intCast(@intFromEnum(op.op)));
            try appendBinaryBool(allocator, out, op.jump_if_truthy);
            try appendBinaryI32(allocator, out, op.offset);
        },
        .test_op => |op| {
            try appendBinaryU16(allocator, out, op.register);
            try appendBinaryBool(allocator, out, op.jump_if_truthy);
            try appendBinaryI32(allocator, out, op.offset);
        },
        .test_set => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU16(allocator, out, op.source);
            try appendBinaryBool(allocator, out, op.jump_if_truthy);
            try appendBinaryI32(allocator, out, op.offset);
        },
        .call, .tail_call => |op| {
            try appendBinaryU16(allocator, out, op.base);
            try appendBinaryU16(allocator, out, op.arg_count);
            try appendBinaryU16(allocator, out, op.return_count);
        },
        .ret => |op| {
            try appendBinaryU16(allocator, out, op.first);
            try appendBinaryU16(allocator, out, op.count);
        },
        .vararg => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU16(allocator, out, op.count);
        },
        .closure => |op| {
            try appendBinaryU16(allocator, out, op.dest);
            try appendBinaryU32(allocator, out, op.proto);
        },
        .close, .check_close, .close_tbc => |register| try appendBinaryU16(allocator, out, register),
        .for_prep, .for_loop => |op| {
            try appendBinaryU16(allocator, out, op.base);
            try appendBinaryI32(allocator, out, op.offset);
        },
        .tfor_prep, .tfor_call, .tfor_loop => |op| {
            try appendBinaryU16(allocator, out, op.base);
            try appendBinaryU16(allocator, out, op.variable_count);
            try appendBinaryI32(allocator, out, op.offset);
        },
    }
}

fn appendBinaryMove(allocator: std.mem.Allocator, out: *std.ArrayList(u8), op: bytecode.Move) !void {
    try appendBinaryU16(allocator, out, op.dest);
    try appendBinaryU16(allocator, out, op.source);
}

fn appendBinaryBinary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), op: bytecode.Binary) !void {
    try appendBinaryU16(allocator, out, op.dest);
    try appendBinaryU16(allocator, out, op.left);
    try appendBinaryU16(allocator, out, op.right);
}

fn appendBinaryErrorSite(allocator: std.mem.Allocator, out: *std.ArrayList(u8), site: proto_mod.ErrorSite) !void {
    try appendBinaryU64(allocator, out, site.line);
    try out.append(allocator, @intCast(@intFromEnum(site.op)));
    try appendBinaryU32(allocator, out, site.operands.len);
    for (site.operands) |origin| try appendBinaryOrigin(allocator, out, origin);
    try appendBinaryBool(allocator, out, site.call_name != null);
    if (site.call_name) |origin| try appendBinaryOrigin(allocator, out, origin);
}

fn appendBinaryOrigin(allocator: std.mem.Allocator, out: *std.ArrayList(u8), origin: proto_mod.OperandOrigin) !void {
    try out.append(allocator, @intCast(@intFromEnum(std.meta.activeTag(origin))));
    switch (origin) {
        .temporary => {},
        .local, .upvalue, .global, .field, .method, .metamethod, .constant => |name| try appendBinaryString(allocator, out, name),
    }
}

fn appendBinaryString(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: []const u8) !void {
    try appendBinaryU32(allocator, out, value.len);
    try out.appendSlice(allocator, value);
}

fn appendBinaryBool(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: bool) !void {
    try out.append(allocator, if (value) 1 else 0);
}

fn appendBinaryU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, bytes[0..], value, .little);
    try out.appendSlice(allocator, bytes[0..]);
}

fn appendBinaryU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: anytype) !void {
    const int_value = std.math.cast(u32, value) orelse return error.OutOfMemory;
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..], int_value, .little);
    try out.appendSlice(allocator, bytes[0..]);
}

fn appendBinaryI32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: i32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(i32, bytes[0..], value, .little);
    try out.appendSlice(allocator, bytes[0..]);
}

fn appendBinaryU64(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: anytype) !void {
    const int_value = std.math.cast(u64, value) orelse return error.OutOfMemory;
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..], int_value, .little);
    try out.appendSlice(allocator, bytes[0..]);
}

pub fn BinaryChunkReader(comptime State: type) type {
    return struct {
        state: *State,
        source: []const u8,
        pos: usize,

        const Self = @This();

        pub fn readProto(self: *Self, parent_source_name: ?[]const u8) anyerror!*proto_mod.Proto {
            const proto = try self.state.allocator.create(proto_mod.Proto);
            errdefer self.state.allocator.destroy(proto);
            proto.* = proto_mod.Proto.init(self.state.allocator);
            errdefer proto.deinit();
            try self.readProtoBody(proto, parent_source_name);
            return proto;
        }

        fn readProtoBody(self: *Self, proto: *proto_mod.Proto, parent_source_name: ?[]const u8) anyerror!void {
            proto.source_name = if (try self.readBool())
                try self.readProtoString(proto)
            else if (parent_source_name) |source_name|
                try proto.arena.allocator().dupe(u8, source_name)
            else
                return self.state.fail("bad binary chunk");
            if (try self.readBool()) proto.debug_name = try self.readProtoString(proto);
            proto.defined_line = try self.readUsize();
            proto.last_defined_line = try self.readUsize();
            proto.max_registers = try self.readU16();
            proto.param_count = try self.readU16();
            proto.is_vararg = try self.readBool();
            proto.named_vararg = try self.readBool();

            const constant_count = try self.readCount();
            try proto.constants.ensureTotalCapacity(proto.allocator, constant_count);
            for (0..constant_count) |_| try proto.constants.append(proto.allocator, try self.readConstant(proto));

            const instruction_count = try self.readCount();
            try proto.instructions.ensureTotalCapacity(proto.allocator, instruction_count);
            try proto.line_info.ensureTotalCapacity(proto.allocator, instruction_count);
            for (0..instruction_count) |_| {
                try proto.instructions.append(proto.allocator, try self.readInstruction());
                try proto.line_info.append(proto.allocator, .{ .line = try self.readUsize() });
            }

            const local_count = try self.readCount();
            try proto.locals.ensureTotalCapacity(proto.allocator, local_count);
            for (0..local_count) |_| {
                const name = try self.readProtoString(proto);
                const register = try self.readU16();
                const start_pc = try self.readUsize();
                const end_pc = try self.readUsize();
                const to_close = try self.readBool();
                try proto.locals.append(proto.allocator, .{
                    .name = name,
                    .register = register,
                    .start_pc = start_pc,
                    .end_pc = end_pc,
                    .to_close = to_close,
                });
                if (to_close) proto.has_to_close_locals = true;
            }

            const upvalue_count = try self.readCount();
            try proto.upvalues.ensureTotalCapacity(proto.allocator, upvalue_count);
            for (0..upvalue_count) |_| {
                try proto.upvalues.append(proto.allocator, .{
                    .name = try self.readProtoString(proto),
                    .in_stack = try self.readBool(),
                    .index = try self.readU16(),
                });
            }

            const error_site_count = try self.readCount();
            try proto.error_sites.ensureTotalCapacity(proto.allocator, error_site_count);
            for (0..error_site_count) |_| {
                const pc = try self.readUsize();
                const site = try self.readErrorSite(proto);
                try proto.error_sites.append(proto.allocator, .{ .pc = pc, .site = site });
            }

            const child_count = try self.readCount();
            try proto.children.ensureTotalCapacity(proto.allocator, child_count);
            for (0..child_count) |_| {
                const child = try self.readProto(proto.source_name);
                errdefer {
                    child.deinit();
                    self.state.allocator.destroy(child);
                }
                try proto.children.append(proto.allocator, child);
            }
        }

        fn readConstant(self: *Self, proto: *proto_mod.Proto) !bytecode.Constant {
            const ConstantTag = std.meta.Tag(bytecode.Constant);
            const tag = try self.readEnum(ConstantTag);
            return switch (tag) {
                .nil => .nil,
                .boolean => .{ .boolean = try self.readBool() },
                .integer => .{ .integer = try self.readProtoString(proto) },
                .number => .{ .number = try self.readProtoString(proto) },
                .string => .{ .string = try self.readProtoString(proto) },
            };
        }

        fn readInstruction(self: *Self) !bytecode.Instruction {
            const InstructionTag = std.meta.Tag(bytecode.Instruction);
            const tag = try self.readEnum(InstructionTag);
            return switch (tag) {
                .load_nil => .{ .load_nil = try self.readU16() },
                .load_bool => .{ .load_bool = .{ .dest = try self.readU16(), .value = try self.readBool() } },
                .load_const => .{ .load_const = .{ .dest = try self.readU16(), .constant = try self.readU32() } },
                .move => .{ .move = .{ .dest = try self.readU16(), .source = try self.readU16() } },
                .get_global => .{ .get_global = .{ .register = try self.readU16(), .name = try self.readU32() } },
                .set_global => .{ .set_global = .{ .register = try self.readU16(), .name = try self.readU32() } },
                .declare_global => .{ .declare_global = .{ .table = try self.readU16(), .value = try self.readU16(), .name = try self.readU32() } },
                .get_upvalue => .{ .get_upvalue = .{ .register = try self.readU16(), .upvalue = try self.readU16() } },
                .set_upvalue => .{ .set_upvalue = .{ .register = try self.readU16(), .upvalue = try self.readU16() } },
                .get_table => .{ .get_table = .{ .dest = try self.readU16(), .table = try self.readU16(), .key = try self.readU16() } },
                .set_table => .{ .set_table = .{ .table = try self.readU16(), .key = try self.readU16(), .value = try self.readU16() } },
                .set_array => .{ .set_array = .{ .table = try self.readU16(), .index = try self.readU32(), .value = try self.readU16() } },
                .get_field => .{ .get_field = .{ .dest = try self.readU16(), .table = try self.readU16(), .name = try self.readU32() } },
                .set_field => .{ .set_field = .{ .table = try self.readU16(), .name = try self.readU32(), .value = try self.readU16() } },
                .new_table => .{ .new_table = .{ .dest = try self.readU16(), .array_hint = try self.readU32(), .hash_hint = try self.readU32() } },
                .set_list => .{ .set_list = .{ .table = try self.readU16(), .first = try self.readU16(), .count = try self.readU32(), .start_index = try self.readU32() } },
                .add => .{ .add = try self.readBinary() },
                .sub => .{ .sub = try self.readBinary() },
                .mul => .{ .mul = try self.readBinary() },
                .div => .{ .div = try self.readBinary() },
                .idiv => .{ .idiv = try self.readBinary() },
                .mod => .{ .mod = try self.readBinary() },
                .pow => .{ .pow = try self.readBinary() },
                .unm => .{ .unm = try self.readUnary() },
                .band => .{ .band = try self.readBinary() },
                .bor => .{ .bor = try self.readBinary() },
                .bxor => .{ .bxor = try self.readBinary() },
                .bnot => .{ .bnot = try self.readUnary() },
                .shl => .{ .shl = try self.readBinary() },
                .shr => .{ .shr = try self.readBinary() },
                .eq => .{ .eq = try self.readBinary() },
                .lt => .{ .lt = try self.readBinary() },
                .le => .{ .le = try self.readBinary() },
                .not => .{ .not = try self.readUnary() },
                .len => .{ .len = try self.readUnary() },
                .concat => .{ .concat = try self.readBinary() },
                .jmp => .{ .jmp = try self.readI32() },
                .compare_branch => .{ .compare_branch = .{ .left = try self.readU16(), .right = try self.readU16(), .op = try self.readEnum(bytecode.CompareBranchOp), .jump_if_truthy = try self.readBool(), .offset = try self.readI32() } },
                .test_op => .{ .test_op = .{ .register = try self.readU16(), .jump_if_truthy = try self.readBool(), .offset = try self.readI32() } },
                .test_set => .{ .test_set = .{ .dest = try self.readU16(), .source = try self.readU16(), .jump_if_truthy = try self.readBool(), .offset = try self.readI32() } },
                .call => .{ .call = .{ .base = try self.readU16(), .arg_count = try self.readU16(), .return_count = try self.readU16() } },
                .tail_call => .{ .tail_call = .{ .base = try self.readU16(), .arg_count = try self.readU16(), .return_count = try self.readU16() } },
                .ret => .{ .ret = .{ .first = try self.readU16(), .count = try self.readU16() } },
                .vararg => .{ .vararg = .{ .dest = try self.readU16(), .count = try self.readU16() } },
                .closure => .{ .closure = .{ .dest = try self.readU16(), .proto = try self.readU32() } },
                .close => .{ .close = try self.readU16() },
                .check_close => .{ .check_close = try self.readU16() },
                .close_tbc => .{ .close_tbc = try self.readU16() },
                .for_prep => .{ .for_prep = .{ .base = try self.readU16(), .offset = try self.readI32() } },
                .for_loop => .{ .for_loop = .{ .base = try self.readU16(), .offset = try self.readI32() } },
                .tfor_prep => .{ .tfor_prep = .{ .base = try self.readU16(), .variable_count = try self.readU16(), .offset = try self.readI32() } },
                .tfor_call => .{ .tfor_call = .{ .base = try self.readU16(), .variable_count = try self.readU16(), .offset = try self.readI32() } },
                .tfor_loop => .{ .tfor_loop = .{ .base = try self.readU16(), .variable_count = try self.readU16(), .offset = try self.readI32() } },
            };
        }

        fn readUnary(self: *Self) !bytecode.Unary {
            return .{ .dest = try self.readU16(), .source = try self.readU16() };
        }

        fn readBinary(self: *Self) !bytecode.Binary {
            return .{ .dest = try self.readU16(), .left = try self.readU16(), .right = try self.readU16() };
        }

        fn readErrorSite(self: *Self, proto: *proto_mod.Proto) !proto_mod.ErrorSite {
            const line = try self.readUsize();
            const op = try self.readEnum(proto_mod.ErrorOp);
            const operand_count = try self.readCount();
            const operands = try proto.arena.allocator().alloc(proto_mod.OperandOrigin, operand_count);
            for (operands) |*operand| operand.* = try self.readOrigin(proto);
            const call_name = if (try self.readBool()) try self.readOrigin(proto) else null;
            return .{ .line = line, .op = op, .operands = operands, .call_name = call_name };
        }

        fn readOrigin(self: *Self, proto: *proto_mod.Proto) !proto_mod.OperandOrigin {
            const OriginTag = std.meta.Tag(proto_mod.OperandOrigin);
            const tag = try self.readEnum(OriginTag);
            return switch (tag) {
                .temporary => .temporary,
                .local => .{ .local = try self.readProtoString(proto) },
                .upvalue => .{ .upvalue = try self.readProtoString(proto) },
                .global => .{ .global = try self.readProtoString(proto) },
                .field => .{ .field = try self.readProtoString(proto) },
                .method => .{ .method = try self.readProtoString(proto) },
                .metamethod => .{ .metamethod = try self.readProtoString(proto) },
                .constant => .{ .constant = try self.readProtoString(proto) },
            };
        }

        fn readProtoString(self: *Self, proto: *proto_mod.Proto) ![]const u8 {
            const bytes = try self.readStringBytes();
            return proto.arena.allocator().dupe(u8, bytes);
        }

        fn readStringBytes(self: *Self) ![]const u8 {
            return self.readBytes(try self.readCount());
        }

        pub fn readBool(self: *Self) !bool {
            return switch (try self.readByte()) {
                0 => false,
                1 => true,
                else => self.state.fail("bad binary chunk"),
            };
        }

        fn readEnum(self: *Self, comptime T: type) !T {
            const tag = try self.readByte();
            if (tag >= std.meta.fields(T).len) return self.state.fail("bad binary chunk");
            return @enumFromInt(tag);
        }

        fn readCount(self: *Self) !usize {
            return std.math.cast(usize, try self.readU32()) orelse self.state.fail("bad binary chunk");
        }

        fn readUsize(self: *Self) !usize {
            return std.math.cast(usize, try self.readU64()) orelse self.state.fail("bad binary chunk");
        }

        fn readByte(self: *Self) !u8 {
            if (self.pos >= self.source.len) return self.state.fail("truncated binary chunk");
            const byte = self.source[self.pos];
            self.pos += 1;
            return byte;
        }

        fn readBytes(self: *Self, len: usize) ![]const u8 {
            if (self.source.len - self.pos < len) return self.state.fail("truncated binary chunk");
            const bytes = self.source[self.pos .. self.pos + len];
            self.pos += len;
            return bytes;
        }

        fn readU16(self: *Self) !u16 {
            return std.mem.readInt(u16, (try self.readBytes(2))[0..2], .little);
        }

        fn readU32(self: *Self) !u32 {
            return std.mem.readInt(u32, (try self.readBytes(4))[0..4], .little);
        }

        fn readI32(self: *Self) !i32 {
            return std.mem.readInt(i32, (try self.readBytes(4))[0..4], .little);
        }

        fn readU64(self: *Self) !u64 {
            return std.mem.readInt(u64, (try self.readBytes(8))[0..8], .little);
        }
    };
}

fn appendHeaderInt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: i64, size: usize) !void {
    var bytes: [8]u8 = undefined;
    const unsigned: u64 = @bitCast(value);
    switch (size) {
        1 => bytes[0] = @truncate(unsigned),
        2 => std.mem.writeInt(u16, bytes[0..2], @truncate(unsigned), nativeEndian()),
        4 => std.mem.writeInt(u32, bytes[0..4], @truncate(unsigned), nativeEndian()),
        8 => std.mem.writeInt(u64, bytes[0..8], unsigned, nativeEndian()),
        else => unreachable,
    }
    try out.appendSlice(allocator, bytes[0..size]);
}

fn nativeEndian() std.builtin.Endian {
    return switch (@import("builtin").target.cpu.arch.endian()) {
        .little => .little,
        .big => .big,
    };
}
