# Runtime Split Plan

## Goal

Break `src/runtime.zig` into a `src/runtime/` package while keeping `src/runtime.zig` as the top-level runtime entrypoint. The facade should expose the runtime types and entrypoints useful to consumers and tests, not every helper needed by the VM, standard libraries, C API shim, or debug machinery.

The split should reduce edit conflicts and make runtime responsibilities easier to reason about without changing Lua behavior.

## Current Shape

`src/runtime.zig` is currently about 8.3k lines. It owns several different layers at once:

- Public runtime facade types: `Value`, `State`, `StateOptions`, capabilities, `ProtectedCallResult`, callback contexts, GC enums, and bytecode dump constants.
- Mutually recursive object model: closures, C closures, upvalues, tables, userdata, threads, call frames, continuations, and table hashing.
- Binary chunk writer/reader for zlua-owned bytecode dumps.
- `State` lifecycle, loading, execution, global/table operations, callback dispatch, host capability shims, and error capture.
- VM dispatch loop and fast loop.
- Call, return, vararg, protected-call, metamethod, coroutine, generic-for, and to-be-closed continuation logic.
- GC accounting, marking, weak table handling, finalizers, sweeping, tracking, and allocation stats.
- Debug/error formatting and traceback helpers.
- Scalar value helpers used by stdlib modules: conversion, parsing, formatting, equality, hashing, truthiness, and argument access.
- CLI/test-oriented helpers: `executeSource`, `executeSourceWithOptions`, and runtime unit tests.

The runtime is also the central integration point for zlua-owned modules. Current external references from `src/api.zig`, `src/c_api.zig`, `src/main.zig`, `src/stdlib*.zig`, and testing code use both real public entrypoints and private implementation helpers through `@import("runtime.zig")`.

## Constraints

- Zig files can coexist as `src/runtime.zig` and `src/runtime/*.zig`, matching the existing `compile.zig` plus `compile/` layout.
- `State` methods are declared inside the `State` struct today. Moving methods into many files is not a plain cut-and-paste operation; it needs either wrapper methods in `State` or `usingnamespace`/mixin-style method groups.
- `Value`, `Table`, `Thread`, `Closure`, and continuation structs are mutually recursive. Splitting these too early is likely to create import cycles or awkward type plumbing.
- `stdlib` and `c_api` need lower-level runtime hooks that should not define the consumer-facing runtime facade.
- Runtime behavior is dashboard-driven. Refactors should be verified against `zig build test`, targeted differential/official tests when touching execution behavior, and `zig build ci` before landing large stages.

## Target Module Shape

Use `src/runtime.zig` as the narrow facade and add `src/runtime/internal.zig` as the broad zlua-internal import surface.

```text
src/runtime.zig              public runtime facade
src/runtime/internal.zig     broad internal re-export surface for zlua-owned modules
src/runtime/types.zig        shared runtime types and mutually recursive object model
src/runtime/chunk.zig        zlua binary chunk dump/load support
src/runtime/state.zig        State fields, lifecycle, and remaining State methods during early split
src/runtime/host.zig         capability types and MemoryFilesystem helpers
src/runtime/execute.zig      executeSource helpers used by CLI/testing
src/runtime/value.zig        scalar conversion, parsing, formatting, equality, and argument helpers
src/runtime/vm.zig           VM dispatch loop and fast loop, later stage
src/runtime/call.zig         call/return/protected-call/metamethod helpers, later stage
src/runtime/coroutine.zig    coroutine helpers, later stage
src/runtime/gc.zig           GC methods and allocation accounting, later stage
src/runtime/debug.zig        debug/error/traceback formatting, later stage
src/runtime/tests.zig        runtime unit tests, later stage
```

This is the intended final shape, not the first patch. The first useful split should move low-risk chunks first and leave the hardest method groups in `state.zig` until the import graph is stable.

## Public Facade

`src/runtime.zig` should re-export only the runtime surface that callers reasonably need without importing internals directly.

Initial facade candidates:

- Core execution: `State`, `StateOptions`, `ExecuteOptions`, `executeSource`, `executeSourceWithOptions`.
- Core values and objects needed by low-level embedders/tests: `Value`, `Table`, `Userdata`, `Closure`, `CClosure`, `Upvalue`, `Thread`.
- Errors and call results: `RuntimeError`, `ProtectedCallResult`, `RuntimeErrorPayload` if still needed outside internals.
- Host options: `StdlibMode`, `MemoryFile`, `MemoryFilesystem`, `FilesystemCapability`, `ClockCapability`, `ProcessCapability`.
- GC knobs: `GcMode`, `GcParam`.
- Low-level callback hooks required by `api` and `c_api`: callback context and dispatch types.
- Explicit utility surface already used across public-ish modules: `truthy`, `toInteger`, `toNumber`, `valuesEqual`, `appendValue`, `appendLuaString`, `appendNumber`, `appendFmt`, `parseIntegerStrict`, `parseLuaNumber`, `floatToInteger`, `trimAscii`, `argValue`, `runtimeArgValue`, `localActiveAt`, `isFileValue`, `isClosedFileValue`.

Everything else should move behind `runtime/internal.zig` or stay private to the submodule that owns it.

Longer term, consider grouping utilities instead of keeping a wide top-level namespace:

```zig
pub const chunk = @import("runtime/chunk.zig");
pub const value = @import("runtime/value.zig");
```

Then public code can use `runtime.chunk.dumpClosureBinary` or `runtime.value.toInteger` when that is clearer than top-level re-exports. Keep top-level aliases only where they materially improve the common path.

## Internal Surface

Add `src/runtime/internal.zig` for zlua-owned modules that need implementation details. It can re-export a wider set of declarations than `src/runtime.zig` and can change freely.

Expected internal import users:

- `src/stdlib.zig` and `src/stdlib/*.zig`, because stdlib native functions need `Thread`, raw argument access, formatting helpers, table/userdata helpers, and runtime error helpers.
- `src/c_api.zig`, because it needs C closure internals, debug hook contexts, upvalues, protected-call results, and raw runtime values.
- `src/api.zig`, where the high-level API bridges to raw runtime state and values.
- Testing harnesses that intentionally exercise runtime internals.

Switching these imports to `runtime/internal.zig` is what allows `runtime.zig` to stop being the dumping ground for every implementation helper.

## Migration Phases

### Phase 1: Create Facade And Internal Module

- Add `src/runtime/internal.zig` as soon as there is at least one extracted module for it to re-export.
- Do not make `internal.zig` a blanket wrapper around the current monolithic `runtime.zig`; `runtime.zig` already imports `stdlib.zig`, and stdlib currently imports runtime, so a broad wrapper can make the existing cycle harder to reason about.
- Keep `src/runtime.zig` import-compatible for the first extraction patch unless there is a deliberate decision to narrow it immediately.
- Switch zlua-owned implementation files from `@import("runtime.zig")` to `@import("runtime/internal.zig")` only after the needed declarations live in extracted modules or after the import graph has been checked for cycles.
- Verify that `zig build test` passes before moving code.

This phase is mostly about import ownership: consumer-facing imports go through `runtime.zig`; implementation imports should move toward `runtime/internal.zig` as the split creates real internal modules.

### Phase 2: Extract Low-Risk Data And Utility Modules

Move code that has clear boundaries and minimal dependence on `State` private methods.

Good first candidates:

- `runtime/host.zig`: `MemoryFile`, `MemoryFilesystem`, `FilesystemCapability`, `ClockCapability`, `ProcessCapability`, and related option-only types.
- `runtime/chunk.zig`: binary chunk constants, writer helpers, `BinaryChunkReader`, and public dump/load helpers.
- `runtime/value.zig`: pure scalar helpers such as truthiness, numeric parsing, number formatting, integer conversion, and Lua string rendering.
- `runtime/types.zig`: keep the mutually recursive object model together at first, including `Value`, table internals, closure structs, userdata, threads, call frames, continuation structs, and callback context types.

Do not split `Value` away from `Table` on the first pass. `Table` stores `Value`, `Value` stores `*Table`, and `TableEntryIndex` depends on value hashing/equality. Keeping these in one file avoids a high-risk type cycle.

