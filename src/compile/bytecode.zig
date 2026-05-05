const std = @import("std");

pub const Register = u16;
pub const ConstantIndex = u32;
pub const ProtoIndex = u32;
pub const UpvalueIndex = u16;
pub const LocalIndex = u16;
pub const JumpOffset = i32;

pub const Constant = union(enum) {
    nil,
    boolean: bool,
    integer: []const u8,
    number: []const u8,
    string: []const u8,
};

pub fn constantEql(lhs: Constant, rhs: Constant) bool {
    if (std.meta.activeTag(lhs) != std.meta.activeTag(rhs)) return false;
    return switch (lhs) {
        .nil => true,
        .boolean => |value| value == rhs.boolean,
        .integer => |value| std.mem.eql(u8, value, rhs.integer),
        .number => |value| std.mem.eql(u8, value, rhs.number),
        .string => |value| std.mem.eql(u8, value, rhs.string),
    };
}

pub const Instruction = union(enum) {
    load_nil: Register,
    load_bool: LoadBool,
    load_const: LoadConst,
    move: Move,

    get_global: GlobalAccess,
    set_global: GlobalAccess,
    get_upvalue: UpvalueAccess,
    set_upvalue: UpvalueAccess,
    get_table: TableAccess,
    set_table: TableSet,
    get_field: FieldAccess,
    set_field: FieldSet,

    new_table: NewTable,
    set_list: SetList,

    add: Binary,
    sub: Binary,
    mul: Binary,
    div: Binary,
    idiv: Binary,
    mod: Binary,
    pow: Binary,
    unm: Unary,

    band: Binary,
    bor: Binary,
    bxor: Binary,
    bnot: Unary,
    shl: Binary,
    shr: Binary,

    eq: Binary,
    lt: Binary,
    le: Binary,
    not: Unary,
    len: Unary,
    concat: Binary,

    jmp: JumpOffset,
    test_op: Test,
    test_set: TestSet,

    call: Call,
    tail_call: Call,
    ret: Return,
    vararg: Vararg,

    closure: Closure,
    close: Register,

    for_prep: ForLoop,
    for_loop: ForLoop,
    tfor_prep: GenericFor,
    tfor_call: GenericFor,
    tfor_loop: GenericFor,
};

pub const LoadBool = struct {
    dest: Register,
    value: bool,
};

pub const LoadConst = struct {
    dest: Register,
    constant: ConstantIndex,
};

pub const Move = struct {
    dest: Register,
    source: Register,
};

pub const GlobalAccess = struct {
    register: Register,
    name: ConstantIndex,
};

pub const UpvalueAccess = struct {
    register: Register,
    upvalue: UpvalueIndex,
};

pub const TableAccess = struct {
    dest: Register,
    table: Register,
    key: Register,
};

pub const TableSet = struct {
    table: Register,
    key: Register,
    value: Register,
};

pub const FieldAccess = struct {
    dest: Register,
    table: Register,
    name: ConstantIndex,
};

pub const FieldSet = struct {
    table: Register,
    name: ConstantIndex,
    value: Register,
};

pub const NewTable = struct {
    dest: Register,
    array_hint: u32 = 0,
    hash_hint: u32 = 0,
};

pub const SetList = struct {
    table: Register,
    first: Register,
    count: u32,
};

pub const Unary = struct {
    dest: Register,
    source: Register,
};

pub const Binary = struct {
    dest: Register,
    left: Register,
    right: Register,
};

pub const Test = struct {
    register: Register,
    jump_if_truthy: bool,
    offset: JumpOffset,
};

pub const TestSet = struct {
    dest: Register,
    source: Register,
    jump_if_truthy: bool,
    offset: JumpOffset,
};

pub const Call = struct {
    base: Register,
    arg_count: u16,
    return_count: u16,
};

pub const Return = struct {
    first: Register,
    count: u16,
};

pub const Vararg = struct {
    dest: Register,
    count: u16,
};

pub const Closure = struct {
    dest: Register,
    proto: ProtoIndex,
};

pub const ForLoop = struct {
    base: Register,
    offset: JumpOffset,
};

pub const GenericFor = struct {
    base: Register,
    variable_count: u16,
    offset: JumpOffset,
};
