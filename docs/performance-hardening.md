# Milestone 24: Performance And Hardening Scope

## Goal

Milestone 24 should start with measurement, risk reduction, and stress coverage before changing hot paths. The benchmark suite is now good enough to show where zlua is slow relative to the vendored Lua 5.5 oracle, but the first work should be to make those gaps explainable and safely reproducible.

The optimization rule for this milestone is:

```text
No performance change is accepted unless observable Lua behavior stays compatible with CLua.
```

## Current Baseline

Baseline command:

```sh
just bench
```

This builds `zlua` in `ReleaseFast` through the `justfile` recipe and compares it against the vendored `lua5.5` oracle. The harness uses process-level timing, so results include startup, parsing, compilation, runtime initialization, and execution.

Captured on 2026-05-06 from the local workspace.

```text
totals  benchmarked=26  skipped=0  failed=0  timed_out=0
```

Category summary:

| Category | Count | Median Ratio | Worst Ratio |
| --- | ---: | ---: | ---: |
| gc | 5 | 17.63x | 55.01x |
| stdlib | 4 | 3.73x | 11.80x |
| string | 5 | 7.39x | 22.08x |
| table | 6 | 24.98x | 61.43x |
| vm | 6 | 19.91x | 33.81x |

Full baseline:

| Benchmark | Category | CLua Mean | zlua Mean | Ratio |
| --- | --- | ---: | ---: | ---: |
| `gc/collectgarbage_cycles.lua` | gc | 8.3ms | 311.8ms | 37.13x |
| `gc/retained_graph.lua` | gc | 0.7ms | 40.8ms | 55.01x |
| `gc/short_lived_closures.lua` | gc | 2.8ms | 28.5ms | 9.96x |
| `gc/short_lived_strings.lua` | gc | 5.2ms | 44.6ms | 8.46x |
| `gc/short_lived_tables.lua` | gc | 4.8ms | 85.9ms | 17.63x |
| `stdlib/math_loop.lua` | stdlib | 3.2ms | 38.1ms | 11.80x |
| `stdlib/table_concat.lua` | stdlib | 47.4ms | 58.4ms | 1.23x |
| `stdlib/table_sort.lua` | stdlib | 2.7ms | 11.5ms | 4.21x |
| `stdlib/utf8_codes.lua` | stdlib | 0.7ms | 2.5ms | 3.26x |
| `string/concat_growth.lua` | string | 1.2ms | 6.5ms | 5.13x |
| `string/find_pattern.lua` | string | 2.2ms | 16.8ms | 7.39x |
| `string/find_plain.lua` | string | 1.8ms | 40.6ms | 22.08x |
| `string/gsub_replace.lua` | string | 19.1ms | 87.5ms | 4.56x |
| `string/sub_loop.lua` | string | 2.4ms | 30.9ms | 12.41x |
| `table/array_append.lua` | table | 2.0ms | 38.4ms | 18.98x |
| `table/array_reads.lua` | table | 2.1ms | 69.5ms | 33.00x |
| `table/array_writes.lua` | table | 2.5ms | 79.7ms | 30.98x |
| `table/metatable_index.lua` | table | 2.4ms | 39.1ms | 15.78x |
| `table/pairs_iteration.lua` | table | 6.1ms | 379.7ms | 61.43x |
| `table/string_keys.lua` | table | 1.4ms | 12.9ms | 8.72x |
| `vm/arithmetic.lua` | vm | 0.6ms | 4.5ms | 6.71x |
| `vm/comparison_branch.lua` | vm | 1.7ms | 56.6ms | 31.83x |
| `vm/float_arithmetic.lua` | vm | 1.0ms | 19.1ms | 19.09x |
| `vm/function_calls.lua` | vm | 1.9ms | 40.9ms | 20.72x |
| `vm/locals.lua` | vm | 1.9ms | 66.2ms | 33.81x |
| `vm/upvalues.lua` | vm | 2.0ms | 37.4ms | 18.40x |

## Interpretation

The strongest signal is not a single isolated benchmark. It is that table and VM basics are much slower across several independent fixtures:

| Area | Signal | Initial Read |
| --- | --- | --- |
| Table iteration | `table/pairs_iteration.lua` at 61.43x | Highest priority because iteration is a common Lua workload and likely exercises table layout, `next`, string keys, and VM loop overhead together. |
| Table indexed access | array reads and writes at 33.00x and 30.98x | Suggests ordinary get/set paths need fast-path analysis before table representation changes. |
| VM dispatch/register traffic | locals and branch loops at 33.81x and 31.83x | Suggests the main interpreter loop and register access overhead are material even without complex objects. |
| GC retained graph | 55.01x | Suggests collector marking/tracking overhead matters beyond allocation rate alone. |
| Explicit GC cycles | 37.13x | Suggests `collectgarbage` behavior and accounting are expensive enough to investigate separately from normal allocation pacing. |
| String plain find | 22.08x | Suggests string library hot loops or matcher setup need profiling independent of VM/table work. |

`stdlib/table_concat.lua` at 1.23x is an important counterexample: not every library path is currently dominated by interpreter overhead. Keep this benchmark as a guard against broad assumptions.

## Scope

Milestone 24 should cover four workstreams.

### 1. Measurement And Attribution

Before optimizing, make the current ratios explainable.

Tasks:

