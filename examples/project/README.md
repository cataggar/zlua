# zlua-test

`zlua-test` is a small test project for validating how a downstream Zig project can use `zig fetch` to set up and consume `@zlua/`.

The project depends on `zlua` in `build.zig.zon`, wires the dependency into `build.zig`, and imports it from `src/main.zig` as `@import("zlua")`. It exists as a minimal integration fixture rather than a production application.

## Usage

Build the executable:

```sh
zig build
```

Run the example program:

```sh
zig build run
```

Run tests:

```sh
zig build test
```

## Dependency Setup

This repository is intended to demonstrate the result of adding `zlua` to a Zig project with `zig fetch --save`, then exposing the dependency module from `build.zig`:

```zig
const zlua_dep = b.dependency("zlua", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zlua", zlua_dep.module("zlua"));
```
