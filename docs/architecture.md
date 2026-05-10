# Architecture

zlua is a source-compatible Lua 5.5 implementation written in Zig. It has a conventional frontend/compiler/runtime split, but the most important architectural choice is that compatibility is oracle-driven: the official Lua 5.5 C implementation is the behavioral source of truth for parser acceptance, runtime semantics, standard-library behavior, error paths, and C API behavior.

## System Shape

The project has five major runtime-facing surfaces:

| Surface | Entry point | Responsibility |
| --- | --- | --- |
| CLI | `src/main.zig` | Host-oriented `zlua` executable with full stdlib/capability defaults, REPL, `-e`, dump modes, script execution, and test subcommands. |
| Zig embedding API | `src/api.zig` through `src/root.zig` | Stable typed facade for Zig hosts: states, tables, functions, callbacks, userdata, bytecode, capabilities, and resource limits. |
| Runtime internals | `src/runtime.zig` and `src/runtime/` | VM state, values, objects, calls, coroutines, GC, host capabilities, binary chunks, debug state, and error unwinding. |
| Standard libraries | `src/stdlib.zig` and `src/stdlib/` | Lua-visible library functions implemented as runtime-native functions. |
| C API layer | `src/c_api.zig` | Lua 5.5 C API compatibility shim backed by zlua runtime objects where practical and separate C-facing stack/value wrappers where required. |

The testing and benchmark harnesses are first-class build artifacts, not external scripts. They live under `src/testing/` and use the same downloaded CLua oracle as the rest of the project.

## Build Graph

`build.zig` builds these important artifacts:

| Artifact | Source | Purpose |
| --- | --- | --- |
| `zlua` | `src/main.zig` | CLI executable. |
| `lua5.5` | `.zlua-deps/lua-5.5.0/src` | Downloaded CLua oracle. |
| `zlua-test-diff` | `src/test_diff_main.zig` | Differential fixture runner. |
| `zlua-test-official` | `src/test_official_main.zig` | Official Lua 5.5 dashboard runner. |
| `zlua-test-bench` | `src/test_bench_main.zig` | Process-level benchmark runner. |
| `zlua-c` | `src/c_api.zig` | Static Lua C API compatibility library. |
| `zlua-test-c-api` | `src/test_c_api_main.zig` | C API differential fixture runner. |
| `zlua-embed-*` | `examples/*.zig` | Zig embedding examples. |

Testing policy and CI composition are documented in [testing.md](testing.md).

## Public Facade

`src/root.zig` is the library facade exposed to package users. It exports subsystem modules and aliases the high-level embedding types:

```zig
pub const frontend = @import("frontend.zig");
pub const compile = @import("compile.zig");
pub const runtime = @import("runtime.zig");
pub const stdlib = @import("stdlib.zig");
pub const testing = @import("testing.zig");

pub const State = api.State;
pub const Table = api.Table;
pub const Function = api.Function;
pub const Context = api.Context;
```

The intended embedding contract is `src/api.zig`, not `src/runtime.zig`. Runtime imports are useful for zlua internals and tests, but they expose object layouts, frame details, GC roots, and bytecode structures that are allowed to change.

## Source To Execution

The standard source execution path is:

```text
source bytes
  -> frontend lexer
  -> frontend AST
  -> resolver
  -> compiler Proto
  -> runtime Closure
  -> Thread stack + CallFrame
  -> VM instruction loop
  -> runtime/native stdlib calls
```

The same logical pipeline is used by the CLI, embedding API, and test harnesses, but the owning wrapper differs:

| Caller | Wrapper behavior |
| --- | --- |
| CLI | Reads files/stdin, strips initial shebangs, initializes `runtime.State` with full host capabilities, installs `arg`, and executes chunks. |
| Embedding API | Converts Zig options to runtime options, loads strings/files/bytecode, returns rooted `Function` handles, and maps runtime failures to Zig errors or protected-call results. |
| Differential harness | Can stop after lex/parse/resolve/compile stages or execute in a configured runtime state and compare with CLua. |
| Official harness | Spawns CLua and zlua as child processes for each official file with the official prelude. |

