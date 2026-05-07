# Milestone 22: C API Compatibility

## Goal

Expose a Lua 5.5 source-compatible C API for embedding zlua as a library.

This layer must cover the public API exported by the vendored Lua 5.5.0 headers under `vendor/lua-5.5.0/src`. The implementation is not a wrapper around the Zig-native embedding API in `src/api.zig`; it is a separate C stack API that talks directly to `src/runtime.zig` and pushes runtime changes down when the current runtime cannot model CLua semantics yet.

The target is source compatibility, not ABI compatibility. C programs should be able to compile against zlua-provided `lua.h`, `lauxlib.h`, and `lualib.h` and behave like the same program compiled against the vendored CLua oracle. zlua does not promise that existing Lua binary modules or a system `liblua` ABI can be loaded unchanged.

## Scope Source

The compatibility surface is pinned to these vendored files:

| Header | Role |
| --- | --- |
| `vendor/lua-5.5.0/src/lua.h` | Core public C API, constants, types, debug API |
| `vendor/lua-5.5.0/src/lauxlib.h` | Auxiliary library helpers, references, buffers, load helpers |
| `vendor/lua-5.5.0/src/lualib.h` | Standard-library open functions and selected-library loader |
| `vendor/lua-5.5.0/src/luaconf.h` | Public configuration macros, numeric types, export macros, buffer sizes |

Internal CLua headers such as `lstate.h`, `lobject.h`, `ltable.h`, and `lapi.h` are not source compatibility targets.

## Current zlua Context

`src/api.zig` already exposes a high-level Zig API with `State`, typed conversion, rooted handles, host callbacks, capabilities, memory-backed files, and userdata helpers. This API intentionally does not mimic the C stack API.

`src/runtime.zig` already has the core VM objects and several primitives the C API can reuse directly:

| Runtime support | Current shape |
| --- | --- |
| State and options | `runtime.State`, `runtime.StateOptions` |
| Values | `runtime.Value` tagged union |
| Tables | `runtime.Table` with raw storage and metatable pointer |
| Userdata | `runtime.Userdata` with pointer, type name, metatable, finalizer |
| Closures | Lua closures and fixed native function enum |
| Threads | `runtime.Thread` for VM execution and coroutine state |
| Roots | `api_roots` for Zig handles |
| Calls | `callLoadedClosure`, `protectedCallLoadedClosure`, `protectedCall`, `callCollect` |
| Loading | `loadSourceAsClosure*`, `loadBinaryDump`, `loadFileAsClosure*` |
| Debug hooks | line/call/return/count hook plumbing exists |
| Libraries | `stdlib.openLibraries`, `installGlobalTable` |

The C API needs additional runtime-facing infrastructure instead of adapting the Zig API facade.

## Compatibility Contract

zlua should provide:

```text
include/lua.h
include/lauxlib.h
include/lualib.h
include/luaconf.h
libzlua-c or equivalent build artifact
tests/c-api fixtures compiled against CLua and zlua
```

The headers should preserve public names, typedefs, constants, and source macros from the vendored Lua 5.5.0 headers. If the headers are copied or derived from the vendored public headers, preserve the Lua copyright notice.

The library should export C ABI symbols for all public `LUA_API`, `LUALIB_API`, and `LUAMOD_API` functions listed below.

## Explicit Non-Goals

| Non-goal | Reason |
| --- | --- |
| ABI-compatible `liblua.so` replacement | The project roadmap explicitly excludes ABI compatibility |
| CLua internal header compatibility | The public API is only `lua.h`, `lauxlib.h`, `lualib.h`, `luaconf.h` |
| PUC Lua binary chunk compatibility in Milestone 22 | Milestone 23 owns the binary chunk decision |
| Reimplementing the C API on top of `zlua.State` | The stack API needs direct runtime control and CLua-like error behavior |
| Stable zlua-specific C extensions in the first pass | Keep the compatibility surface pinned to Lua 5.5 public API |

## Core Architecture

### State Ownership

Add an internal C API state layer, tentatively `src/c_api.zig`, with a private implementation object behind the public opaque `lua_State` pointer.

