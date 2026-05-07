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
just bench --iterations 20
```

This builds `zlua` in `ReleaseFast` through the `justfile` recipe and compares it against the vendored `lua5.5` oracle. The harness uses process-level timing, so results include startup, parsing, compilation, runtime initialization, and execution.

Captured on 2026-05-07 from the local workspace after the first P0 VM/table fast-path pass.

```text
totals  benchmarked=26  skipped=0  failed=0  timed_out=0
```

Category summary:

| Category | Count | Median Ratio | Worst Ratio |
| --- | ---: | ---: | ---: |
| gc | 5 | 1.71x | 2.82x |
| stdlib | 4 | 1.14x | 1.86x |
| string | 5 | 1.73x | 2.11x |
| table | 6 | 1.82x | 2.50x |
| vm | 6 | 1.93x | 2.16x |

Full baseline:

| Benchmark | Category | CLua Mean | zlua Mean | Ratio |
| --- | --- | ---: | ---: | ---: |
| `gc/collectgarbage_cycles.lua` | gc | 8.2ms | 10.8ms | 1.31x |
| `gc/retained_graph.lua` | gc | 0.6ms | 0.9ms | 1.39x |
| `gc/short_lived_closures.lua` | gc | 3.0ms | 5.1ms | 1.71x |
| `gc/short_lived_strings.lua` | gc | 5.2ms | 9.1ms | 1.75x |
| `gc/short_lived_tables.lua` | gc | 4.6ms | 13.1ms | 2.82x |
| `stdlib/math_loop.lua` | stdlib | 3.2ms | 6.0ms | 1.86x |
| `stdlib/table_concat.lua` | stdlib | 47.7ms | 44.7ms | 0.93x |
| `stdlib/table_sort.lua` | stdlib | 2.6ms | 2.6ms | 1.00x |
| `stdlib/utf8_codes.lua` | stdlib | 0.7ms | 0.9ms | 1.27x |
| `string/concat_growth.lua` | string | 1.3ms | 2.7ms | 2.11x |
| `string/find_pattern.lua` | string | 2.3ms | 2.9ms | 1.27x |
| `string/find_plain.lua` | string | 1.7ms | 3.4ms | 1.99x |
| `string/gsub_replace.lua` | string | 19.2ms | 33.3ms | 1.73x |
| `string/sub_loop.lua` | string | 2.4ms | 3.9ms | 1.59x |
| `table/array_append.lua` | table | 2.0ms | 3.0ms | 1.52x |
| `table/array_reads.lua` | table | 2.1ms | 4.5ms | 2.11x |
| `table/array_writes.lua` | table | 2.5ms | 4.8ms | 1.89x |
| `table/metatable_index.lua` | table | 2.3ms | 5.9ms | 2.50x |
| `table/pairs_iteration.lua` | table | 6.0ms | 10.5ms | 1.74x |
| `table/string_keys.lua` | table | 1.4ms | 1.8ms | 1.26x |
| `vm/arithmetic.lua` | vm | 0.6ms | 0.8ms | 1.21x |
| `vm/comparison_branch.lua` | vm | 1.7ms | 3.0ms | 1.79x |
| `vm/float_arithmetic.lua` | vm | 1.0ms | 1.8ms | 1.86x |
| `vm/function_calls.lua` | vm | 2.0ms | 4.1ms | 2.03x |
| `vm/locals.lua` | vm | 1.9ms | 3.9ms | 2.00x |
| `vm/upvalues.lua` | vm | 2.0ms | 4.3ms | 2.16x |

## Interpretation

The strongest signal is no longer a single catastrophic category gap. The first P0 fast-path pass reduced every category worst ratio below 3x, mostly by keeping simple numeric loops inside the plain fast loop, adding raw `#` handling, reducing compiler-emitted register traffic, and adding more raw table fast paths. The remaining gaps are smaller and more mixed: metatable/table misses, function/upvalue traffic, short-lived table allocation, and a few string loops now dominate more than basic dispatch.

| Area | Signal | Initial Read |
| --- | --- | --- |
| Table metatable/index path | `table/metatable_index.lua` at 2.50x | Now the worst table fixture; likely spends time in general get/metamethod lookup and should be profiled before adding more table representation complexity. |
| Short-lived tables | `gc/short_lived_tables.lua` at 2.82x | Worst overall fixture; likely combines table allocation, growth, raw fill, and collector accounting. Treat as allocation/table-construction work first, not a full GC rewrite by default. |
| Function/upvalue traffic | `vm/function_calls.lua` at 2.03x and `vm/upvalues.lua` at 2.16x | VM arithmetic and branching improved enough that call frames, return adjustment, closure/upvalue access, and continuation state are now better P0/P1 candidates. |
| Array reads and locals | `table/array_reads.lua` at 2.11x and `vm/locals.lua` at 2.00x | Remaining overhead likely comes from instruction count, constant loading, table hash/array checks, and non-packed `Value`/instruction representation more than missing gross fast paths. |
| String loops | `string/concat_growth.lua` at 2.11x and `string/find_plain.lua` at 1.99x | String work is now competitive with VM/table as a follow-up target; focus on simple fast paths before deeper pattern changes. |
| Explicit GC cycles | `gc/collectgarbage_cycles.lua` at 1.31x | No longer a top gap after allocation accounting/fast-loop improvements; keep it as a regression guard while prioritizing normal allocation paths. |

