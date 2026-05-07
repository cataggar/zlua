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
| gc | 5 | 3.28x | 6.46x |
| stdlib | 4 | 1.34x | 3.51x |
| string | 5 | 1.89x | 3.35x |
| table | 6 | 3.84x | 4.84x |
| vm | 6 | 3.45x | 6.50x |

Full baseline:

| Benchmark | Category | CLua Mean | zlua Mean | Ratio |
| --- | --- | ---: | ---: | ---: |
| `gc/collectgarbage_cycles.lua` | gc | 8.3ms | 54.2ms | 6.46x |
| `gc/retained_graph.lua` | gc | 0.7ms | 1.0ms | 1.47x |
| `gc/short_lived_closures.lua` | gc | 2.8ms | 7.9ms | 2.79x |
| `gc/short_lived_strings.lua` | gc | 5.4ms | 17.8ms | 3.28x |
| `gc/short_lived_tables.lua` | gc | 4.8ms | 21.0ms | 4.29x |
| `stdlib/math_loop.lua` | stdlib | 3.2ms | 11.2ms | 3.51x |
| `stdlib/table_concat.lua` | stdlib | 47.4ms | 45.4ms | 0.95x |
| `stdlib/table_sort.lua` | stdlib | 2.5ms | 3.5ms | 1.39x |
| `stdlib/utf8_codes.lua` | stdlib | 0.7ms | 0.9ms | 1.28x |
| `string/concat_growth.lua` | string | 1.7ms | 3.0ms | 1.75x |
| `string/find_pattern.lua` | string | 2.2ms | 7.6ms | 3.35x |
| `string/find_plain.lua` | string | 2.8ms | 4.4ms | 1.57x |
| `string/gsub_replace.lua` | string | 20.2ms | 38.5ms | 1.89x |
| `string/sub_loop.lua` | string | 2.4ms | 7.6ms | 3.16x |
| `table/array_append.lua` | table | 1.8ms | 7.3ms | 3.89x |
| `table/array_reads.lua` | table | 2.9ms | 14.2ms | 4.84x |
| `table/array_writes.lua` | table | 3.2ms | 15.2ms | 4.63x |
| `table/metatable_index.lua` | table | 2.3ms | 8.8ms | 3.79x |
| `table/pairs_iteration.lua` | table | 6.5ms | 11.6ms | 1.79x |
| `table/string_keys.lua` | table | 1.3ms | 3.9ms | 2.87x |
| `vm/arithmetic.lua` | vm | 0.9ms | 1.1ms | 1.15x |
| `vm/comparison_branch.lua` | vm | 1.7ms | 11.5ms | 6.50x |
| `vm/float_arithmetic.lua` | vm | 1.6ms | 5.1ms | 3.22x |
| `vm/function_calls.lua` | vm | 2.6ms | 9.6ms | 3.68x |
| `vm/locals.lua` | vm | 1.8ms | 11.2ms | 6.16x |
| `vm/upvalues.lua` | vm | 4.1ms | 10.3ms | 2.49x |

## Interpretation

The strongest signal is no longer a single catastrophic category gap. The benchmark suite now shows smaller but still broad overhead in ordinary VM and table paths, with GC allocation-heavy cases still visible.

| Area | Signal | Initial Read |
| --- | --- | --- |
| VM conditionals | `vm/comparison_branch.lua` at 6.50x | Highest priority because it mixes common integer arithmetic, comparisons, boolean materialization, and branch dispatch. |
| VM register traffic | `vm/locals.lua` at 6.16x | Suggests the main interpreter loop still pays material overhead for frame/base/stack access and helper calls. |
| Table indexed access | array reads and writes at 4.84x and 4.63x | Suggests ordinary table get/set paths need direct fast paths before deeper representation changes. |
| Short-lived tables | `gc/short_lived_tables.lua` at 4.29x | Likely combines table construction, raw array/hash fill, allocator pressure, and collector accounting. |
| Explicit GC cycles | `gc/collectgarbage_cycles.lua` at 6.46x | Suggests full collection remains expensive and should be treated separately from normal allocation pacing. |
| String pattern search | `string/find_pattern.lua` at 3.35x | Still worth isolating, but it is no longer the dominant project versus VM/table work. |

`stdlib/table_concat.lua` at 0.95x and `vm/arithmetic.lua` at 1.15x are important counterexamples: not every path is dominated by interpreter dispatch. Keep these benchmarks as guards against broad assumptions.

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
| P0 | VM fast paths | `vm/locals` and `vm/comparison_branch` are the largest non-GC signals and exercise core interpreter overhead. |
| P0 | Table array get/set | `table/array_reads`, `table/array_writes`, and `table/array_append` remain broad hot paths for normal Lua code. |
| P0 | Conditional branch lowering | Current compiler output materializes many branch conditions into registers before `test_op`; compare-and-branch bytecode may reduce instruction count. |
| P1 | Fresh table construction and raw fill | Short-lived table benchmarks likely pay both general metamethod paths and collector pressure. |
| P1 | GC accounting and collection model | `collectgarbage_cycles` remains the worst GC fixture, but a full generational rewrite should follow smaller attribution work. |
| P1 | Call/return allocation | `vm/function_calls` is still slower enough to justify examining frame and return handling after register/table work. |
| P2 | String search and pattern paths | Pattern and substring loops still lag, but they are lower-value than core VM/table costs in this snapshot. |
| P2 | Value representation | NaN boxing may help stack/table density later, but it is a wide API/runtime change and should be driven by post-fast-path profiles. |

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
inline fast integer arithmetic and comparison paths in the dispatch loop
add compare-and-branch bytecode or a compileCondition path for if/while/repeat
add raw fast paths for plain table array and string-key access
avoid double lookup in common table set paths
use raw array/hash fill for fresh table constructors before exposing the table
cache interned string hashes or add pointer fast paths for interned strings
replace linear object tracking checks with object headers or side maps
maintain running allocation counters instead of scanning all allocations
avoid heap allocation for common fixed return and vararg paths
specialize simple string.find and string.gsub cases before pattern backtracking
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