```text
CState
  extraspace bytes immediately before lua_State pointer
  allocator bridge from lua_Alloc
  runtime.State
  main CThread
  registry table
  global table reference
  panic function
  warning function and userdata
  active protected-call chain
  string return scratch/roots if needed

CThread
  owning CState
  runtime.Thread or coroutine handle
  persistent C API stack
  current C callback frame metadata
  status
```

`lua_newstate` allocates the C state through the supplied `lua_Alloc`, initializes `runtime.State` directly, creates the registry table, stores `LUA_RIDX_GLOBALS` and `LUA_RIDX_MAINTHREAD`, and returns a pointer that makes `lua_getextraspace(L)` work.

`lua_close` tears down C API stack storage, runtime roots, runtime state, allocator bookkeeping, and the original allocation.

### Allocator Bridge

Lua's allocator has realloc-style semantics:

```c
void *(*lua_Alloc)(void *ud, void *ptr, size_t osize, size_t nsize)
```

zlua needs a Zig allocator adapter backed by `lua_Alloc`. The adapter must track allocation sizes because Zig allocator operations receive alignment and size constraints while Lua's allocator receives `osize`. This bridge should be shared by `runtime.State` so every runtime allocation is visible to the host allocator.

`lua_getallocf` and `lua_setallocf` must reflect the active allocator. `lua_setallocf` is not just metadata; future runtime allocations and frees must route through the new function, matching CLua's public behavior as closely as possible.

### C API Stack

The C API needs a persistent stack independent of ordinary Zig handles. It must support positive indices, negative indices, pseudo-indices, stack growth checks, and API stack effects exactly enough for differential C tests.

Required operations:

| Area | Requirements |
| --- | --- |
| Indexing | `lua_absindex`, positive indices, negative indices, `LUA_REGISTRYINDEX`, `lua_upvalueindex` |
| Stack top | `lua_gettop`, `lua_settop`, `lua_pop`, `lua_checkstack` |
| Mutation | `lua_pushvalue`, `lua_rotate`, `lua_copy`, `lua_insert`, `lua_remove`, `lua_replace` |
| Cross-thread moves | `lua_xmove` between threads belonging to the same global state |
| Error checks | `LUA_USE_APICHECK` compatible assertions where feasible |

The C stack stores `runtime.Value`. Values reachable only through the C API stack must be GC roots.

### Registry

Add a real registry table to the runtime-facing state used by the C API. It should be accessible through `LUA_REGISTRYINDEX`, debug library behavior, and auxlib references.

Required predefined values:

| Name | Index |
| --- | --- |
| reference mechanism reserved slot | `1` |
| `LUA_RIDX_GLOBALS` | `2` |
| `LUA_RIDX_MAINTHREAD` | `3` |

`luaL_ref` and `luaL_unref` should use the same reference list behavior as CLua, including `LUA_NOREF` and `LUA_REFNIL`.

### Dynamic C Closures

The current runtime represents native functions mostly as a fixed `stdlib.NativeFn` enum plus a Zig API callback dispatcher. The C API needs first-class dynamic C closures:

```text
runtime.CClosure
  lua_CFunction pointer
  upvalue array
  debug name if available
  callable from VM
```

`lua_pushcclosure` should create a runtime callable with `n` stack values captured as upvalues. `lua_tocfunction`, `lua_iscfunction`, `lua_upvalueindex`, `lua_getupvalue`, `lua_setupvalue`, `lua_upvalueid`, and `lua_upvaluejoin` all depend on this representation.

C callbacks execute with a `lua_State *` whose API stack initially contains the callback arguments. The callback returns an integer result count, and zlua copies that many top stack values back into the VM result path.

### Error Semantics

CLua uses non-local exits for errors. zlua's C API needs equivalent behavior at the C boundary:

| API | Required behavior |
| --- | --- |
| `lua_error` | Does not return to the C caller when unprotected |
| `lua_call` | Raises errors through panic or a surrounding protected boundary |
| `lua_pcall` | Catches runtime and C callback errors, returns Lua status code |
| `luaL_error` | Formats, pushes, and raises an error |
| `lua_atpanic` | Installs unprotected error fallback |

Implement this with an explicit protected-call frame stack and a small C or Zig-compatible trampoline for `setjmp`/`longjmp` if needed. Keep `longjmp` contained in the C API boundary. Runtime internals should continue using Zig errors and `runtime.ProtectedCallResult`.

### Strings

