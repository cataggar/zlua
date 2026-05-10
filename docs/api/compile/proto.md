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
pub const LineInfo = struct {
    line: usize,
};
```

<a id="type-localdebug"></a>

## LocalDebug

```zig
pub const LocalDebug = struct {
    name: []const u8,
    register: bytecode.Register,
    start_pc: usize,
    end_pc: usize = 0,
    to_close: bool = false,
};
```

<a id="type-upvaluedesc"></a>

## UpvalueDesc

```zig
pub const UpvalueDesc = struct {
    name: []const u8,
    in_stack: bool,
    index: u16,
};
```

<a id="type-errorop"></a>

## ErrorOp

```zig
pub const ErrorOp = enum { ... };
```

<a id="type-operandorigin"></a>

## OperandOrigin

```zig
pub const OperandOrigin = union(enum) {
    local: []const u8,
    upvalue: []const u8,
    global: []const u8,
    field: []const u8,
    method: []const u8,
    metamethod: []const u8,
    constant: []const u8,
};
```

<a id="type-errorsite"></a>

## ErrorSite

```zig
pub const ErrorSite = struct {
    line: usize,
    op: ErrorOp,
    operands: []const OperandOrigin = &.{},
    call_name: ?OperandOrigin = null,
};
```

<a id="type-errorsiteentry"></a>

## ErrorSiteEntry

```zig
pub const ErrorSiteEntry = struct {
    pc: usize,
    site: ErrorSite,
};
```

<a id="type-proto"></a>

## Proto

```zig
pub const Proto = struct {
    allocator: std.mem.Allocator,
    arena: std.heap.ArenaAllocator,
    constants: std.ArrayList(bytecode.Constant) = .empty,
    instructions: std.ArrayList(bytecode.Instruction) = .empty,
    line_info: std.ArrayList(LineInfo) = .empty,
    locals: std.ArrayList(LocalDebug) = .empty,
    upvalues: std.ArrayList(UpvalueDesc) = .empty,
    error_sites: std.ArrayList(ErrorSiteEntry) = .empty,
    children: std.ArrayList(*Proto) = .empty,
    max_registers: u16 = 0,
    param_count: u16 = 0,
    is_vararg: bool = false,
    named_vararg: bool = false,
    source_name: []const u8 = "zlua",
    debug_name: ?[]const u8 = null,
    defined_line: usize = 0,
    last_defined_line: usize = 0,
    has_to_close_locals: bool = false,
};
```

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

