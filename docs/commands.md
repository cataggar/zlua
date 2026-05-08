# Command Reference

This document is the detailed command reference for zlua development and local usage. The root README keeps the common path short; this page covers the project-specific `just` recipes, `zig build` steps, zlua CLI options, and harness arguments.

## Command Layers

zlua exposes commands at three layers:

| Layer | Use it for |
| --- | --- |
| `just` recipes | Short local aliases for common development workflows. |
| `zig build` steps | Source-of-truth build graph, install artifacts, tests, examples, benchmarks, and harness runners. |
| zlua binaries | The installed CLI and standalone test/benchmark harness executables under `zig-out/bin/`. |

Arguments after `zig build <step> --` are forwarded to that step's executable. Arguments after `just <recipe>` are forwarded by the recipe when the recipe accepts `*args`.

## Common Commands

| Command | Purpose |
| --- | --- |
| `zig build` or `just build` | Build and install `zlua` and the downloaded `lua5.5` oracle. |
| `zig build run -- path/to/script.lua` or `just run path/to/script.lua` | Run a Lua script through zlua. |
| `zig build examples` | Compile all Zig embedding examples. |
| `zig build run-example` or `just example` | Run all Zig embedding examples. |
| `zig build ci` or `just ci` | Run the CI-equivalent local check. |
| `just diff tests/diff/runtime/tables.lua` | Run one differential fixture with debug errors enabled. |
| `just official calls` | Run one official Lua test file by name. |
| `just c-api tests/c-api/stack` | Run C API fixtures under one directory. |
| `just bench --list` | List benchmark fixtures. |

## just Recipes

The `justfile` is a convenience layer over `zig build` and direct binaries. It assumes `zig` is on `PATH` and uses `zig-out/bin` artifacts where needed.

| Recipe | Expands to | Notes |
| --- | --- | --- |
| `just` | `just --list` | Shows available recipes. |
| `just build` | `zig build` | Builds and installs zlua plus the downloaded CLua oracle. |
| `just fetch-lua` | `zig build fetch-lua` | Downloads and extracts Lua 5.5 source and official tests. |
| `just release` | `zig build -Doptimize=ReleaseSafe` | Builds with ReleaseSafe optimization. |
| `just test` | `zig build --summary all test` | Runs Zig unit tests. |
| `just ci` | `zig build ci` | Runs the aggregate local CI gate. |
| `just example [filters...]` | `zig build run-example -- [filters...]` | Runs all embedding examples or selected examples. |
| `just fmt` | `zig fmt build.zig src/*.zig src/testing/*.zig examples/*.zig` | Formats the root, top-level source files, testing files, and examples. |
| `just run [args...]` | `zig build run -- [args...]` | Runs zlua through the build runner. |
| `just version` | `zig build run -- --version` | Prints zlua version information. |
| `just clua-version` | `zig-out/bin/lua5.5 -v` after `just build` | Prints downloaded CLua version information. |
| `just diff [args...]` | `zig build --summary all run-test-diff -- --debug-errors [args...]` | Runs the differential harness with debug errors enabled. |
| `just official [args...]` | `zig build --summary all run-test-official -- --debug-errors --memory-limit-mb=256 [args...]` | Runs the official suite harness with debug errors and a 256 MiB child cap. |
| `just c-api [args...]` | `zig build --summary all test-c-api -- [args...]` | Runs C API fixtures. |
| `just bench [args...]` | `zig build -Doptimize=ReleaseFast --summary all run-test-bench -- [args...]` | Runs benchmarks with a ReleaseFast zlua build. |
| `just clean` | `rm -rf zig-out .zig-cache` | Removes local build outputs and Zig cache directories. |

`just example` filters can be an example key, binary name, path, basename, or basename without `.zig`. Current keys are `run_script`, `register_function`, `typed_host_function`, `plugin_sandbox`, `bytecode_roundtrip`, `memory_rw_files`, `userdata_counter`, and `preload_module`.

## zig build Options

The project uses Zig's standard build options plus one project-specific option. This section covers the options that matter for this repository; use `zig build --help` for Zig's full generic build flag reference.

| Option | Meaning |
| --- | --- |
| `-Dtarget=<target>` | Standard Zig target selection. |
| `-Doptimize=<mode>` | Standard Zig optimization mode, such as `Debug`, `ReleaseSafe`, `ReleaseFast`, or `ReleaseSmall`. |
| `-Dofficial-memory-limit-mb=<n>` | Memory cap, in MiB, passed to the `test-official` step. The default is `256`; `0` disables the cap for that step. |

Examples:

```sh
zig build -Doptimize=ReleaseSafe
zig build test-official -Dofficial-memory-limit-mb=0
zig build run-test-official -Doptimize=ReleaseFast -- --mode=complete strings.lua
```

## zig build Steps

| Step | Purpose | Forwarded arguments |
| --- | --- | --- |
| `zig build` | Default build and install step. Builds and installs `zlua`, downloaded `lua5.5`, `zlua-test-diff`, `zlua-test-official`, and `zlua-test-bench`. | None. |
| `zig build fetch-lua` | Downloads and extracts Lua 5.5 source and official tests into `.zlua-deps/`. | None. |
| `zig build run -- [args...]` | Builds and runs `zlua`. | zlua CLI arguments. |
| `zig build test` | Runs Zig unit tests for the library facade and CLI root module. | None. |
| `zig build examples` | Compiles all Zig embedding examples under `examples/`. | None. |
| `zig build run-example -- [filters...]` | Runs all embedding examples, or only selected examples. | Example filters. |
| `zig build test-diff` | Runs all differential fixtures under `tests/diff` using the downloaded CLua oracle. | None. |
| `zig build run-test-diff -- [args...]` | Runs the differential harness with forwarded harness arguments. | Differential harness arguments. |
| `zig build test-official` | Runs the official Lua 5.5 dashboard using the downloaded CLua oracle and configured memory cap. | None. |
| `zig build run-test-official -- [args...]` | Runs the official suite harness with forwarded harness arguments. | Official-suite harness arguments. |
| `zig build run-test-bench -- [args...]` | Runs the benchmark harness. The build graph passes downloaded CLua and the ReleaseFast zlua benchmark binary. | Benchmark harness arguments. |
| `zig build c-api` | Builds and installs the `zlua-c` static library, Lua headers, and C API harness. | None. |
| `zig build test-c-api -- [args...]` | Runs C API fixtures. The build graph passes the Zig executable, CLua include/lib paths, and zlua include/lib paths. | C API harness arguments. |
| `zig build ci-c-api` | Builds the C API artifacts and runs the C API fixture harness. | None. |
| `zig build ci` | Runs unit tests, embedding example compilation, differential fixtures, official dashboard, and C API checks. | None. |

## Installed Artifacts

After `zig build`, important artifacts are installed under `zig-out`:

| Artifact | Purpose |
| --- | --- |
| `zig-out/bin/zlua` | zlua command-line interpreter. |
| `zig-out/bin/lua5.5` | Downloaded official Lua 5.5 C implementation used as the oracle. |
| `zig-out/bin/zlua-test-diff` | Standalone differential fixture harness. |
| `zig-out/bin/zlua-test-official` | Standalone official-suite harness. |
| `zig-out/bin/zlua-test-bench` | Standalone benchmark harness. |
| `zig-out/bin/zlua-test-c-api` | Standalone C API fixture harness when installed by `zig build c-api` or `zig build ci-c-api`. |
| `zig-out/lib/libzlua-c.a` | Static Lua C API compatibility library when installed by `zig build c-api` or `zig build ci-c-api`. |
| `zig-out/include/lua.h`, `lauxlib.h`, `lualib.h`, `luaconf.h` | Lua headers installed with the C API library. |

## zlua CLI

Usage:

```sh
zlua [options] [script [args...]]
```

The CLI initializes a full standard-library state with host filesystem, environment, process, and I/O access enabled. This is intentionally different from the Zig embedding API, whose default state uses safe standard libraries and sandboxed capabilities.

| Option | Meaning |
| --- | --- |
| `--help`, `-h` | Print usage and exit. |
| `--version`, `-v` | Print zlua and Lua target version. If no input is provided on a TTY, exits after printing. |
| `--debug-errors` | Include internal debug details in runtime error reporting. |
| `--trace-vm` | Trace VM execution while running or dumping input. |
| `--stdlib <mode>` | Select standard libraries using a separate value. |
| `--stdlib=<mode>` | Select standard libraries using an inline value. |
| `-e <chunk>` | Execute a command-line chunk before the script. May be repeated. |
| `-e<chunk>` | Compact form of `-e <chunk>`. |
| `-i` | Enter the REPL after executing command-line chunks and any script. |
| `--dump-ast [script]` | Parse input and print the AST-oriented debug dump. |
| `--dump-scope [script]` | Parse and resolve input, then print the scope-oriented debug dump. |
| `--dump-bytecode [script]` | Parse, resolve, compile, and print disassembled zlua bytecode. |
| `--` | Stop option parsing. The following argument is treated as the script path if present. |
| `-` | Read the script from stdin. |

