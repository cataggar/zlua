const std = @import("std");
const bytecode = @import("bytecode.zig");
const compiler = @import("compiler.zig");
const frontend = @import("../frontend.zig");
const proto_mod = @import("proto.zig");

pub fn disassembleAlloc(allocator: std.mem.Allocator, proto: *const proto_mod.Proto) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try writeProto(allocator, &out, proto, 0);
    return out.toOwnedSlice(allocator);
}

fn writeProto(allocator: std.mem.Allocator, out: *std.ArrayList(u8), proto: *const proto_mod.Proto, depth: usize) !void {
    try appendFmt(allocator, out, "{s}proto regs={d} consts={d} locals={d} upvalues={d}\n", .{ indent(depth), proto.max_registers, proto.constants.items.len, proto.locals.items.len, proto.upvalues.items.len });

    for (proto.constants.items, 0..) |constant, index| {
        try appendFmt(allocator, out, "{s}K{d} = ", .{ indent(depth + 1), index });
        try writeConstant(allocator, out, constant);
        try out.append(allocator, '\n');
    }

    for (proto.locals.items, 0..) |local, index| {
        try appendFmt(allocator, out, "{s}L{d} r{d} {s}{s} [{d},{d})\n", .{ indent(depth + 1), index, local.register, local.name, if (local.to_close) "<close>" else "", local.start_pc, local.end_pc });
    }

    for (proto.upvalues.items, 0..) |upvalue, index| {
        try appendFmt(allocator, out, "{s}U{d} {s} in_stack={} index={d}\n", .{ indent(depth + 1), index, upvalue.name, upvalue.in_stack, upvalue.index });
    }

    for (proto.instructions.items, 0..) |instruction, pc| {
        try appendFmt(allocator, out, "{s}{d:0>4} [{d}] ", .{ indent(depth + 1), pc, proto.line_info.items[pc].line });
        try writeInstruction(allocator, out, instruction);
        try out.append(allocator, '\n');
    }

    for (proto.children.items, 0..) |child, index| {
        try appendFmt(allocator, out, "{s}child {d}:\n", .{ indent(depth + 1), index });
        try writeProto(allocator, out, child, depth + 2);
    }
}

fn writeConstant(allocator: std.mem.Allocator, out: *std.ArrayList(u8), constant: bytecode.Constant) !void {
    switch (constant) {
        .nil => try out.appendSlice(allocator, "nil"),
        .boolean => |value| try appendFmt(allocator, out, "{}", .{value}),
        .integer => |value| try appendFmt(allocator, out, "int({s})", .{value}),
        .number => |value| try appendFmt(allocator, out, "num({s})", .{value}),
        .string => |value| try appendFmt(allocator, out, "str({s})", .{value}),
    }
}

