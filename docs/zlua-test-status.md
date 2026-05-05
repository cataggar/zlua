# zlua Test Status

Last updated: 2026-05-05

This document tracks the test layers currently used for zlua and the current status of each official Lua 5.5 test file in the basic official dashboard.

## Test Layers

| Test layer | Command | Status | Notes |
| --- | --- | --- | --- |
| Unit tests | `zig build test` or `just test` | Pass | Runs Zig tests for the library module and CLI root module. |
| CLua differential fixtures | `zig build test-diff` or `just diff-ci` | Pass | Current summary: `passed=51`, `failed=0`, `unexpected_failed=0`. Individual handwritten fixtures are not listed here. |
| Official Lua 5.5 quick subset | `zig build test-official` or `just official-ci` | Pass | Runs every per-file official test except memory-stress `heavy.lua`. Current summary: `clua_passed=32`, `clua_failed=0`, `zlua_passed=18`, `categorized_failed=14`, `skipped=1`, `timed_out=0`, `unexpected_failed=0`. |
| Official Lua 5.5 heavy dashboard | `zig build test-official-heavy` or `just official-heavy` | Pass as dashboard | Full official dashboard. Last recorded summary: `clua_passed=33`, `clua_failed=0`, `zlua_passed=13`, `categorized_failed=20`, `unexpected_failed=0`. Not rerun during the latest focused `calls.lua` work. Categorized zlua failures remain expected work items. |
| Full CI aggregate | `zig build ci` or `just ci` | Pass if child layers pass | Build step depends on unit tests, differential fixtures, and the quick official subset. |
| Focused official file runner | `just official-file NAME` | Helper | Runs one official test file through zlua with the basic official prelude. Accepts names with or without `.lua`. |

## Status Meanings

| Status | Meaning |
| --- | --- |
| Pass | zlua exits successfully for the file in the basic official dashboard. |
| XFail | CLua exits successfully, but zlua currently exits unsuccessfully and the dashboard categorizes the failure. |
| Not run | The file exists in the official suite but is not part of the per-file basic dashboard. |

## Focused Official Progress

Latest focused work verified with `zig build test`, `zig build test-diff`, `zig build test-official`, `zig build ci`, and `just official-file math`.

Latest focused `math.lua` work:

- Numeric comparisons preserve exact integer ordering and handle mixed integer/float boundary cases without rounding through `f64`.
- `math.modf`, integer floor division/modulo, float modulo, `math.floor`/`ceil`, `math.tointeger`, `math.fmod`, `math.frexp`, and `math.ldexp` cover the official numeric edge cases.
- `tonumber` rejects textual `inf`/`nan`, oversized hexadecimal integer strings wrap like Lua integers, and `string.gsub` covers the official numeric-trimming replacement forms used by `math.lua`.
- `math.random`/`randomseed` follow PUC Lua's xoshiro256** state transition, seed warm-up, high-bit float conversion, full-width `random(0)`, and rejection-sampled integer intervals; compiler labels are scoped so repeated `::doagain::` retry blocks jump correctly.

Latest focused `sort.lua` work:

- The official harness no longer applies a per-file timeout by default; quick mode still skips memory-stress `heavy.lua`.
- `table.create` accounts reserved array/hash capacity in `collectgarbage("count")`, uses CLua-compatible 32-bit C `int` bounds, and reports official range/overflow errors.
- `string.packsize("i")` and zlua binary chunk headers now use 4-byte C `int` fields, so official binary header checks pass.
- `table.insert`, `table.unpack`, `table.move`, and `table.sort` cover the official table-library edge cases, including metamethod-aware moves and a non-quadratic sort path.
- `os.clock` is available for official progress timing checks.

Latest focused `utf8.lua` work:

- `utf8.offset` follows Lua 5.5 start/end return semantics, explicit bounds and continuation-byte errors, and sentinel/negative offset behavior.
- `utf8.len`, `utf8.codepoint`, and `utf8.codes` use strict UTF-8 decoding by default while preserving the non-strict path for original 5- and 6-byte sequences.
- `utf8.codes` supports CLua-compatible strict iterator state and direct iterator calls.

Latest focused `constructs.lua` work:

- Numeric `for` variables are not visible to their own start/limit/step expressions, so nested `for i = i, ...` resolves the initializer from the outer scope.
- CLI error exits flush buffered stdout/stderr before printing the runtime error, matching CLua-visible progress output.
- `load` reports official-compatible messages for unknown local attributes and assignment to `<const>`/`<close>` locals.
- `debug.getinfo(level, "n").name` reports names for named Lua function declarations.

