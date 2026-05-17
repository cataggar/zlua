# root

## Navigation

- [API Index](README.md)

<details>
<summary>All documents</summary>

- [root](root.md)
- [frontend](frontend.md)
- [errors](errors.md)
- [frontend.source](frontend/source.md)
- [frontend.token](frontend/token.md)
- [frontend.diagnostic](frontend/diagnostic.md)
- [frontend.lexer](frontend/lexer.md)
- [frontend.ast](frontend/ast.md)
- [frontend.parser](frontend/parser.md)
- [compile](compile.md)
- [compile.resolver](compile/resolver.md)
- [compile.bytecode](compile/bytecode.md)
- [compile.proto](compile/proto.md)
- [compile.compiler](compile/compiler.md)
- [compile.disasm](compile/disasm.md)
- [api](api.md)
- [runtime](runtime.md)
- [runtime.chunk](runtime/chunk.md)
- [runtime.types](runtime/types.md)
- [runtime.value](runtime/value.md)
- [runtime.execute](runtime/execute.md)
- [testing.process](testing/process.md)
- [runtime.state](runtime/state.md)
- [runtime.call](runtime/call.md)
- [runtime.coroutine](runtime/coroutine.md)
- [runtime.debug](runtime/debug.md)
- [runtime.gc](runtime/gc.md)
- [runtime.host](runtime/host.md)
- [stdlib](stdlib.md)
- [stdlib.base](stdlib/base.md)
- [stdlib.table](stdlib/table.md)
- [stdlib.string](stdlib/string.md)
- [stdlib.math](stdlib/math.md)
- [stdlib.utf8](stdlib/utf8.md)
- [stdlib.coroutine](stdlib/coroutine.md)
- [stdlib.debug](stdlib/debug.md)
- [stdlib.package](stdlib/package.md)
- [stdlib.io](stdlib/io.md)
- [stdlib.os](stdlib/os.md)
- [stdlib.json](stdlib/json.md)
- [stdlib.zerde_lua](stdlib/zerde_lua.md)
- [stdlib.toml](stdlib/toml.md)
- [stdlib.msgpack](stdlib/msgpack.md)
- [stdlib.csv](stdlib/csv.md)
- [runtime.vm](runtime/vm.md)
- [runtime.tests](runtime/tests.md)
- [runtime.internal](runtime/internal.md)
- [testing](testing.md)
- [testing.clua](testing/clua.md)
- [testing.bench_runner](testing/bench_runner.md)
- [testing.c_api_runner](testing/c_api_runner.md)
- [testing.diff_runner](testing/diff_runner.md)
- [testing.expected_failures](testing/expected_failures.md)
- [testing.metadata](testing/metadata.md)
- [testing.normalizer](testing/normalizer.md)
- [testing.extension_runner](testing/extension_runner.md)
- [testing.official_suite](testing/official_suite.md)

</details>

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
- [FilesystemCapability](#alias-filesystemcapability)
- [CustomFilesystem](#alias-customfilesystem)
- [EnvironmentCapability](#alias-environmentcapability)
- [CustomEnvironment](#alias-customenvironment)
- [ClockCapability](#alias-clockcapability)
- [CustomClock](#alias-customclock)
- [ProcessCapability](#alias-processcapability)
- [CustomProcess](#alias-customprocess)
- [ProcessResult](#alias-processresult)
- [ProcessStatus](#alias-processstatus)

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
pub const version = "0.3.0";
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

References: [`api.Error`](api.md#type-error)

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

<a id="alias-filesystemcapability"></a>

## FilesystemCapability

```zig
pub const FilesystemCapability = api.FilesystemCapability;
```

References: [`api.FilesystemCapability`](api.md#alias-filesystemcapability)

<a id="alias-customfilesystem"></a>

## CustomFilesystem

```zig
pub const CustomFilesystem = api.CustomFilesystem;
```

References: [`api.CustomFilesystem`](api.md#alias-customfilesystem)

<a id="alias-environmentcapability"></a>

## EnvironmentCapability

```zig
pub const EnvironmentCapability = api.EnvironmentCapability;
```

References: [`api.EnvironmentCapability`](api.md#alias-environmentcapability)

<a id="alias-customenvironment"></a>

## CustomEnvironment

```zig
pub const CustomEnvironment = api.CustomEnvironment;
```

References: [`api.CustomEnvironment`](api.md#alias-customenvironment)

<a id="alias-clockcapability"></a>

## ClockCapability

```zig
pub const ClockCapability = api.ClockCapability;
```

References: [`api.ClockCapability`](api.md#alias-clockcapability)

<a id="alias-customclock"></a>

## CustomClock

```zig
pub const CustomClock = api.CustomClock;
```

References: [`api.CustomClock`](api.md#alias-customclock)

<a id="alias-processcapability"></a>

## ProcessCapability

```zig
pub const ProcessCapability = api.ProcessCapability;
```

References: [`api.ProcessCapability`](api.md#alias-processcapability)

<a id="alias-customprocess"></a>

## CustomProcess

```zig
pub const CustomProcess = api.CustomProcess;
```

References: [`api.CustomProcess`](api.md#alias-customprocess)

<a id="alias-processresult"></a>

## ProcessResult

```zig
pub const ProcessResult = api.ProcessResult;
```

References: [`api.ProcessResult`](api.md#alias-processresult)

<a id="alias-processstatus"></a>

## ProcessStatus

```zig
pub const ProcessStatus = api.ProcessStatus;
```

References: [`api.ProcessStatus`](api.md#alias-processstatus)