The C API returns raw string pointers from `lua_tolstring`, `lua_pushlstring`, `lua_pushstring`, and related helpers. zlua's current string representation is `[]const u8`; C compatibility needs stable NUL-terminated storage for string data while preserving embedded NUL bytes and exact lengths.

`lua_tolstring` must also implement CLua's stack mutation when converting numbers to strings.

`lua_pushexternalstring` is public in Lua 5.5. It should be represented explicitly as an external string object with the supplied deallocation callback, not silently treated as an ordinary copied string in the final implementation.

### Userdata

The current `runtime.Userdata` is enough for Zig-owned typed userdata, but the C API needs full Lua userdata semantics:

| Feature | Required work |
| --- | --- |
| Full userdata allocation | `lua_newuserdatauv` allocates inline bytes and returns a stable pointer |
| Multiple user values | `lua_getiuservalue`, `lua_setiuservalue`, compatibility macros for one user value |
| Light userdata | distinct value kind for raw pointers if not already added to runtime.Value |
| Metatable | `lua_getmetatable`, `lua_setmetatable`, auxlib named metatables |
| Finalization | `__gc` behavior through runtime GC |
| To-be-closed slots | `lua_toclose`, `lua_closeslot` |

### Tables, Metatables, And Operators

The C API table functions must route through runtime table/metamethod behavior:

| API kind | Notes |
| --- | --- |
| `lua_gettable`, `lua_getfield`, `lua_geti` | Honor `__index` |
| `lua_settable`, `lua_setfield`, `lua_seti` | Honor `__newindex` |
| `lua_rawget*`, `lua_rawset*` | Bypass metamethods |
| `lua_arith`, `lua_compare`, `lua_len`, `lua_concat` | Use the same metamethod and conversion paths as VM opcodes |
| `lua_next` | Match CLua stack effect and invalid-key error behavior |

### Threads, Coroutines, And Continuations

Lua 5.5 public API includes continuations and yieldable protected calls:

```text
lua_callk
lua_pcallk
lua_yieldk
lua_resume
lua_status
lua_isyieldable
lua_closethread
```

Initial implementation can stage these behind the existing coroutine support, but final Milestone 22 compatibility requires C callback frames, C continuations, and yield restrictions to agree with CLua. `lua_call` and `lua_pcall` macros are only source-level wrappers around the `k` forms.

### Debug API

The runtime already tracks line info, names, locals, upvalues, transfer counts, and hooks for the Lua debug library. The C debug API should reuse and complete that data path.

Required public APIs:

```text
lua_getstack
lua_getinfo
lua_getlocal
lua_setlocal
lua_getupvalue
lua_setupvalue
lua_upvalueid
lua_upvaluejoin
lua_sethook
lua_gethook
lua_gethookmask
lua_gethookcount
```

The public `lua_Debug` struct layout must match the vendored `lua.h`, including `LUA_IDSIZE` and the private `i_ci` pointer field being opaque to users.

## Public API Inventory

This inventory is the implementation checklist. The source of truth is the vendored headers, not this prose.

### Core Functions From `lua.h`

