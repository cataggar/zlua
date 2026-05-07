# Contributing

zlua is compatibility-driven. When Lua-visible behavior is in question, use the official Lua 5.5 implementation as the oracle and add a regression test.

Detailed development conventions are in [docs/development.md](docs/development.md). Test methodology is in [docs/testing.md](docs/testing.md).

## Toolchain

Use Zig `0.16.0`.

```sh
zig version
```

The build downloads Lua 5.5 source and official tests into `.zlua-deps/` and builds the CLua oracle from there, so a system Lua install is not required for normal development.

```sh
zig build fetch-lua
```

## Development Loop

For behavior changes:

1. Add or update a fixture, unit test, C API fixture, or embedding example.
2. Verify expected behavior against CLua when the behavior is Lua-visible.
3. Make the smallest implementation change that preserves compatibility.
4. Run a focused check first.
5. Run broader checks before submitting.

Useful focused commands:

```sh
zig build test
zig build test-diff
zig build test-official
zig build test-c-api
zig build examples
```

Full default CI-equivalent check:

```sh
zig build ci
```

The C API aggregate is separate:

```sh
zig build ci-c-api
```

Useful just recipes are documented in [docs/development.md](docs/development.md).

## Differential Tests

Lua differential fixtures live under `tests/diff/**/*.lua` and can include top-of-file metadata:

```lua
-- expect: pass
-- stage: runtime
-- feature: table
-- normalize: none
```

Use focused runs while developing:

```sh
just diff tests/diff/runtime/tables.lua
just diff --stage=parse
just diff --feature=table
```

Expected failures should be rare, documented with a reason, and removed as soon as the behavior is implemented.

## Official Tests

The official Lua 5.5 dashboard runs each downloaded official file individually, excluding `all.lua`.

```sh
zig build test-official
just official calls db locals nextvar
```

When an official test exposes a bug, prefer adding a smaller permanent differential fixture in addition to fixing the official case.

## Benchmarks

Benchmarks are diagnostics, not CI gates.

```sh
just bench
just bench --category table --iterations=20
just bench --json /tmp/zlua-bench.json
```

Performance changes must preserve differential and official behavior.

## Formatting

Format touched Zig files before submitting:

```sh
just fmt
```

If you touch nested Zig files not covered by `just fmt`, run `zig fmt` on those paths explicitly.

Follow the source conventions in [docs/development.md](docs/development.md): use explicit `std.Io` patterns already present in CLI/testing code, prefer top-level imports, and keep public embedding API work in `src/api.zig` unless there is a deliberate API decision.

## Documentation

Current docs live under `docs/`. Historical planning docs under `docs/old/` are not authoritative.

Markdown-only changes are ignored by CI, so run relevant local checks when documentation mentions commands, examples, or behavior.

## API Boundaries

Use `src/api.zig` for public Zig embedding changes. Avoid exposing `src/runtime.zig` internals to embedding users unless there is a deliberate API decision.

The zlua binary chunk format is zlua-specific and should not be treated as a stable external ABI.
