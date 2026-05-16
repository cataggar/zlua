# Embedding zlua From Zig

zlua exposes a Zig-native embedding API through `@import("zlua")`. The API is intentionally not a clone of the Lua C stack API: hosts create a `zlua.State`, pass explicit capabilities, use typed values and rooted handles, and receive Zig errors instead of `longjmp`-style control flow.

The public embedding entrypoint is `zlua.State`. The lower-level `zlua.runtime` module is available for zlua internals and tests, but it is not a stable embedding contract.

## Lifecycle

Create one `State` for each Lua environment owned by the host:

```zig
const std = @import("std");
const zlua = @import("zlua");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var lua = try zlua.State.init(allocator, .{});
    defer lua.deinit();

    try lua.doString("assert(_VERSION == 'Lua 5.5')", .{ .name = "=main" });
}
```

`State.init` defaults to `.safe` standard libraries and sandboxed host access. Use `.stdlib = .full` only when you need the full standard-library surface, and grant filesystem, environment, process, clock, and I/O capabilities explicitly.

Supported standard-library modes are:

```zig
none
base
safe
full
```

## Capabilities

Capabilities are the host services Lua code may use. The default is sandboxed:

```zig
var lua = try zlua.State.init(allocator, .{});
```

This opens safe libraries while leaving filesystem, environment, clock, process, and default output access disabled unless explicitly configured.

The sandbox boundary has two layers. The `stdlib` option controls which Lua globals are opened. The `capabilities` option controls whether opened libraries can reach host services. Opening `.full` exposes globals such as `io`, `os`, `package`, `require`, `loadfile`, and `dofile`, but those functions still fail or return denial-style errors when the matching host capability is disabled.

| Capability | Grants | Disabled behavior |
| --- | --- | --- |
| `io` | Host `std.Io`, stdin contents, and optional stdout/stderr writers. Required by std-backed host filesystem, clock, and process operations that need Zig I/O. | No host I/O handle is available; std-backed file, clock, or process operations that require it fail instead of falling back to ambient process I/O. |
| `filesystem` | `.memory` read-only files, `.memory_rw` writable memory files, `.host_cwd` access to the process current working directory, or `.custom` callback-backed files. | `loadfile`, `dofile`, `require`, `io.open`, `io.lines`, `os.remove`, and `os.rename` cannot read or mutate host files. |
| `environment` | A std environment map or `.custom` callback for `os.getenv`. Std-backed child processes also receive `.map` environments. | `os.getenv` returns `nil`; enabled std-backed child processes receive no implicit environment map from zlua. |
| `clock` | A fixed timestamp, std system clock, or `.custom` callback for `os.time` and default-time `os.date` calls. | Current-time reads fail with `clock access disabled`. |
| `process` | `os.execute` through std process spawning or a `.custom` callback. | `os.execute` fails with `process access disabled`; zlua does not provide dynamic native module loading. |

The command-line `zlua` binary is intentionally different from the embedding default: it starts with full host filesystem, environment, process, and I/O access so it behaves like a normal Lua interpreter. Use the Zig embedding API when untrusted or plugin-style code should start sandboxed.

The std-backed host variants, `.filesystem = .host_cwd`, `.clock = .system`, and `.process = .enabled`, use Zig standard-library host facilities. They are intended for normal hosted targets. Freestanding embedders, kernels, unikernels, and other non-std hosts should provide `.custom` capabilities instead.

To capture output and provide deterministic time:

```zig
var output = std.Io.Writer.Allocating.init(allocator);
defer output.deinit();

var lua = try zlua.State.init(allocator, .{
    .stdlib = .full,
    .capabilities = .{
        .io = .{ .stdout = &output.writer },
        .clock = .{ .fixed = 0 },
    },
});
defer lua.deinit();

try lua.doString("print(os.time())", .{ .name = "=time" });
```

Memory-backed files let embedded hosts support `loadfile`, `dofile`, and `require` without granting host filesystem access:

```zig
const files = [_]zlua.api.MemoryFile{
    .{ .path = "plugins/mathx.lua", .contents = "return { double = function(x) return x * 2 end }" },
};

var lua = try zlua.State.init(allocator, .{
    .stdlib = .full,
    .capabilities = .{ .filesystem = .{ .memory = &files } },
});
defer lua.deinit();

try lua.setPackagePath("plugins/?.lua");
try lua.doString("assert(require('mathx').double(21) == 42)", .{ .name = "=require" });
```

