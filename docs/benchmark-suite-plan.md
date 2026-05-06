# CLua Benchmark Suite Plan

## Goal

Add a benchmark harness that compares `zlua` against the vendored Lua 5.5 CLua executable across the main interpreter performance edges. The suite should be useful for tracking regressions over time, identifying which VM or stdlib areas need optimization, and comparing behavior under the same source workloads without becoming part of normal CI correctness checks.

## User Interface

The benchmark harness should be installed as a new executable:

```text
zig-out/bin/zlua-test-bench
```

Build integration should mirror the existing differential and official harnesses:

```text
zig build run-test-bench
zig build run-test-bench -- tests/bench/vm/arithmetic.lua
```

The `justfile` should add:

```text
just bench [optional benchmark file]
```

Example invocations:

```text
just bench
just bench tests/bench/vm/arithmetic.lua
just bench arithmetic
just bench string_find
just bench tests/bench/stdlib/string_find.lua --iterations=20
```

The default `just bench` should run all benchmark fixtures under `tests/bench`. Positional arguments should narrow the run, matching the style of `just official db`: a user can pass either a full path, a directory, a relative benchmark path, a metadata `name`, or a basename with or without `.lua`.

The harness should discover the available benchmark files before resolving positional arguments. This lets it know the full set of choices and produce useful errors for missing or ambiguous selectors.

Selector examples:

```text
just bench arithmetic
just bench arithmetic.lua
just bench vm/arithmetic
just bench tests/bench/vm/arithmetic.lua
just bench stdlib/string_find
```

If more than one benchmark matches a short selector, the harness should fail with the matching candidates and ask for a more specific selector. Add `--list` to print all known benchmark selectors without running them.

## Build Wiring

Add `src/test_bench_main.zig` as a thin CLI entrypoint like `src/test_diff_main.zig` and `src/test_official_main.zig`.

Add a new testing module implementation under:

```text
src/testing/bench_runner.zig
```

Update `src/root.zig` to expose it through `zlua.testing` if needed by the entrypoint.

Update `build.zig` to:

```text
1. Add executable `zlua-test-bench`.
2. Install the executable with the other harnesses.
3. Add a `run-test-bench` step.
4. Pass `--clua` with the vendored `lua5.5` artifact.
5. Pass `--zlua` with the built `zlua` artifact.
6. Forward `b.args` after `--`.
```

Do not add benchmarks to `zig build ci`. Benchmarks are timing-sensitive and should be explicitly invoked.

Update `justfile` with:

```just
# Run zlua vs CLua benchmarks, or one benchmark file/directory.
bench *args:
    {{zig}} build --summary all run-test-bench -- {{args}}
```

## Fixture Layout

Use a dedicated tree so performance fixtures do not mix with correctness fixtures:

```text
tests/bench/
  vm/
  frontend/
  stdlib/
  gc/
  patterns/
  fixtures/
```

Each benchmark should be plain Lua and executable by both CLua and zlua. The harness should not require a Lua-side framework dependency.

Use top-of-file metadata comments, similar to differential tests:

```lua
-- name: arithmetic/integer_add
-- category: vm
-- iterations: 10
-- warmup: 2
-- timeout-ms: 30000
-- expect: pass

local sum = 0
for i = 1, 20000000 do
  sum = sum + i
end
print(sum)
```

Initial metadata keys:

```text
name: stable display name; defaults to path
category: vm, frontend, stdlib, gc, patterns, or misc
iterations: measured repeats per engine
warmup: unmeasured repeats per engine
timeout-ms: per process timeout
expect: pass, skip, or fail
reason: required for skip/fail
```

The benchmark suite should compare output correctness before reporting timing. If CLua and zlua produce different stdout, stderr, or exit status, mark the benchmark as failed and do not treat timing as meaningful.

## Harness Behavior

For each benchmark file:

```text
1. Discover all benchmark files under `tests/bench`.
2. Parse metadata for selector names and categories.
3. Resolve positional selectors against discovered files.
4. Run CLua warmups.
5. Run zlua warmups.
6. Run CLua measured iterations.
7. Run zlua measured iterations.
8. Verify result compatibility from at least one measured run.
9. Print per-benchmark timing and ratio.
10. Print a suite summary grouped by category.
```

Default process execution should use `src/testing/process.zig` so timeouts, output caps, and future resource limits remain consistent with the other harnesses.

Use process-level measurements initially. This includes startup time, parser time, compiler time, runtime initialization, and execution. That makes the first version simple and comparable to real CLI use. Add opt-in in-process zlua measurements later only when the embedding/runtime API is stable enough to avoid duplicated execution paths.

Recommended default timing settings:

```text
warmup: 1
iterations: 5
timeout-ms: 60000
max-output-bytes: 1048576
```

The harness should support CLI overrides:

```text
--clua PATH
--zlua PATH
--list
--iterations N
--warmup N
--timeout-ms N
--category NAME
--json PATH
--csv PATH
--no-warmup
--debug-errors
```

`--json` should be the primary machine-readable output for future dashboards. Human output should stay compact and terminal-friendly.

## Timing Metrics

Capture at least:

```text
engine: clua or zlua
benchmark path
category
iteration count
warmup count
min wall time
median wall time
mean wall time
max wall time
standard deviation
zlua/clua ratio
exit status
timeout flag
```

Wall-clock time is enough for the initial harness. CPU time and peak RSS can be added later behind platform-specific support.

Report ratios as:

```text
zlua_time / clua_time
```

Lower is better. A ratio of `1.00x` means parity with CLua, `2.00x` means zlua took twice as long, and `0.50x` means zlua took half as long.

