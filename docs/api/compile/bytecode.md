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

- `boolean`
- `integer`
- `number`
- `string`

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

- `load_nil`
- `load_bool`
- `load_const`
- `move`
- `get_global`
- `set_global`
- `declare_global`
- `get_upvalue`
- `set_upvalue`
- `get_table`
- `set_table`
- `set_array`
- `get_field`
- `set_field`
- `new_table`
- `set_list`
- `add`
- `sub`
- `mul`
- `div`
- `idiv`
- `mod`
- `pow`
- `unm`
- `band`
- `bor`
- `bxor`
- `bnot`
- `shl`
- `shr`
- `eq`
- `lt`
- `le`
- `not`
- `len`
- `concat`
- `jmp`
- `compare_branch`
- `test_op`
- `test_set`
- `call`
- `tail_call`
- `ret`
- `vararg`
- `closure`
- `close`
- `check_close`
- `close_tbc`
- `for_prep`
- `for_loop`
- `tfor_prep`
- `tfor_call`
- `tfor_loop`

<a id="type-loadbool"></a>

## LoadBool

```zig
pub const LoadBool = struct { ... };
```

### Fields

- `dest`
- `value`

<a id="type-loadconst"></a>

## LoadConst

```zig
pub const LoadConst = struct { ... };
```

### Fields

- `dest`
- `constant`

<a id="type-move"></a>

## Move

```zig
pub const Move = struct { ... };
```

### Fields

- `dest`
- `source`

<a id="type-globalaccess"></a>

## GlobalAccess

```zig
pub const GlobalAccess = struct { ... };
```

### Fields

- `register`
- `name`

<a id="type-globaldeclare"></a>

## GlobalDeclare

```zig
pub const GlobalDeclare = struct { ... };
```

### Fields

- `table`
- `value`
- `name`

<a id="type-upvalueaccess"></a>

## UpvalueAccess

```zig
pub const UpvalueAccess = struct { ... };
```

### Fields

- `register`
- `upvalue`

<a id="type-tableaccess"></a>

## TableAccess

```zig
pub const TableAccess = struct { ... };
```

### Fields

- `dest`
- `table`
- `key`

<a id="type-tableset"></a>

## TableSet

```zig
pub const TableSet = struct { ... };
```

### Fields

- `table`
- `key`
- `value`

<a id="type-arrayset"></a>

## ArraySet

```zig
pub const ArraySet = struct { ... };
```

### Fields

- `table`
- `index`
- `value`

<a id="type-fieldaccess"></a>

## FieldAccess

```zig
pub const FieldAccess = struct { ... };
```

### Fields

- `dest`
- `table`
- `name`

<a id="type-fieldset"></a>

## FieldSet

```zig
pub const FieldSet = struct { ... };
```

### Fields

- `table`
- `name`
- `value`

<a id="type-newtable"></a>

## NewTable

```zig
pub const NewTable = struct { ... };
```

### Fields

- `dest`
- `array_hint`
- `hash_hint`

<a id="type-setlist"></a>

## SetList

```zig
pub const SetList = struct { ... };
```

### Fields

- `table`
- `first`
- `count`
- `start_index`

<a id="type-unary"></a>

## Unary

```zig
pub const Unary = struct { ... };
```

### Fields

- `dest`
- `source`

<a id="type-binary"></a>

## Binary

```zig
pub const Binary = struct { ... };
```

### Fields

- `dest`
- `left`
- `right`

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

- `left`
- `right`
- `op`
- `jump_if_truthy`
- `offset`

<a id="type-test"></a>

## Test

```zig
pub const Test = struct { ... };
```

### Fields

- `register`
- `jump_if_truthy`
- `offset`

<a id="type-testset"></a>

## TestSet

```zig
pub const TestSet = struct { ... };
```

### Fields

- `dest`
- `source`
- `jump_if_truthy`
- `offset`

<a id="type-call"></a>

## Call

```zig
pub const Call = struct { ... };
```

### Fields

- `base`
- `arg_count`
- `return_count`

<a id="type-return"></a>

## Return

```zig
pub const Return = struct { ... };
```

### Fields

- `first`
- `count`

<a id="type-vararg"></a>

## Vararg

```zig
pub const Vararg = struct { ... };
```

### Fields

- `dest`
- `count`

<a id="type-closure"></a>

## Closure

```zig
pub const Closure = struct { ... };
```

### Fields

- `dest`
- `proto`

<a id="type-forloop"></a>

## ForLoop

```zig
pub const ForLoop = struct { ... };
```

### Fields

- `base`
- `offset`

<a id="type-genericfor"></a>

## GenericFor

```zig
pub const GenericFor = struct { ... };
```

### Fields

- `base`
- `variable_count`
- `offset`