Use `MemoryFilesystem` with `.memory_rw` when Lua code should be able to create, update, remove, or rename files without touching the host filesystem:

```zig
var filesystem = zlua.MemoryFilesystem.init(allocator);
defer filesystem.deinit();

var lua = try zlua.State.init(allocator, .{
    .stdlib = .full,
    .capabilities = .{ .filesystem = .{ .memory_rw = &filesystem } },
});
defer lua.deinit();

try lua.doString(
    \\local file = assert(io.open('report.txt', 'w'))
    \\assert(file:write('ok'))
    \\assert(file:close())
, .{ .name = "=write-report" });

const report = try filesystem.readFileAlloc(allocator, "report.txt");
defer allocator.free(report);
```

`State.addMemoryFile` can add owned files to a state that was initialized with disabled or read-only memory filesystem access. It writes through to `.memory_rw` filesystems and returns `error.UnsupportedOption` for host and custom filesystem states.

Memory filesystem paths are sandbox-relative. zlua normalizes `.` segments and repeated `/` separators, rejects absolute paths, rejects `..` path traversal, rejects backslash-containing paths, rejects NUL bytes, rejects empty paths, and enforces a configurable maximum normalized path length for writable memory files. `loadfile`, `dofile`, and `require` use the same memory-filesystem path checks, so package paths that expand to absolute or parent-traversal paths do not escape the memory sandbox.

`MemoryFilesystem.init` uses the default path limit. Use `MemoryFilesystem.initWithOptions` or `MemoryFilesystem.initWithFilesAndOptions` to set `max_path_len` or an optional `max_bytes` content quota. The quota counts file contents, applies during seed-file initialization, creates, and overwrites, decreases when files are removed, and `renameFile` overwrites an existing normalized target without changing the total byte count except for the removed target contents.

`io.tmpfile` and `os.tmpname` are currently synthetic helpers in embedded states. They do not create host files by themselves, but closing a writable temporary file still goes through the configured filesystem capability.

### Custom Host Capabilities

Use `.custom` capabilities when the host has filesystem, environment, clock, or process services that are not exposed through Zig's std host APIs. This is the intended shape for freestanding kernels that still want Lua's full host-facing standard library profile.

Custom callbacks receive an opaque context pointer supplied by the embedder. Filesystem read callbacks must return an allocator-owned buffer using the allocator passed by zlua. Optional filesystem mutation callbacks can be left `null`; Lua write/remove/rename operations then report capability-denial style errors.

```zig
const Host = struct {
    filesystem: zlua.MemoryFilesystem,

    fn self(ctx: ?*anyopaque) *Host {
        return @ptrCast(@alignCast(ctx.?));
    }

    fn readFileAlloc(ctx: ?*anyopaque, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        return self(ctx).filesystem.readFileAlloc(allocator, path);
    }

    fn writeFile(ctx: ?*anyopaque, path: []const u8, contents: []const u8) !void {
        try self(ctx).filesystem.writeFile(path, contents);
    }

    fn removeFile(ctx: ?*anyopaque, path: []const u8) !void {
        try self(ctx).filesystem.removeFile(path);
    }

    fn renameFile(ctx: ?*anyopaque, old_path: []const u8, new_path: []const u8) !void {
        try self(ctx).filesystem.renameFile(old_path, new_path);
    }

    fn getenv(ctx: ?*anyopaque, name: []const u8) ?[]const u8 {
        _ = ctx;
        if (std.mem.eql(u8, name, "KERNEL_ENV")) return "present";
        return null;
    }

    fn now(ctx: ?*anyopaque) !i64 {
        _ = ctx;
        return 1_700_000_000;
    }

    fn execute(ctx: ?*anyopaque, command: []const u8) !zlua.ProcessResult {
        _ = ctx;
        if (std.mem.eql(u8, command, "true")) return .{ .status = .exit, .code = 0 };
        return .{ .status = .exit, .code = 1 };
    }
};

var host = Host{ .filesystem = zlua.MemoryFilesystem.init(allocator) };
defer host.filesystem.deinit();
try host.filesystem.writeFile("scripts/main.lua", "return os.getenv('KERNEL_ENV')");

var lua = try zlua.State.init(allocator, .{
    .stdlib = .full,
    .capabilities = .{
        .filesystem = .{ .custom = .{
            .context = &host,
            .read_file_alloc = Host.readFileAlloc,
            .write_file = Host.writeFile,
            .remove_file = Host.removeFile,
            .rename_file = Host.renameFile,
        } },
        .environment = .{ .custom = .{
            .context = &host,
            .get = Host.getenv,
        } },
        .clock = .{ .custom = .{
            .context = &host,
            .now = Host.now,
        } },
        .process = .{ .custom = .{
            .context = &host,
            .execute = Host.execute,
        } },
    },
});
defer lua.deinit();

try lua.doString(
    \\assert(dofile('scripts/main.lua') == 'present')
    \\assert(os.time() == 1700000000)
    \\local ok, why, code = os.execute('true')
    \\assert(ok == true and why == 'exit' and code == 0)
, .{ .name = "=custom-host" });
```