| Area | Functions |
| --- | --- |
| State lifecycle | `lua_newstate`, `lua_close`, `lua_newthread`, `lua_closethread`, `lua_atpanic`, `lua_version` |
| Stack manipulation | `lua_absindex`, `lua_gettop`, `lua_settop`, `lua_pushvalue`, `lua_rotate`, `lua_copy`, `lua_checkstack`, `lua_xmove` |
| Type checks | `lua_isnumber`, `lua_isstring`, `lua_iscfunction`, `lua_isinteger`, `lua_isuserdata`, `lua_type`, `lua_typename` |
| Conversions | `lua_tonumberx`, `lua_tointegerx`, `lua_toboolean`, `lua_tolstring`, `lua_rawlen`, `lua_tocfunction`, `lua_touserdata`, `lua_tothread`, `lua_topointer` |
| Arithmetic and comparison | `lua_arith`, `lua_rawequal`, `lua_compare` |
| Push values | `lua_pushnil`, `lua_pushnumber`, `lua_pushinteger`, `lua_pushlstring`, `lua_pushexternalstring`, `lua_pushstring`, `lua_pushvfstring`, `lua_pushfstring`, `lua_pushcclosure`, `lua_pushboolean`, `lua_pushlightuserdata`, `lua_pushthread` |
| Get values | `lua_getglobal`, `lua_gettable`, `lua_getfield`, `lua_geti`, `lua_rawget`, `lua_rawgeti`, `lua_rawgetp`, `lua_createtable`, `lua_newuserdatauv`, `lua_getmetatable`, `lua_getiuservalue` |
| Set values | `lua_setglobal`, `lua_settable`, `lua_setfield`, `lua_seti`, `lua_rawset`, `lua_rawseti`, `lua_rawsetp`, `lua_setmetatable`, `lua_setiuservalue` |
| Load and call | `lua_callk`, `lua_pcallk`, `lua_load`, `lua_dump` |
| Coroutines | `lua_yieldk`, `lua_resume`, `lua_status`, `lua_isyieldable` |
| Warnings | `lua_setwarnf`, `lua_warning` |
| GC | `lua_gc` |
| Misc | `lua_error`, `lua_next`, `lua_concat`, `lua_len`, `lua_numbertocstring`, `lua_stringtonumber`, `lua_getallocf`, `lua_setallocf`, `lua_toclose`, `lua_closeslot` |
| Debug | `lua_getstack`, `lua_getinfo`, `lua_getlocal`, `lua_setlocal`, `lua_getupvalue`, `lua_setupvalue`, `lua_upvalueid`, `lua_upvaluejoin`, `lua_sethook`, `lua_gethook`, `lua_gethookmask`, `lua_gethookcount` |

### Core Macros And Constants From `lua.h`

| Area | Public names |
| --- | --- |
| Version | `LUA_VERSION_MAJOR_N`, `LUA_VERSION_MINOR_N`, `LUA_VERSION_RELEASE_N`, `LUA_VERSION_NUM`, `LUA_VERSION_RELEASE_NUM`, `LUA_VERSION_MAJOR`, `LUA_VERSION_MINOR`, `LUA_VERSION_RELEASE`, `LUA_VERSION`, `LUA_RELEASE`, `LUA_COPYRIGHT`, `LUA_AUTHORS`, `lua_ident` |
| Loading and stack | `LUA_SIGNATURE`, `LUA_MULTRET`, `LUA_REGISTRYINDEX`, `lua_upvalueindex`, `LUA_MINSTACK`, `lua_getextraspace` |
| Status | `LUA_OK`, `LUA_YIELD`, `LUA_ERRRUN`, `LUA_ERRSYNTAX`, `LUA_ERRMEM`, `LUA_ERRERR` |
| Types | `LUA_TNONE`, `LUA_TNIL`, `LUA_TBOOLEAN`, `LUA_TLIGHTUSERDATA`, `LUA_TNUMBER`, `LUA_TSTRING`, `LUA_TTABLE`, `LUA_TFUNCTION`, `LUA_TUSERDATA`, `LUA_TTHREAD`, `LUA_NUMTYPES` |
| Registry | `LUA_RIDX_GLOBALS`, `LUA_RIDX_MAINTHREAD`, `LUA_RIDX_LAST` |
| Arithmetic | `LUA_OPADD`, `LUA_OPSUB`, `LUA_OPMUL`, `LUA_OPMOD`, `LUA_OPPOW`, `LUA_OPDIV`, `LUA_OPIDIV`, `LUA_OPBAND`, `LUA_OPBOR`, `LUA_OPBXOR`, `LUA_OPSHL`, `LUA_OPSHR`, `LUA_OPUNM`, `LUA_OPBNOT` |
| Comparison | `LUA_OPEQ`, `LUA_OPLT`, `LUA_OPLE` |
| GC controls | `LUA_GCSTOP`, `LUA_GCRESTART`, `LUA_GCCOLLECT`, `LUA_GCCOUNT`, `LUA_GCCOUNTB`, `LUA_GCSTEP`, `LUA_GCISRUNNING`, `LUA_GCGEN`, `LUA_GCINC`, `LUA_GCPARAM`, `LUA_GCPMINORMUL`, `LUA_GCPMAJORMINOR`, `LUA_GCPMINORMAJOR`, `LUA_GCPPAUSE`, `LUA_GCPSTEPMUL`, `LUA_GCPSTEPSIZE`, `LUA_GCPN` |
| Convenience macros | `lua_tonumber`, `lua_tointeger`, `lua_pop`, `lua_newtable`, `lua_register`, `lua_pushcfunction`, `lua_isfunction`, `lua_istable`, `lua_islightuserdata`, `lua_isnil`, `lua_isboolean`, `lua_isthread`, `lua_isnone`, `lua_isnoneornil`, `lua_pushliteral`, `lua_pushglobaltable`, `lua_tostring`, `lua_insert`, `lua_remove`, `lua_replace` |
| Compatibility macros | `lua_newuserdata`, `lua_getuservalue`, `lua_setuservalue`, `lua_resetthread` |
| Debug | `LUA_HOOKCALL`, `LUA_HOOKRET`, `LUA_HOOKLINE`, `LUA_HOOKCOUNT`, `LUA_HOOKTAILCALL`, `LUA_MASKCALL`, `LUA_MASKRET`, `LUA_MASKLINE`, `LUA_MASKCOUNT`, `LUA_IDSIZE` |

