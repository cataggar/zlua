# zlua

Zig implementation work toward Lua 5.5 compatibility.

## Official Lua 5.5 Suite Status

The Lua 5.5.0 official test archive is vendored as `vendor/lua-5.5.0-tests.tar.gz` and extracted at `tests/official/lua-5.5.0-tests`. The runner verifies the archive SHA-256 before executing any suite mode.

Current dashboard commands:

```text
zig build test-official
zig build run-test-official -- --mode=basic
zig build run-test-official -- --mode=complete
```

Current status: `zig build test-official` runs each top-level official Lua test file individually, using the vendored CLua baseline for each file and reporting zlua gaps as categorized expected failures. The aggregate `all.lua` harness is not used for the dashboard breakdown. The complete mode is runnable as a local compatibility dashboard; zlua is not expected to pass the official suite yet.