### Phase 3: Move `State` Into `runtime/state.zig`

- Move the `State` struct and its methods to `runtime/state.zig` once `types`, `host`, `chunk`, and `value` exist.
- Have `runtime.zig` re-export `pub const State = state.State` and other public types.
- Keep large method groups inside `State` initially. A single `state.zig` that is still several thousand lines is better than a broken multi-file method split.
- Run `zig fmt` on `src/runtime.zig` and `src/runtime/*.zig` after the move.

This phase should be mostly mechanical. Behavior should not change.

### Phase 4: Split State Method Groups Deliberately

After `State` lives in `runtime/state.zig`, split method groups only where the boundary is obvious.

Recommended order:

- `runtime/execute.zig`: top-level `executeSource` helpers and source failure rendering.
- `runtime/debug.zig`: debug dump, traceback, and error message rendering helpers.
- `runtime/gc.zig`: GC public methods and private mark/sweep/finalizer helpers.
- `runtime/coroutine.zig`: coroutine creation, resume, yield, close, wrapper, and resume-result helpers.
- `runtime/call.zig`: call resolution, protected call continuations, returns, metamethod dispatch, and generic-for continuations.
- `runtime/vm.zig`: `runThreadUntil`, `runPlainFastLoop`, dispatch helpers, and execution limit checks.

Use one of two patterns for each group:

- Wrapper pattern: keep a small method in `State` that calls a free function in another module. Use this when the function can be written without importing `state.zig` back into the helper module.
- Mixin pattern: use `usingnamespace` with a comptime `State` parameter for groups that need to remain methods and call many other `State` methods. Use this sparingly and only after proving it compiles cleanly.

Avoid creating import cycles where a helper module imports `state.zig` while `state.zig` imports the helper module. If a helper needs the `State` type, prefer passing it as a comptime parameter from `state.zig`.

### Phase 5: Move Tests Last

- Move runtime-only unit tests to `runtime/tests.zig` after the code is already split.
- Keep tests importing the public facade unless they are deliberately testing internals.
- If tests need internals, import `runtime/internal.zig` explicitly so the dependency is visible.

Moving tests last avoids mixing behavior-preserving code movement with test import churn.

## Verification Strategy

For mechanical moves:

```text
zig build test
```

For changes that touch VM dispatch, calls, coroutines, metamethods, GC, binary chunks, or host capabilities:

```text
zig build test
zig build test-diff
zig build test-official
```

Before landing the full split or any large phase:

```text
zig build ci
```

Use targeted `just diff ...` or `just official ...` runs when a moved method group has a known feature area, but do not rely on targeted runs as the only validation for VM or GC moves.

## Risks

- Import cycles are the main technical risk. The first split should keep mutually recursive data types together and avoid having helper modules import `state.zig` unless `state.zig` does not import them.
- Method-group extraction can accidentally change visibility. Keep moved helpers private unless another module already needs them through `internal.zig`.
- `stdlib` currently depends on several runtime helper functions. Moving those helpers without first switching stdlib to `runtime/internal.zig` will either widen the public facade again or create churn.
- GC and coroutine code share thread/frame/error state with the VM. Move them after lower-risk modules and verify with official tests.
- Binary chunks touch compiler proto structures and runtime closures. Keep the zlua binary format constants in one module and preserve existing rejection behavior for PUC chunks.
- `runtime.zig` public narrowing can break consumers if any exist outside this repository. Since `docs/embedding.md` already says `zlua.runtime` is not a stable embedding contract, this is acceptable, but the narrowing should still be intentional and documented in the patch that does it.

## Suggested First Patch

Make the first patch boring:

- Extract `runtime/host.zig` and re-export its types from both `runtime.zig` and `runtime/internal.zig`.
- Create `src/runtime/internal.zig` as part of that host extraction, not as a wrapper around all of `runtime.zig`.
- Extract `runtime/chunk.zig` if the host extraction is clean.
- Update imports only where necessary.
- Run `zig build test`.

Do not move the VM loop, GC, or `State` method groups in the first patch. The goal is to establish the package shape and prove the facade/internal split before touching high-risk execution code.