### Public Types From `lua.h`

```text
lua_State
lua_Number
lua_Integer
lua_Unsigned
lua_KContext
lua_CFunction
lua_KFunction
lua_Reader
lua_Writer
lua_Alloc
lua_WarnFunction
lua_Debug
lua_Hook
```

### Auxiliary Functions From `lauxlib.h`

| Area | Functions |
| --- | --- |
| Version and type helpers | `luaL_checkversion_`, `luaL_getmetafield`, `luaL_callmeta`, `luaL_tolstring`, `luaL_argerror`, `luaL_typeerror` |
| Argument checks | `luaL_checklstring`, `luaL_optlstring`, `luaL_checknumber`, `luaL_optnumber`, `luaL_checkinteger`, `luaL_optinteger`, `luaL_checkstack`, `luaL_checktype`, `luaL_checkany`, `luaL_checkoption` |
| Userdata and metatables | `luaL_newmetatable`, `luaL_setmetatable`, `luaL_testudata`, `luaL_checkudata` |
| Errors and results | `luaL_where`, `luaL_error`, `luaL_fileresult`, `luaL_execresult` |
| Allocation | `luaL_alloc` |
| References | `luaL_ref`, `luaL_unref` |
| Loading | `luaL_loadfilex`, `luaL_loadbufferx`, `luaL_loadstring`, `luaL_newstate`, `luaL_makeseed`, `luaL_len` |
| String helpers | `luaL_addgsub`, `luaL_gsub` |
| Library helpers | `luaL_setfuncs`, `luaL_getsubtable`, `luaL_traceback`, `luaL_requiref` |
| Buffer API | `luaL_buffinit`, `luaL_prepbuffsize`, `luaL_addlstring`, `luaL_addstring`, `luaL_addvalue`, `luaL_pushresult`, `luaL_pushresultsize`, `luaL_buffinitsize` |

### Auxiliary Macros And Types From `lauxlib.h`

| Area | Public names |
| --- | --- |
| Constants | `LUA_GNAME`, `LUA_ERRFILE`, `LUA_LOADED_TABLE`, `LUA_PRELOAD_TABLE`, `LUAL_NUMSIZES`, `LUA_NOREF`, `LUA_REFNIL`, `LUA_FILEHANDLE` |
| Types | `luaL_Buffer`, `luaL_Reg`, `luaL_Stream` |
| Version macros | `luaL_checkversion` |
| Library macros | `luaL_newlibtable`, `luaL_newlib` |
| Argument macros | `luaL_argcheck`, `luaL_argexpected`, `luaL_checkstring`, `luaL_optstring`, `luaL_typename`, `luaL_opt` |
| Loading macros | `luaL_dofile`, `luaL_dostring`, `luaL_loadfile`, `luaL_loadbuffer` |
| Metatable macros | `luaL_getmetatable` |
| Integer macro | `luaL_intop` |
| Failure macro | `luaL_pushfail` |
| Buffer macros | `luaL_bufflen`, `luaL_buffaddr`, `luaL_addchar`, `luaL_addsize`, `luaL_buffsub`, `luaL_prepbuffer` |
| Deprecated conversion macros when enabled | `luaL_checkunsigned`, `luaL_optunsigned`, `luaL_checkint`, `luaL_optint`, `luaL_checklong`, `luaL_optlong` |

