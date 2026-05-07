# Benchmarking

zlua benchmarks are comparison tools, not correctness gates. The benchmark harness runs Lua benchmark files with the downloaded CLua oracle and a ReleaseFast zlua binary, records process-level timings, and reports zlua/CLua ratios.

## Commands

Run the default benchmark set:

```sh
just bench
```

Focused runs:

```sh
just bench --list
just bench --category table
just bench table/pairs_iteration --iterations=20
just bench vm/locals --iterations=20 --no-warmup
```

Capture reports:

```sh
just bench --iterations=20 --json /tmp/zlua-bench.json
just bench --iterations=20 --csv /tmp/zlua-bench.csv
```

The just recipe builds the benchmarked zlua CLI in `ReleaseFast`:

```sh
zig build -Doptimize=ReleaseFast --summary all run-test-bench -- <args>
```

The build also passes a ReleaseFast `zlua-bench-release-fast` executable to the harness and compares it with the vendored `lua5.5` binary.

## Benchmark Fixtures

Benchmark fixtures live under `tests/bench/**/*.lua`. Categories are encoded by metadata and currently cover GC, standard library, string, table, and VM workloads.

Supported fixture metadata is parsed by `src/testing/bench_runner.zig`:

| Key | Values | Default |
| --- | --- | --- |
| `name` | Display name | Fixture path |
| `category` | Free-form category | `misc` |
| `iterations` | Positive integer | `5` |
| `warmup` | Non-negative integer | `1` |
| `timeout-ms` | Positive integer | `60000` |
| `expect` | `pass`, `fail`, `skip` | `pass` |
| `reason` | Required for `fail` or `skip` | empty |

Example:

```lua
-- name: table/array_reads
-- category: table
-- iterations: 10
-- warmup: 1
-- timeout-ms: 60000

local t = {}
for i = 1, 100000 do t[i] = i end
```

## What The Numbers Mean

The harness measures whole-process elapsed time. Results include:

```text
process startup
runtime initialization
source loading
parsing
resolving
compilation
execution
shutdown
```

This is intentional: the current benchmark suite tracks user-visible CLI performance and catches broad regressions. It does not isolate in-process VM dispatch or individual runtime helpers. Use a profiler or a more targeted harness before making large representation changes based on one ratio.

Human output reports min, median, mean, max, standard deviation, and zlua/CLua ratio. JSON and CSV reports include raw nanosecond samples for later comparison.

## Current Baseline

The latest documented local baseline was captured on 2026-05-07 with:

```sh
just bench --iterations 20
```

Summary:

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

These numbers are a local snapshot, not a portable threshold. Machine, Zig version, CPU scaling, filesystem state, and process noise all affect results.

## Interpretation

The current baseline no longer shows one catastrophic category gap. The strongest remaining signals are allocation-heavy table creation, metatable lookup, function/upvalue traffic, repeated table/constant access, and a few string loops.

Useful reads from the baseline:

| Area | Signal | Initial interpretation |
| --- | --- | --- |
| Fresh table allocation and fill | `gc/short_lived_tables.lua` at 2.82x | Profile construction, hints, growth, raw fill, and allocation accounting before changing the collector. |
| Metatable lookup | `table/metatable_index.lua` at 2.50x | Attribute general `getTable` and metamethod lookup costs before a broad table rewrite. |
| Calls and upvalues | `vm/function_calls.lua` at 2.03x and `vm/upvalues.lua` at 2.16x | Inspect frame setup, return adjustment, closure allocation, continuation state, and open-upvalue access. |
| Instruction count and constants | `vm/locals.lua` and `table/array_reads.lua` around 2x | Constant operands or peephole lowering may help, but profiles should come first. |
| Simple string paths | `string/concat_growth.lua` and `string/find_plain.lua` near 2x | Specialize plain cases before deeper pattern machinery work. |

Counterexamples matter: `stdlib/table_concat.lua` and `stdlib/table_sort.lua` are at or faster than CLua in the baseline, and `vm/arithmetic.lua` is close. Avoid assuming every workload is dispatch-bound.

## Performance Workflow

Use this workflow for optimization work:

1. Capture a baseline with JSON or CSV output.
2. Reproduce the relevant category or benchmark with enough iterations to see variance.
3. Profile before changing broad runtime structures.
4. Add or preserve a benchmark that represents the target path.
5. Make the smallest compatibility-preserving change.
6. Run correctness checks before judging speed.
7. Capture an after snapshot and compare raw samples, means, medians, and worst ratios.

Recommended checks for runtime changes:

```sh
zig build test
zig build test-diff
zig build test-official
just bench --category <category> --iterations=20 --json /tmp/after.json
```

Run `zig build ci` for broad validation when the change touches shared VM, GC, compiler, stdlib, or host-capability code.

## Threshold Policy

Benchmarks are not part of `zig build ci`, and no performance thresholds should be added to CI until there is enough cross-machine history. If thresholds are added later, they should be opt-in, local to a benchmark, and generous enough to catch obvious regressions rather than normal machine variance.

Correctness gates remain unit tests, embedding examples, differential fixtures, official dashboard runs, and C API fixtures.
