# zlua

zlua is a source-compatible Lua 5.5 implementation written in Zig. It is built for hosts that want an embeddable Lua runtime with explicit capabilities, while still providing the familiar command-line interpreter, standard libraries, and Lua C API compatibility layer.

The project targets Zig `0.16.0`.

## Example

zlua can run as a CLI, but its main shape is an embeddable Lua runtime where the host decides what Lua can see:

```zig
const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var host_add = try lua.registerTyped("host_add", hostAdd);
    defer host_add.deinit();
    try lua.setGlobal("host_add", host_add);

    var chunk = try lua.loadString(
        \\local name = ...
        \\return name .. " sees " .. host_add(20, 22)
    , .{ .name = "=readme" });
    defer chunk.deinit();

    const message = try chunk.call(.{"Lua"}, []const u8);
    std.debug.print("{s}\n", .{message});
}

fn hostAdd(lhs: i64, rhs: i64) i64 {
    return lhs + rhs;
}
```

Output:

```text
Lua sees 42
```

The default state opens safe standard libraries with sandboxed host capabilities. Hosts can opt into filesystem, output, clock, process, bytecode, callbacks, userdata, and resource-limit behavior through the API documented in [docs/embedding.md](docs/embedding.md).

## Design Priorities

zlua is compatibility-driven. Its target is the official Lua 5.5 C implementation for parser acceptance, runtime semantics, standard-library behavior, diagnostics, and C API behavior.

The project is designed to be useful in four related ways:

- Run Lua 5.5 programs through a standalone command-line interpreter.
- Embed Lua in Zig with explicit host capabilities, resource limits, callbacks, and userdata.
- Keep standard-library behavior close to Lua 5.5 while allowing sandboxed embedding defaults.
- Provide practical, testable Lua C API compatibility where it can be backed by zlua semantics.

These priorities are kept honest by building and testing against downloaded Lua 5.5 sources and tests.

## Quick Start

Build the CLI and downloaded CLua oracle:

```sh
zig build
```

Run a Lua script through the build runner:

```sh
zig build run -- path/to/script.lua
```

Compile the Zig embedding examples:

```sh
zig build examples
```

Run the default CI-equivalent local check:

```sh
zig build ci
```

For focused development, testing, benchmarking, and `just` recipes, see [docs/development.md](docs/development.md), [docs/testing.md](docs/testing.md), and [docs/benchmark.md](docs/benchmark.md).

## Compatibility

Compatibility work is oracle-driven rather than example-driven. The build downloads Lua 5.5 sources and official tests, builds a local `lua5.5`, and uses that binary as the behavioral reference; a system Lua install is not required.

`zig build ci` is the aggregate gate for the main project surfaces:

| Layer | What it checks |
| --- | --- |
| Zig unit tests | Internal data structures, compiler behavior, runtime helpers, and API pieces. |
| Differential fixtures | Small Lua programs compared against the official Lua 5.5 implementation. |
| Official dashboard | The upstream Lua 5.5 test suite run against zlua and CLua. |
| Embedding examples | Public Zig host API behavior. |
| C API fixtures | Lua C API behavior compared through a separate C-facing harness. |

See [docs/testing.md](docs/testing.md) for the full test policy and command reference.

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