## Frontend

The frontend owns lexical and syntactic compatibility before runtime behavior exists.

| Module | Responsibility |
| --- | --- |
| `frontend/source.zig` | Source spans and location utilities. |
| `frontend/token.zig` | Token tags and token representation. |
| `frontend/lexer.zig` | Tokenization, Lua literals, comments, long strings, keywords, and lexer diagnostics. |
| `frontend/ast.zig` | AST node structures allocated from the AST arena. |
| `frontend/parser.zig` | Recursive parser and parse diagnostics. |
| `frontend/diagnostic.zig` | Frontend diagnostic payloads. |

`frontend.ast.Ast` owns an arena allocator. Parsed identifiers, blocks, expressions, and statements are slices/pointers into that arena. Deinitializing the AST releases the parse tree as a unit.

The AST models Lua 5.5-specific syntax currently supported by zlua, including `global` declarations, `<const>` and `<close>` local attributes, named varargs, labels, gotos, numeric and generic `for`, and function/method declarations.

The frontend does not decide every validity rule. Syntax shape is parsed first; declaration and scope legality is checked in the resolver so diagnostics can match CLua's load-time behavior more closely.

## Resolver

`compile/resolver.zig` validates source-level rules that require scope knowledge. Its job is to accept or reject chunks before bytecode generation.

Resolver responsibilities include:

```text
local/global declaration ordering
_ENV visibility and initialization
local attribute validation
assignment to const and for-loop variables
named vararg restrictions
upvalue capture decisions
to-be-closed lifetime boundaries
```

The differential harness uses the `resolve` stage to compare resolver acceptance against CLua `loadfile` without depending on VM execution.

## Compiler And Proto

The compiler lowers a resolved AST into `compile.proto.Proto`. A proto is the immutable runtime plan for a Lua function or chunk.

`Proto` owns:

| Field | Meaning |
| --- | --- |
| `constants` | Deduplicated bytecode constants: nil, booleans, integer text, number text, and strings. |
| `instructions` | Register-based bytecode instructions. |
| `line_info` | Per-PC line information for diagnostics and debug hooks. |
| `locals` | Debug local names, register slots, PC ranges, and to-be-closed flags. |
| `upvalues` | Captured value descriptors. |
| `children` | Nested function prototypes. |
| `error_sites` | Operand-origin metadata used for Lua-compatible runtime error messages. |
| `max_registers` | Register frame size needed by the function. |
| `param_count`, `is_vararg`, `named_vararg` | Function call and vararg shape. |
| `source_name`, `debug_name`, line ranges | Debug and error reporting metadata. |

The bytecode is register-oriented. Instructions operate on `u16` register indexes and refer to constants, child protos, upvalues, and jump offsets by compact indexes.

Instruction set:

| Instruction | Payload | Meaning |
| --- | --- | --- |
| `load_nil` | `Register` | Writes `nil` to the destination register. |
| `load_bool` | `dest`, `value` | Writes a boolean constant to a register. |
| `load_const` | `dest`, `constant` | Writes a `Proto.constants` entry to a register. |
| `move` | `dest`, `source` | Copies one register to another. |
| `get_global` | `register`, `name` | Reads a named global into a register. |
| `set_global` | `register`, `name` | Writes a register value to a named global. |
| `declare_global` | `table`, `value`, `name` | Declares a global in the target global table. |
| `get_upvalue` | `register`, `upvalue` | Reads a captured upvalue into a register. |
| `set_upvalue` | `register`, `upvalue` | Writes a register value to a captured upvalue. |
| `get_table` | `dest`, `table`, `key` | Reads `table[key]` using register operands. |
| `set_table` | `table`, `key`, `value` | Writes `table[key] = value` using register operands. |
| `set_array` | `table`, `index`, `value` | Writes one array element during table construction. |
| `get_field` | `dest`, `table`, `name` | Reads `table[name]` where `name` is a string constant. |
| `set_field` | `table`, `name`, `value` | Writes `table[name] = value` where `name` is a string constant. |
| `new_table` | `dest`, `array_hint`, `hash_hint` | Allocates a table with constructor size hints. |
| `set_list` | `table`, `first`, `count`, `start_index` | Bulk-writes sequential constructor values. |
| `add` | `dest`, `left`, `right` | Computes `left + right`. |
| `sub` | `dest`, `left`, `right` | Computes `left - right`. |
| `mul` | `dest`, `left`, `right` | Computes `left * right`. |
| `div` | `dest`, `left`, `right` | Computes `left / right`. |
| `idiv` | `dest`, `left`, `right` | Computes floor division. |
| `mod` | `dest`, `left`, `right` | Computes modulo. |
| `pow` | `dest`, `left`, `right` | Computes exponentiation. |
| `unm` | `dest`, `source` | Computes unary minus. |
| `band` | `dest`, `left`, `right` | Computes bitwise and. |
| `bor` | `dest`, `left`, `right` | Computes bitwise or. |
| `bxor` | `dest`, `left`, `right` | Computes bitwise exclusive or. |
| `bnot` | `dest`, `source` | Computes bitwise not. |
| `shl` | `dest`, `left`, `right` | Computes left shift. |
| `shr` | `dest`, `left`, `right` | Computes right shift. |
| `eq` | `dest`, `left`, `right` | Writes the equality comparison result. |
| `lt` | `dest`, `left`, `right` | Writes the less-than comparison result. |
| `le` | `dest`, `left`, `right` | Writes the less-or-equal comparison result. |
| `not` | `dest`, `source` | Computes Lua logical not. |
| `len` | `dest`, `source` | Computes Lua length. |
| `concat` | `dest`, `left`, `right` | Concatenates values. |
| `jmp` | `JumpOffset` | Moves the program counter by a relative offset. |
| `compare_branch` | `left`, `right`, `op`, `jump_if_truthy`, `offset` | Branches on `eq`, `lt`, or `le`. |
| `test_op` | `register`, `jump_if_truthy`, `offset` | Branches on register truthiness. |
| `test_set` | `dest`, `source`, `jump_if_truthy`, `offset` | Copies `source` to `dest`, then branches on truthiness. |
| `call` | `base`, `arg_count`, `return_count` | Calls a value with fixed or multret arity. |
| `tail_call` | `base`, `arg_count`, `return_count` | Performs a tail call. |
| `ret` | `first`, `count` | Returns fixed or multret values from a function. |
| `vararg` | `dest`, `count` | Loads fixed or multret varargs. |
| `closure` | `dest`, `proto` | Instantiates a child proto as a closure. |
| `close` | `Register` | Closes open upvalues at or above a register. |
| `check_close` | `Register` | Validates a to-be-closed value. |
| `close_tbc` | `Register` | Runs to-be-closed cleanup for a register. |
| `for_prep` | `base`, `offset` | Prepares a numeric `for` loop. |
| `for_loop` | `base`, `offset` | Advances and branches a numeric `for` loop. |
| `tfor_prep` | `base`, `variable_count`, `offset` | Advances a generic `for` iterator and exits on `nil`. |
| `tfor_call` | `base`, `variable_count`, `offset` | Advances a generic `for` iterator and stores loop variables. |
| `tfor_loop` | `base`, `variable_count`, `offset` | Jumps to continue a generic `for` loop. |

The compiler preserves enough debug and operand-origin data to make runtime errors look like Lua errors instead of generic VM errors.

## Runtime State

`runtime.State` is the central owner of a Lua universe. One state owns the global environment, allocated runtime objects, interned strings, API roots, host options, GC state, current thread, error payloads, primitive metatables, C callback dispatch hooks, and runtime output buffers.

Major state-owned collections:

| Collection | Contents |
| --- | --- |
| `globals` and `global_table` | Global name map and `_G` table exposed to Lua. |
| `strings` and `string_allocations` | Interned strings and tracked string storage. |
| `table_allocations` | Heap tables. |
| `userdata_allocations` | Full userdata values and finalizer/deinit metadata. |
| `closure_allocations` | Lua closures loaded from protos. |
| `c_closure_allocations` | C API closures. |
| `upvalue_allocations` and `c_upvalue_allocations` | Lua and C closure upvalues. |
| `thread_allocations` | Main thread and coroutine threads. |
| `proto_allocations` | Runtime-owned loaded protos, including binary chunks. |
| `source_allocations` | Source buffers retained for loaded file debug information. |
| `api_roots` | Values rooted by the Zig embedding API. |

This central ownership model makes teardown straightforward: `State.deinit` walks every allocation list and releases state-owned objects. The tradeoff is that GC and performance-sensitive paths need explicit allocation accounting and careful rooting.

## Values And Objects

Runtime values are represented by `runtime.types.Value`, a tagged union over Lua scalars and runtime object pointers. It also contains variants for built-in native functions and special internal callables such as coroutine wrappers and string iterators.

Core heap objects:

| Object | Shape |
| --- | --- |
| `Closure` | Points at a `Proto`, captured Lua upvalues, optional cached constants, and stripped-debug flag. |
| `CClosure` | Function id plus C upvalues for the C API layer. |
| `Upvalue` | Either open over a thread stack slot or closed over a stored value. |
| `Table` | Split array plus hash-entry storage, hash index map, optional metatable, GC flags, and metatable linked-list hooks. |
| `Userdata` | Native pointer, type identity, type name, optional metatable, finalizer, and deinit hook. |
| `Thread` | Stack, call frames, continuation queues, open upvalues, debug hook state, yield/result bookkeeping, and coroutine status. |

Tables use an array part for positive integer keys and a hash-entry list plus index map for other keys. Deleting hash keys leaves Lua-compatible iteration behavior to higher-level table logic and GC cleanup paths; table order should not be treated as a stable API except where tests intentionally pin CLua-compatible behavior.

## Threads, Frames, And Calls

Each executing Lua thread owns a value stack and a stack of `CallFrame` records. A frame points to a closure/proto, records a base stack index, program counter, return target, varargs, debug overrides, tail-call state, and pending returns.

Calls flow through `runtime/state.zig` and helpers in `runtime/call.zig`:

```text
callable value + args
  -> invokeValue
  -> Lua closure frame, C closure dispatch, native stdlib call, or __call metamethod
  -> runThreadUntil target frame count
  -> return adjustment into caller registers
```

Protected calls snapshot enough thread and state information to restore stack length, frame count, result state, and previous error state when runtime errors, stack overflow, unsupported opcodes, or OOM occur. This machinery is used by Lua `pcall`/`xpcall`, the Zig embedding `Function.protectedCall`, and the C API `lua_pcallk` path.

Coroutine and yield support is continuation-based. The thread stores protected-call, generic-for, tail-call, and single-call continuations so native calls, metamethods, protected calls, generic iterators, and close handlers can resume in the right opcode context after yielding.

## VM Loop

The main instruction dispatch currently lives in `runtime/state.zig` near `runThreadUntil`. `runtime/vm.zig` contains cross-cutting execution-limit checks rather than the full dispatcher.

Each executed instruction can enforce:

| Limit | Behavior |
| --- | --- |
| `max_instructions` | Counts executed instructions against a cumulative per-state budget, exposes query/reset through the embedding API, and raises `instruction limit exceeded` when reached. |
| `max_memory` | The embedding API uses a bounded allocator for parser/compiler, bytecode, VM, API conversion, and output-buffer allocations. The VM also refreshes Lua heap totals at instruction boundaries, attempts conservative collection when possible, then raises `memory limit exceeded` if still over limit. |

The VM is deliberately compatibility-first. It handles Lua-specific details such as fixed versus multret return adjustment, vararg expansion, named vararg tables, tail calls, to-be-closed unwinding, metamethod dispatch, primitive metatables, debug hooks, line events, C stack overflow guards, and official error-message edge cases.

## Standard Libraries

`src/stdlib.zig` opens libraries by inserting runtime-native values into globals and library tables. Native implementations live in separate files by library.

Library selection:

| Selection | Libraries |
| --- | --- |
| `none` | No standard libraries. |
| `base` | Base globals only. |
| `safe` | Base, table, string, math, utf8, coroutine, json, toml, and msgpack. |
| `full` | Safe libraries plus io, os, debug, and package. |
| `libraries` | Explicit per-library set. |

The CLI initializes the runtime with `.full` libraries and host capabilities. The Zig embedding API defaults to `.safe` libraries and sandboxed capabilities.

Native library functions do not have an independent stack API. They operate through runtime state, thread frames, bytecode call metadata, and helper functions for argument access, returns, errors, and metamethod dispatch. This keeps Lua stdlib behavior aligned with the VM rather than creating a second internal calling convention.

## Host Capabilities

Host effects are explicit runtime options. This is essential for embedding because Lua libraries such as `io`, `os`, and `package` can otherwise reach the host environment.

| Capability | Runtime type | Modes |
| --- | --- | --- |
| I/O | `std.Io`, stdout/stderr writers, stdin buffer | Disabled/absent by default in embedding, host-oriented in CLI. |
| Filesystem | `FilesystemCapability` | `disabled`, read-only memory files, read/write memory filesystem, host current working directory. |
| Environment | Environment map pointer | Disabled or provided by host. |
| Clock | `ClockCapability` | `disabled`, fixed value, or system clock. |
| Process | `ProcessCapability` | Disabled or enabled. |

The memory filesystem is intentionally simple: it stores path/content pairs in memory, supports read/write/remove/rename, and avoids touching the host filesystem. It is useful for plugin hosts that need `loadfile`, `dofile`, or `require` without granting host directory access.

## Garbage Collection

The collector is integrated with state-owned allocation lists. Objects carry mark/finalization bits, and the state tracks allocation totals for `collectgarbage("count")`, auto-GC thresholds, and memory limits.

GC responsibilities include:

```text
mark roots from globals, registry/API roots, threads, stacks, frames, closures, upvalues, metatables, current errors, and callback state
handle weak table key/value semantics
run userdata and table finalizers in Lua-compatible order
preserve objects across errors, yields, close handlers, and protected calls
support collectgarbage modes and params at the Lua API surface
provide conservative collection in dangerous execution windows
```

The public `collectgarbage("step")` and embedding `State.stepGc` currently perform full collection-style work rather than a true incremental budgeted step. `GcMode` and `GcParam` exist for Lua API compatibility, but a true generational collector is still future work.

## Errors And Diagnostics

zlua separates load diagnostics from runtime failures:

| Error source | Representation |
| --- | --- |
| Lexer/parser/resolver/compiler | `errors.Diagnostic` rendered as Lua load errors. |
| Runtime execution | `RuntimeErrorPayload` plus current error value and traceback/debug context. |
| Protected calls | `ProtectedCallResult.success` or `ProtectedCallResult.failure`. |
| Embedding convenience APIs | `error.LuaError` plus `State.errorMessage` or `State.takeErrorValue`. |
| C API | Lua status codes such as `LUA_OK`, `LUA_ERRRUN`, `LUA_ERRSYNTAX`, `LUA_ERRMEM`, and `LUA_YIELD`. |

`Proto.error_sites` carries operand-origin metadata so VM failures can produce messages such as bad arithmetic, bad call target, bad index, and bad length errors with useful Lua-compatible wording.

Runtime errors must preserve Lua semantics across close handlers, finalizers, protected calls, coroutines, debug hooks, and host callbacks. This is why error state lives on `runtime.State` and why protected-call restoration is centralized.

## Zig Embedding API

`src/api.zig` wraps runtime values in rooted handles. A handle such as `Table`, `Function`, `Userdata(T)`, `AnyUserdata`, `Value`, `Tuple`, or `ErrorRef` owns a registry root when needed and must be deinitialized by the host.

The facade is responsible for:

```text
mapping API options to runtime options
opening safe/full libraries on demand
rooting values that cross into host code
converting Zig values to runtime values
converting runtime values back to typed Zig results
wrapping host callbacks as Lua closures
turning callback conversion failures into Lua argument errors
providing memory filesystem and module helpers
capturing Lua errors for convenience APIs
```