`--stdlib` accepts the presets `none`, `base`, `safe`, and `full`. It also accepts a comma- or plus-separated library list using names from `base`, `table`, `string`, `math`, `utf8`, `coroutine`, `io`, `os`, `debug`, and `package`.

Input handling:

| Form | Behavior |
| --- | --- |
| `zlua script.lua a b` | Runs `script.lua`; Lua sees script arguments through `arg`. |
| `zlua -e 'print(1)' script.lua` | Runs the `-e` chunk first, then the script. |
| `zlua -` | Reads a script from stdin and names it `@stdin`. |
| `zlua` on a TTY | Starts the REPL. |
| `zlua` with piped stdin | Reads and executes stdin as a script. |
| `zlua --dump-bytecode -e 'return 1 + 2'` | Dumps command-line input instead of executing it. |

Script and stdin reads are currently capped at 1 MiB. Initial shebang lines are stripped for script and stdin execution.

The REPL uses `> ` and `>> ` prompts on a TTY, continues reading when the current source appears incomplete, supports `=expr` as shorthand for `print(expr)`, and also tries expression-style echoing when a line is not a valid chunk by itself.

## Differential Harness

The differential harness compares Lua-visible behavior against the official Lua 5.5 C implementation.

Build-runner forms:

```sh
zig build test-diff
zig build run-test-diff -- [options] [path]
just diff [options] [path]
zig-out/bin/zlua-test-diff [options] [path]
```

Options:

| Option | Meaning |
| --- | --- |
| `[path]` | Fixture file or directory. Defaults to `tests/diff`. Directories are walked recursively for `.lua` files. |
| `--clua <path>` | Use an explicit CLua executable. |
| `--clua=<path>` | Inline form of `--clua`. |
| `--stage=<stage>` | Run only fixtures whose metadata stage matches. Valid stages are `lex`, `parse`, `resolve`, `compile`, `runtime`, `stdlib`, and `official`. |
| `--feature=<tag>` | Run only fixtures whose metadata feature matches. |
| `--timeout-ms=<n>` | Per-process timeout in milliseconds. Defaults to `5000`. |
| `--show-clua` | Print CLua stdout/stderr for each fixture. |
| `--show-zlua` | Print zlua stdout/stderr for each fixture. |
| `--gc-stress` | Enable GC stress behavior in zlua fixture execution. |
| `--debug-errors` | Enable zlua debug error details. |
| `--bless` | Accepted for command stability; currently a no-op. |
| `--update-expected-failures` | Accepted for command stability; currently a no-op. |

CLua discovery order is explicit `--clua`, then `ZLUA_CLUA`, then `zig-out/bin/lua5.5`, `lua5.5`, `lua5.5.0`, and `lua` if it identifies as Lua 5.5.

## Official Suite Harness

The official-suite harness runs downloaded upstream Lua 5.5 tests under CLua and zlua.

Build-runner forms:

```sh
zig build test-official
zig build run-test-official -- [options] [files...]
just official [options] [files...]
zig-out/bin/zlua-test-official [options] [files...]
```

Options:

| Option | Meaning |
| --- | --- |
| `[files...]` | Official test names or files to run. With no files, runs every top-level `.lua` file except `all.lua`. Passing file arguments also enables zlua output display. |
| `--clua <path>` | Use an explicit CLua executable. |
| `--clua=<path>` | Inline form of `--clua`. |
| `--zlua <path>` | Use an explicit zlua executable. |
| `--zlua=<path>` | Inline form of `--zlua`. |
| `--suite-path <path>` | Use an alternate extracted official-suite directory. |
| `--suite-path=<path>` | Inline form of `--suite-path`. |
| `--mode=basic` | Run with the basic official prelude. This is the default. |
| `--mode=complete` | Run with the complete-suite prelude. |
| `--mode=internal` | Parsed but currently skipped because internal `testC` builds are not wired. |
| `--timeout-ms=<n>` | Per-process timeout in milliseconds. Default `0` disables timeout. |
| `--memory-limit-mb=<n>` | Per-child memory cap in MiB. Default `0` disables the cap for direct harness runs. |
| `--show-clua` | Print CLua output. |
| `--show-zlua` | Print zlua output. |
| `--debug-errors` | Pass debug error reporting to zlua executions. |

The harness verifies `.zlua-deps/lua-5.5.0-tests.tar.gz` against the expected SHA-256 before running. The `zig build test-official` step passes `--memory-limit-mb=<n>` from `-Dofficial-memory-limit-mb`, defaulting to `256`.