Latest focused `calls.lua` work:

- Lua 5.5 `global function name(...) ... end` declarations parse and execute.
- `type()` with no arguments errors, so `pcall(type)` matches CLua.
- Tail calls through `__call` metamethod chains avoid stack overflow.
- `__call` chains use the official 15-link limit and report `too long` for longer chains.
- `debug.getinfo(level, "t").extraargs` reports extra arguments from chained `__call` invocations.
- `load` accepts reader functions, treats empty reader chunks as EOF, and returns `nil, message` for reader errors or non-string chunks.
- `load` preserves chunk names for `debug.getinfo(f).source`.
- `load` rejects text chunks in binary-only mode and binary chunks in text-only mode.
- `load` honors the provided `_ENV` value for loaded chunks and supports varargs at chunk scope.
- `string.dump` and `load` support zlua binary chunks for Lua closures, including fresh dumped upvalues, binary mode checks, header validation, and truncated chunk errors.
- `string.unpack`/`packsize` support fixed-size `cN` strings used by the official binary chunk header checks.
- Return statements are capped at the official 254-result limit.

Latest focused `closure.lua` work:

- Root `_ENV` is initialized from `_G`, so explicit `_ENV[...]` access works in loaded chunks.
- Loop and jump upvalues are closed correctly across `for`, `repeat`, `break`, and `goto` paths covered by the official closure tests.
- Automatic GC now clears weak-table sentinels at safe loop backedges without retaining stale temporaries indefinitely.
- Debug upvalue APIs used by the closure tests are available: `debug.getupvalue`, `debug.setupvalue`, `debug.upvalueid`, and `debug.upvaluejoin`.

`constructs.lua` now passes in the basic official dashboard.

## Official Lua 5.5 Files

The dashboard runs with the basic official prelude: `_U=true; _soft=true; _port=true; _nomsg=true; T=nil; ARG=arg`.

| File | CLua | zlua | Category / notes |
| --- | --- | --- | --- |
| `all.lua` | Not run | Not run | Suite driver excluded from the per-file basic dashboard. |
| `api.lua` | Pass | Pass |  |
| `attrib.lua` | Pass | Pass |  |
| `big.lua` | Pass | Pass |  |
| `bitwise.lua` | Pass | Pass |  |
| `bwcoercion.lua` | Pass | Pass |  |
| `calls.lua` | Pass | Pass |  |
| `closure.lua` | Pass | Pass |  |
| `code.lua` | Pass | Pass |  |
| `constructs.lua` | Pass | Pass |  |
| `coroutine.lua` | Pass | XFail | `runtime` |
| `cstack.lua` | Pass | XFail | `runtime` |
| `db.lua` | Pass | XFail | `runtime` |
| `errors.lua` | Pass | XFail | `runtime` |
| `events.lua` | Pass | XFail | `runtime` |
| `files.lua` | Pass | XFail | `runtime` |
| `gc.lua` | Pass | XFail | `runtime` |
| `gengc.lua` | Pass | Pass |  |
| `goto.lua` | Pass | XFail | `runtime` |
| `heavy.lua` | Pass | Pass |  |
| `literals.lua` | Pass | Pass |  |
| `locals.lua` | Pass | XFail | `runtime` |
| `main.lua` | Pass | Pass |  |
| `math.lua` | Pass | Pass |  |
| `memerr.lua` | Pass | Pass |  |
| `nextvar.lua` | Pass | XFail | `runtime` |
| `pm.lua` | Pass | XFail | `runtime` |
| `sort.lua` | Pass | Pass |  |
| `strings.lua` | Pass | XFail | `runtime` |
| `tpack.lua` | Pass | XFail | `runtime` |
| `tracegc.lua` | Pass | Pass |  |
| `utf8.lua` | Pass | Pass |  |
| `vararg.lua` | Pass | XFail | `runtime` |
| `verybig.lua` | Pass | Pass |  |

## Current Official Summary

| Metric | Count |
| --- | ---: |
| Official files in archive directory, including `all.lua` | 34 |
| Files run by the quick per-file dashboard | 32 |
| Files skipped by the quick per-file dashboard | 1 |
| Files run by the heavy per-file dashboard | 33 |
| CLua passes | 32 |
| CLua failures | 0 |
| zlua passes | 18 |
| Categorized zlua failures | 14 |
| Timeouts | 0 |
| Unexpected failures | 0 |
