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

## Result Model

The harness measures whole-process elapsed time, including:

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

These are CLI-level benchmarks. They catch broad regressions, but they do not isolate VM dispatch, allocator behavior, table lookup, GC, or individual stdlib helpers.

Human output reports min, median, mean, max, standard deviation, and zlua/CLua ratio. JSON and CSV reports include raw nanosecond samples for later comparison.

## Current Baseline

The latest documented local baseline was captured on 2026-05-07 with:

```sh
just bench --iterations 20 --json /tmp/zlua-bench-current.json
```

Summary:

```text
totals  benchmarked=26  skipped=0  failed=0  timed_out=0
```

Category summary:

| Category | Count | Median Ratio | Worst Ratio |
| --- | ---: | ---: | ---: |
| gc | 5 | 1.82x | 2.81x |
| stdlib | 4 | 1.12x | 1.76x |
| string | 5 | 1.70x | 1.98x |
| table | 6 | 1.84x | 2.49x |
| vm | 6 | 1.85x | 2.47x |

Full baseline:

| Benchmark | Category | CLua Mean | zlua Mean | Ratio |
| --- | --- | ---: | ---: | ---: |
| `gc/collectgarbage_cycles.lua` | gc | 8.6ms | 10.9ms | 1.26x |
| `gc/retained_graph.lua` | gc | 0.7ms | 0.9ms | 1.35x |
| `gc/short_lived_closures.lua` | gc | 2.7ms | 5.1ms | 1.86x |
| `gc/short_lived_strings.lua` | gc | 5.0ms | 9.1ms | 1.82x |
| `gc/short_lived_tables.lua` | gc | 4.6ms | 13.0ms | 2.81x |
| `stdlib/math_loop.lua` | stdlib | 3.4ms | 6.1ms | 1.76x |
| `stdlib/table_concat.lua` | stdlib | 47.3ms | 44.8ms | 0.94x |
| `stdlib/table_sort.lua` | stdlib | 2.6ms | 2.6ms | 1.00x |
| `stdlib/utf8_codes.lua` | stdlib | 0.7ms | 0.9ms | 1.24x |
| `string/concat_growth.lua` | string | 1.3ms | 2.6ms | 1.98x |
| `string/find_pattern.lua` | string | 2.2ms | 2.9ms | 1.30x |
| `string/find_plain.lua` | string | 1.7ms | 3.3ms | 1.95x |
| `string/gsub_replace.lua` | string | 19.3ms | 33.1ms | 1.70x |
| `string/sub_loop.lua` | string | 2.4ms | 3.9ms | 1.59x |
| `table/array_append.lua` | table | 1.9ms | 3.0ms | 1.53x |
| `table/array_reads.lua` | table | 2.1ms | 4.5ms | 2.08x |
| `table/array_writes.lua` | table | 2.5ms | 4.8ms | 1.90x |
| `table/metatable_index.lua` | table | 2.3ms | 5.9ms | 2.49x |
| `table/pairs_iteration.lua` | table | 6.0ms | 10.7ms | 1.79x |
| `table/string_keys.lua` | table | 1.4ms | 1.8ms | 1.24x |
| `vm/arithmetic.lua` | vm | 0.6ms | 0.8ms | 1.26x |
| `vm/comparison_branch.lua` | vm | 1.7ms | 3.0ms | 1.77x |
| `vm/float_arithmetic.lua` | vm | 1.0ms | 1.8ms | 1.77x |
| `vm/function_calls.lua` | vm | 2.0ms | 4.3ms | 2.16x |
| `vm/locals.lua` | vm | 2.0ms | 3.8ms | 1.92x |
| `vm/upvalues.lua` | vm | 1.9ms | 4.9ms | 2.47x |

These numbers are a local snapshot, not a threshold. Machine, Zig version, CPU scaling, filesystem state, and process noise all affect results.

## Performance Workflow

For optimization work:

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

Benchmarks are not part of `zig build ci`. Do not add performance thresholds to CI until there is enough cross-machine history.

Correctness gates remain unit tests, embedding examples, differential fixtures, official dashboard runs, and C API fixtures.