## Benchmark Harness

The benchmark harness compares process-level execution time for benchmark Lua files under CLua and a ReleaseFast zlua binary.

Build-runner forms:

```sh
zig build run-test-bench -- [options] [selectors...]
just bench [options] [selectors...]
zig-out/bin/zlua-test-bench [options] [selectors...]
```

Options:

| Option | Meaning |
| --- | --- |
| `[selectors...]` | Benchmark selectors. A selector may match benchmark name, path, relative path, basename, basename without `.lua`, or a directory. With no selectors, all benchmarks matching `--category` are selected. |
| `--list` | List selected benchmarks instead of running them. |
| `--clua <path>` | Use an explicit CLua executable. |
| `--clua=<path>` | Inline form of `--clua`. |
| `--zlua <path>` | Use an explicit zlua executable. |
| `--zlua=<path>` | Inline form of `--zlua`. |
| `--iterations <n>` | Override benchmark iteration count. Must be positive. |
| `--iterations=<n>` | Inline form of `--iterations`. |
| `--warmup <n>` | Override warmup count. May be `0`. |
| `--warmup=<n>` | Inline form of `--warmup`. |
| `--no-warmup` | Set warmup count to `0`. |
| `--timeout-ms <n>` | Override per-process timeout. Must be positive. |
| `--timeout-ms=<n>` | Inline form of `--timeout-ms`. |
| `--category <name>` | Run only benchmarks with a matching metadata category. |
| `--category=<name>` | Inline form of `--category`. |
| `--json <path>` | Write a JSON report. |
| `--json=<path>` | Inline form of `--json`. |
| `--csv <path>` | Write a CSV report. |
| `--csv=<path>` | Inline form of `--csv`. |
| `--debug-errors` | Pass debug error reporting to zlua executions. |

Benchmark files live under `tests/bench` and are discovered recursively. Metadata comments can set `name`, `category`, `iterations`, `warmup`, `timeout-ms`, `expect`, and `reason`. Defaults are category `misc`, `5` iterations, `1` warmup run, `60000` ms timeout, and `expect: pass`.

## C API Harness

The C API harness compiles each C fixture twice, once against CLua and once against `zlua-c`, then compares behavior.

Build-runner forms:

```sh
zig build c-api
zig build test-c-api -- [options] [path]
zig build ci-c-api
just c-api [options] [path]
zig-out/bin/zlua-test-c-api [options] [path]
```

Options:

| Option | Meaning |
| --- | --- |
| `[path]` | Fixture file or directory. Defaults to `tests/c-api`. Directories are walked recursively for `.c` files. |
| `--zig <path>` | Zig executable used to compile fixtures. Defaults to `zig`; the build step passes its current Zig executable. |
| `--clua-include <path>` | Include directory for CLua headers. Defaults to `.zlua-deps/lua-5.5.0/src`. |
| `--clua-lib <path>` | CLua static library path. If omitted, fixture execution is skipped after status inventory validation. |
| `--zlua-include <path>` | Include directory for zlua headers. Defaults to `.zlua-deps/lua-5.5.0/src`. |
| `--zlua-lib <path>` | zlua C API static library path. If omitted, fixture execution is skipped after status inventory validation. |
| `--status <path>` | Public C API symbol status inventory. Defaults to `tests/fixtures/c_api_status.toml`. |
| `--timeout-ms=<n>` | Per-fixture run timeout in milliseconds. Defaults to `5000`. |
| `--compile-timeout-ms=<n>` | Per-fixture compile/link timeout in milliseconds. Defaults to `60000`. |
| `--show-build` | Print compile/link details for fixture builds. |

The harness always validates the status inventory before deciding whether fixture libraries are available. It writes fixture build outputs under `.zig-cache/c-api-fixtures`.

## Environment And Dependency Cache

`zig build fetch-lua` populates `.zlua-deps/`, and any step that needs CLua depends on that fetch step. The fetch script verifies SHA-256 checksums before extraction.

Environment variables:

| Variable | Meaning |
| --- | --- |
| `ZLUA_CLUA` | Preferred CLua executable for differential, official, and benchmark harnesses when `--clua` is not provided. |
| `ZLUA_LUA_URL` | Override URL for the Lua 5.5 source archive used by `zig build fetch-lua`. |
| `ZLUA_LUA_TESTS_URL` | Override URL for the Lua 5.5 official tests archive used by `zig build fetch-lua`. |

The dependency cache lives in `.zlua-deps/` and is ignored by Git. Build outputs live in `zig-out/` and `.zig-cache/`.
