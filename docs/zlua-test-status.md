# zlua Test Status

Last updated: 2026-05-06

This document tracks the test layers currently used for zlua and the current status of each official Lua 5.5 test file in the basic official dashboard.

## Test Layers

| Test layer | Command | Status | Notes |
| --- | --- | --- | --- |
| Unit tests | `zig build test` or `just test` | Pass | Runs Zig tests for the library module and CLI root module. |
| CLua differential fixtures | `zig build test-diff` or `just diff-ci` | Pass | Current summary: `passed=51`, `failed=0`, `unexpected_failed=0`. Individual handwritten fixtures are not listed here. |
| Official Lua 5.5 quick subset | `zig build test-official` or `just official-ci` | Pass | Runs every per-file official test except memory-stress `heavy.lua`. Current summary: `clua_passed=32`, `clua_failed=0`, `zlua_passed=29`, `categorized_failed=3`, `skipped=1`, `timed_out=0`, `unexpected_failed=0`. |
| Official Lua 5.5 heavy dashboard | `zig build test-official-heavy` or `just official-heavy` | Pass as dashboard | Full official dashboard. Last recorded summary: `clua_passed=33`, `clua_failed=0`, `zlua_passed=13`, `categorized_failed=20`, `unexpected_failed=0`. Not rerun during the latest focused official-test work. Categorized zlua failures remain expected work items. |
| Full CI aggregate | `zig build ci` or `just ci` | Pass if child layers pass | Build step depends on unit tests, differential fixtures, and the quick official subset. |
| Focused official file runner | `just official-file NAME` | Helper | Runs one official test file through zlua with the basic official prelude. Accepts names with or without `.lua`. |

## Status Meanings

| Status | Meaning |
| --- | --- |
| Pass | zlua exits successfully for the file in the basic official dashboard. |
| XFail | CLua exits successfully, but zlua currently exits unsuccessfully and the dashboard categorizes the failure. |
| Not run | The file exists in the official suite but is not part of the per-file basic dashboard. |

## Focused Official Progress

Latest focused `events.lua` work verified with `just official-file events`, `just official-file cstack`, `just official-file attrib`, `zig build test`, `zig build test-diff`, and `zig build test-official`. `heavy.lua`, `zig build test-official-heavy`, and `zig build ci` were not rerun during the latest focused work. The quick official dashboard now reports `zlua_passed=29` and `categorized_failed=3`.

- Unary metamethod calls (`__unm`, `__bnot`, and `__len`) now pass the operand twice, matching Lua's official call convention covered by `events.lua`.
- `rawlen` rejects zlua file-handle tables so `rawlen(io.stdin)` behaves like official userdata-backed file handles.
- `debug.setmetatable` now supports primitive metatables for numbers, booleans, nil, and strings, and primitive metatables participate in `getmetatable`, `__index`, `__add`, and `__len` lookup.
- Pattern matching uses a plain-literal fast path and a lower recursive-pattern guard, preserving long literal searches while reporting `pattern too complex` before native stack overflow in the official `cstack.lua` recursive pattern case.
- `events.lua` now passes in the basic official dashboard.

Latest focused `tpack.lua` work verified with `just official-file tpack`, `zig build test`, `zig build test-diff`, and `zig build test-official`. `heavy.lua`, `zig build test-official-heavy`, and `zig build ci` were not rerun during the latest focused work.

- `string.pack`, `string.unpack`, and `string.packsize` now handle official pack-format alignment controls (`!n`, `x`, and `Xop`), mixed endianness, fixed/zero/length-prefixed strings, byte-width integers up to 16 bytes, and official overflow/short-data diagnostics covered by `tpack.lua`.
- Oversized hexadecimal integer literals now wrap through 64-bit Lua integer bits, matching the official long hex literal used by `tpack.lua`.
- `tpack.lua` now passes in the basic official dashboard.

Latest focused `pm.lua` work verified with `just official-file pm`, `zig build test`, `zig build test-diff`, and `zig build test-official`. `heavy.lua`, `zig build test-official-heavy`, and `zig build ci` were not rerun during the latest focused work.

- String pattern matching now tracks captures, position captures, backreferences, balanced matches, frontier assertions, escaped bracket-class items, and malformed-pattern diagnostics covered by `pm.lua`.
- `string.gsub` now expands `%0`/`%1` replacement captures, passes captures to function replacements, handles table replacement keys from captures, preserves official empty-match skip semantics, and reuses the original string when no substitution changes the output.
- `string.gmatch` now honors the optional initial position and skips empty matches immediately following the previous match.
- `pm.lua` now passes in the basic official dashboard.

Latest focused `vararg.lua` work verified with `just official-file vararg`, `zig build test`, `zig build test-diff`, and `zig build test-official`. `heavy.lua`, `zig build test-official-heavy`, and `zig build ci` were not rerun during the latest focused work.

