const std = @import("std");
const runtime = @import("../runtime.zig");
const internal = @import("internal.zig");

const State = runtime.State;
const Value = runtime.Value;
const MemoryFile = runtime.MemoryFile;
const FilesystemCapability = runtime.FilesystemCapability;
const ClockCapability = runtime.ClockCapability;
const ProcessCapability = runtime.ProcessCapability;
const binary_chunk_signature = runtime.binary_chunk_signature;
const binary_chunk_payload_magic = runtime.binary_chunk_payload_magic;
const executeSource = runtime.executeSource;
const executeSourceWithOptions = runtime.executeSourceWithOptions;
const valuesEqual = runtime.valuesEqual;
const appendBinaryChunkHeader = runtime.appendBinaryChunkHeader;
const dumpClosureBinary = runtime.dumpClosureBinary;

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
    comptime {
        if (internal.State != State) @compileError("internal State diverged from facade");
        if (internal.StateOptions != runtime.StateOptions) @compileError("internal StateOptions diverged from facade");
        if (internal.Value != Value) @compileError("internal Value diverged from facade");
        if (internal.Table != runtime.Table) @compileError("internal Table diverged from facade");
        if (internal.Thread != runtime.Thread) @compileError("internal Thread diverged from facade");
        if (internal.GcMode != runtime.GcMode) @compileError("internal GcMode diverged from facade");
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

test "GC stress during table mutation closure allocation and string interning" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\local roots = { entries = {} }
        \\local marker = "literal-anchor"
        \\for i = 1, 30 do
        \\  local key = assert(load("return 'interned-" .. i .. "'"))()
        \\  roots.entries[key] = { value = i }
        \\  roots.entries[i] = function(delta)
        \\    return key, roots.entries[key].value + delta, marker
        \\  end
        \\  collectgarbage("collect")
        \\  local got_key, total, got_marker = roots.entries[i](2)
        \\  assert(got_key == key and total == i + 2 and got_marker == marker)
        \\end
        \\collectgarbage("collect")
        \\print(roots.entries["interned-30"].value, roots.entries[30](12))
    , .{ .collect_after_instruction = true });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u8, 0), result.exit_code);
    try std.testing.expect(std.mem.eql(u8, result.stdout, "30\tinterned-30\t42\tliteral-anchor\n"));
}

test "GC stress during binary dumping and bytecode loading" {
    var result = try executeSourceWithOptions(std.testing.allocator,
        \\answer = 37
        \\local dumped = string.dump(assert(load("return function(delta) return answer + delta end"))())
        \\collectgarbage("collect")
        \\local loaded = assert(load(dumped, "dumped", "b", _ENV))
        \\collectgarbage("collect")
        \\answer = 40
        \\print(loaded(2))
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

test "last Lua error value is a GC root" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const object = try state.newTableWithHints(0, 1);
    try object.table.set(state.allocator, .{ .string = try state.intern("tag") }, .{ .string = try state.intern("live") });
    try std.testing.expectEqual(error.RuntimeError, state.failValue(object));

    try state.collectGarbage();

    const error_value = state.currentErrorValue();
    try std.testing.expect(error_value == .table);
    try std.testing.expect(error_value.table == object.table);
    try std.testing.expect(state.isTrackedTable(object.table));
    try std.testing.expect(valuesEqual(error_value.table.get(.{ .string = "tag" }), .{ .string = "live" }));
}

test "collects unreachable runtime allocations" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const before = state.allocationStats();
    _ = try state.intern("transient-gc-string");
    _ = try state.newTableWithHints(4, 4);

    try state.collectGarbage();

    const after = state.allocationStats();
    try std.testing.expect(after.strings >= before.strings);
    try std.testing.expectEqual(before.tables, after.tables);
    try std.testing.expectEqual(before.closures, after.closures);
    try std.testing.expectEqual(before.upvalues, after.upvalues);
    try std.testing.expectEqual(before.threads, after.threads);
}

test "keeps global table graph alive during collection" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const root = try state.newTableWithHints(0, 1);
    const child = try state.newTableWithHints(0, 1);
    const key = try state.intern("child");
    try child.table.set(state.allocator, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try root.table.set(state.allocator, .{ .string = key }, child);
    try state.globals.put(try state.intern("gc_root"), root);

    try state.collectGarbage();

    const kept_root = state.globals.get("gc_root") orelse Value.nil;
    try std.testing.expect(kept_root == .table);
    const kept_child = kept_root.table.get(.{ .string = key });
    try std.testing.expect(kept_child == .table);
    try std.testing.expect(valuesEqual(kept_child.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}

test "weak value tables clear unreachable values" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try metatable.table.set(state.allocator, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("v") });
    state.setTableMetatableRaw(weak.table, metatable.table);
    try state.globals.put(try state.intern("weak_values"), weak);

    const dead = try state.newTableWithHints(0, 0);
    try weak.table.set(state.allocator, .{ .string = try state.intern("item") }, dead);

    try state.collectGarbage();

    try std.testing.expect(weak.table.get(.{ .string = "item" }) == .nil);
}

test "weak key tables clear unreachable keys" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const weak = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try metatable.table.set(state.allocator, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    state.setTableMetatableRaw(weak.table, metatable.table);
    try state.globals.put(try state.intern("weak_keys"), weak);

    const dead_key = try state.newTableWithHints(0, 0);
    try weak.table.set(state.allocator, dead_key, .{ .integer = 1 });

    try state.collectGarbage();

    try std.testing.expectEqual(@as(usize, 0), weak.table.entries.items.len);
}

test "ephemeron table marks value when key is reachable" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    const ephemeron = try state.newTableWithHints(0, 1);
    const metatable = try state.newTableWithHints(0, 1);
    try metatable.table.set(state.allocator, .{ .string = try state.intern("__mode") }, .{ .string = try state.intern("k") });
    state.setTableMetatableRaw(ephemeron.table, metatable.table);
    try state.globals.put(try state.intern("ephemeron"), ephemeron);

    const key = try state.newTableWithHints(0, 0);
    const value = try state.newTableWithHints(0, 1);
    try value.table.set(state.allocator, .{ .string = try state.intern("answer") }, .{ .integer = 42 });
    try ephemeron.table.set(state.allocator, key, value);
    try state.globals.put(try state.intern("live_key"), key);

    try state.collectGarbage();

    const kept_value = ephemeron.table.get(key);
    try std.testing.expect(kept_value == .table);
    try std.testing.expect(valuesEqual(kept_value.table.get(.{ .string = "answer" }), .{ .integer = 42 }));
}