### Standard Library Functions From `lualib.h`

| Area | Functions and names |
| --- | --- |
| Library open functions | `luaopen_base`, `luaopen_package`, `luaopen_coroutine`, `luaopen_debug`, `luaopen_io`, `luaopen_math`, `luaopen_os`, `luaopen_string`, `luaopen_table`, `luaopen_utf8` |
| Library selection | `luaL_openselectedlibs`, `luaL_openlibs` |
| Library names and masks | `LUA_GLIBK`, `LUA_LOADLIBNAME`, `LUA_LOADLIBK`, `LUA_COLIBNAME`, `LUA_COLIBK`, `LUA_DBLIBNAME`, `LUA_DBLIBK`, `LUA_IOLIBNAME`, `LUA_IOLIBK`, `LUA_MATHLIBNAME`, `LUA_MATHLIBK`, `LUA_OSLIBNAME`, `LUA_OSLIBK`, `LUA_STRLIBNAME`, `LUA_STRLIBK`, `LUA_TABLIBNAME`, `LUA_TABLIBK`, `LUA_UTF8LIBNAME`, `LUA_UTF8LIBK`, `LUA_VERSUFFIX` |

### Configuration Surface From `luaconf.h`

zlua should keep these public configuration decisions aligned with the vendored default unless a portability target requires a documented variation:

| Area | Vendored default |
| --- | --- |
| Integer type | `LUA_INTEGER` is `long long` by default |
| Number type | `LUA_NUMBER` is `double` by default |
| Unsigned type | `LUA_UNSIGNED` follows `unsigned LUA_INTEGER` |
| Continuation context | `LUA_KCONTEXT` is `intptr_t` when available, otherwise `ptrdiff_t` |
| Export macros | `LUA_API`, `LUALIB_API`, `LUAMOD_API` source-compatible definitions |
| Path macros | `LUA_PATH_DEFAULT`, `LUA_CPATH_DEFAULT`, `LUA_PATH_SEP`, `LUA_PATH_MARK`, `LUA_EXEC_DIR`, `LUA_DIRSEP`, `LUA_IGMARK` |
| Compatibility macros | `LUA_COMPAT_GLOBAL`, `lua_strlen`, `lua_objlen`, `lua_equal`, `lua_lessthan` |
| API-affecting sizes | `LUA_EXTRASPACE`, `LUA_IDSIZE`, `LUAL_BUFFERSIZE`, `LUAI_MAXALIGN` |

## Implementation Phases

### Phase 0: Harness And Headers

Goal: compile C fixtures against CLua and zlua with the same source.

Tasks:

```text
Add zlua C API headers derived from vendored public headers
Add Zig library target exporting C ABI symbols
Add build step for C API differential tests
Add C fixture runner that builds each fixture twice
Add header smoke fixture that includes lua.h, lauxlib.h, lualib.h
Add symbol inventory test to keep docs and implementation honest
```

Acceptance criteria:

```text
C fixture can include zlua headers
CLua and zlua variants compile from the same C source
Missing exported symbols are reported clearly
```

### Phase 1: State, Allocator, Registry, And Stack

Goal: make basic stack programs compile and run.

Tasks:

```text
Implement lua_State backing structs
Implement extraspace layout
Implement lua_newstate and lua_close
Implement luaL_newstate and luaL_alloc
Bridge lua_Alloc into runtime allocator
Create registry table with predefined slots
Implement stack indexing and mutation
Root all C stack values for GC
Implement basic type tags and names
```

Acceptance criteria:

```text
Stack manipulation fixture matches CLua
Allocator fixture sees expected allocation and free calls
Registry fixture can read globals and main thread slots
```

### Phase 2: Values, Tables, And Metatables

Goal: support ordinary data exchange.

Tasks:

```text
Implement push and conversion APIs
Implement stable C string pointers and lengths
Implement raw and metamethod table get/set APIs
Implement table creation and length
Implement arithmetic, comparison, concat, len, next
Implement light userdata runtime value if missing
```

Acceptance criteria:

```text
Numbers strings booleans nil and light userdata round trip
Table access stack effects match CLua
Metamethod fixtures match CLua
```

### Phase 3: Loading, Calls, Errors, And Panic

Goal: execute Lua chunks and C callbacks with CLua-compatible error behavior.