- Named vararg tables now drive later `...` expansion from the table and its `n` field, so mutations such as changing indexed values or `n` are reflected in returned varargs.
- Named vararg `n` validation now reports the official-compatible `no proper 'n'` error for invalid counts while allowing large dynamic vararg expansion used by `vararg.lua`.
- Load diagnostics recognize assignment to named vararg parameters, including nested closure assignment cases covered by the official const checks.
- Named vararg backing tables remain normal GC-tracked table values but are excluded from `collectgarbage("count")`, matching the official read-only named-vararg memory check.
- `vararg.lua` now passes in the basic official dashboard.

Latest focused `nextvar.lua` work verified with `just official-file nextvar`, `zig build test-diff`, and `zig build test-official`. `heavy.lua`, `zig build test-official-heavy`, and `zig build ci` were not rerun during the latest focused work. `zig build test` initially exposed a stale generic-for resolver unit expectation, which has been updated.

Latest focused `goto.lua` work:

- `load` diagnostics now report official-compatible goto/label/scope and global-declaration errors for the covered invalid chunks.
- `repeat` body labels no longer use the trailing-label scope reset before the `until` condition, so jumps into locals used by the condition are rejected.
- Goto code generation now patches pending gotos with scope-aware label targets and closes upvalues from the target label boundary instead of closing the whole frame.
- Trailing labels close the current scope before the label target, and jump-time to-be-closed handling treats local end PCs as exclusive while ignoring reused non-closable slots.
- Compiler name resolution now tracks ordered local/global declarations, including `global *`, `global function`, `_ENV` environments, global initialization order, and runtime global redefinition checks.
- `global` can be parsed as a normal identifier in assignment/expression positions when it is not a global declaration.
- `goto.lua` now passes in the basic official dashboard.

Latest focused `db.lua` work:

- Generic `for` variables are now assignable while numeric `for` variables remain const, matching Lua 5.5 and allowing `db.lua` to compile past its active-line helper.
- `debug.gethook` is available, hook masks/counts are introspectable, line hooks receive the line argument, and count hooks have basic instruction-count dispatch.
- `debug.getinfo` now handles invalid options, out-of-range stack levels, C-function source names, `func`, active-line tables, stripped dumped chunks, and the early official source-name/namewhat checks.
- `load` string chunks propagate source names to child closures, and short source formatting now covers string, `@`, and `=` chunk names used by `db.lua`.
- `db.lua` still xfails later in official line-hook trace sequencing; the quick official dashboard counts are unchanged.

Latest focused `gc.lua` work:

- Simple capture delimiters are now recognized by the string pattern matcher, covering the long-string `gsub` block while preserving the UTF-8 `gmatch` position-plus-character capture case.
- Weak tables now keep string keys and values alive when Lua weak-table semantics retain them, avoiding dangling strings in weak-value and all-weak table checks.
- Finalizer execution now respects weak-value `__gc` liveness, marks the finalized object graph before calling `__gc`, clears reachable weak tables first, and returns `false` for reentrant `collectgarbage()` calls from finalizers.
- `string.rep` accepts integral float counts for official long-string construction without changing arithmetic result tagging.
- `gc.lua` now passes in the basic official dashboard.

Earlier focused `cstack.lua` work:

- Pattern matching now reports `pattern too complex` for excessively deep recursive patterns while preserving longer literal search cases used by the official require tests.
- `string.gsub` table replacements use normal `__index` lookup, so recursive replacement tables participate in stack-overflow detection.
- Standard `io.stdin`/`io.stdout`/`io.stderr` handles expose lightweight file methods, covering `tracegc.lua` finalizer calls such as `io.stderr:write`.
- GC finalizer calls restore interrupted thread stack/result bookkeeping, and conservative collection now keeps all live stack slots rooted while auto-GC runs between instructions.
- Nested `coroutine.close` and coroutine resume chains now report `C stack overflow` for the official close/resume nesting limits.
- `cstack.lua` now passes in the basic official dashboard.

Latest focused `coroutine.lua` work:

- `coroutine.isyieldable` and `coroutine.close` are now available, including dead/main/normal coroutine checks and basic to-be-closed unwinding.
- Coroutine wrappers keep their active resumer chain rooted during GC, avoiding the crash exposed by the official sieve-of-Eratosthenes wrapper chain.
- `coroutine.create` and `coroutine.wrap` accept native function values through a small entry trampoline, covering official uses such as `print`, `error`, and `pcall` as coroutine bodies.
- `pcall`/`xpcall` no longer count as unyieldable native boundaries, and protected-call close handlers expose the expected C frame to `debug.getinfo(2)` for the covered close-unwind check.
- Protected-call continuations now survive coroutine yields far enough to recover from yielded `pcall` close-unwind errors, including the official nested close-handler error ordering case.
- `coroutine.close()` on the running coroutine no longer tries to return through frames it just closed when a close handler errors, avoiding the previous panic in the self-closing coroutine block.
- Native tail calls that yield now use frame-count keyed continuations, so the yielded generic-`for` iterator under `pcall`/`xpcall` resumes before the protected-call chain continues.
- Basic `debug.sethook` call/line/return tracing, closure line ranges, collected-coroutine open-upvalue closing, and resume-chain stack overflow guards now cover the next official coroutine blocks.
- Yielded single-result metamethod calls now restore their results into the suspended opcode before execution continues, covering arithmetic, bitwise, comparison, length, concat, and table access/update continuations.
- `coroutine.lua` now passes in the basic official dashboard.

