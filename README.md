# zlua

zlua is a source-compatible Lua 5.5 implementation written in Zig. It is built for hosts that want an embeddable Lua runtime with explicit capabilities, while still providing the familiar command-line interpreter, standard libraries, and Lua C API compatibility layer.

The project targets Zig `0.16.0`.

## Project Status

zlua is pre-1.0.

The Zig embedding API is the main public surface. Runtime internals, zlua binary chunks, and exact C API support scope are still evolving.

## Quickstart

1. Add zlua to your Zig package dependencies:

```sh
zig fetch --save git+https://codeberg.org/gron/zlua#v0.1.1
```

2. Wire the dependency into your executable in `build.zig`:

```zig
const zlua_dep = b.dependency("zlua", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zlua", zlua_dep.module("zlua"));
```

3. Import zlua from Zig and run a Lua chunk:

```zig
const std = @import("std");
const zlua = @import("zlua");

const Budget = struct {
    remaining: i64,

    fn spend(self: *@This(), amount: i64) i64 {
        self.remaining = @max(self.remaining - amount, 0);
        return self.remaining;
    }
};

fn newBudget(ctx: *zlua.Context, amount: i64) !zlua.Userdata(Budget) {
    var budget = try ctx.state().newUserdata(Budget, .{ .remaining = amount }, .{});
    errdefer budget.deinit();
    try budget.method("spend", Budget.spend);
    return budget;
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    var new_budget = try lua.registerTyped("new_budget", newBudget);
    defer new_budget.deinit();
    try lua.setGlobal("new_budget", new_budget);

    var chunk = try lua.loadString(
        \\local budget = new_budget(25)
        \\budget:spend(7)
        \\budget:spend(20)
        \\return budget
    , .{ .name = "=readme" });
    defer chunk.deinit();

    var budget = try chunk.call(.{}, zlua.Userdata(Budget));
    defer budget.deinit();

    std.debug.print("remaining={d}\n", .{(try budget.ptr()).remaining});
}
```

Output:

```text
remaining=0
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

## Build, Run, and Test

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

For the full command reference, including `just` recipes, `zig build` steps, CLI options, and harness arguments, see [docs/commands.md](docs/commands.md). For focused development, testing, and benchmarking workflows, see [docs/development.md](docs/development.md), [docs/testing.md](docs/testing.md), and [docs/benchmark.md](docs/benchmark.md).

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
| [Commands](docs/commands.md) | `just` recipes, `zig build` steps, CLI options, and harness arguments. |
| [Development](docs/development.md) | Project shape, commands, source conventions, and local workflow. |
| [Lua Standard Library and Extensions](docs/stdlib.md) | Lua-visible standard libraries, selection modes, and extensions. |
| [Testing](docs/testing.md) | Test layers, CLua differential fixtures, official dashboard, and C API fixtures. |
| [Benchmarking](docs/benchmark.md) | Benchmark harness and current performance methodology. |
| [Embedding](docs/embedding.md) | Zig-native embedding API. |
| [Next Steps](docs/next-steps.md) | Remaining hardening, performance, API, and release-documentation work. |

## License

MIT License see [LICENSE](LICENSE).
