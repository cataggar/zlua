# zlua

zlua is a Zig implementation of Lua 5.5. It includes a CLI, a Zig-native embedding API, a Lua C API compatibility layer, standard libraries, differential tests against the Lua 5.5 implementation, and the official Lua 5.5 test dashboard.

The project targets Zig `0.16.0`.

## Status

zlua is compatibility-driven and uses the official Lua 5.5 C implementation as its behavioral oracle. The build downloads the source and official tests into `.zlua-deps/` when needed. The default CI-equivalent check runs unit tests, embedding examples, CLua differential fixtures, and the official Lua 5.5 dashboard.

The C API layer has its own build and differential fixture harness and is tracked separately from the default CI aggregate.

## Quick Start

Build the CLI and downloaded CLua oracle:

```sh
zig build
```

Download the Lua source and official tests explicitly:

```sh
zig build fetch-lua
```

Run zlua:

```sh
zig build run -- --version
zig build run -- path/to/script.lua
```

Run the main checks:

```sh
zig build ci
```

Useful focused commands:

```sh
zig build test
zig build test-diff
zig build test-official
zig build examples
zig build test-c-api
```

If you use `just`:

```sh
just test
just diff
just official
just example
just c-api
just bench
```

## Embedding

Zig hosts import the package as `zlua` and create a `zlua.State`:

```zig
const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    var lua = try zlua.State.init(std.heap.smp_allocator, .{});
    defer lua.deinit();

    try lua.doString("assert(_VERSION == 'Lua 5.5')", .{ .name = "=main" });
}
```

The embedding API defaults to safe standard libraries and sandboxed host capabilities. See [docs/embedding.md](docs/embedding.md) for capabilities, callbacks, userdata, bytecode, memory files, and error handling.

## Documentation

Start with [docs/README.md](docs/README.md).

| Document | Scope |
| --- | --- |
| [Architecture](docs/architecture.md) | How the implementation fits together. |
| [Development](docs/development.md) | Project shape, commands, source conventions, and local workflow. |
| [Testing](docs/testing.md) | Test layers, CLua differential fixtures, official dashboard, and C API fixtures. |
| [Benchmarking](docs/benchmark.md) | Benchmark harness and current performance methodology. |
| [Embedding](docs/embedding.md) | Zig-native embedding API. |
| [Next Steps](docs/next-steps.md) | Remaining hardening, performance, API, and release-documentation work. |

Historical planning documents live under `docs/old/` and are not authoritative.

## Repository Layout

```text
src/              implementation
examples/embed/   Zig embedding examples
tests/diff/       Lua differential fixtures
tests/c-api/      Lua C API differential fixtures
tests/bench/      benchmark fixtures
.zlua-deps/       ignored downloaded Lua source and official tests
docs/             current documentation
```

## License

See [LICENSE](LICENSE).
