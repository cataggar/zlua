# Next Steps

The original milestone plan is largely implemented. Current correctness dashboards pass, expected failures are empty, and basic embedding resource limits are implemented. Trust the codebase and harnesses over older milestone wording. Remaining work should focus on hardening the public embedding safety boundary, then performance attribution, API polish, and release readiness.

## Highest Priority: Embedding Sandbox Hardening

The highest-priority follow-up is to make the Zig embedding API's sandbox behavior explicit, tested, and documented. The default `State.init` path is safe-by-default, and `.full` standard libraries still require explicit host capabilities, but the remaining work is in edge coverage and file policy decisions.

Immediate tasks:

1. Define and test memory-filesystem path rules: relative paths only, normalization of `.` and duplicate separators, rejection of absolute paths and `..`, maximum path length, and rename/remove overwrite behavior.
2. Add optional memory-filesystem quotas and tests for quota exhaustion during creates, overwrites, and initialization from seed files.
3. Add negative sandbox tests for `io`, `os`, `package`, environment, process, filesystem mutation, and module-loading edges under default and full-stdlib-without-capabilities states.
4. Document the safe/full capability threat model in [embedding.md](embedding.md), including what each capability grants and what remains denied by default.
5. Keep CLI behavior separate: the CLI intentionally starts with full host capabilities unless explicit sandbox flags are added later.

## Performance

Current performance work should stay measurement-first. [benchmark.md](benchmark.md) owns the current baseline and interpretation; this document tracks follow-up work.

1. Capture JSON benchmark snapshots for optimization work and keep before/after comparisons in PR notes.
2. Profile the current worst benchmark fixtures before broad runtime changes.
3. Attribute process-level benchmark time versus in-process VM execution time for the worst fixtures.
4. Preserve the existing fast paths with focused regression benchmarks.
5. Defer CI performance thresholds until enough cross-machine benchmark history exists.

Likely optimization projects:

| Area | Notes |
| --- | --- |
| Fresh table construction | Profile constructor bytecode, table hints, raw fill, growth, and allocation accounting. |
| Table lookup and metamethod paths | Avoid broad representation rewrites until lookup and miss costs are attributed. |
| Call/return and upvalue traffic | Inspect frame setup, fixed return adjustment, closure allocation, continuations, and open-upvalue lookup. |
| Instruction count | Consider constant operands or peephole lowering for repeated constant loads and common branches. |
| Simple string operations | Specialize plain `find`, `sub`, and concat growth paths before deeper pattern work. |

Large representation projects remain plausible but should follow profiles:

```text
true Lua 5.5-style generational GC
NaN-boxed or otherwise packed values
packed bytecode representation
threaded or jump-table dispatch
larger table layout rewrite
```

## Resource Limits And Sandboxing

The embedding API exposes memory, stack, call-frame, and instruction limits. Unit coverage already exercises protected errors, resettable instruction budgets, stack/frame recursion, memory limits during loading and execution, captured output, stdlib temporaries, memory file reads, and recovery after OOM-style Lua errors. Remaining work is mostly edge hardening and harness expansion:

1. Extend low-limit coverage into official and differential harness modes once stack, frame, memory, and instruction limit semantics are stable.
2. Document stream-only guidance for embedding hosts that do not want captured output buffers counted against state memory.
3. Keep adding negative sandbox tests for remaining `io`, `os`, `debug`, `package`, environment, process, filesystem, memory files, and module loading edges.
4. Keep memory-filesystem quotas, path normalization, maximum path length, and rename/remove edge behavior documented as they become stable API.
6. Consider CLI flags for sandboxed execution and explicit memory/instruction limits.

## GC And Error Recovery

The GC and unwinding paths are heavily covered by official tests, but public API hardening should continue:

1. Add forced-GC tests around every public handle type: `Ref`, `Table`, `Function`, `Value`, `Tuple`, `Userdata`, `AnyUserdata`, and `ErrorRef`.
2. Stress API roots through callbacks, userdata finalizers, weak tables, and error values.
3. Test GC during table mutation, closure allocation, string interning, native callback dispatch, binary dumping, and bytecode loading.
4. Decide whether `State.stepGc` remains documented as full collection or becomes budget-respecting.
5. Test errors during `__close`, `__gc`, host callbacks, OOM paths, stack overflow, nested protected calls, and coroutine close/resume chains.
6. Verify protected calls restore stack, frames, pending returns, current error, registry roots, and GC roots after all error paths.
7. Add small-memory and small-stack modes to the differential or official harness once semantics are stable.

## Zig Embedding API

The current Zig API is usable, but these areas still need decisions or polish:

| Area | Next step |
| --- | --- |
| `GcOptions` | Either document as reserved or add real tuning knobs. |
| `State.stepGc` | Make the budget meaningful or explicitly commit to full-collection semantics. |
| Convenience calls | Consider `callGlobal` and `protectedCallGlobal` if examples keep repeating the pattern. |
| Coroutine handles | Decide whether the high-level API should expose thread/coroutine handles. |
| Table decoding | Add targeted table-to-struct decoding only if there is a concrete embedding use case. |
| Raw escape hatch | Prefer small facade methods over exposing runtime values, but identify missing operations. |
| Error ownership | Keep documenting and testing `errorMessage`, `takeErrorValue`, and `protectedCall` ownership. |
| Capability examples | Add more examples for safe mode denial, memory files, fixed clocks, and output capture. |

## C API Compatibility

The C API layer has broad public symbol inventory coverage and many CLua-differential fixtures. Remaining work:

1. Move more `implemented` symbols in `tests/fixtures/c_api_status.toml` to `tested-clua-diff` with targeted fixtures.
2. Expand fixture coverage for auxiliary library formatting, traceback, warning, package opening, and stdlib open functions.
3. Document supported C API scope, known deviations, and build/link instructions in a future `docs/c-api.md` if the layer becomes user-facing.
4. Decide whether internal `testC` official mode is worth wiring for deeper compatibility checks.

## Official And Differential Testing

Current dashboards pass, but the test methodology can still improve:

1. Keep reducing large official failures into smaller permanent differential fixtures when regressions are found.
2. Add focused fixtures for resource limits and sandbox denial as semantics settle.
3. Keep `tests/fixtures/expected_failures.toml` empty unless a deliberate, documented compatibility gap is introduced.
4. Add optional low-memory, low-stack, and GC-stress official modes if they become stable enough for local diagnostics.
5. Keep benchmark fixtures separate from correctness fixtures.

## Documentation And Release Readiness

Recommended documentation follow-up:

1. Keep the root `README.md` focused on positioning, quickstart, compatibility status, and links to deeper docs.
2. Keep [commands.md](commands.md) updated when `just` recipes, `zig build` steps, CLI options, or harness flags change.
3. Add a C API document only when support is intentionally user-facing.
4. Update `src/root.zig` versioning and release notes when cutting a real release.
5. Decide whether zlua binary chunks need a format/versioning document or should remain explicitly internal.

## Compatibility Non-Goals To Keep Explicit

These are not current goals unless project scope changes:

```text
JIT compilation
LuaJIT compatibility
multi-version Lua modes
PUC Lua luac binary chunk compatibility
ABI-compatible drop-in liblua replacement without documented caveats
LuaRocks/native dynamic module compatibility
```