The core embedding rule is that host-owned references should be explicit and short-lived. Installing a handle into a Lua table/global gives Lua its own reference; it does not transfer or consume the host handle.

## C API Layer

`src/c_api.zig` exposes Lua 5.5 C symbols and installs the downloaded Lua headers. It is not a simple direct export of `runtime.State`; it has C-facing wrapper types for stack values, strings, tables, userdata, threads, light userdata, Lua closures, C closures, and runtime-native functions.

The C API layer must satisfy different constraints from the Zig API:

| Constraint | Consequence |
| --- | --- |
| Stack-indexed API | C-facing `lua_State` needs Lua stack operations and pseudo-index behavior. |
| C ABI | Exported functions and structs must match Lua 5.5 headers closely enough for fixtures. |
| Continuations | `lua_callk`, `lua_pcallk`, `lua_yieldk`, and coroutine APIs need continuation state. |
| Auxiliary library | `luaL_*` helpers need compatible argument checks, refs, buffers, loading, and errors. |
| Differential fixtures | The same C fixture is compiled and run against CLua and zlua. |

The C API status inventory lives in `tests/fixtures/c_api_status.toml`. Symbols marked `tested-clua-diff` have direct fixture coverage against both implementations.

## Binary Chunks

zlua has its own binary chunk format for zlua-to-zlua use. It is used by Lua `string.dump`, the embedding `Function.dumpBytecode`, and `State.loadBytecode`.

Important boundaries:

```text
zlua can load zlua binary chunks
zlua rejects malformed or incompatible zlua chunks
zlua does not promise PUC Lua luac compatibility
the internal bytecode format is not a stable external ABI
```

The binary chunk implementation lives under `src/runtime/chunk.zig` and runtime load/dump paths. It serializes enough proto and debug information to round-trip zlua closures while preserving the project’s freedom to change bytecode internals.

## Testing Architecture

Correctness is dashboard-driven. The main test architecture is part of the codebase:

| Harness | Source | Oracle |
| --- | --- | --- |
| Unit tests | Zig `test` blocks | Zig assertions. |
| Differential | `src/testing/diff_runner.zig` | Vendored CLua exit status and output. |
| Official dashboard | `src/testing/official_suite.zig` | Vendored Lua 5.5 official tests under CLua and zlua. |
| C API | `src/testing/c_api_runner.zig` | Same C fixture compiled against CLua and zlua. |
| Benchmarks | `src/testing/bench_runner.zig` | Process-level CLua versus ReleaseFast zlua timing. |

The differential harness can test staged acceptance before execution, which is why frontend, resolver, and compiler errors can be locked down independently of runtime semantics.

See [testing.md](testing.md) and [benchmark.md](benchmark.md) for commands and methodology.

## Architectural Invariants

These are the rules to preserve when changing internals:

| Invariant | Why it matters |
| --- | --- |
| CLua behavior beats intuition. | Lua edge cases are often surprising, and the official tests encode those surprises. |
| `src/api.zig` is the stable Zig boundary. | Embedding hosts should not depend on runtime object layout. |
| Runtime objects are state-owned. | Teardown, GC, and roots depend on one owning state. |
| Values crossing into host code must be rooted when they can outlive the call. | GC can run during callbacks, finalizers, errors, and allocation. |
| Protected calls must restore stack/frame/error state. | `pcall`, `xpcall`, embedding protected calls, and C API protected calls rely on this. |
| Host capabilities must remain explicit. | Safe embedding depends on avoiding accidental filesystem, process, environment, or clock access. |
| Bytecode is internal. | Binary chunks are zlua-specific and should not freeze compiler/VM representation. |
| Benchmarks do not replace compatibility tests. | Performance changes must preserve differential and official behavior. |

Architecture changes should identify which boundary is moving. Most risky changes cross one of these boundaries: compiler to runtime, runtime to stdlib, runtime to embedding API, runtime to C API, or host capability to stdlib. Use the workflow in [development.md](development.md) for behavior changes.