## Benchmark Coverage

The first benchmark set should cover broad edges rather than micro-optimizing one implementation detail.

### Frontend

These isolate lexer, parser, resolver, and compiler-heavy workloads through CLI execution:

```text
large flat source file
many local declarations
deep expression trees
many nested blocks
many function declarations
large table constructors
large string literals
large numeric literal sets
```

### VM Dispatch And Arithmetic

These stress instruction dispatch and scalar hot paths:

```text
integer addition loop
float arithmetic loop
mixed numeric coercion loop
bitwise operation loop
comparison-heavy loop
boolean branch loop
numeric for loop
generic for loop over tables
while loop with manual index
repeat-until loop
```

### Locals, Upvalues, And Calls

These stress stack/register handling and closure mechanics:

```text
local variable reads/writes
global variable reads/writes
function call loop
recursive calls
tail-recursive calls
closure creation
upvalue reads/writes
vararg calls
multiple return propagation
method calls with colon syntax
```

### Tables And Metatables

These cover the highest-risk Lua data-structure paths:

```text
array append
array indexed reads
array indexed writes
sparse integer keys
string-key reads/writes
mixed key types
table constructor bulk creation
table iteration with pairs
table iteration with ipairs
metatable __index function
metatable __index table
metatable __newindex
arithmetic metamethods
comparison metamethods
```

### Strings And Stdlib

These stress allocation, hashing, and C-library parity paths:

```text
string concatenation growth
short string interning/hash lookup
long string equality
string.sub loop
string.find plain search
string.find pattern search
string.gsub replacement
table.concat
table.sort numeric
table.sort custom comparator
math library tight loops
utf8.len and utf8.codes
```

### Garbage Collection And Allocation

These expose allocator pressure and collector behavior:

```text
many short-lived tables
many short-lived closures
many short-lived strings
retained table graph
large temporary arrays
weak table churn
collectgarbage forced cycles
metatable-heavy object churn
```

### Coroutines And Control Transfer

Include once coroutine support is reliable enough for comparable runs:

```text
coroutine create/resume loop
yield/resume ping-pong
coroutine with captured upvalues
error propagation through pcall
xpcall with handler
to-be-closed variable unwinding
```

### Realistic Patterns

These should combine language features in ways closer to user programs:

```text
tokenizer over a large string
recursive-descent parser over generated input
JSON-like table construction and traversal
object-style method dispatch
memoized Fibonacci or dynamic-programming table
small module load graph
text processing with patterns
```

## Fixture Design Rules

Benchmark fixtures should:

```text
print a deterministic final checksum
avoid filesystem and wall-clock reads unless the benchmark is explicitly about I/O
avoid random input unless seeded deterministically
keep stdout tiny
run long enough to overcome startup noise
prefer one dominant behavior per file
avoid relying on unspecified table iteration order for output
```

Benchmarks should not:

```text
hide correctness failures behind timing output
benchmark unsupported features as normal pass cases
require system Lua or external packages
depend on host-specific paths
produce large output streams
```

## Output Format

Human output should be concise:

```text
bench vm/arithmetic_integer.lua       clua 120.4ms  zlua 315.8ms  ratio 2.62x
bench table/array_append.lua          clua 180.1ms  zlua 740.9ms  ratio 4.11x

summary
category   count  median-ratio  worst-ratio
vm         10     2.40x         5.10x
table      12     3.80x         9.20x
```

JSON output should include raw samples, not just aggregates, so external tools can recompute statistics.

## Regression Policy

The first version should not fail on performance thresholds. It should fail only when:

```text
CLua cannot be found
zlua cannot be found
a benchmark marked pass produces incompatible output
a benchmark times out
the harness encounters invalid metadata
```

Add optional thresholds later, probably through metadata:

```text
-- max-ratio: 10.0
```

Thresholds should be opt-in until the suite has stable history on common machines.

## Implementation Phases

### Phase 1: Harness Skeleton

```text
1. Add `zlua-test-bench` executable and `run-test-bench` build step.
2. Add `just bench *args`.
3. Discover `.lua` files under `tests/bench` or run a provided file/directory.
4. Parse minimal metadata.
5. Run CLua and zlua through `process.runProcess`.
6. Print per-file wall-clock timings and ratios.
```

### Phase 2: Initial Benchmark Corpus

```text
1. Add 20-30 benchmark files across VM, table, string, stdlib, and GC categories.
2. Ensure each fixture prints a deterministic checksum.
3. Mark unsupported feature benchmarks as skip or fail with a reason.
4. Keep each default benchmark under roughly one minute on a development machine.
```

### Phase 3: Reporting

```text
1. Add median/mean/min/max/stddev calculations.
2. Add category summaries.
3. Add JSON output.
4. Add CSV output if useful for ad-hoc spreadsheet analysis.
```

### Phase 4: Stability And History

```text
1. Add optional benchmark threshold metadata.
2. Add a script or dashboard path that compares JSON results over time.
3. Consider a quick subset for local smoke checks.
4. Consider platform-specific RSS and CPU-time collection.
```

## Open Questions

```text
Should the first benchmark command default to ReleaseSafe or inherit the user's selected optimize mode?
Should `just bench` force `-Doptimize=ReleaseFast`, or should that be a separate `just bench-release` command?
Should the initial harness run CLua and zlua in alternating order to reduce thermal/cache bias?
Should in-process zlua execution be added before or after JSON reporting?
```

The recommended first implementation is to inherit the build optimize mode, document that serious runs should use `zig build -Doptimize=ReleaseFast run-test-bench`, and add a later convenience recipe only if local workflow shows it is needed.