fn writeInstruction(allocator: std.mem.Allocator, out: *std.ArrayList(u8), instruction: bytecode.Instruction) !void {
    switch (instruction) {
        .load_nil => |dest| try appendFmt(allocator, out, "LOAD_NIL r{d}", .{dest}),
        .load_bool => |op| try appendFmt(allocator, out, "LOAD_BOOL r{d} {}", .{ op.dest, op.value }),
        .load_const => |op| try appendFmt(allocator, out, "LOAD_CONST r{d} K{d}", .{ op.dest, op.constant }),
        .move => |op| try appendFmt(allocator, out, "MOVE r{d} r{d}", .{ op.dest, op.source }),
        .get_global => |op| try appendFmt(allocator, out, "GET_GLOBAL r{d} K{d}", .{ op.register, op.name }),
        .set_global => |op| try appendFmt(allocator, out, "SET_GLOBAL r{d} K{d}", .{ op.register, op.name }),
        .declare_global => |op| try appendFmt(allocator, out, "DECLARE_GLOBAL r{d} K{d} r{d}", .{ op.table, op.name, op.value }),
        .get_upvalue => |op| try appendFmt(allocator, out, "GET_UPVALUE r{d} U{d}", .{ op.register, op.upvalue }),
        .set_upvalue => |op| try appendFmt(allocator, out, "SET_UPVALUE r{d} U{d}", .{ op.register, op.upvalue }),
        .get_table => |op| try appendFmt(allocator, out, "GET_TABLE r{d} r{d} r{d}", .{ op.dest, op.table, op.key }),
        .set_table => |op| try appendFmt(allocator, out, "SET_TABLE r{d} r{d} r{d}", .{ op.table, op.key, op.value }),
        .set_array => |op| try appendFmt(allocator, out, "SET_ARRAY r{d} [{d}] r{d}", .{ op.table, op.index, op.value }),
        .get_field => |op| try appendFmt(allocator, out, "GET_FIELD r{d} r{d} K{d}", .{ op.dest, op.table, op.name }),
        .set_field => |op| try appendFmt(allocator, out, "SET_FIELD r{d} K{d} r{d}", .{ op.table, op.name, op.value }),
        .new_table => |op| try appendFmt(allocator, out, "NEW_TABLE r{d} array={d} hash={d}", .{ op.dest, op.array_hint, op.hash_hint }),
        .set_list => |op| try appendFmt(allocator, out, "SET_LIST r{d} first=r{d} count={d} start={d}", .{ op.table, op.first, op.count, op.start_index }),
        .add => |op| try writeBinary(allocator, out, "ADD", op),
        .sub => |op| try writeBinary(allocator, out, "SUB", op),
        .mul => |op| try writeBinary(allocator, out, "MUL", op),
        .div => |op| try writeBinary(allocator, out, "DIV", op),
        .idiv => |op| try writeBinary(allocator, out, "IDIV", op),
        .mod => |op| try writeBinary(allocator, out, "MOD", op),
        .pow => |op| try writeBinary(allocator, out, "POW", op),
        .unm => |op| try writeUnary(allocator, out, "UNM", op),
        .band => |op| try writeBinary(allocator, out, "BAND", op),
        .bor => |op| try writeBinary(allocator, out, "BOR", op),
        .bxor => |op| try writeBinary(allocator, out, "BXOR", op),
        .bnot => |op| try writeUnary(allocator, out, "BNOT", op),
        .shl => |op| try writeBinary(allocator, out, "SHL", op),
        .shr => |op| try writeBinary(allocator, out, "SHR", op),
        .eq => |op| try writeBinary(allocator, out, "EQ", op),
        .lt => |op| try writeBinary(allocator, out, "LT", op),
        .le => |op| try writeBinary(allocator, out, "LE", op),
        .not => |op| try writeUnary(allocator, out, "NOT", op),
        .len => |op| try writeUnary(allocator, out, "LEN", op),
        .concat => |op| try writeBinary(allocator, out, "CONCAT", op),
        .jmp => |offset| try appendFmt(allocator, out, "JMP {d}", .{offset}),
        .compare_branch => |op| try appendFmt(allocator, out, "COMPARE_BRANCH {s} r{d} r{d} truthy={} {d}", .{ @tagName(op.op), op.left, op.right, op.jump_if_truthy, op.offset }),
        .test_op => |op| try appendFmt(allocator, out, "TEST r{d} truthy={} {d}", .{ op.register, op.jump_if_truthy, op.offset }),
        .test_set => |op| try appendFmt(allocator, out, "TEST_SET r{d} r{d} truthy={} {d}", .{ op.dest, op.source, op.jump_if_truthy, op.offset }),
        .call => |op| try appendFmt(allocator, out, "CALL r{d} args={d} returns={d}", .{ op.base, op.arg_count, op.return_count }),
        .tail_call => |op| try appendFmt(allocator, out, "TAIL_CALL r{d} args={d} returns={d}", .{ op.base, op.arg_count, op.return_count }),
        .ret => |op| try appendFmt(allocator, out, "RETURN r{d} count={d}", .{ op.first, op.count }),
        .vararg => |op| try appendFmt(allocator, out, "VARARG r{d} count={d}", .{ op.dest, op.count }),
        .closure => |op| try appendFmt(allocator, out, "CLOSURE r{d} P{d}", .{ op.dest, op.proto }),
        .close => |register| try appendFmt(allocator, out, "CLOSE r{d}", .{register}),
        .check_close => |register| try appendFmt(allocator, out, "CHECK_CLOSE r{d}", .{register}),
        .close_tbc => |register| try appendFmt(allocator, out, "CLOSE_TBC r{d}", .{register}),
        .for_prep => |op| try appendFmt(allocator, out, "FOR_PREP r{d} {d}", .{ op.base, op.offset }),
        .for_loop => |op| try appendFmt(allocator, out, "FOR_LOOP r{d} {d}", .{ op.base, op.offset }),
        .tfor_prep => |op| try appendFmt(allocator, out, "TFOR_PREP r{d} vars={d} {d}", .{ op.base, op.variable_count, op.offset }),
        .tfor_call => |op| try appendFmt(allocator, out, "TFOR_CALL r{d} vars={d} {d}", .{ op.base, op.variable_count, op.offset }),
        .tfor_loop => |op| try appendFmt(allocator, out, "TFOR_LOOP r{d} vars={d} {d}", .{ op.base, op.variable_count, op.offset }),
    }
}

fn writeUnary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, op: bytecode.Unary) !void {
    try appendFmt(allocator, out, "{s} r{d} r{d}", .{ name, op.dest, op.source });
}

fn writeBinary(allocator: std.mem.Allocator, out: *std.ArrayList(u8), name: []const u8, op: bytecode.Binary) !void {
    try appendFmt(allocator, out, "{s} r{d} r{d} r{d}", .{ name, op.dest, op.left, op.right });
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const rendered = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(rendered);
    try out.appendSlice(allocator, rendered);
}

fn indent(depth: usize) []const u8 {
    const spaces = "                                ";
    return spaces[0..@min(depth * 2, spaces.len)];
}

test "disassembles compiled bytecode" {
    var tree = try frontend.parse(std.testing.allocator,
        \\local x = 1
        \\return x
    );
    defer tree.deinit();

    var proto = try compiler.compile(std.testing.allocator, &tree);
    defer proto.deinit();

    const text = try disassembleAlloc(std.testing.allocator, &proto);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "proto regs=") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "LOAD_CONST") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "RETURN") != null);
}
