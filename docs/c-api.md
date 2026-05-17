# Lua C API Compatibility

zlua provides a source-compatible Lua 5.5 C API layer as a static library named `zlua-c`. It is intended for C hosts or fixtures that want Lua 5.5 C API semantics backed by zlua, not for ABI-compatible replacement of an existing system `liblua`.

The Zig-native embedding API remains zlua's main public API. Use `zlua.State` from Zig hosts when you want explicit capabilities, resource limits, typed callbacks, and rooted handles.

## Scope

The tracked Lua 5.5 public C API symbol inventory lives in `tests/fixtures/c_api_status.toml`. Every listed symbol is currently marked `tested-clua-diff`, which means there is fixture coverage that builds and runs against both the downloaded Lua 5.5 C implementation and `zlua-c`.

Covered areas include:

| Area | Examples |
| --- | --- |
| State and stack | `lua_newstate`, `lua_close`, `lua_gettop`, `lua_settop`, `lua_checkstack`, `lua_xmove`. |
| Value conversion | `lua_type`, `lua_tointegerx`, `lua_tolstring`, `lua_push*`, `lua_rawlen`, `lua_topointer`. |
| Tables and metatables | `lua_gettable`, `lua_settable`, raw accessors, user values, metatables, refs. |
| Calls and loading | `lua_callk`, `lua_pcallk`, `lua_load`, `lua_dump`, Lua status codes. |
| Coroutines | `lua_newthread`, `lua_resume`, `lua_yieldk`, `lua_status`, `lua_closethread`. |
| Debug API | stack inspection, locals/upvalues, hooks, traceback support. |
| Auxlib | argument checks, buffers, refs, loaders, `luaL_requiref`, traceback helpers. |
| Standard-library openers | `luaopen_base`, `luaopen_package`, `luaopen_io`, `luaL_openselectedlibs`, and related openers. |

The exact tested symbol set should be read from `tests/fixtures/c_api_status.toml` when changing or auditing C API behavior.

## Build Artifacts

Build the C API library, installed Lua 5.5 headers, and harness:

```sh
zig build c-api
```

Installed artifacts:

| Artifact | Purpose |
| --- | --- |
| `zig-out/lib/libzlua-c.a` | Static zlua C API compatibility library. |
| `zig-out/include/lua.h` | Lua 5.5 public C API header. |
| `zig-out/include/lauxlib.h` | Lua 5.5 auxiliary library header. |
| `zig-out/include/lualib.h` | Lua 5.5 standard-library opener header. |
| `zig-out/include/luaconf.h` | Lua 5.5 configuration header. |
| `zig-out/bin/zlua-test-c-api` | Standalone C API differential fixture harness. |

The installed headers are taken from the downloaded Lua 5.5 source tree so C sources can include normal Lua headers:

```c
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
```

## Linking

The fixture harness links C programs with `zig cc` like this:

```sh
zig cc -std=c99 -Wall -Wextra \
  -I zig-out/include \
  main.c zig-out/lib/libzlua-c.a \
  -o main
```

For application builds, use the same include directory and static library path, adjusted for your build system and target. The C API library is target-specific; rebuild it with the same `-Dtarget` and `-Doptimize` choices expected by the consuming program.

## Verification

Run the C API compatibility gate:

```sh
zig build ci-c-api
```

Run a focused fixture or directory:

```sh
zig build test-c-api -- tests/c-api/stack
zig build test-c-api -- tests/c-api/coroutines/newthread_resume.c
```

The harness compiles each fixture twice, once against the downloaded CLua library and once against `zlua-c`, then compares exit status, stdout, and stderr. It also validates the public symbol inventory before fixture execution.

## Caveats

zlua C API compatibility is practical and fixture-backed, but it has deliberate boundaries:

| Boundary | Meaning |
| --- | --- |
| Static library, not ABI drop-in | `zlua-c` is not promised to be binary-compatible with an existing system `liblua` or dynamically loaded native modules. Rebuild C code against the installed headers and static library. |
| Lua 5.5 target only | zlua targets Lua 5.5 semantics and headers. Multi-version Lua modes and LuaJIT compatibility are non-goals. |
| zlua binary chunks | `lua_dump` produces zlua binary chunks. PUC Lua `luac` binary chunk compatibility is not a goal. |
| Dynamic native modules | zlua does not provide LuaRocks/native dynamic module compatibility. Prefer statically linked C hosts or Lua source modules. |
| Host capabilities differ by entrypoint | The standalone CLI opens full host access by default. Zig embedding defaults are sandboxed. C API states use the C API layer's state creation/open-library behavior and should be tested under the intended host setup. |

When changing C API behavior, add or update a C fixture under `tests/c-api`, keep the relevant symbol at `tested-clua-diff`, and run at least the focused fixture plus `zig build ci-c-api`.
