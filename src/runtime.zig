const std = @import("std");
const compile = @import("compile.zig");
const chunk_mod = @import("runtime/chunk.zig");
const errors = @import("errors.zig");
const frontend = @import("frontend.zig");
const host = @import("runtime/host.zig");
const process = @import("testing/process.zig");
const state_mod = @import("runtime/state.zig");
const types = @import("runtime/types.zig");

pub const RuntimeError = types.RuntimeError;
pub const binary_chunk_signature = chunk_mod.binary_chunk_signature;
pub const binary_chunk_payload_magic = chunk_mod.binary_chunk_payload_magic;

pub const State = state_mod.State;
pub const StateOptions = state_mod.StateOptions;

pub const Value = types.Value;
pub const NativeFn = types.NativeFn;
pub const UserdataFinalizer = types.UserdataFinalizer;
pub const UserdataDeinit = types.UserdataDeinit;
pub const ProtectedCallResult = types.ProtectedCallResult;
pub const ApiCallbackDispatchFn = types.ApiCallbackDispatchFn;
pub const CClosureDispatchFn = types.CClosureDispatchFn;
pub const CClosureResumeDispatchFn = types.CClosureResumeDispatchFn;
pub const CDebugHookDispatchFn = types.CDebugHookDispatchFn;
pub const DebugHookEvent = types.DebugHookEvent;
pub const CDebugHookContext = types.CDebugHookContext;
pub const CClosureContext = types.CClosureContext;
pub const CClosureResumeContext = types.CClosureResumeContext;
pub const ApiCallbackContext = types.ApiCallbackContext;
pub const RuntimeErrorPayload = types.RuntimeErrorPayload;

pub const appendBinaryChunkHeader = chunk_mod.appendBinaryChunkHeader;
pub const dumpClosureBinary = chunk_mod.dumpClosureBinary;

pub const Closure = types.Closure;
pub const CClosure = types.CClosure;
pub const CUpvalue = types.CUpvalue;
pub const Upvalue = types.Upvalue;
pub const Table = types.Table;
pub const Userdata = types.Userdata;
pub const Thread = types.Thread;
pub const GcMode = types.GcMode;
pub const GcParam = types.GcParam;

pub const StdlibMode = state_mod.StdlibMode;
pub const MemoryFile = host.MemoryFile;
pub const MemoryFilesystem = host.MemoryFilesystem;
pub const FilesystemCapability = host.FilesystemCapability;
pub const ClockCapability = host.ClockCapability;
pub const ProcessCapability = host.ProcessCapability;

pub const CompareOp = state_mod.CompareOp;
pub const valuesEqual = state_mod.valuesEqual;
pub const truthy = state_mod.truthy;
pub const toInteger = state_mod.toInteger;
pub const toNumber = state_mod.toNumber;
pub const appendLuaString = state_mod.appendLuaString;
pub const localActiveAt = state_mod.localActiveAt;
pub const parseIntegerStrict = state_mod.parseIntegerStrict;
pub const parseLuaNumber = state_mod.parseLuaNumber;
pub const floatToInteger = state_mod.floatToInteger;
pub const trimAscii = state_mod.trimAscii;
pub const runtimeArgValue = state_mod.runtimeArgValue;
pub const argValue = state_mod.argValue;
pub const appendValue = state_mod.appendValue;
pub const isFileValue = state_mod.isFileValue;
pub const isClosedFileValue = state_mod.isClosedFileValue;
pub const appendNumber = state_mod.appendNumber;
pub const appendFmt = state_mod.appendFmt;

pub const ExecuteOptions = struct {
    collect_after_instruction: bool = false,
    state: StateOptions = .{},
};

pub fn executeSource(allocator: std.mem.Allocator, source: []const u8) !process.ProcessResult {
    return executeSourceWithOptions(allocator, source, .{});
}

