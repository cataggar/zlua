# Testing

zlua treats the official Lua 5.5 C implementation as the behavioral oracle. The build downloads that implementation into `.zlua-deps/` and builds it locally. The main rule is simple: when Lua-visible behavior is in question, compare against CLua and keep the fixture.

## Test Layers

| Layer | Command | Scope |
| --- | --- | --- |
| Unit tests | `zig build test` or `just test` | Zig tests for the library facade, CLI root module, runtime internals, API conversion, and test utilities. |
| Embedding examples | `zig build examples` or `just example` | Compiles every Zig-native embedding example under `examples/embed`. |
| CLua differential fixtures | `zig build test-diff` or `just diff` | Runs `tests/diff/**/*.lua` against CLua and zlua. |
| Official Lua 5.5 dashboard | `zig build test-official` or `just official` | Runs each official Lua 5.5 test file, excluding `all.lua`, under CLua and zlua. |
| C API fixtures | `zig build test-c-api` or `just c-api` | Compiles C fixtures against CLua and zlua and compares behavior. |
| Full CI aggregate | `zig build ci` or `just ci` | Unit tests, embedding examples, differential fixtures, and official dashboard. |

CI currently runs `zig build ci` on code changes. Markdown-only changes are ignored by the GitHub workflow, so documentation edits should be checked locally when they mention commands, examples, or behavior.

## CLua Oracle

The build creates `zig-out/bin/lua5.5` from `.zlua-deps/lua-5.5.0/src`. Test harnesses discover CLua in this order:

```text
explicit --clua option
ZLUA_CLUA
zig-out/bin/lua5.5
lua5.5
lua5.5.0
lua
```

Normal `zig build` and `just` workflows use the downloaded binary, so a system Lua installation is not required.

## Differential Fixtures

Differential fixtures live under `tests/diff/**/*.lua`. Each fixture can include top-of-file metadata comments parsed by `src/testing/metadata.zig`:

```lua
-- expect: pass
-- stage: runtime
-- feature: table
-- normalize: none

print(({ 10, 20, 30 })[2])
```

Supported metadata:

| Key | Values | Default |
| --- | --- | --- |
| `expect` | `pass`, `fail`, `skip` | `pass` |
| `stage` | `lex`, `parse`, `resolve`, `compile`, `runtime`, `stdlib`, `official` | `runtime` |
| `feature` | Free-form tag | `uncategorized` |
| `normalize` | `none`, `paths` | `none` |
| `reason` | Free-form explanation | empty |
| `issue` | Free-form issue reference | empty |

Stage behavior:

| Stage | CLua action | zlua action | Comparison |
| --- | --- | --- | --- |
| `lex` | `loadfile` | Lex source | Exit status, signal, timeout. |
| `parse` | `loadfile` | Parse source | Exit status, signal, timeout. |
| `resolve` | `loadfile` | Parse and resolve source | Exit status, signal, timeout. |
| `compile` | `loadfile` | Parse, resolve, and compile source | Exit status, signal, timeout. |
| `runtime` | Execute file | Execute source | Exit status, signal, timeout, stdout, stderr. |
| `stdlib` | Execute file | Execute source | Exit status, signal, timeout, stdout, stderr. |
| `official` | Execute file | Execute source | Exit status, signal, timeout, stdout, stderr. |

For runtime-style stages, output is normalized only through `src/testing/normalizer.zig` according to fixture metadata. Do not normalize real semantic differences such as wrong values, missing output, extra output, success/failure mismatches, return-count differences, or mutation differences.

Useful differential commands:

```sh
just diff
just diff tests/diff/runtime/tables.lua
just diff --stage=parse
just diff --stage=compile
just diff --feature=table
just diff --gc-stress
just diff --show-clua --show-zlua tests/diff/runtime/errors.lua
```

`--bless` and `--update-expected-failures` are accepted for command stability but are currently no-ops. Update fixtures and `tests/fixtures/expected_failures.toml` manually.

## Expected Failures

