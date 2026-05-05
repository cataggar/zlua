# zlua Test Status

Last updated: 2026-05-05

This document tracks the test layers currently used for zlua and the current status of each official Lua 5.5 test file in the basic official dashboard.

## Test Layers

| Test layer | Command | Status | Notes |
| --- | --- | --- | --- |
| Unit tests | `zig build test` or `just test` | Pass | Runs Zig tests for the library module and CLI root module. |
| CLua differential fixtures | `zig build test-diff` or `just diff-ci` | Pass | Current summary: `passed=51`, `failed=0`, `unexpected_failed=0`. Individual handwritten fixtures are not listed here. |
| Official Lua 5.5 basic dashboard | `zig build test-official` or `just official-ci` | Pass as dashboard | Current summary: `clua_passed=33`, `clua_failed=0`, `zlua_passed=12`, `categorized_failed=21`, `unexpected_failed=0`. Categorized zlua failures remain expected work items. |
| Full CI aggregate | `zig build ci` or `just ci` | Pass if child layers pass | Build step depends on unit tests, differential fixtures, and the official dashboard. |
| Focused official file runner | `just official-file NAME` | Helper | Runs one official test file through zlua with the basic official prelude. Accepts names with or without `.lua`. |

## Status Meanings

| Status | Meaning |
| --- | --- |
| Pass | zlua exits successfully for the file in the basic official dashboard. |
| XFail | CLua exits successfully, but zlua currently exits unsuccessfully and the dashboard categorizes the failure. |
| Not run | The file exists in the official suite but is not part of the per-file basic dashboard. |

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
| `calls.lua` | Pass | XFail | `runtime` |
| `closure.lua` | Pass | XFail | `runtime` |
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
| `literals.lua` | Pass | XFail | `runtime` |
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
| Files run by the basic per-file dashboard | 33 |
| CLua passes | 33 |
| CLua failures | 0 |
| zlua passes | 12 |
| Categorized zlua failures | 21 |
| Timeouts | 0 |
| Unexpected failures | 0 |
