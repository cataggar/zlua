# compile.proto

## Navigation

- [API Index](../README.md)
- Previous: [compile.bytecode](../compile/bytecode.md)
- Next: [compile.compiler](../compile/compiler.md)
- Parent: [compile](../compile.md)

## Types

- [LineInfo](#type-lineinfo)
- [LocalDebug](#type-localdebug)
- [UpvalueDesc](#type-upvaluedesc)
- [ErrorOp](#type-errorop)
- [OperandOrigin](#type-operandorigin)
- [ErrorSite](#type-errorsite)
- [ErrorSiteEntry](#type-errorsiteentry)
- [Proto](#type-proto)

<a id="type-lineinfo"></a>

## LineInfo

```zig
pub const LineInfo = struct { ... };
```

### Fields

- `line`

<a id="type-localdebug"></a>

## LocalDebug

```zig
pub const LocalDebug = struct { ... };
```

### Fields

- `name`
- `register`
- `start_pc`
- `end_pc`
- `to_close`

<a id="type-upvaluedesc"></a>

## UpvalueDesc

```zig
pub const UpvalueDesc = struct { ... };
```

### Fields

- `name`
- `in_stack`
- `index`

<a id="type-errorop"></a>

## ErrorOp

```zig
pub const ErrorOp = enum { ... };
```

<a id="type-operandorigin"></a>

## OperandOrigin

```zig
pub const OperandOrigin = union(enum) { ... };
```

### Fields

- `local`
- `upvalue`
- `global`
- `field`
- `method`
- `metamethod`
- `constant`

<a id="type-errorsite"></a>

## ErrorSite

```zig
pub const ErrorSite = struct { ... };
```

### Fields

- `line`
- `op`
- `operands`
- `call_name`

<a id="type-errorsiteentry"></a>

## ErrorSiteEntry

```zig
pub const ErrorSiteEntry = struct { ... };
```

### Fields

- `pc`
- `site`

<a id="type-proto"></a>

## Proto

```zig
pub const Proto = struct { ... };
```

### Fields

- `allocator`
- `arena`
- `constants`
- `instructions`
- `line_info`
- `locals`
- `upvalues`
- `error_sites`
- `children`
- `max_registers`
- `param_count`
- `is_vararg`
- `named_vararg`
- `source_name`
- `debug_name`
- `defined_line`
- `last_defined_line`
- `has_to_close_locals`

### Nested Declarations

- [init](#fn-proto-init)
- [deinit](#fn-proto-deinit)
- [pc](#fn-proto-pc)
- [emit](#fn-proto-emit)
- [patchJump](#fn-proto-patchjump)
- [addConstant](#fn-proto-addconstant)
- [addLocal](#fn-proto-addlocal)
- [addUpvalue](#fn-proto-addupvalue)
- [addChild](#fn-proto-addchild)
- [addErrorSite](#fn-proto-adderrorsite)
- [errorSiteAt](#fn-proto-errorsiteat)
- [setDebugName](#fn-proto-setdebugname)

<a id="fn-proto-init"></a>

### Proto.init

```zig
pub fn init(allocator: std.mem.Allocator) Proto
```

References: [`Proto`](#type-proto)

<a id="fn-proto-deinit"></a>

### Proto.deinit

```zig
pub fn deinit(self: *Proto) void
```

References: [`Proto`](#type-proto)

<a id="fn-proto-pc"></a>

### Proto.pc

```zig
pub fn pc(self: Proto) usize
```

References: [`Proto`](#type-proto)

<a id="fn-proto-emit"></a>

### Proto.emit

```zig
pub fn emit(self: *Proto, instruction: bytecode.Instruction, line: usize) !usize
```

References: [`Proto`](#type-proto)

<a id="fn-proto-patchjump"></a>

### Proto.patchJump

```zig
pub fn patchJump(self: *Proto, index: usize, target_pc: usize) !void
```

References: [`Proto`](#type-proto)

<a id="fn-proto-addconstant"></a>

### Proto.addConstant

```zig
pub fn addConstant(self: *Proto, constant: bytecode.Constant) !bytecode.ConstantIndex
```

References: [`Proto`](#type-proto)

<a id="fn-proto-addlocal"></a>

### Proto.addLocal

```zig
pub fn addLocal(self: *Proto, local: LocalDebug) !usize
```

References: [`Proto`](#type-proto), [`LocalDebug`](#type-localdebug)

<a id="fn-proto-addupvalue"></a>

### Proto.addUpvalue

```zig
pub fn addUpvalue(self: *Proto, upvalue: UpvalueDesc) !bytecode.UpvalueIndex
```

References: [`Proto`](#type-proto), [`UpvalueDesc`](#type-upvaluedesc)

<a id="fn-proto-addchild"></a>

### Proto.addChild

```zig
pub fn addChild(self: *Proto, child: *Proto) !bytecode.ProtoIndex
```

References: [`Proto`](#type-proto)

<a id="fn-proto-adderrorsite"></a>

### Proto.addErrorSite

```zig
pub fn addErrorSite(self: *Proto, pc_index: usize, site: ErrorSite) !void
```

References: [`Proto`](#type-proto), [`ErrorSite`](#type-errorsite)

<a id="fn-proto-errorsiteat"></a>

### Proto.errorSiteAt

```zig
pub fn errorSiteAt(self: Proto, pc_index: usize) ?ErrorSite
```

References: [`Proto`](#type-proto), [`ErrorSite`](#type-errorsite)

<a id="fn-proto-setdebugname"></a>

### Proto.setDebugName

```zig
pub fn setDebugName(self: *Proto, name: []const u8) !void
```

References: [`Proto`](#type-proto)