```text
capture benchmark JSON snapshots for local comparisons
add a short benchmark-run note to PRs that change runtime hot paths
run category-focused benchmarks while investigating one area
separate process-level costs from in-process VM execution costs
profile the top table, VM, GC, and string benchmarks
record benchmark variance before setting thresholds
```

Useful commands:

```sh
just bench --json /tmp/zlua-bench-baseline.json
just bench --category table
just bench table/pairs_iteration --iterations=20
just bench vm/locals --iterations=20 --no-warmup
```

Do not add performance thresholds to `zig build ci` yet. The harness should remain a diagnostic tool until there is enough history across machines.

### 2. Performance Investigation

Start with narrow investigations. Prefer a benchmark, a profile, and a hypothesis before changing shared runtime structures.

Priority order:

| Priority | Area | Why |
| --- | --- | --- |
| P0 | VM fast path | `vm/locals`, `vm/comparison_branch`, and function-call loops show large overhead without table-heavy behavior. |
| P0 | Table get/set/iteration | Table benchmarks are the worst category and table access is central to Lua programs. |
| P1 | GC accounting and marking | GC benchmarks show both retained-object and explicit-cycle gaps. |
| P1 | Call/return allocation | `vm/function_calls` and `vm/upvalues` are slow enough to justify examining frame and return handling. |
| P2 | String search and pattern paths | `string/find_plain` is much slower than related string workloads and should be isolated. |
| P2 | Compiler/register allocation | Only after runtime hot-path attribution shows compiler output is the limiting factor. |

Likely runtime hot spots to inspect:

```text
src/runtime.zig main VM dispatch loop
src/runtime.zig register get/set helpers
src/runtime.zig table get/set/next implementation
src/runtime.zig normal getTable/setTable metamethod paths
src/runtime.zig callValue/invokeValue and return adjustment
src/runtime.zig GC mark/sweep and allocation accounting
src/compile/bytecode.zig instruction representation
src/stdlib/string.zig string.find/string.gsub pattern machinery
```

Candidate performance projects:

```text
split a hook/limit/debug-capable VM loop from a plain fast loop
cache frame base, stack slice, and current proto data in the dispatch loop
add raw fast paths for plain table array and string-key access
avoid double lookup in common table set paths
cache interned string hashes or add pointer fast paths for interned strings
replace linear object tracking checks with object headers or side maps
maintain running allocation counters instead of scanning all allocations
avoid heap allocation for common fixed return and vararg paths
specialize simple string.find and string.gsub cases before pattern backtracking
```

Packed bytecode, threaded dispatch, and larger table rewrites should come after the smaller fast-path and accounting work has been measured. They are likely useful but carry more regression risk.

### 3. Hardening And Resource Limits

Hardening should happen alongside performance work because many optimizations touch the same dangerous edges: stacks, GC roots, limits, host capabilities, and error unwinding.

Resource-limit work:

```text
define whether instruction limits are per State, per chunk, or per protected call
add reset/query API only after the chosen instruction-limit semantics are clear
enforce memory limits through an allocator-backed quota or equivalent accounting
cover parser/compiler allocations, stdlib temporaries, host callback returns, and output buffers
test low stack and low call-frame limits against recursion, metamethod recursion, coroutines, and host callback reentry
add stdout/stderr capture limits or a stream-only mode for embedding hosts
```

GC safety work:

```text
run forced-GC tests around every public handle type
stress API roots through callbacks, userdata finalizers, weak tables, and error values
test GC during table mutation, closure allocation, string interning, and native callback dispatch
decide whether stepGc should remain documented as full collection or become budget-respecting
```

Sandbox and host capability work:

```text
document the safe/full capability threat model
add negative tests for io, os, debug, package, environment, process, and filesystem access in safe mode
add process timeout and output caps for os.execute when process execution is enabled
define memory filesystem quotas, max path length, path normalization, and rename/remove behavior
consider CLI flags for sandboxed execution and explicit memory/instruction limits
```

Error recovery work:

```text
test errors during __close, __gc finalizers, host callbacks, OOM paths, stack overflow, and nested protected calls
verify protected calls restore stack, frames, pending returns, current error, and GC roots
add small-memory and small-stack modes to the differential or official harness once semantics are stable
```

### 4. Regression Tracking

Benchmarks should not be compatibility gates in this milestone. Correctness gates stay differential, official, unit, and embedding tests.

Recommended tracking policy:

```text
keep `just bench` manual and ReleaseFast by default
capture JSON snapshots for before/after comparisons on optimization PRs
track category median and worst ratio over time
track the top five worst benchmarks explicitly
only add opt-in metadata thresholds after several stable snapshots exist
```

If thresholds are added later, they should be local to a benchmark file and generous enough to catch obvious regressions, not normal machine variance.

## Acceptance Criteria

Milestone 24 is done when:

```text
performance hot spots have benchmark-backed explanations
at least the worst table, VM, GC, and string gaps have scoped follow-up issues or completed fixes
all optimization changes preserve differential and official behavior
benchmark snapshots can be captured and compared without manual parsing
resource-limit semantics are documented and covered by tests
safe-mode capability denial has targeted regression tests
forced-GC, small-stack, and small-memory stress paths exist for the most important runtime surfaces
```

Performance targets should be set only after the first round of attribution. A useful first target is not CLua parity. It is reducing the largest category-level gaps without making correctness or embeddability less robust.
