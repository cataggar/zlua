# Development

This document covers day-to-day zlua development conventions: project shape, commands, source conventions, and local workflow. For test methodology, see [testing.md](testing.md). For implementation structure, see [architecture.md](architecture.md).

## Project Shape

zlua is a Zig package targeting Zig `0.16.0`. `build.zig.zon` has no external Zig package dependencies, and CI uses `mlugg/setup-zig@v2` with `version: 0.16.0`.

The build downloads Lua 5.5 source and official tests into `.zlua-deps/`, which is ignored by Git. The CLua oracle is built from `.zlua-deps/lua-5.5.0/src`; do not assume a system Lua is required.

`zig build ci` runs the default CI-equivalent checks:

```text
unit tests
embedding examples
CLua differential fixtures
official Lua 5.5 dashboard
C API fixtures
```

Build artifacts installed or produced by `build.zig` include:

| Artifact | Purpose |
| --- | --- |
| `zlua` | CLI executable from `src/main.zig`. |
| `lua5.5` | Downloaded CLua oracle built from `.zlua-deps/lua-5.5.0/src`. |
| `zlua-test-diff` | CLua differential harness. |
| `zlua-test-official` | Official Lua 5.5 dashboard harness. |
| `zlua-test-bench` | Benchmark harness. |
| `zlua-c` | Static Lua C API compatibility library. |
| `zlua-test-c-api` | C API differential fixture harness. |

The library facade is `src/root.zig`. It exports `api`, `frontend`, `compile`, `runtime`, `stdlib`, and `testing`, plus top-level embedding aliases like `State`, `Table`, `Function`, and `Context`.

The public Zig embedding API lives in `src/api.zig`. `docs/embedding.md` is the user-facing API document. Embedding hosts should go through `zlua.State`; runtime internals are not a stable embedding contract.

The CLI currently wires directly to `runtime.State` with full host capabilities. Embedding defaults are safer: `.safe` standard libraries and sandboxed host capabilities unless the host grants more.

Runtime and standard-library compatibility are dashboard-driven. Use downloaded CLua behavior and official Lua 5.5 tests as the oracle instead of guessing from docs.

Historical planning docs under `docs/old/` are not authoritative. Prefer `build.zig`, `justfile`, CI, and current `src/` behavior when historical docs differ.

## Commands

Fetch Lua source and official tests:

```sh
zig build fetch-lua
just fetch-lua
```

Build zlua and CLua:

```sh
zig build
just build
```

Run the CLI through the build runner:

```sh
zig build run -- --version
zig build run -- path/to/file.lua
just run path/to/file.lua
just version
```

Run checks:

```sh
zig build ci
just ci
zig build test
just test
zig build test-diff
just diff
zig build test-official
just official
zig build examples
just example
zig build ci-c-api
just c-api
```

Run targeted examples:

```sh
zig build run-example -Dexample=run_script
just example run_script
```

Run targeted differential fixtures:

```sh
just diff tests/diff/runtime/tables.lua
just diff --stage=parse
just diff --stage=compile
just diff --feature=table
```

Run targeted official files:

```sh
just official attrib calls.lua
just official calls db locals nextvar
```

Run benchmarks:

```sh
just bench
just bench table/pairs_iteration --iterations=20
just bench --category table
just bench --json /tmp/zlua-bench.json
```

Format Zig sources:

```sh
just fmt
```

`just fmt` formats `build.zig`, `src/*.zig`, `src/testing/*.zig`, and `examples/embed/*.zig`. Run `zig fmt` explicitly for touched nested files under `src/frontend/`, `src/compile/`, `src/runtime/`, `src/stdlib/`, or other paths not covered by the recipe.

## Source Conventions

Follow the existing Zig 0.16 `std.Io` pattern. CLI and testing code thread explicit `std.Io` values through execution instead of using process-global I/O helpers.

Lua 5.5 `global` declarations and `<const>`/`<close>` attributes are part of the language surface tested by this project. Do not treat them as fixture noise from another Lua version.

Prefer top-level imports. Avoid inline imports in declarations such as:

```zig
@import("std").mem.Allocator
```

Use a top-level import instead:

```zig
const std = @import("std");
```

Keep public embedding changes in `src/api.zig` unless there is a deliberate API decision to expose something else. Prefer adding a small facade method to exposing runtime internals.

The zlua binary chunk format is zlua-specific. It is not PUC Lua `luac` compatibility and should not be treated as a stable external ABI.

Markdown-only GitHub changes are ignored by CI through `paths-ignore: '**/*.md'`. Run relevant local checks when documentation mentions commands, examples, or behavior.

## Development Workflow

For behavior changes:

1. Add or update a Lua fixture, C API fixture, Zig unit test, or embedding example that captures the behavior.
2. Verify expected behavior against CLua when the behavior is Lua-visible.
3. Make the smallest implementation change that preserves compatibility.
4. Run the narrow relevant command first.
5. Run broader checks before submitting.

When an official test exposes a bug, prefer adding a smaller permanent differential fixture in addition to fixing the official file.

Expected failures should be rare, documented with a reason, and removed as soon as the behavior is implemented.

Benchmarks are diagnostics, not CI gates. Performance changes must preserve differential and official behavior.

## Dependency Cache

Lua dependency files are downloaded and extracted by `tools/fetch-lua.sh` into `.zlua-deps/`.

The default URLs can be overridden for local mirrors:

```sh
ZLUA_LUA_URL=https://example.invalid/lua-5.5.0.tar.gz \
ZLUA_LUA_TESTS_URL=https://example.invalid/lua-5.5.0-tests.tar.gz \
zig build fetch-lua
```

The fetch script verifies SHA-256 checksums before extraction. If the downloaded archive already exists, it is reused and re-verified.