pub fn executeSourceWithOptions(allocator: std.mem.Allocator, source: []const u8, options: ExecuteOptions) !process.ProcessResult {
    var diagnostic: ?errors.Diagnostic = null;
    var tree = frontend.parseWithDiagnostic(allocator, source, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot load source");
    };
    defer tree.deinit();

    compile.resolver.resolveWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot resolve source");
    };

    var proto = compile.compileWithDiagnostic(allocator, &tree, &diagnostic) catch {
        return sourceFailureResult(allocator, source, diagnostic, "cannot compile source");
    };
    defer proto.deinit();

    var state = try State.initWithOptions(allocator, options.state);
    defer state.deinit();
    state.collect_after_instruction = options.collect_after_instruction;
    state.execute(&proto) catch |err| {
        const detail = try state.errorDetailAlloc(allocator, err);
        defer allocator.free(detail);
        const message = try std.fmt.allocPrint(allocator, "{s}\n", .{detail});
        defer allocator.free(message);
        var stderr = std.ArrayList(u8).empty;
        errdefer stderr.deinit(allocator);
        try stderr.appendSlice(allocator, state.stderr.items);
        try stderr.appendSlice(allocator, message);
        return .{
            .stdout = try allocator.dupe(u8, state.stdout.items),
            .stderr = try stderr.toOwnedSlice(allocator),
            .exit_code = 1,
            .signal = null,
            .timed_out = false,
        };
    };

    return .{
        .stdout = try allocator.dupe(u8, state.stdout.items),
        .stderr = try allocator.dupe(u8, state.stderr.items),
        .exit_code = 0,
        .signal = null,
        .timed_out = false,
    };
}

fn sourceFailureResult(allocator: std.mem.Allocator, source: []const u8, diagnostic: ?errors.Diagnostic, fallback: []const u8) !process.ProcessResult {
    const rendered = if (diagnostic) |diag|
        try errors.renderLoadDiagnostic(allocator, null, source, diag)
    else
        try allocator.dupe(u8, fallback);
    defer allocator.free(rendered);
    const message = try std.fmt.allocPrint(allocator, "{s}\n", .{rendered});
    defer allocator.free(message);
    return process.ownedResult(allocator, "", message, 1);
}

test "executes basic print and arithmetic" {
    var result = try executeSource(std.testing.allocator,
        \\print(1 + 2)
        \\print(9 // 4)
        \\print(2 ^ 8)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "3\n2\n256.0\n"));
}

test "executes if while and repeat jumps" {
    var result = try executeSource(std.testing.allocator,
        \\local x = 0
        \\while x < 3 do
        \\  x = x + 1
        \\end
        \\if x == 3 then print("while") else print("bad") end
        \\repeat
        \\  x = x - 1
        \\until x == 0
        \\print(x)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "while\n0\n"));
}

test "reports stack overflow for unbounded Lua recursion" {
    var result = try executeSource(std.testing.allocator,
        \\function f()
        \\  return 1 + f()
        \\end
        \\f()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack overflow") != null);
}

test "reports calls to non-functions" {
    var result = try executeSource(std.testing.allocator,
        \\local value = 1
        \\value()
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "attempt to call a number value") != null);
}

test "debug errors dump stack state before unwinding" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local x = 42
        \\error("boom", 0)
    , .{ .state = .{ .debug_errors = true } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "[zlua debug] unhandled runtime exception") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "local x r") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.stderr, "stack (") != null);
}

test "unhandled Lua errors render without zlua prefix" {
    var result = try executeSource(std.testing.allocator,
        \\error("boom", 0)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 1), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stderr, "boom\n"));
}

test "safe stdlib omits host-facing libraries" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\print(type(io), type(os), type(package), type(debug))
    , .{ .state = .{ .stdlib = .safe } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "nil\tnil\tnil\tnil\n"));
}

test "granular stdlib loads selected libraries only" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\print(type(string), type(table), string.upper("ok"))
    , .{ .state = .{ .stdlib = .{ .libraries = .{ .base = true, .string = true } } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "table\tnil\tOK\n"));
}

test "full stdlib can use memory-backed filesystem and fixed clock" {
    const files = [_]MemoryFile{
        .{ .path = "input.txt", .contents = "alpha\nbeta" },
        .{ .path = "loaded.lua", .contents = "return 'loaded'" },
    };
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file = assert(io.open("input.txt", "r"))
        \\print(file:read("*l"))
        \\print(file:read("*a"))
        \\print(assert(loadfile("loaded.lua"))())
        \\print(os.date("!%Y", 0))
    , .{ .state = .{ .filesystem = .{ .memory = &files }, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "alpha\nbeta\nloaded\n1970\n"));
}