Tasks:

```text
Implement lua_load reader loop
Implement luaL_loadbufferx luaL_loadstring luaL_loadfilex
Implement lua_callk and lua_pcallk non-continuation behavior first
Implement lua_error and luaL_error
Implement panic function handling
Implement status code mapping
Implement protected-call frame stack
```

Acceptance criteria:

```text
loadstring and pcall fixtures match CLua
lua_call unprotected error reaches panic path
lua_error from C callback behaves like CLua
```

### Phase 4: Dynamic C Closures And Upvalues

Goal: make C functions first-class Lua callables.

Tasks:

```text
Add runtime dynamic C closure object
Implement lua_pushcclosure and lua_pushcfunction macro support
Expose C callback arguments through C API stack
Return callback results from top of C stack
Implement lua_tocfunction and lua_iscfunction
Implement C closure upvalue pseudo-indices
Implement get/set/upvalue id/join APIs for C and Lua closures
```

Acceptance criteria:

```text
C callback fixture matches CLua
C closure upvalue fixture matches CLua
Lua calling C and C calling Lua works under pcall
```

### Phase 5: Userdata, User Values, And Finalization

Goal: support the C API userdata model.

Tasks:

```text
Add full userdata allocation mode with inline bytes
Support multiple user values
Implement lua_newuserdatauv and compatibility macros
Implement lua_touserdata and lua_isuserdata behavior
Implement uservalue get/set APIs
Implement named metatable helpers in auxlib
Implement __gc finalization compatibility
Implement lua_toclose and lua_closeslot
```

Acceptance criteria:

```text
Full userdata fixture matches CLua
User values fixture matches CLua
Finalizer fixture matches CLua where GC timing is forced
To-be-closed userdata fixture matches CLua
```

### Phase 6: Coroutines And Continuations

Goal: cover yieldable C API behavior.

Tasks:

```text
Map lua_newthread to runtime thread objects
Implement lua_resume lua_yieldk lua_status lua_isyieldable lua_closethread
Implement C continuation records for lua_callk and lua_pcallk
Enforce yield restrictions across non-yieldable C frames
Preserve C API stack state across yield and resume
```

Acceptance criteria:

```text
Coroutine C fixtures match CLua
Yield across allowed C frames works
Yield across forbidden C frames errors like CLua
```

### Phase 7: GC, Warnings, External Strings, And Misc APIs

Goal: finish core API behavior outside debug and auxlib.

Tasks:

```text
Implement lua_gc option matrix and parameter behavior
Implement lua_setwarnf and lua_warning
Implement lua_pushexternalstring with allocator-backed finalization
Implement lua_dump using current zlua binary chunk support
Implement lua_numbertocstring and lua_stringtonumber
Implement lua_getallocf and lua_setallocf edge cases
```

Acceptance criteria:

```text
GC API fixtures match CLua for observable behavior
Warning fixture matches CLua
External string lifecycle fixture passes
```

### Phase 8: Auxlib And Standard Library Open Functions

Goal: complete `lauxlib.h` and `lualib.h`.

Tasks:

```text
Implement all luaL_check* and luaL_opt* helpers
Implement luaL_ref and luaL_unref free-list behavior
Implement luaL_Buffer growth and stack interaction
Implement luaL_fileresult and luaL_execresult
Implement luaL_requiref and luaL_setfuncs
Export luaopen_* functions for every standard library
Implement luaL_openselectedlibs and luaL_openlibs macro behavior
```

Acceptance criteria:

```text
Auxlib fixtures match CLua
Buffer fixtures match CLua
Standard library open fixtures match CLua
```

### Phase 9: Debug API

Goal: finish public debug functions and hooks.

Tasks:

```text
Implement lua_Debug filling for `n`, `S`, `l`, `u`, `t`, and `r` options
Implement local get/set for Lua and C frames where CLua exposes them
Implement hook installation and hook metadata
Implement transfer fields ftransfer and ntransfer
Implement short_src formatting
```

Acceptance criteria:

```text
Debug info fixtures match CLua for covered fields
Hook call line return and count fixtures match CLua
Official debug-library behavior remains passing
```

## Testing Plan

Add a new C API differential test family under `tests/c-api`.

Each fixture should compile and run twice:

```text
CLua build: include vendor/lua-5.5.0/src headers and link vendored CLua sources/artifact
zlua build: include zlua C API headers and link zlua C API artifact
```

Compare:

```text
stdout
stderr
exit code
signal/crash status
timeout
```

Normalize only unavoidable implementation details:

```text
absolute paths
pointer addresses when the test explicitly prints addresses
platform-specific dynamic-loader messages
traceback paths where existing normalizers already apply
```

Do not normalize stack effects, type names, return counts, success vs failure, or error status codes.

Recommended fixture groups:

| Group | Coverage |
| --- | --- |
| `headers` | include order, macro compilation, typedef sizes, symbol availability |
| `state` | newstate, close, extraspace, allocator, panic, version |
| `stack` | gettop, settop, absindex, rotate, copy, checkstack, xmove |
| `types` | type, typename, is*, to*, rawlen, topointer |
| `push` | nil, booleans, integers, numbers, strings, formatted strings, light userdata, thread |
| `tables` | global access, table access, raw access, metatables, length, next |
| `calls` | load, call, pcall, multret, error handler index, Lua calls C, C calls Lua |
| `errors` | lua_error, luaL_error, arg errors, panic path, syntax/runtime/memory status |
| `closures` | cclosure upvalues, get/set upvalue, upvalueid, upvaluejoin |
| `userdata` | full userdata, user values, metatables, finalizers, toclose |
| `coroutines` | newthread, resume, yield, continuations, close/reset |
| `gc` | gc options, collect, count, step, modes, finalization |
| `auxlib` | check/opt helpers, refs, buffers, gsub, requiref, traceback |
| `stdlib-open` | luaopen_* functions and selected library masks |
| `debug` | getinfo, stack levels, locals, hooks, transfer fields |

The harness should also have an inventory test that fails when a public function declared in the vendored headers has no zlua implementation status entry.

## Build Integration

Add build steps without making normal Zig embedding users pay C API costs unless they opt in.

Proposed build targets:

```text
zig build c-api
zig build test-c-api
zig build ci-c-api
```

Potential artifacts:

```text
zig-out/include/lua.h
zig-out/include/lauxlib.h
zig-out/include/lualib.h
zig-out/include/luaconf.h
zig-out/lib/libzlua.a
zig-out/lib/libzlua.so or platform equivalent when requested
zig-out/bin/zlua-test-c-api
```

`zig build ci` can include `test-c-api` after the harness is stable. Before that, keep it as an explicit dashboard step with expected failures tracked per fixture.

## Status Tracking

Track each public C API item with one of these states:

```text
not-started
stubbed
implemented
tested-clua-diff
deviation-documented
```

Use a checked-in status file or generated test manifest so new vendored public symbols cannot be forgotten.

Suggested location:

```text
tests/fixtures/c_api_status.toml
```

Each deviation should include:

```text
symbol
reason
observable behavior
planned resolution
test fixture
```

## Open Design Decisions

| Decision | Default recommendation |
| --- | --- |
| Header source | Derive from vendored public headers and preserve copyright |
| Library name | Install as zlua-owned artifact first, not `liblua` |
| Dynamic module loading | Defer full dynamic loading unless package C searchers become a Milestone 22 acceptance gate |
| Binary chunks | Implement `lua_dump`/`lua_load` with zlua binary chunks until Milestone 23 decides PUC compatibility |
| Panic implementation | Use a contained C trampoline if Zig-only non-local exit is not practical |
| C API default capabilities | Match CLua behavior for `luaL_openlibs`; add zlua-specific capability configuration only after public compatibility is working |

## Acceptance Criteria

Milestone 22 is complete when:

```text
All public functions from vendored lua.h lauxlib.h lualib.h are exported or documented with a tracked deviation
All public source macros and typedefs compile for C fixtures
C fixtures compile unchanged against vendored CLua and zlua
Core stack, value, table, call, error, userdata, coroutine, auxlib, lualib, and debug fixtures match CLua
C callbacks interact directly with runtime closures and do not use src/api.zig
Values reachable from the C API stack, registry, closures, userdata user values, and threads survive GC correctly
Protected calls restore stack and runtime state after errors
Unprotected errors follow CLua panic/non-local-exit behavior
No ABI compatibility promise is made in docs or build artifact names
```
