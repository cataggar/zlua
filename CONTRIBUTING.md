# Contributing

zlua is compatibility-driven. When Lua-visible behavior is in question, use the official Lua 5.5 implementation as the oracle and add a regression test.

## Setup

Use Zig `0.16.0`.

```sh
zig version
zig build fetch-lua
```

`fetch-lua` downloads Lua 5.5 source and official tests into `.zlua-deps/`, which is ignored by Git.

## Workflow

For behavior changes:

1. Add or update a fixture, unit test, C API fixture, or embedding example.
2. Verify expected behavior against CLua when the behavior is Lua-visible.
3. Make the smallest implementation change that preserves compatibility.
4. Run a focused check first.
5. Run broader checks before submitting.

Default CI-equivalent check:

```sh
zig build ci
```

The C API portion can also be run on its own:

```sh
zig build ci-c-api
```

Format touched Zig files:

```sh
just fmt
```

## Docs

Detailed conventions live in:

| Document | Scope |
| --- | --- |
| [Development](docs/development.md) | Project shape, commands, source conventions, and local workflow. |
| [Testing](docs/testing.md) | Differential fixtures, official dashboard, C API fixtures, and CI policy. |
| [Lua C API Compatibility](docs/c-api.md) | C API scope, build/link instructions, caveats, and fixture policy. |
| [Benchmarking](docs/benchmark.md) | Performance workflow and benchmark interpretation. |
| [Architecture](docs/architecture.md) | Implementation structure and invariants. |
| [Embedding](docs/embedding.md) | Public Zig embedding API. |
