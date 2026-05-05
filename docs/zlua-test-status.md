# zlua Test Status

Last updated: 2026-05-05

This document tracks the test layers currently used for zlua and the current status of each official Lua 5.5 test file in the basic official dashboard.

## Test Layers

| Test layer | Command | Status | Notes |
| --- | --- | --- | --- |
| Unit tests | `zig build test` or `just test` | Pass | Runs Zig tests for the library module and CLI root module. |
| CLua differential fixtures | `zig build test-diff` or `just diff-ci` | Pass | Current summary: `passed=51`, `failed=0`, `unexpected_failed=0`. Individual handwritten fixtures are not listed here. |
| Official Lua 5.5 quick subset | `zig build test-official` or `just official-ci` | Pass | Runs every per-file official test except memory-stress `heavy.lua`. Current summary: `clua_passed=32`, `clua_failed=0`, `zlua_passed=14`, `categorized_failed=18`, `skipped=1`, `unexpected_failed=0`. |
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

Latest focused work verified with `zig build test`, `zig build test-diff`, `zig build test-official`, and `just official-file calls`.

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

`calls.lua` now passes in the basic official dashboard.

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
| `constructs.lua` | Pass | XFail | `runtime` |
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
| `math.lua` | Pass | XFail | `runtime` |
| `memerr.lua` | Pass | Pass |  |
| `nextvar.lua` | Pass | XFail | `runtime` |
| `pm.lua` | Pass | XFail | `runtime` |
| `sort.lua` | Pass | XFail | `runtime` |
| `strings.lua` | Pass | XFail | `runtime` |
| `tpack.lua` | Pass | XFail | `runtime` |
| `tracegc.lua` | Pass | Pass |  |
| `utf8.lua` | Pass | XFail | `runtime` |
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
| zlua passes | 14 |
| Categorized zlua failures | 18 |
| Timeouts | 0 |
| Unexpected failures | 0 |
