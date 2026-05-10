# Next Steps

This document tracks remaining work only. `tests/fixtures/expected_failures.toml` is empty, the Zig embedding API is safe-by-default, and the tracked Lua 5.5 C API symbol inventory is covered by CLua-differential fixtures.

## Embedding Sandbox And Limits

1. Decide whether `io.tmpfile` and `os.tmpname` should remain synthetic helpers in sandboxed embeddings or become capability-gated.
2. Extend low-limit and sandbox-denial coverage into official and differential harness modes once the public semantics stop changing.
3. Document stream-only guidance for hosts that do not want captured stdout/stderr buffers counted against state memory.
4. Consider CLI flags for sandboxed execution and explicit memory/instruction limits.

## Performance

Current performance work should stay measurement-first. [benchmark.md](benchmark.md) owns the current baseline and interpretation.

1. Capture JSON benchmark snapshots for optimization work and keep before/after comparisons in PR notes.
2. Profile the current worst benchmark fixtures before broad runtime changes.
3. Attribute process-level benchmark time versus in-process VM execution time for the worst fixtures.
4. Preserve existing fast paths with focused regression benchmarks.
5. Defer CI performance thresholds until enough cross-machine benchmark history exists.

Likely optimization projects:

| Area | Notes |
| --- | --- |
| Fresh table construction | Profile constructor bytecode, table hints, raw fill, growth, and allocation accounting. |
| Table lookup and metamethod paths | Attribute lookup and miss costs before broad representation rewrites. |
| Call/return and upvalue traffic | Inspect frame setup, fixed return adjustment, closure allocation, continuations, and open-upvalue lookup. |
| Instruction count | Consider constant operands or peephole lowering for repeated constant loads and common branches. |
| Simple string operations | Specialize plain `find`, `sub`, and concat growth paths before deeper pattern work. |

Large representation projects remain plausible, but should follow profiles:

```text
true Lua 5.5-style generational GC
NaN-boxed or otherwise packed values
packed bytecode representation
threaded or jump-table dispatch
larger table layout rewrite
```

## GC And Error Recovery

1. Decide whether `State.stepGc` remains full-collection semantics or becomes budget-respecting.
2. Test errors during `__close`, `__gc`, host callbacks, OOM paths, stack overflow, nested protected calls, and coroutine close/resume chains.
3. Verify protected calls restore stack, frames, pending returns, current error, registry roots, and GC roots after error paths.
4. Add small-memory and small-stack modes to the differential or official harness once semantics are stable.

## Zig Embedding API

| Area | Next step |
| --- | --- |
| `GcOptions` | Keep documented as reserved or add real tuning knobs. |
| Convenience calls | Consider `callGlobal` and `protectedCallGlobal` if examples keep repeating the pattern. |
| Coroutine handles | Decide whether the high-level API should expose thread/coroutine handles. |
| Table decoding | Add targeted table-to-struct decoding only if there is a concrete embedding use case. |
| Raw escape hatch | Prefer small facade methods over exposing runtime values, but identify missing operations. |
| Error ownership | Keep testing `errorMessage`, `takeErrorValue`, and `protectedCall` ownership. |
| Capability examples | Add more examples for safe-mode denial, memory files, fixed clocks, and output capture when they clarify real use cases. |

## C API Compatibility

The Lua 5.5 C API compatibility layer is implemented for the tracked public symbol inventory. Remaining work is coverage depth, edge-case hardening, and user-facing documentation.

1. Keep every tracked public symbol at `tested-clua-diff`; add targeted fixtures before adding new symbols or changing C API behavior.
2. Expand stress coverage around protected-call unwinding, coroutine continuation/yield edges, debug hooks, to-be-closed variables, userdata finalizers, allocator failures, long strings/buffers, warning callbacks, traceback formatting, and stdlib/package opening combinations.
3. Add negative and recovery fixtures for stack misuse boundaries, panic/error paths, OOM-style failures, registry references, cross-thread `lua_xmove`, and closing/resuming coroutine chains.
4. Document supported C API scope, known deviations, and build/link instructions in `docs/c-api.md` before advertising `zlua-c` as a stable user-facing library.
5. Decide whether internal `testC` official mode is worth wiring for deeper compatibility checks.

## Testing Methodology

1. Keep reducing large official failures into smaller permanent differential fixtures when regressions are found.
2. Keep `tests/fixtures/expected_failures.toml` empty unless a deliberate, documented compatibility gap is introduced.
3. Add optional low-memory, low-stack, and GC-stress official modes if they become stable enough for local diagnostics.
4. Keep benchmark fixtures separate from correctness fixtures.

## Release Readiness

1. Keep [commands.md](commands.md) updated when `just` recipes, `zig build` steps, CLI options, or harness flags change.
2. Add `docs/c-api.md` before advertising `zlua-c` as stable.
3. Update `src/root.zig` versioning and release notes when cutting a real release.
4. Decide whether zlua binary chunks need a format/versioning document or should remain explicitly internal.

## Compatibility Non-Goals

```text
JIT compilation
LuaJIT compatibility
multi-version Lua modes
PUC Lua luac binary chunk compatibility
ABI-compatible drop-in liblua replacement without documented caveats
LuaRocks/native dynamic module compatibility
```