Latest focused `strings.lua` work:

- `string.find` and `string.byte` now handle boundary start positions the same way as the official tests, including empty-pattern and negative-start cases.
- `string.rep` rejects impossible result sizes before allocation, preserves short-string interning, and leaves long repeated strings non-internalized for `%p` identity checks.
- `string.format` covers the official `%p`, `%q`, `%c`, `%s`, integer, fixed-float, hex-float, and selected scientific/general format edge cases, including width, precision, signs, invalid-format errors, and literal serialization.
- `table.concat` reports index-specific errors for invalid elements and handles extreme integer ranges used by `strings.lua`.
- `string.gmatch` now returns a callable iterator with captured state, supports direct calls and the official `coroutine.wrap` case, and exposes a stable debug upvalue id.
- GC marking now ignores already-swept stale upvalue pointers, avoiding the crash exposed by the additional long-string allocation coverage in `literals.lua`.

Latest focused `locals.lua` / `nextvar.lua` work:

- `ipairs` iterator advancement wraps from `math.maxinteger` to `math.mininteger`, matching the official overflow case in `nextvar.lua`.
- Table hash entries now maintain an index map, avoiding the previous long stall in `nextvar.lua`'s repeated temporary insert/delete workload.
- Hash deletion now preserves dead keys long enough for `next(t, deleted_key)`, compacts collectable tombstones before sweep, and keeps iteration order stable across GC cleanup.
- `pairs`/`ipairs` report argument-specific table errors, `pairs` honors yielding `__pairs` metamethods and fourth to-be-closed iterator state, and `ipairs` uses normal indexed access for `__index`-backed proxy tables.
- `table.insert`, `table.remove`, `table.sort`, `table.concat`, and `table.unpack` now use metamethod-aware length/index/update paths covered by `nextvar.lua`, including `table.insert` wraparound at `math.maxinteger`.
- Numeric `for` loops preserve integer control-variable types for float/string limits, handle integer step overflow termination, and reject assignment to generic `for` variables like official Lua 5.5.
- String GC now sweeps unreferenced temporary strings, uses allocation identity when marking/removing strings, and keeps load-reader callbacks conservative so `collectgarbage()` inside readers does not free in-flight chunks.
- `load` reports official-compatible messages for multiple `<close>` locals and broader const-assignment forms, including repeated declaration attributes and assignment through function declarations.
- To-be-closed variables now receive the correct close arguments, clear slots after successful close, preserve pending return values across close handlers, and prevent tail-call compilation while close variables are active.
- Generic `for` loops preserve the fourth iterator result as an implicit to-be-closed state value without displacing user loop variables.
- Function literals assigned with simple assignment, such as `foo = function () ... end`, carry a debug name for `debug.getinfo`.
- Calls to non-callable values now report typed messages such as `attempt to call a number value`, matching close-error assertions in `locals.lua`.
- Runtime close unwinding now preserves nested close frames through errors and coroutine yields, keeps pending return values alive across yielding close handlers, and resumes protected-call error restoration after close-method yields.
- Return hooks use the returning function's name, including `close`, `foo`, and native names such as `sethook`, for the debug hook checks in `locals.lua`.
- `error()` prefixes use the active chunk source name instead of a fixed `zlua` label, matching official wrapped-coroutine close-error message checks.
- `break` and `goto` out of generic `for` loops close implicit to-be-closed iterator state without detaching unrelated outer upvalues.
- `locals.lua` and `nextvar.lua` now pass in the basic official dashboard.

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
| `coroutine.lua` | Pass | Pass |  |
| `cstack.lua` | Pass | Pass |  |
| `db.lua` | Pass | XFail | `runtime` |
| `errors.lua` | Pass | XFail | `runtime` |
| `events.lua` | Pass | Pass |  |
| `files.lua` | Pass | XFail | `runtime` |
| `gc.lua` | Pass | Pass |  |
| `gengc.lua` | Pass | Pass |  |
| `goto.lua` | Pass | Pass |  |
| `heavy.lua` | Pass | Pass |  |
| `literals.lua` | Pass | Pass |  |
| `locals.lua` | Pass | Pass |  |
| `main.lua` | Pass | Pass |  |
| `math.lua` | Pass | Pass |  |
| `memerr.lua` | Pass | Pass |  |
| `nextvar.lua` | Pass | Pass |  |
| `pm.lua` | Pass | Pass |  |
| `sort.lua` | Pass | Pass |  |
| `strings.lua` | Pass | Pass |  |
| `tpack.lua` | Pass | Pass |  |
| `tracegc.lua` | Pass | Pass |  |
| `utf8.lua` | Pass | Pass |  |
| `vararg.lua` | Pass | Pass |  |
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
| zlua passes | 29 |
| Categorized zlua failures | 3 |
| Timeouts | 0 |
| Unexpected failures | 0 |