test "disabled capabilities block filesystem and process access" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local file, err = io.open("missing.lua", "r")
        \\print(file == nil, type(err))
        \\print(pcall(os.execute, "true"))
    , .{ .state = .{ .filesystem = .disabled, .process = .disabled, .clock = .{ .fixed = 0 } } });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "true\tstring\nfalse\tprocess access disabled\n"));
}

test "runtime internal re-exports match facade" {
    const internal = @import("runtime/internal.zig");

    comptime {
        if (internal.State != State) @compileError("internal State diverged from facade");
        if (internal.StateOptions != StateOptions) @compileError("internal StateOptions diverged from facade");
        if (internal.Value != Value) @compileError("internal Value diverged from facade");
        if (internal.Table != Table) @compileError("internal Table diverged from facade");
        if (internal.Thread != Thread) @compileError("internal Thread diverged from facade");
        if (internal.GcMode != GcMode) @compileError("internal GcMode diverged from facade");
    }

    const memory_file: MemoryFile = internal.MemoryFile{ .path = "init.lua", .contents = "return 1" };
    _ = memory_file;
    const filesystem: FilesystemCapability = internal.FilesystemCapability.disabled;
    _ = filesystem;
    const clock: ClockCapability = internal.ClockCapability.system;
    _ = clock;
    const process_capability: ProcessCapability = internal.ProcessCapability.disabled;
    _ = process_capability;

    try std.testing.expect(internal.valuesEqual(Value.nil, .nil));
    var out = std.ArrayList(u8).empty;
    defer out.deinit(std.testing.allocator);
    try internal.appendValue(std.testing.allocator, &out, .{ .integer = 42 });
    try std.testing.expect(std.mem.eql(u8, out.items, "42"));

    out.clearRetainingCapacity();
    try internal.appendBinaryChunkHeader(std.testing.allocator, &out);
    try std.testing.expect(std.mem.startsWith(u8, out.items, binary_chunk_signature));
}

test "GC stress preserves live locals during execution" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local keep = { answer = 42 }
        \\local i = 1
        \\while i <= 50 do
        \\  local transient = { i, { i + 1 } }
        \\  collectgarbage("collect")
        \\  i = i + 1
        \\end
        \\collectgarbage("collect")
        \\print(keep.answer)
    , .{ .collect_after_instruction = true });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\n"));
}

test "collectgarbage runs table finalizers before sweeping" {
    var result = try executeSource(std.testing.allocator,
        \\do
        \\  local dead = setmetatable({ name = "dead" }, {
        \\    __gc = function(self)
        \\      print("gc-final", self.name)
        \\    end,
        \\  })
        \\  dead = nil
        \\end
        \\collectgarbage("collect")
        \\collectgarbage("collect")
        \\print("done")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "gc-final\tdead\ndone\n"));
}

test "string.dump reloads Lua closures" {
    var result = try executeSource(std.testing.allocator,
        \\local f = assert(load(string.dump(function() return 42 end)))
        \\local ok, message = pcall(string.dump, print)
        \\print(f(), ok, message ~= nil)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "42\tfalse\ttrue\n"));
}

test "zlua binary chunks are portable across states" {
    var dump = std.ArrayList(u8).empty;
    defer dump.deinit(std.testing.allocator);

    {
        var source_state = try State.init(std.testing.allocator);
        defer source_state.deinit();
        const loaded = try source_state.loadSourceAsClosure("return 42, 'ok'");
        try dumpClosureBinary(std.testing.allocator, &dump, loaded.closure, false);
    }

    var target_state = try State.init(std.testing.allocator);
    defer target_state.deinit();
    const loaded = try target_state.loadBinaryDump(dump.items, .nil);
    const values = try target_state.callLoadedClosure(loaded.closure, &.{});
    defer target_state.allocator.free(values);

    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expect(valuesEqual(values[0], .{ .integer = 42 }));
    try std.testing.expect(valuesEqual(values[1], .{ .string = "ok" }));
}