Expected failures can be declared inline with `-- expect: fail` or listed in `tests/fixtures/expected_failures.toml`. The harness exits nonzero only when `unexpected_failed` is nonzero.

Current expected-failure policy:

| Rule | Reason |
| --- | --- |
| Prefer new passing fixtures when behavior is implemented. | Passing fixtures are stronger regression guards. |
| Expected failures need a reason. | They should describe an intentional gap, not hide unknown breakage. |
| Remove expected failures as soon as they pass for the right reason. | Avoid stale compatibility status. |
| Treat “expected failure passed” as a failure. | The registry or fixture expectation is stale. |

At the time this documentation was written, `tests/fixtures/expected_failures.toml` is empty and the default official dashboard passes all per-file cases.

## Official Lua 5.5 Suite

The official tests are downloaded as `.zlua-deps/lua-5.5.0-tests.tar.gz` and extracted under `.zlua-deps/lua-5.5.0-tests`. `src/testing/official_suite.zig` verifies the archive SHA-256 before running the dashboard.

Default behavior:

| Setting | Value |
| --- | --- |
| Suite path | `.zlua-deps/lua-5.5.0-tests` |
| Files | Every top-level `.lua` file except `all.lua` |
| Mode | `basic` |
| Basic prelude | `_U=true; _soft=true; _port=true; _nomsg=true; T=nil; ARG=arg` |
| Build-step memory cap | `256` MiB per child process |
| Timeout | Disabled by default unless provided with `--timeout-ms=` |

Useful official commands:

```sh
zig build test-official
zig build test-official -Dofficial-memory-limit-mb=0
just official
just official calls db locals nextvar
just official --mode=complete strings.lua
```

The harness parses `--mode=internal`, but internal `testC`-enabled CLua/zlua builds are not wired and are skipped.

## C API Fixtures

The C API layer builds `zlua-c` from `src/c_api.zig` and installs the downloaded Lua 5.5 headers. The fixture harness compiles each C file under `tests/c-api` twice: once against CLua and once against zlua. A fixture passes when both variants build, run, and produce compatible behavior.

Run all C API fixtures:

```sh
zig build c-api
zig build test-c-api
just c-api
```

Run a focused fixture or directory:

```sh
just c-api tests/c-api/stack/stack_manipulation.c
just c-api tests/c-api/coroutines
```

`tests/fixtures/c_api_status.toml` is the public symbol inventory. Valid statuses are checked by the harness, and every public Lua 5.5 C API symbol listed in `src/testing/c_api_runner.zig` must appear in the inventory. A status of `tested-clua-diff` is stronger than `implemented` because it means a fixture has exercised the symbol against both libraries.

## Embedding Examples

Embedding examples live under `examples/embed` and are compiled by `zig build examples`, which is part of `zig build ci`.

Current examples:

```text
bytecode_roundtrip.zig
memory_rw_files.zig
plugin_sandbox.zig
preload_module.zig
register_function.zig
run_script.zig
typed_host_function.zig
userdata_counter.zig
```

Run them with:

```sh
zig build run-example
zig build run-example -Dexample=plugin_sandbox
just example
just example typed_host_function
```

## Debugging Failures

Recommended failure workflow:

1. Re-run the narrowest failing fixture with output enabled.
2. Compare CLua and zlua stdout, stderr, exit code, timeout, and signal.
3. Add a smaller fixture when the failing official file is too broad.
4. Fix the implementation against the small fixture.
5. Re-run the original official or differential target.
6. Re-run broader checks before finishing.

Useful flags:

```sh
just diff --debug-errors --show-clua --show-zlua path/to/case.lua
just official --debug-errors --show-clua --show-zlua calls
just c-api --show-build tests/c-api/values/roundtrip.c
```

## CI Policy

`zig build ci` currently depends on:

```text
test
examples
```

The C API harness is available through `zig build ci-c-api`, but it is not part of the default `ci` aggregate in `build.zig` at the time this document was written.

The compatibility gate is correctness, not speed. Benchmarks are intentionally manual diagnostics; see [benchmark.md](benchmark.md).
