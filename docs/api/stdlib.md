# stdlib

## Navigation

- [API Index](README.md)
- Previous: [runtime.host](runtime/host.md)
- Next: [stdlib.base](stdlib/base.md)
- Submodules: [stdlib.base](stdlib/base.md), [stdlib.table](stdlib/table.md), [stdlib.string](stdlib/string.md), [stdlib.math](stdlib/math.md), [stdlib.utf8](stdlib/utf8.md), [stdlib.coroutine](stdlib/coroutine.md), [stdlib.debug](stdlib/debug.md), [stdlib.package](stdlib/package.md), [stdlib.io](stdlib/io.md), [stdlib.os](stdlib/os.md), [stdlib.json](stdlib/json.md), [stdlib.zerde_lua](stdlib/zerde_lua.md), [stdlib.toml](stdlib/toml.md), [stdlib.msgpack](stdlib/msgpack.md)

## Functions

- [openLibraries](#fn-openlibraries)
- [installGlobalTable](#fn-installglobaltable)
- [callNative](#fn-callnative)

## Types

- [LibrarySelection](#type-libraryselection)
- [LibrarySet](#type-libraryset)

## Aliases

- [NativeFn](#alias-nativefn)

## Imports

- [base](#import-base) `@import("stdlib/base.zig")`
- [table](#import-table) `@import("stdlib/table.zig")`
- [string](#import-string) `@import("stdlib/string.zig")`
- [math](#import-math) `@import("stdlib/math.zig")`
- [utf8](#import-utf8) `@import("stdlib/utf8.zig")`
- [coroutine](#import-coroutine) `@import("stdlib/coroutine.zig")`
- [debug](#import-debug) `@import("stdlib/debug.zig")`
- [package](#import-package) `@import("stdlib/package.zig")`
- [io](#import-io) `@import("stdlib/io.zig")`
- [os](#import-os) `@import("stdlib/os.zig")`
- [json](#import-json) `@import("stdlib/json.zig")`
- [toml](#import-toml) `@import("stdlib/toml.zig")`
- [msgpack](#import-msgpack) `@import("stdlib/msgpack.zig")`

<a id="import-base"></a>

## base

```zig
pub const base = @import("stdlib/base.zig");
```

<a id="import-table"></a>

## table

```zig
pub const table = @import("stdlib/table.zig");
```

<a id="import-string"></a>

## string

```zig
pub const string = @import("stdlib/string.zig");
```

<a id="import-math"></a>

## math

```zig
pub const math = @import("stdlib/math.zig");
```

<a id="import-utf8"></a>

## utf8

```zig
pub const utf8 = @import("stdlib/utf8.zig");
```

<a id="import-coroutine"></a>

## coroutine

```zig
pub const coroutine = @import("stdlib/coroutine.zig");
```

<a id="import-debug"></a>

## debug

```zig
pub const debug = @import("stdlib/debug.zig");
```

<a id="import-package"></a>

## package

```zig
pub const package = @import("stdlib/package.zig");
```

<a id="import-io"></a>

## io

```zig
pub const io = @import("stdlib/io.zig");
```

<a id="import-os"></a>

## os

```zig
pub const os = @import("stdlib/os.zig");
```

<a id="import-json"></a>

## json

```zig
pub const json = @import("stdlib/json.zig");
```

<a id="import-toml"></a>

## toml

```zig
pub const toml = @import("stdlib/toml.zig");
```

<a id="import-msgpack"></a>

## msgpack

```zig
pub const msgpack = @import("stdlib/msgpack.zig");
```

<a id="type-libraryselection"></a>

## LibrarySelection

```zig
pub const LibrarySelection = union(enum) { ... };
```

### Fields

```zig
    libraries: LibrarySet
```


### Nested Declarations

- [toSet](#fn-libraryselection-toset)
- [isEmpty](#fn-libraryselection-isempty)

<a id="fn-libraryselection-toset"></a>

### LibrarySelection.toSet

```zig
pub fn toSet(self: LibrarySelection) LibrarySet
```

References: [`LibrarySelection`](#type-libraryselection), [`LibrarySet`](#type-libraryset)

<a id="fn-libraryselection-isempty"></a>

### LibrarySelection.isEmpty

```zig
pub fn isEmpty(self: LibrarySelection) bool
```

References: [`LibrarySelection`](#type-libraryselection)

<a id="type-libraryset"></a>

## LibrarySet

```zig
pub const LibrarySet = struct { ... };
```

### Fields

```zig
    base: bool = false
    table: bool = false
    string: bool = false
    math: bool = false
    utf8: bool = false
    coroutine: bool = false
    io: bool = false
    os: bool = false
    debug: bool = false
    package: bool = false
    json: bool = false
    toml: bool = false
    msgpack: bool = false
```


### Nested Declarations

- [safe](#fn-libraryset-safe)
- [full](#fn-libraryset-full)
- [isEmpty](#fn-libraryset-isempty)

<a id="fn-libraryset-safe"></a>

### LibrarySet.safe

```zig
pub fn safe() LibrarySet
```

References: [`LibrarySet`](#type-libraryset)

<a id="fn-libraryset-full"></a>

### LibrarySet.full

```zig
pub fn full() LibrarySet
```

References: [`LibrarySet`](#type-libraryset)

<a id="fn-libraryset-isempty"></a>

### LibrarySet.isEmpty

```zig
pub fn isEmpty(self: LibrarySet) bool
```

References: [`LibrarySet`](#type-libraryset)

<a id="fn-openlibraries"></a>

## openLibraries

```zig
pub fn openLibraries(state: *State, selection: LibrarySelection) !void
```

References: [`LibrarySelection`](#type-libraryselection)

<a id="fn-installglobaltable"></a>

## installGlobalTable

```zig
pub fn installGlobalTable(state: *State) !void
```

<a id="alias-nativefn"></a>

## NativeFn

```zig
pub const NativeFn = runtime.NativeFn;
```

References: [`runtime.NativeFn`](runtime.md#alias-nativefn)

<a id="fn-callnative"></a>

## callNative

```zig
pub fn callNative(state: *State, native: NativeFn, thread: *Thread, op: bytecode.Call) !void
```

References: [`NativeFn`](#alias-nativefn)

