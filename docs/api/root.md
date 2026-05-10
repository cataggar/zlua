# root

## Navigation

- [API Index](README.md)
- Next: [frontend](frontend.md)

## Constants

- [version](#const-version)
- [lua_target_version](#const-lua_target_version)

## Aliases

- [State](#alias-state)
- [Options](#alias-options)
- [Value](#alias-value)
- [Ref](#alias-ref)
- [Table](#alias-table)
- [Function](#alias-function)
- [Context](#alias-context)
- [Error](#alias-error)
- [BytecodeLoadOptions](#alias-bytecodeloadoptions)
- [BytecodeDumpOptions](#alias-bytecodedumpoptions)
- [Tuple](#alias-tuple)
- [HostFn](#alias-hostfn)
- [Userdata](#alias-userdata)
- [AnyUserdata](#alias-anyuserdata)
- [MemoryFile](#alias-memoryfile)
- [MemoryFilesystem](#alias-memoryfilesystem)

## Imports

- [frontend](#import-frontend) `@import("frontend.zig")`
- [compile](#import-compile) `@import("compile.zig")`
- [errors](#import-errors) `@import("errors.zig")`
- [api](#import-api) `@import("api.zig")`
- [runtime](#import-runtime) `@import("runtime.zig")`
- [stdlib](#import-stdlib) `@import("stdlib.zig")`
- [testing](#import-testing) `@import("testing.zig")`

<a id="const-version"></a>

## version

```zig
pub const version = "0.1.0";
```

<a id="const-lua_target_version"></a>

## lua_target_version

```zig
pub const lua_target_version = "Lua 5.5";
```

<a id="import-frontend"></a>

## frontend

```zig
pub const frontend = @import("frontend.zig");
```

<a id="import-compile"></a>

## compile

```zig
pub const compile = @import("compile.zig");
```

<a id="import-errors"></a>

## errors

```zig
pub const errors = @import("errors.zig");
```

<a id="import-api"></a>

## api

```zig
pub const api = @import("api.zig");
```

<a id="import-runtime"></a>

## runtime

```zig
pub const runtime = @import("runtime.zig");
```

<a id="import-stdlib"></a>

## stdlib

```zig
pub const stdlib = @import("stdlib.zig");
```

<a id="import-testing"></a>

## testing

```zig
pub const testing = @import("testing.zig");
```

<a id="alias-state"></a>

## State

```zig
pub const State = api.State;
```

References: [`api.State`](api.md#type-state)

<a id="alias-options"></a>

## Options

```zig
pub const Options = api.Options;
```

References: [`api.Options`](api.md#type-options)

<a id="alias-value"></a>

## Value

```zig
pub const Value = api.Value;
```

References: [`api.Value`](api.md#type-value)

<a id="alias-ref"></a>

## Ref

```zig
pub const Ref = api.Ref;
```

References: [`api.Ref`](api.md#type-ref)

<a id="alias-table"></a>

## Table

```zig
pub const Table = api.Table;
```

References: [`api.Table`](api.md#type-table)

<a id="alias-function"></a>

## Function

```zig
pub const Function = api.Function;
```

References: [`api.Function`](api.md#type-function)

<a id="alias-context"></a>

## Context

```zig
pub const Context = api.Context;
```

References: [`api.Context`](api.md#type-context)

<a id="alias-error"></a>

## Error

```zig
pub const Error = api.Error;
```

References: [`api.Error`](api.md#const-error)

<a id="alias-bytecodeloadoptions"></a>

## BytecodeLoadOptions

```zig
pub const BytecodeLoadOptions = api.BytecodeLoadOptions;
```

References: [`api.BytecodeLoadOptions`](api.md#type-bytecodeloadoptions)

<a id="alias-bytecodedumpoptions"></a>

## BytecodeDumpOptions

```zig
pub const BytecodeDumpOptions = api.BytecodeDumpOptions;
```

References: [`api.BytecodeDumpOptions`](api.md#type-bytecodedumpoptions)

<a id="alias-tuple"></a>

## Tuple

```zig
pub const Tuple = api.Tuple;
```

References: [`api.Tuple`](api.md#fn-tuple)

<a id="alias-hostfn"></a>

## HostFn

```zig
pub const HostFn = api.HostFn;
```

References: [`api.HostFn`](api.md#const-hostfn)

<a id="alias-userdata"></a>

## Userdata

```zig
pub const Userdata = api.Userdata;
```

References: [`api.Userdata`](api.md#fn-userdata)

<a id="alias-anyuserdata"></a>

## AnyUserdata

```zig
pub const AnyUserdata = api.AnyUserdata;
```

References: [`api.AnyUserdata`](api.md#type-anyuserdata)

<a id="alias-memoryfile"></a>

## MemoryFile

```zig
pub const MemoryFile = api.MemoryFile;
```

References: [`api.MemoryFile`](api.md#alias-memoryfile)

<a id="alias-memoryfilesystem"></a>

## MemoryFilesystem

```zig
pub const MemoryFilesystem = api.MemoryFilesystem;
```

References: [`api.MemoryFilesystem`](api.md#alias-memoryfilesystem)

