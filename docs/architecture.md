# Architecture

zlua is a source-compatible Lua 5.5 implementation written in Zig. The implementation parses Lua source, resolves declarations, lowers to zlua bytecode, executes on a register-oriented VM, opens standard libraries, and exposes both a Zig-native embedding API and a Lua C API compatibility layer.

The official Lua 5.5 C implementation, vendored under `vendor/lua-5.5.0`, is the behavioral oracle. Compatibility work should be validated against CLua rather than inferred from manuals or older planning notes.

## Build Outputs

`build.zig` wires the main development artifacts:

| Artifact | Purpose |
| --- | --- |
| `zlua` | CLI executable from `src/main.zig`. |
| `lua5.5` | Vendored CLua oracle built from `vendor/lua-5.5.0/src`. |
| `zlua-test-diff` | Differential fixture harness. |
| `zlua-test-official` | Official Lua 5.5 dashboard harness. |
| `zlua-test-bench` | zlua-vs-CLua benchmark harness. |
| `zlua-c` | Static C API compatibility library from `src/c_api.zig`. |
| `zlua-test-c-api` | C API differential fixture harness. |
| `examples/embed/*` | Zig-native embedding examples. |

The library facade is `src/root.zig`. It re-exports `frontend`, `compile`, `runtime`, `stdlib`, `testing`, and the public embedding types such as `State`, `Table`, `Function`, `Context`, `Value`, `Tuple`, `Userdata`, and `MemoryFilesystem`.

## Source Layout

| Path | Role |
| --- | --- |
| `src/main.zig` | CLI argument parsing, REPL, dump modes, script execution, and test harness subcommands. |
| `src/frontend.zig` and `src/frontend/` | Source handling, tokens, lexer, AST, parser, and diagnostics. |
| `src/compile.zig` and `src/compile/` | Declaration resolver, bytecode representation, prototypes, compiler, and disassembler. |
| `src/runtime.zig` and `src/runtime/` | VM state, values, calls, threads, coroutines, GC, debug state, binary chunks, and host capabilities. |
| `src/stdlib.zig` and `src/stdlib/` | Lua libraries: base, table, string, math, utf8, coroutine, debug, package, io, and os. |
| `src/api.zig` | Stable Zig-native embedding facade. |
| `src/c_api.zig` | Lua 5.5 C API compatibility layer. |
| `src/testing.zig` and `src/testing/` | CLua discovery, process execution, differential tests, official dashboard, C API tests, benchmark harness, metadata, and normalization. |

Top-level facade files such as `src/runtime.zig`, `src/compile.zig`, and `src/stdlib.zig` collect the nested implementation modules and provide stable import points inside the codebase.

## Execution Pipeline

Lua source flows through the same major phases in the CLI, embedding API, and test harnesses:

1. Source text is tokenized by `frontend.lexer`.
2. Tokens are parsed into `frontend.ast.Ast` by `frontend.parser`.
3. `compile.resolver` validates declarations, labels, scopes, globals, local attributes, and assignment rules.
4. `compile.compiler` lowers the AST to `compile.proto.Proto` using the bytecode definitions in `compile.bytecode`.
5. `runtime.State` loads the prototype into closures and executes it through the VM.
6. Standard-library calls dispatch into native Zig implementations in `src/stdlib/`.

The differential harness can stop at `lex`, `parse`, `resolve`, or `compile` to compare acceptance with CLua before executing code.

## Runtime Model

`runtime.State` owns the VM heap, interned strings, globals, registry roots, loaded standard-library state, host capability configuration, thread state, GC bookkeeping, and current error state.

Runtime values and objects are defined primarily in `src/runtime/types.zig` and manipulated through `src/runtime/state.zig`, `src/runtime/vm.zig`, and related modules. The runtime supports Lua scalars, strings, tables, closures, C closures, userdata, threads/coroutines, upvalues, metatables, weak tables, finalizers, debug hooks, to-be-closed values, and zlua binary chunks.

The collector is compatibility-oriented. It is exercised heavily by official Lua tests, differential GC fixtures, C API fixtures, and benchmark fixtures. Public embedding code should not depend on GC object layout or root internals; those are runtime implementation details.

## Standard Libraries

`src/stdlib.zig` exposes a library selection model:

| Selection | Libraries |
| --- | --- |
| `none` | No standard libraries. |
| `base` | Base globals only. |
| `safe` | Base, table, string, math, utf8, and coroutine. |
| `full` | Safe libraries plus io, os, debug, and package. |
| `libraries` | Explicit per-library set. |

The CLI defaults to full host-oriented behavior. The Zig embedding API defaults to `.safe` libraries and sandboxed host capabilities.

## Host Capabilities

Host effects are modeled explicitly in the runtime and surfaced by `zlua.api.Capabilities`:

| Capability | Purpose |
| --- | --- |
| I/O | Standard input, output, error, and runtime `std.Io` plumbing. |
| Filesystem | Disabled, read-only memory files, read/write memory filesystem, or host current working directory. |
| Environment | Disabled or a provided environment map. |
| Clock | Disabled, fixed deterministic values, or host clock behavior. |
| Process | Disabled or enabled process execution. |

Embedding hosts should grant only the capabilities required by their Lua code. The CLI uses the lower-level runtime directly with full host filesystem, environment, process, and I/O access.

## Public API Layers

zlua has three API layers with different stability expectations:

| Layer | Import | Audience | Stability |
| --- | --- | --- | --- |
| Zig embedding API | `@import("zlua").State` and aliases | Zig hosts | Intended public API. |
| Runtime internals | `@import("zlua").runtime` | zlua internals and tests | Not a stable embedding contract. |
| C API compatibility | `src/c_api.zig`, installed Lua headers | C hosts and compatibility tests | Compatibility layer, tracked by fixture coverage. |

New embedding operations should usually be added as small `src/api.zig` facade methods instead of exposing runtime internals.

## Binary Chunks

zlua supports its own binary chunk format for `string.dump`, `Function.dumpBytecode`, and `State.loadBytecode`. This format is for zlua-to-zlua caching or transfer. It is not PUC Lua `luac` compatibility, and the internal bytecode format may change.

## Testing Architecture

Correctness is dashboard-driven:

| Layer | Oracle |
| --- | --- |
| Unit tests | Zig test expectations. |
| Differential fixtures | Vendored CLua exit status and output. |
| Official suite | Vendored Lua 5.5 tests run per file under CLua and zlua. |
| C API fixtures | Same C fixture compiled and run against CLua and zlua. |
| Benchmarks | Process-level CLua and ReleaseFast zlua timing comparison. |

See [testing.md](testing.md) and [benchmark.md](benchmark.md) for operational details.

## Change Workflow

For behavior changes, prefer this loop:

1. Add or update a Lua fixture, C API fixture, Zig unit test, or embedding example that captures the behavior.
2. Verify CLua behavior when the behavior is Lua-compatible surface area.
3. Make the smallest implementation change that preserves existing dashboard results.
4. Run the narrow relevant command first.
5. Run broader checks before considering the work complete.

The strongest compatibility signal is `zig build ci`, which runs unit tests, embedding examples, differential fixtures, and the full official dashboard.