test "zlua binary chunks preserve nested protos and upvalue descriptors" {
    var result = try executeSource(std.testing.allocator,
        \\local source = [[
        \\  return function(seed)
        \\    local total = seed
        \\    local function add(value)
        \\      total = total + value
        \\      return total
        \\    end
        \\    return add
        \\  end
        \\]]
        \\local factory = assert(load(string.dump(assert(load(source)))))()
        \\local add = factory(10)
        \\print(add(2), add(3))
        \\local debug = require "debug"
        \\local closure = factory(1)
        \\print(debug.getupvalue(closure, 1))
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "12\t15\ntotal\t1\n"));
}

test "zlua binary chunks honor supplied load environment" {
    var dump = std.ArrayList(u8).empty;
    defer dump.deinit(std.testing.allocator);

    {
        var source_state = try State.init(std.testing.allocator);
        defer source_state.deinit();
        const loaded = try source_state.loadSourceAsClosure("return answer + ...");
        try dumpClosureBinary(std.testing.allocator, &dump, loaded.closure, false);
    }

    var target_state = try State.init(std.testing.allocator);
    defer target_state.deinit();
    const environment = try target_state.newTableWithHints(0, 1);
    try environment.table.set(target_state.allocator, .{ .string = try target_state.intern("answer") }, .{ .integer = 40 });

    const loaded = try target_state.loadBinaryDump(dump.items, environment);
    const values = try target_state.callLoadedClosure(loaded.closure, &.{.{ .integer = 2 }});
    defer target_state.allocator.free(values);

    try std.testing.expectEqual(@as(usize, 1), values.len);
    try std.testing.expect(valuesEqual(values[0], .{ .integer = 42 }));
}

test "zlua binary chunks preserve stripped debug state" {
    var result = try executeSource(std.testing.allocator,
        \\local debug = require "debug"
        \\local secret = 12
        \\local f = assert(load(string.dump(function() return secret end, true)))
        \\print(debug.getupvalue(f, 1))
        \\print(debug.getinfo(f).currentline)
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "(no name)\tnil\n-1\n"));
}

test "PUC binary chunks are rejected explicitly" {
    var chunk = std.ArrayList(u8).empty;
    defer chunk.deinit(std.testing.allocator);
    try appendBinaryChunkHeader(std.testing.allocator, &chunk);
    try chunk.appendNTimes(std.testing.allocator, 0, binary_chunk_payload_magic.len);

    var state = try State.init(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectError(error.RuntimeError, state.loadBinaryDump(chunk.items, .nil));
    const detail = try state.errorDetailAlloc(std.testing.allocator, error.RuntimeError);
    defer std.testing.allocator.free(detail);
    try std.testing.expect(std.mem.indexOf(u8, detail, "unsupported PUC Lua binary chunk") != null);
}

test "official closure upvalue edge cases" {
    var result = try executeSource(std.testing.allocator,
        \\local a = {}
        \\local i = 1
        \\repeat
        \\  local x = i
        \\  a[i] = function () i = x + 1; return x end
        \\until i > 10 or a[i]() ~= x
        \\assert(i == 11 and a[1]() == 1 and a[3]() == 3 and i == 4)
        \\
        \\a = {}
        \\for j = 1, 3 do
        \\  if j % 3 == 2 then
        \\    local t
        \\    goto make
        \\    ::assign:: a[j] = t; goto done
        \\    ::make::
        \\    local y = 2
        \\    t = function (x) local old = y; y = x; return old end
        \\    goto assign
        \\    ::done::
        \\  end
        \\end
        \\assert(a[2](20) == 2 and a[2]() == 20)
        \\
        \\local debug = require "debug"
        \\local foo1, foo2
        \\do
        \\  local x, y = 3, 5
        \\  foo1 = function () return x + y end
        \\  foo2 = function () return y + x end
        \\end
        \\assert(debug.upvalueid(foo1, 1) == debug.upvalueid(foo2, 2))
        \\debug.upvaluejoin(foo1, 2, foo2, 2)
        \\assert(foo1() == 6 and foo2() == 8)
        \\print("ok")
    );
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "ok\n"));
}