`stdlib/table_concat.lua` at 0.93x, `stdlib/table_sort.lua` at 1.00x, and `vm/arithmetic.lua` at 1.21x are important counterexamples: not every path is dominated by interpreter dispatch. Keep these benchmarks as guards against broad assumptions.

## Scope

Milestone 24 should cover five workstreams.

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
| P0 done | First VM/table fast-path pass | Plain fast loop now covers no-op `close`, raw `len`, more raw table get/set cases, compare branches, and direct local-left binary operands. Preserve these with targeted regression benchmarks. |
| P0 | Fresh table construction and raw fill | `gc/short_lived_tables` is now the worst benchmark at 2.82x; profile constructor emission, table hints, array growth, and raw fill before changing the collector. |
| P0 | Metatable and table lookup attribution | `table/metatable_index` is the worst table fixture at 2.50x; profile general `getTable`/metamethod lookup and avoid broad table rewrites until the miss/metamethod cost is clear. |
| P1 | Call/return and upvalue traffic | `vm/function_calls` and `vm/upvalues` are now the highest VM ratios; inspect frame allocation, fixed-return adjustment, closure allocation, and open-upvalue lookup. |
| P1 | Instruction count and constant operands | `vm/locals`, `table/array_reads`, and `vm/comparison_branch` still pay repeated constant loads and multi-instruction common expressions; constant operands or peephole lowering may help. |
| P1 | String simple fast paths | `string/concat_growth` and `string/find_plain` are now near the top; specialize simple concat/find/sub cases before investing in pattern machinery. |
| P2 | GC collection model | `collectgarbage_cycles` is much less urgent than normal allocation-heavy table cases; defer a real generational collector until allocation hot paths are attributed. |
| P2 | Value and bytecode representation | NaN boxing and packed bytecode may help the remaining broad 1.7x-2.1x gaps, but they are cross-cutting and should follow profiles of table construction, calls, and instruction count. |

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
profile fresh table construction and raw constructor fill
use raw array/hash fill for fresh table constructors before exposing the table
presize array/hash parts from constructor and loop patterns where safe
profile general getTable/setTable metamethod lookup and table miss handling
avoid double lookup in remaining common table get/set paths
add constant-operand or peephole forms for arithmetic, modulo, and comparisons
reduce repeated constant loads in numeric loops and branch conditions
avoid heap allocation for common fixed return and vararg paths
speed up open-upvalue lookup or cache closure/upvalue access patterns
specialize simple string.find, string.sub, and concat growth cases before pattern backtracking
cache interned string hashes or add pointer fast paths for interned strings
replace linear object tracking checks with object headers or side maps
maintain running allocation counters instead of scanning all allocations
```

### 3. Larger Runtime Projects

Several larger projects are plausible, but they should follow the P0 fast-path work unless profiling proves otherwise.

| Project | Current Recommendation | Reason |
| --- | --- | --- |
| Lua 5.5-style generational GC | Defer until after allocation accounting and table/closure allocation hot paths are measured. | The current `generational` mode is API-compatible surface over full reset/mark/sweep behavior, and true young/old collection touches weak tables, finalizers, write barriers, threads, strings, and API roots. |
| NaN-boxed values | Defer until VM/table fast paths are exhausted. | It can improve stack/table density, but it changes the central `Value` representation and all API/C API conversion paths. |
| Jump-table or threaded dispatch | Defer for now. | `vm/arithmetic.lua` is already close to CLua, so raw opcode dispatch is probably not the dominant bottleneck yet. |
| Packed bytecode | Defer until instruction-count and cache profiles justify it. | It is likely useful, but current evidence points first to helper calls, branch lowering, table paths, and allocation/GC behavior. |
| Table representation rewrite | Defer unless targeted array/string-key fast paths plateau. | The existing split array/hash structure can still support cheaper common-case access before a full layout rewrite. |

Packed bytecode, threaded dispatch, NaN boxing, generational GC, and larger table rewrites are likely useful long-term, but they carry more regression risk than the next VM/table fast-path projects.

### 4. Hardening And Resource Limits

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

### 5. Regression Tracking

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
