const std = @import("std");
const builtin = @import("builtin");
const zlua = @import("zlua");

var heap_buffer: [4 * 1024 * 1024]u8 align(16) = undefined;

export fn _start() noreturn {
    run() catch exit(1);
    exit(0);
}

fn run() !void {
    var fixed = std.heap.FixedBufferAllocator.init(&heap_buffer);
    var host = Host{
        .filesystem = zlua.MemoryFilesystem.init(fixed.allocator()),
    };
    defer host.filesystem.deinit();
    try host.filesystem.writeFile("boot/init.lua", "return 'booted'");
    try host.filesystem.writeFile("mod.lua", "return { answer = 42 }");

    var lua = try zlua.State.init(fixed.allocator(), .{
        .stdlib = .full,
        .capabilities = .{
            .io = .{ .stdin = "kernel input\n" },
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
        .limits = .{ .max_instructions = 200_000 },
    });
    defer lua.deinit();

    try lua.doString(
        \\assert(_VERSION == 'Lua 5.5')
        \\assert(io ~= nil and os ~= nil and package ~= nil and debug ~= nil)
        \\
        \\local t = { 3, 1, 2 }
        \\table.sort(t)
        \\assert(table.concat(t, ',') == '1,2,3')
        \\assert(string.reverse('abc') == 'cba')
        \\assert(string.pack('>I2', 0x1234) == string.char(0x12, 0x34))
        \\assert(math.max(1, 5, 3) == 5)
        \\assert(utf8.len('hello') == 5)
        \\
        \\local co = coroutine.create(function(x)
        \\  coroutine.yield(x + 1)
        \\  return x + 2
        \\end)
        \\local ok, value = coroutine.resume(co, 40)
        \\assert(ok and value == 41)
        \\ok, value = coroutine.resume(co, 40)
        \\assert(ok and value == 42)
        \\
        \\local json_value = json.read('{"name":"Ada","nums":[1,null]}')
        \\assert(json_value.name == 'Ada' and json_value.nums[2] == json.null)
        \\assert(json.write({ ok = true }):find('"ok":true') ~= nil)
        \\local toml_value = toml.read('name = "Ada"\nok = true\n')
        \\assert(toml_value.name == 'Ada' and toml_value.ok == true)
        \\local csv_value = csv.read('name,age\nAda,37\nBob,\n')
        \\assert(csv_value[1].name == 'Ada' and csv_value[2].age == csv.null)
        \\local msgpack_value = msgpack.read(msgpack.write({ name = 'Ada', ok = true }))
        \\assert(msgpack_value.name == 'Ada' and msgpack_value.ok == true)
        \\
        \\assert(os.getenv('KERNEL_ENV') == 'present')
        \\assert(os.time() == 123456)
        \\local ok, why, code = os.execute('true')
        \\assert(ok == true and why == 'exit' and code == 0)
        \\ok, why, code = os.execute('false')
        \\assert(ok == nil and why == 'exit' and code == 7)
        \\
        \\assert(dofile('boot/init.lua') == 'booted')
        \\local loaded = assert(loadfile('boot/init.lua'))
        \\assert(loaded() == 'booted')
        \\assert(require('mod').answer == 42)
        \\local input = io.read('l')
        \\assert(input == 'kernel input')
        \\local f = assert(io.open('tmp.txt', 'w'))
        \\assert(f:write('hello from kernel fs'))
        \\assert(f:close())
        \\f = assert(io.open('tmp.txt', 'r'))
        \\assert(f:read('a') == 'hello from kernel fs')
        \\assert(f:close())
        \\assert(os.rename('tmp.txt', 'renamed.txt'))
        \\assert(assert(io.open('renamed.txt', 'r')):read('a') == 'hello from kernel fs')
        \\assert(os.remove('renamed.txt'))
    , .{ .name = "=freestanding-custom-host-profile" });
}

const Host = struct {
    filesystem: zlua.MemoryFilesystem,

    fn fromContext(context: ?*anyopaque) *Host {
        return @ptrCast(@alignCast(context.?));
    }

    fn readFileAlloc(context: ?*anyopaque, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        return fromContext(context).filesystem.readFileAlloc(allocator, path);
    }

    fn writeFile(context: ?*anyopaque, path: []const u8, contents: []const u8) !void {
        try fromContext(context).filesystem.writeFile(path, contents);
    }

    fn removeFile(context: ?*anyopaque, path: []const u8) !void {
        try fromContext(context).filesystem.removeFile(path);
    }

    fn renameFile(context: ?*anyopaque, old_path: []const u8, new_path: []const u8) !void {
        try fromContext(context).filesystem.renameFile(old_path, new_path);
    }

    fn getenv(context: ?*anyopaque, name: []const u8) ?[]const u8 {
        _ = context;
        if (std.mem.eql(u8, name, "KERNEL_ENV")) return "present";
        return null;
    }

    fn now(context: ?*anyopaque) !i64 {
        _ = context;
        return 123456;
    }

    fn execute(context: ?*anyopaque, command: []const u8) !zlua.ProcessResult {
        _ = context;
        if (std.mem.eql(u8, command, "true")) return .{ .status = .exit, .code = 0 };
        if (std.mem.eql(u8, command, "false")) return .{ .status = .exit, .code = 7 };
        return .{ .status = .signal, .code = 0 };
    }
};

fn exit(code: u8) noreturn {
    if (comptime builtin.target.cpu.arch != .x86_64) @compileError("freestanding smoke test uses x86_64 Linux syscall ABI");

    asm volatile ("syscall"
        :
        : [number] "{rax}" (@as(u64, 60)),
          [arg1] "{rdi}" (@as(u64, code)),
        : .{ .rcx = true, .r11 = true, .memory = true });
    unreachable;
}

fn panicExit() noreturn {
    exit(255);
}

pub const panic = struct {
    pub fn call(msg: []const u8, ra: ?usize) noreturn {
        _ = msg;
        _ = ra;
        panicExit();
    }

    pub fn sentinelMismatch(expected: anytype, found: @TypeOf(expected)) noreturn {
        _ = found;
        panicExit();
    }

    pub fn unwrapError(err: anyerror) noreturn {
        _ = &err;
        panicExit();
    }

    pub fn outOfBounds(index: usize, len: usize) noreturn {
        _ = index;
        _ = len;
        panicExit();
    }

    pub fn startGreaterThanEnd(start: usize, end: usize) noreturn {
        _ = start;
        _ = end;
        panicExit();
    }

    pub fn inactiveUnionField(active: anytype, accessed: @TypeOf(active)) noreturn {
        _ = accessed;
        panicExit();
    }

    pub fn sliceCastLenRemainder(src_len: usize) noreturn {
        _ = src_len;
        panicExit();
    }

    pub fn reachedUnreachable() noreturn {
        panicExit();
    }

    pub fn unwrapNull() noreturn {
        panicExit();
    }

    pub fn castToNull() noreturn {
        panicExit();
    }

    pub fn incorrectAlignment() noreturn {
        panicExit();
    }

    pub fn invalidErrorCode() noreturn {
        panicExit();
    }

    pub fn integerOutOfBounds() noreturn {
        panicExit();
    }

    pub fn integerOverflow() noreturn {
        panicExit();
    }

    pub fn shlOverflow() noreturn {
        panicExit();
    }

    pub fn shrOverflow() noreturn {
        panicExit();
    }

    pub fn divideByZero() noreturn {
        panicExit();
    }

    pub fn exactDivisionRemainder() noreturn {
        panicExit();
    }

    pub fn integerPartOutOfBounds() noreturn {
        panicExit();
    }

    pub fn corruptSwitch() noreturn {
        panicExit();
    }

    pub fn shiftRhsTooBig() noreturn {
        panicExit();
    }

    pub fn invalidEnumValue() noreturn {
        panicExit();
    }

    pub fn forLenMismatch() noreturn {
        panicExit();
    }

    pub fn copyLenMismatch() noreturn {
        panicExit();
    }

    pub fn memcpyAlias() noreturn {
        panicExit();
    }

    pub fn noreturnReturned() noreturn {
        panicExit();
    }
};
