# compile.bytecode

## Navigation

- [API Index](../README.md)
- Previous: [compile.resolver](../compile/resolver.md)
- Next: [compile.proto](../compile/proto.md)
- Parent: [compile](../compile.md)

## Functions

- [constantEql](#fn-constanteql)

## Types

- [Constant](#type-constant)
- [Instruction](#type-instruction)
- [LoadBool](#type-loadbool)
- [LoadConst](#type-loadconst)
- [Move](#type-move)
- [GlobalAccess](#type-globalaccess)
- [GlobalDeclare](#type-globaldeclare)
- [UpvalueAccess](#type-upvalueaccess)
- [TableAccess](#type-tableaccess)
- [TableSet](#type-tableset)
- [ArraySet](#type-arrayset)
- [FieldAccess](#type-fieldaccess)
- [FieldSet](#type-fieldset)
- [NewTable](#type-newtable)
- [SetList](#type-setlist)
- [Unary](#type-unary)
- [Binary](#type-binary)
- [CompareBranchOp](#type-comparebranchop)
- [CompareBranch](#type-comparebranch)
- [Test](#type-test)
- [TestSet](#type-testset)
- [Call](#type-call)
- [Return](#type-return)
- [Vararg](#type-vararg)
- [Closure](#type-closure)
- [ForLoop](#type-forloop)
- [GenericFor](#type-genericfor)

## Constants

- [multret_count](#const-multret_count)

## Aliases

- [Register](#alias-register)
- [ConstantIndex](#alias-constantindex)
- [ProtoIndex](#alias-protoindex)
- [UpvalueIndex](#alias-upvalueindex)
- [LocalIndex](#alias-localindex)
- [JumpOffset](#alias-jumpoffset)

<a id="alias-register"></a>

## Register

```zig
pub const Register = u16;
```

<a id="alias-constantindex"></a>

## ConstantIndex

```zig
pub const ConstantIndex = u32;
```

<a id="alias-protoindex"></a>

## ProtoIndex

```zig
pub const ProtoIndex = u32;
```

<a id="alias-upvalueindex"></a>

## UpvalueIndex

```zig
pub const UpvalueIndex = u16;
```

<a id="alias-localindex"></a>

## LocalIndex

```zig
pub const LocalIndex = u16;
```

<a id="alias-jumpoffset"></a>

## JumpOffset

```zig
pub const JumpOffset = i32;
```

<a id="const-multret_count"></a>

## multret_count

```zig
pub const multret_count: u16 = std.math.maxInt(u16);
```

<a id="type-constant"></a>

## Constant

```zig
pub const Constant = union(enum) { ... };
```

### Fields

```zig
    boolean: bool
    integer: []const u8
    number: []const u8
    string: []const u8
```


<a id="fn-constanteql"></a>

## constantEql

```zig
pub fn constantEql(lhs: Constant, rhs: Constant) bool
```

References: [`Constant`](#type-constant)

<a id="type-instruction"></a>

## Instruction

```zig
pub const Instruction = union(enum) { ... };
```

### Fields

```zig
    load_nil: Register
    load_bool: LoadBool
    load_const: LoadConst
    move: Move
    get_global: GlobalAccess
    set_global: GlobalAccess
    declare_global: GlobalDeclare
    get_upvalue: UpvalueAccess
    set_upvalue: UpvalueAccess
    get_table: TableAccess
    set_table: TableSet
    set_array: ArraySet
    get_field: FieldAccess
    set_field: FieldSet
    new_table: NewTable
    set_list: SetList
    add: Binary
    sub: Binary
    mul: Binary
    div: Binary
    idiv: Binary
    mod: Binary
    pow: Binary
    unm: Unary
    band: Binary
    bor: Binary
    bxor: Binary
    bnot: Unary
    shl: Binary
    shr: Binary
    eq: Binary
    lt: Binary
    le: Binary
    not: Unary
    len: Unary
    concat: Binary
    jmp: JumpOffset
    compare_branch: CompareBranch
    test_op: Test
    test_set: TestSet
    call: Call
    tail_call: Call
    ret: Return
    vararg: Vararg
    closure: Closure
    close: Register
    check_close: Register
    close_tbc: Register
    for_prep: ForLoop
    for_loop: ForLoop
    tfor_prep: GenericFor
    tfor_call: GenericFor
    tfor_loop: GenericFor
```


<a id="type-loadbool"></a>

## LoadBool

```zig
pub const LoadBool = struct { ... };
```

### Fields

```zig
    dest: Register
    value: bool
```


<a id="type-loadconst"></a>

## LoadConst

```zig
pub const LoadConst = struct { ... };
```

### Fields

```zig
    dest: Register
    constant: ConstantIndex
```


<a id="type-move"></a>

## Move

```zig
pub const Move = struct { ... };
```

### Fields

```zig
    dest: Register
    source: Register
```


<a id="type-globalaccess"></a>

## GlobalAccess

```zig
pub const GlobalAccess = struct { ... };
```

### Fields

```zig
    register: Register
    name: ConstantIndex
```


<a id="type-globaldeclare"></a>

## GlobalDeclare

```zig
pub const GlobalDeclare = struct { ... };
```

### Fields

```zig
    table: Register
    value: Register
    name: ConstantIndex
```


<a id="type-upvalueaccess"></a>

## UpvalueAccess

```zig
pub const UpvalueAccess = struct { ... };
```

### Fields

```zig
    register: Register
    upvalue: UpvalueIndex
```


<a id="type-tableaccess"></a>

## TableAccess

```zig
pub const TableAccess = struct { ... };
```

### Fields

```zig
    dest: Register
    table: Register
    key: Register
```


<a id="type-tableset"></a>

## TableSet

```zig
pub const TableSet = struct { ... };
```

### Fields

```zig
    table: Register
    key: Register
    value: Register
```


<a id="type-arrayset"></a>

## ArraySet

```zig
pub const ArraySet = struct { ... };
```

### Fields

```zig
    table: Register
    index: u32
    value: Register
```


<a id="type-fieldaccess"></a>

## FieldAccess

```zig
pub const FieldAccess = struct { ... };
```

### Fields

```zig
    dest: Register
    table: Register
    name: ConstantIndex
```


<a id="type-fieldset"></a>

## FieldSet

```zig
pub const FieldSet = struct { ... };
```

### Fields

```zig
    table: Register
    name: ConstantIndex
    value: Register
```


<a id="type-newtable"></a>

## NewTable

```zig
pub const NewTable = struct { ... };
```

### Fields

```zig
    dest: Register
    array_hint: u32 = 0
    hash_hint: u32 = 0
```


<a id="type-setlist"></a>

## SetList

```zig
pub const SetList = struct { ... };
```

### Fields

```zig
    table: Register
    first: Register
    count: u32
    start_index: u32
```


<a id="type-unary"></a>

## Unary

```zig
pub const Unary = struct { ... };
```

### Fields

```zig
    dest: Register
    source: Register
```


<a id="type-binary"></a>

## Binary

```zig
pub const Binary = struct { ... };
```

### Fields

```zig
    dest: Register
    left: Register
    right: Register
```


<a id="type-comparebranchop"></a>

## CompareBranchOp

```zig
pub const CompareBranchOp = enum { ... };
```

<a id="type-comparebranch"></a>

## CompareBranch

```zig
pub const CompareBranch = struct { ... };
```

### Fields

```zig
    left: Register
    right: Register
    op: CompareBranchOp
    jump_if_truthy: bool
    offset: JumpOffset
```


<a id="type-test"></a>

## Test

```zig
pub const Test = struct { ... };
```

### Fields

```zig
    register: Register
    jump_if_truthy: bool
    offset: JumpOffset
```


<a id="type-testset"></a>

## TestSet

```zig
pub const TestSet = struct { ... };
```

### Fields

```zig
    dest: Register
    source: Register
    jump_if_truthy: bool
    offset: JumpOffset
```


<a id="type-call"></a>

## Call

```zig
pub const Call = struct { ... };
```

### Fields

```zig
    base: Register
    arg_count: u16
    return_count: u16
```


<a id="type-return"></a>

## Return

```zig
pub const Return = struct { ... };
```

### Fields

```zig
    first: Register
    count: u16
```


<a id="type-vararg"></a>

## Vararg

```zig
pub const Vararg = struct { ... };
```

### Fields

```zig
    dest: Register
    count: u16
```


<a id="type-closure"></a>

## Closure

```zig
pub const Closure = struct { ... };
```

### Fields

```zig
    dest: Register
    proto: ProtoIndex
```


<a id="type-forloop"></a>

## ForLoop

```zig
pub const ForLoop = struct { ... };
```

### Fields

```zig
    base: Register
    offset: JumpOffset
```


<a id="type-genericfor"></a>

## GenericFor

```zig
pub const GenericFor = struct { ... };
```

### Fields

```zig
    base: Register
    variable_count: u16
    offset: JumpOffset
```