`CustomProcess.execute` maps directly to Lua's `os.execute` result convention. Return `.status = .exit, .code = 0` for success, `.status = .exit` with a non-zero code for command failure, or `.status = .signal` when the host process abstraction reports signal-style termination.

## Limits

Public options include memory, instruction, stack value, and call frame limits:

```zig
var lua = try zlua.State.init(allocator, .{
    .limits = .{
        .max_memory = 16 * 1024 * 1024,
        .max_stack_values = 4096,
        .max_call_frames = 128,
        .max_instructions = 1_000_000,
    },
});
```

`max_instructions` is a cumulative per-state budget. Every executed VM instruction consumes one unit across all loaded chunks, protected calls, unprotected calls, and coroutine resumes in that state. Use `State.instructionBudget` to query the configured limit, used count, and remaining budget. Use `State.resetInstructionBudget` to set the used count back to zero.

`max_memory` installs a bounded allocator for the embedding state. It covers parser/compiler work, bytecode loading, VM objects, API conversion, memory-file copies, and captured stdout/stderr buffers. The VM also checks Lua heap usage at instruction boundaries so collectible objects can be reclaimed before reporting `memory limit exceeded`.

When a protected call hits these limits, zlua returns a Lua error value through `Function.protectedCall`. Convenience APIs such as `loadString`, `loadBytecode`, and `doString` return `error.LuaError` and store the error details on the state when the configured limit was the cause. `State.init` can still return `error.OutOfMemory` if the configured memory limit is too small to initialize the requested libraries. `State.stepGc` currently performs a full collection and returns `.complete`; `GcOptions` is reserved for future tuning.

## Loading And Running Code

Use `doString` or `doFile` for one-shot scripts:

```zig
try lua.doString("answer = 21 * 2", .{ .name = "=setup" });
try lua.doFile("plugin.lua", .{ .name = "@plugin.lua" });
```

`LoadOptions.environment` can run a chunk with a host-provided `_ENV` table:

```zig
var env = try lua.createTable(.{ .hash_hint = 1 });
defer env.deinit();
try env.set("answer", 42);

var chunk = try lua.loadString("return answer", .{ .environment = env });
defer chunk.deinit();

const answer = try chunk.call(.{}, i64);
```

`LoadOptions.mode` accepts `source_only`, `binary_only`, and `source_or_binary`. Binary loading supports zlua binary chunks produced by zlua, such as data from Lua `string.dump`; PUC Lua `luac` chunks are rejected.

For host-managed bytecode round trips, dump a loaded function and reload it directly:

```zig
var chunk = try lua.loadString("return 40 + ...", .{ .name = "=cached" });
defer chunk.deinit();

const bytecode = try chunk.dumpBytecode(.{ .strip_debug = true });
defer lua.allocator().free(bytecode);

var cached = try lua.loadBytecode(bytecode, .{});
defer cached.deinit();

const value = try cached.call(.{42}, i64);
```

`dumpBytecode` returns zlua-owned bytecode only. It is intended for zlua-to-zlua caching or transfer and is not compatible with PUC Lua `luac` output.

Use `loadString` or `loadFile` when you want a reusable, rooted function handle:

```zig
var chunk = try lua.loadString("local name = ...; return 'hello, ' .. name", .{ .name = "=greet" });
defer chunk.deinit();

const greeting = try chunk.call(.{"host"}, []const u8);
```

Function handles own registry roots. Release them with `deinit` when the host no longer needs them. Installing a handle with `setGlobal` or `Table.set` does not consume it; Lua keeps its own table/global reference, and `deinit` only releases the host-owned root.

## Values And Conversion

The high-level `zlua.Value` union supports immediate interop:

```zig
nil
boolean
integer
number
string
table
function
userdata
```

Most common Zig values convert automatically when passed to `setGlobal`, `Table.set`, callback returns, or function calls:

```text
null -> nil
bool -> boolean
integers -> Lua integer when representable
floats -> Lua number
[]const u8 -> Lua string
arrays and slices -> Lua array table
structs -> Lua table by field name
Table, Function, Ref, Value, Userdata(T) -> existing Lua value
```

Reading values requires an explicit result type:

```zig
try lua.setGlobal("answer", 42);
const answer = try lua.getGlobal("answer", i64);
```

For multiple returns, use `zlua.Tuple`:

```zig
var chunk = try lua.loadString("return true, 42, 'ok'", .{ .name = "=tuple" });
defer chunk.deinit();

const Result = zlua.Tuple(&.{ bool, i64, []const u8 });
var result = try chunk.call(.{}, Result);
defer result.deinit();

const flag = result.get(0);
const number = result.get(1);
const label = result.get(2);
```

Returned `Table`, `Function`, `Userdata`, `AnyUserdata`, `Ref`, and tuple fields containing owned handles must be deinitialized by the host.

## Globals And Tables

Global access is direct:

```zig
try lua.setGlobal("answer", 42);
const answer = try lua.getGlobal("answer", i64);
```

Build tables with `createTable` and mutate them through `Table.get` and `Table.set`:

```zig
var config = try lua.createTable(.{ .hash_hint = 4 });
defer config.deinit();

try config.set("title", "demo");
try config.set("max_players", 8);
try config.set("debug", true);

try lua.setGlobal("config", config);
```

Arrays and simple structs can be converted directly:

```zig
try lua.setGlobal("search_path", &.{ "scripts/?.lua", "scripts/?/init.lua" });
try lua.setGlobal("app", .{
    .name = "zlua-host",
    .version = 1,
    .features = &.{ "plugins", "sandbox" },
});
```

## Modules And `require`

Preload a host-created module table:

```zig
var host = try lua.createModule("host");
defer host.deinit();

try host.set("name", "host-module");
try host.set("version", 1);
try lua.preloadModule("host", host);

try lua.doString(
    \\local host = require('host')
    \\assert(host.name == 'host-module')
, .{ .name = "=host-module" });
```

Host callbacks are created as `Function` handles and can be installed in module tables or globals:

```zig
var double_fn = try lua.register("host_double", hostDouble);
defer double_fn.deinit();
try host.set("double", double_fn);
```

Pure Lua modules can be loaded from the memory filesystem with `setPackagePath`.

## Host Callbacks

Create callbacks with `State.register`, then install them where Lua code should find them:

```zig
var host_add = try lua.register("host_add", hostAdd);
defer host_add.deinit();
try lua.setGlobal("host_add", host_add);

fn hostAdd(ctx: *zlua.Context) !void {
    const lhs = try ctx.arg(0, i64);
    const rhs = try ctx.arg(1, i64);
    try ctx.returnValues(.{ lhs + rhs, "ok" });
}
```

Lua code can then call the function normally:

```lua
local sum, status = host_add(20, 22)
assert(sum == 42 and status == "ok")
```

Use `ctx.arg` for required arguments, `ctx.optionalArg` for optional arguments, and `ctx.returnValues` for zero or more return values. Argument conversion failures become Lua errors with callback and argument context.

Callbacks can raise Lua errors explicitly:

```zig
fn fail(ctx: *zlua.Context) !void {
    return ctx.raise("host boom");
}
```

Callbacks can also receive and call Lua functions:

```zig
fn eachItem(ctx: *zlua.Context) !void {
    var callback = try ctx.arg(0, zlua.Function);
    defer callback.deinit();

    _ = try callback.call(.{.{ .name = "first", .id = 1 }}, void);
    try ctx.returnValues(.{});
}
```

`registerTyped` is available for simple typed Zig functions and also returns a `Function`:

```zig
var clamp_fn = try lua.registerTyped("clamp", clamp);
defer clamp_fn.deinit();
try lua.setGlobal("clamp", clamp_fn);

fn clamp(value: f64, min: f64, max: f64) f64 {
    return @min(@max(value, min), max);
}
```

## Calling Lua From Zig

Load a chunk or read a global function as `zlua.Function`, then call it with tuple arguments:

```zig
try lua.doString("function add(a, b) return a + b end", .{ .name = "=defs" });

var add = try lua.getGlobal("add", zlua.Function);
defer add.deinit();

const sum = try add.call(.{ 20, 22 }, i64);
```

Use `protectedCall` when Lua failures should be handled as values:

```zig
var failing = try lua.loadString("error('boom')", .{ .name = "=failing" });
defer failing.deinit();

const result = try failing.protectedCall(.{}, void);
switch (result) {
    .ok => {},
    .lua_error => |err_ref| {
        var err = err_ref;
        defer err.deinit();
        const message = try err.message();
        defer lua.allocator().free(message);
    },
}
```

## Errors

Convenience APIs return `error.LuaError` for Lua syntax and runtime errors. The state stores the last Lua error value:

```zig
lua.doString("error('boom')", .{ .name = "=plugin" }) catch |err| switch (err) {
    error.LuaError => {
        const message = try lua.errorMessage();
        defer lua.allocator().free(message);
        std.debug.print("lua error: {s}\n", .{message});
    },
    else => return err,
};
```

Use `takeErrorValue` when host code needs to keep the Lua error value rooted after inspecting it.

## Userdata

Use userdata to expose native Zig objects:

```zig
const Counter = struct {
    value: i64,

    fn inc(self: *@This(), amount: i64) i64 {
        self.value += amount;
        return self.value;
    }
};

var counter = try lua.newUserdata(Counter, .{ .value = 0 }, .{});
defer counter.deinit();

try counter.method("inc", Counter.inc);
try lua.setGlobal("counter", counter);

try lua.doString(
    \\assert(counter:inc(2) == 2)
    \\assert(counter:inc(3) == 5)
, .{ .name = "=counter" });
```

`newUserdata` allocates Lua-owned native storage. `newUserdataPtr` wraps a host-owned pointer. Both support typed reads in callbacks through `ctx.arg(0, *T)`.

Lua-owned userdata can run a finalizer during garbage collection:

```zig
var value = try lua.newUserdata(T, initial_value, .{ .finalizer = T.finalize });
```

Userdata metatables can also receive methods and metamethods such as `__close`.

## Sandboxed Plugin Pattern

A typical plugin host combines safe libraries, memory files, output capture, deterministic capabilities, limits, and host callbacks:

```zig
const files = [_]zlua.api.MemoryFile{
    .{ .path = "plugin.lua", .contents = "emit({ kind = 'loaded', version = 1 })" },
};

var output = std.Io.Writer.Allocating.init(allocator);
defer output.deinit();

var lua = try zlua.State.init(allocator, .{
    .stdlib = .safe,
    .capabilities = .{
        .io = .{ .stdout = &output.writer },
        .filesystem = .{ .memory = &files },
        .clock = .{ .fixed = 0 },
    },
    .limits = .{
        .max_memory = 16 * 1024 * 1024,
        .max_instructions = 1_000_000,
    },
});
defer lua.deinit();

var emit_fn = try lua.register("emit", emit);
defer emit_fn.deinit();
try lua.setGlobal("emit", emit_fn);
try lua.doFile("plugin.lua", .{ .name = "@plugin.lua" });
```

## Raw Escape Hatch

There is no stable high-level raw escape hatch in the embedding API yet. Importing or storing `zlua.runtime` types should be treated as an internal, unstable integration point: runtime values, bytecode, frames, GC layout, and registry internals may change without embedding-API compatibility guarantees.

If you need a low-level operation that is not available through `zlua.State`, prefer adding a small facade method to `src/api.zig` rather than exposing runtime internals to application code.

## Current Reserved Or Unsupported Areas

These areas are reserved or incomplete in the current embedding surface:

```text
GcOptions is reserved for future tuning.
State.stepGc accepts a budget but currently performs a full collection.
There is no State.callGlobal or State.protectedCallGlobal convenience method; get a Function and call it.
There is no stable zlua.api.Raw wrapper.
Coroutine/thread handles are not exposed through the high-level API.
Broad table-to-struct decoding is not implemented.
```

## Examples

Embedding examples live under `examples`:

```text
examples/run_script.zig
examples/register_function.zig
examples/typed_host_function.zig
examples/plugin_sandbox.zig
examples/bytecode_roundtrip.zig
examples/memory_rw_files.zig
examples/userdata_counter.zig
examples/typed_userdata_initializer.zig
examples/preload_module.zig
```

Compile them with:

```sh
zig build examples
```

Run all examples with:

```sh
zig build run-example
```

Run one example by basename or file name with:

```sh
zig build run-example -- run_script
zig build run-example -- run_script.zig
```

The justfile exposes the same workflow as a single endpoint:

```sh
just example
just example run_script
```

The `examples` build step is part of `zig build ci`.
