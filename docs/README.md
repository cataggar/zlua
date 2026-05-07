# zlua Documentation

zlua is a Zig implementation of Lua 5.5. The current project documentation is organized around the implementation as it exists today, not the original milestone plan.

## Start Here

| Document | Scope |
| --- | --- |
| [Architecture](architecture.md) | Source layout, execution pipeline, runtime model, embedding boundary, and C API layer. |
| [Development](development.md) | Project shape, commands, source conventions, and local workflow. |
| [Testing](testing.md) | Unit tests, CLua differential fixtures, official Lua 5.5 dashboard, C API fixtures, and CI policy. |
| [Benchmarking](benchmark.md) | Benchmark harness, current baseline, result interpretation, and performance workflow. |
| [Embedding](embedding.md) | Zig-native host API for creating states, loading code, exposing callbacks, sandboxing, bytecode, and userdata. |
| [Next Steps](next-steps.md) | Remaining hardening, performance, API, and release-documentation work. |

Historical planning and status documents live in [old](old/). They can be useful for context, but the current docs and code are the source of truth.

## Common Commands

```sh
zig build ci
zig build fetch-lua
zig build test
zig build test-diff
zig build test-official
zig build examples
just bench
```

The build uses Zig `0.16.0`, downloads Lua 5.5 source and official tests into `.zlua-deps/`, and builds CLua as the behavioral oracle. A system Lua installation is not required for normal build, test, or benchmark workflows.
