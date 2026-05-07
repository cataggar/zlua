# zlua

zlua is a Zig implementation of Lua 5.5. It is built around the same surfaces Lua users expect: a command-line interpreter, standard libraries, a Zig-native embedding API, and a Lua C API compatibility layer.

The project targets Zig `0.16.0`.

## Project Goals

zlua is compatibility-driven. The official Lua 5.5 C implementation is the behavioral oracle for parser acceptance, runtime semantics, standard-library behavior, diagnostics, and C API behavior.

The implementation is organized as a conventional frontend/compiler/runtime pipeline, with public APIs layered on top:

| Surface | Purpose |
| --- | --- |
| CLI | Run Lua files, stdin, expressions, REPL sessions, and implementation test modes. |
| Zig embedding API | Create Lua states, load code, expose callbacks, manage userdata, and control host capabilities. |
| Standard libraries | Provide Lua-visible library behavior implemented against the zlua runtime. |
| C API layer | Offer a Lua C API compatibility library backed by zlua where practical. |
| Test harnesses | Compare zlua against CLua through differential fixtures and the official Lua 5.5 test suite. |

The build downloads the Lua 5.5 source and official tests into `.zlua-deps/` when needed; a system Lua install is not required.

## Quick Start

Build the CLI and downloaded CLua oracle, then run a script through the build runner:

```sh
zig build
zig build run -- path/to/script.lua
```

Run the default CI-equivalent local check:

```sh
zig build ci
```

For focused development, testing, benchmarking, and `just` recipes, see [docs/development.md](docs/development.md), [docs/testing.md](docs/testing.md), and [docs/benchmark.md](docs/benchmark.md).

## Compatibility

Compatibility work is tested at several levels instead of relying on isolated examples:

| Layer | What it checks |
| --- | --- |
| Zig unit tests | Internal data structures, compiler behavior, runtime helpers, and API pieces. |
| Differential fixtures | Small Lua programs compared against the official Lua 5.5 implementation. |
| Official dashboard | The upstream Lua 5.5 test suite run against zlua and CLua. |
| Embedding examples | Public Zig host API behavior. |
| C API fixtures | Lua C API behavior compared through a separate C-facing harness. |

See [docs/testing.md](docs/testing.md) for the full test policy and command reference.

## Embedding

Zig hosts use `zlua.State` as the public embedding entry point:

```zig
const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    var lua = try zlua.State.init(std.heap.smp_allocator, .{});
    defer lua.deinit();

    try lua.doString("assert(_VERSION == 'Lua 5.5')", .{ .name = "=main" });
}
```

The embedding API defaults to safe standard libraries and sandboxed host capabilities. Hosts can opt into additional libraries, expose native callbacks, attach userdata, load bytecode, and configure resource limits through the API documented in [docs/embedding.md](docs/embedding.md).

## Documentation

Start with [docs/README.md](docs/README.md) for the full documentation index.

| Document | Scope |
| --- | --- |
| [Architecture](docs/architecture.md) | How the implementation fits together. |
| [Development](docs/development.md) | Project shape, commands, source conventions, and local workflow. |
| [Testing](docs/testing.md) | Test layers, CLua differential fixtures, official dashboard, and C API fixtures. |
| [Benchmarking](docs/benchmark.md) | Benchmark harness and current performance methodology. |
| [Embedding](docs/embedding.md) | Zig-native embedding API. |
| [Next Steps](docs/next-steps.md) | Remaining hardening, performance, API, and release-documentation work. |

## License

See [LICENSE](LICENSE).
