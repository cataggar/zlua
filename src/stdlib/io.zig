const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

const max_line_args = 250;

pub fn read(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try currentFile(state, "__zlua_input");
    if (runtime.isClosedFileValue(.{ .table = file })) return state.fail(" input file is closed");
    try readFromFile(state, thread, op, file, 0);
}

pub fn write(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try currentFile(state, "__zlua_output");
    if (runtime.isClosedFileValue(.{ .table = file })) return state.fail(" output file is closed");
    try writeToFile(state, thread, op, file, 0);
}

pub fn open(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try state.expectString(runtime.argValue(state, thread, op, 0));
    const mode = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        try state.expectString(runtime.argValue(state, thread, op, 1))
    else
        "r";
    const parsed = parseMode(mode) orelse return state.fail("invalid mode");

    if (isSpecialDevice(path)) {
        try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, mode, "", parsed)});
        return;
    }
    if (path.len != 0 and path[0] == '/' and parsed.kind != 'r') return openFailure(state, thread, op, "cannot open file");

    const contents = if (parsed.reads_existing or parsed.append)
        state.readFileAlloc(path) catch |err| switch (err) {
            error.RuntimeError => if (parsed.kind == 'r') return openFailure(state, thread, op, "cannot open file") else try state.allocator.dupe(u8, ""),
            else => return err,
        }
    else
        try state.allocator.dupe(u8, "");
    defer state.allocator.free(contents);
    try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, mode, contents, parsed)});
}

pub fn input(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try setCurrentFile(state, thread, op, "__zlua_input", "r");
}

pub fn output(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try setCurrentFile(state, thread, op, "__zlua_output", "w");
}

pub fn close(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const value = if (op.arg_count == 0 or runtime.argValue(state, thread, op, 0) == .nil)
        Value{ .table = try currentFile(state, "__zlua_output") }
    else
        runtime.argValue(state, thread, op, 0);
    try closeFileValue(state, thread, op, value, false);
}

pub fn flush(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try currentFile(state, "__zlua_output");
    try flushFile(state, file);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn lines(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count > max_line_args + 1) return state.fail("too many arguments");
    var start: u16 = 0;
    const file_value = if (op.arg_count >= 1 and runtime.argValue(state, thread, op, 0) != .nil) blk: {
        start = 1;
        const path = try state.expectString(runtime.argValue(state, thread, op, 0));
        const parsed = parseMode("r").?;
        const contents = state.readFileAlloc(path) catch return state.fail("cannot open file");
        defer state.allocator.free(contents);
        break :blk try newFile(state, path, "r", contents, parsed);
    } else blk: {
        if (op.arg_count >= 1) start = 1;
        break :blk Value{ .table = try currentFile(state, "__zlua_input") };
    };
    const iterator = try newLinesIterator(state, thread, file_value, op, start, start == 1);
    if (start == 1) {
        try state.returnValues(thread, op.base, op.return_count, &.{ iterator, file_value, .nil, file_value });
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{iterator});
    }
}

pub fn tmpfile(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const path = try tmpPath(state);
    const parsed = parseMode("w+").?;
    try state.returnValues(thread, op.base, op.return_count, &.{try newFile(state, path, "w+", "", parsed)});
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = runtime.argValue(state, thread, op, 0);
    if (!runtime.isFileValue(file)) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    const name = if (runtime.isClosedFileValue(file)) "closed file" else "file";
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(name) }});
}

pub fn fileRead(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try readFromFile(state, thread, op, file, 1);
}

pub fn fileWrite(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try writeToFile(state, thread, op, file, 1);
}

pub fn fileClose(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.fail("got no value");
    if (runtime.isClosedFileValue(runtime.argValue(state, thread, op, 0))) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    try closeFileValue(state, thread, op, runtime.argValue(state, thread, op, 0), false);
}

pub fn fileSeek(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try ensureOpen(state, file);
    try refreshReadable(state, file);
    const whence = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil)
        try state.expectString(runtime.argValue(state, thread, op, 1))
    else
        "cur";
    const offset = if (op.arg_count >= 3 and runtime.argValue(state, thread, op, 2) != .nil)
        runtime.toInteger(runtime.argValue(state, thread, op, 2)) orelse return state.fail("number expected")
    else
        0;
    const content = try fileString(state, file, "__zlua_file_content");
    const base: i64 = if (std.mem.eql(u8, whence, "set"))
        0
    else if (std.mem.eql(u8, whence, "cur"))
        (fileInteger(file, "__zlua_file_pos") orelse 1) - 1
    else if (std.mem.eql(u8, whence, "end"))
        @intCast(content.len)
    else
        return state.fail("invalid whence");
    const new_pos = base + offset;
    if (new_pos < 0) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("invalid argument") }, .{ .integer = 22 } });
        return;
    }
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = new_pos + 1 });
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .integer = new_pos }});
}

pub fn fileFlush(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try ensureOpen(state, file);
    if (std.mem.eql(u8, try fileString(state, file, "__zlua_file_path"), "/dev/full")) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    try flushFile(state, file);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn fileLines(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file_value = runtime.argValue(state, thread, op, 0);
    _ = try expectFile(state, file_value);
    if (op.arg_count > max_line_args + 1) return state.fail("too many arguments");
    const iterator = try newLinesIterator(state, thread, file_value, op, 1, false);
    try state.returnValues(thread, op.base, op.return_count, &.{iterator});
}

pub fn fileSetvbuf(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const file = try expectFile(state, runtime.argValue(state, thread, op, 0));
    try ensureOpen(state, file);
    const mode = try state.expectString(runtime.argValue(state, thread, op, 1));
    if (!std.mem.eql(u8, mode, "no") and !std.mem.eql(u8, mode, "full") and !std.mem.eql(u8, mode, "line")) return state.fail("invalid mode");
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_buffer_mode") }, .{ .string = try state.intern(mode) });
    if (std.mem.eql(u8, mode, "no")) try flushFile(state, file);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

pub fn linesIter(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const values = try linesNext(state, runtime.argValue(state, thread, op, 0));
    try state.returnValues(thread, op.base, op.return_count, values);
}

pub fn linesNext(state: *State, iterator: Value) ![]const Value {
    if (iterator != .table) return state.fail("file is already closed");
    const table = iterator.table;
    const file_value = table.get(.{ .string = "file" });
    if (runtime.isClosedFileValue(file_value)) return state.fail("file is already closed");
    const file = try expectFile(state, file_value);
    const specs = table.get(.{ .string = "specs" });
    var values = std.ArrayList(Value).empty;
    errdefer values.deinit(state.allocator);
    if (specs == .table and specs.table.array.items.len != 0) {
        for (specs.table.array.items) |spec| try values.append(state.allocator, try readOne(state, file, spec));
    } else {
        try values.append(state.allocator, try readOne(state, file, .{ .string = try state.intern("l") }));
    }
    if (values.items.len == 0 or values.items[0] == .nil) {
        values.deinit(state.allocator);
        if (table.get(.{ .string = "auto_close" }) == .boolean and table.get(.{ .string = "auto_close" }).boolean) {
            try closeFile(state, file, true);
        }
        return &[_]Value{};
    }
    return try values.toOwnedSlice(state.allocator);
}

fn setCurrentFile(state: *State, thread: *Thread, op: bytecode.Call, key: []const u8, mode: []const u8) !void {
    const io_table = try state.expectTable(state.getGlobal("io"));
    if (op.arg_count == 0 or runtime.argValue(state, thread, op, 0) == .nil) {
        try state.returnValues(thread, op.base, op.return_count, &.{io_table.get(.{ .string = key })});
        return;
    }
    var value = runtime.argValue(state, thread, op, 0);
    if (value == .string) {
        const path = value.string;
        const parsed = parseMode(mode).?;
        const contents = if (parsed.kind == 'r') state.readFileAlloc(path) catch return state.fail("cannot open file") else try state.allocator.dupe(u8, "");
        defer state.allocator.free(contents);
        value = try newFile(state, path, mode, contents, parsed);
    } else {
        _ = try expectFile(state, value);
    }
    if (std.mem.eql(u8, key, "__zlua_output")) {
        const old_value = io_table.get(.{ .string = key });
        switch (old_value) {
            .table => |old_file| if (old_file.get(.{ .string = "__zlua_file_standard" }) == .nil and !runtime.isClosedFileValue(old_value)) try closeFile(state, old_file, false),
            else => {},
        }
    }
    try io_table.set(state.allocator, .{ .string = try state.intern(key) }, value);
    try state.returnValues(thread, op.base, op.return_count, &.{value});
}

fn currentFile(state: *State, key: []const u8) !*runtime.Table {
    const io_table = try state.expectTable(state.getGlobal("io"));
    return expectFile(state, io_table.get(.{ .string = key }));
}

fn readFromFile(state: *State, thread: *Thread, op: bytecode.Call, file: *runtime.Table, first_arg: u16) !void {
    try ensureOpen(state, file);
    if (!fileReadable(file)) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("file is not readable") }, .{ .integer = 9 } });
        return;
    }
    var values = std.ArrayList(Value).empty;
    defer values.deinit(state.allocator);
    if (op.arg_count <= first_arg) {
        try values.append(state.allocator, try readOne(state, file, .{ .string = try state.intern("l") }));
    } else {
        var index = first_arg;
        while (index < op.arg_count) : (index += 1) {
            const value = try readOne(state, file, runtime.argValue(state, thread, op, index));
            try values.append(state.allocator, value);
            if (value == .nil) break;
        }
    }
    try state.returnValues(thread, op.base, op.return_count, values.items);
}

fn readOne(state: *State, file: *runtime.Table, spec_value: Value) !Value {
    try ensureOpen(state, file);
    try ensureReadable(state, file);
    try refreshReadable(state, file);
    const content = try fileString(state, file, "__zlua_file_content");
    var pos = fileInteger(file, "__zlua_file_pos") orelse 1;
    if (pos < 1) pos = 1;
    const start: usize = @intCast(@min(@as(i64, @intCast(content.len)), pos - 1));

    if (runtime.toInteger(spec_value)) |count_i64| {
        if (count_i64 < 0) return state.fail("invalid format");
        const count: usize = @intCast(count_i64);
        if (count == 0) return if (start < content.len) .{ .string = try state.intern("") } else .nil;
        if (start >= content.len) return .nil;
        const end = @min(content.len, start + count);
        try setPos(state, file, end + 1);
        return .{ .string = try state.intern(content[start..end]) };
    }

    var spec = try state.expectString(spec_value);
    if (spec.len != 0 and spec[0] == '*') spec = spec[1..];
    if (std.mem.eql(u8, spec, "a") or std.mem.eql(u8, spec, "all")) {
        try setPos(state, file, content.len + 1);
        return .{ .string = try state.intern(content[start..]) };
    }
    if (std.mem.eql(u8, spec, "l") or std.mem.eql(u8, spec, "L")) {
        if (start >= content.len) return .nil;
        var end = start;
        while (end < content.len and content[end] != '\n') end += 1;
        const include_newline = std.mem.eql(u8, spec, "L") and end < content.len;
        const slice_end = if (include_newline) end + 1 else end;
        try setPos(state, file, if (end < content.len) end + 2 else end + 1);
        return .{ .string = try state.intern(content[start..slice_end]) };
    }
    if (std.mem.eql(u8, spec, "n")) return readNumber(state, file, content, start);
    return state.fail("invalid format");
}

fn readNumber(state: *State, file: *runtime.Table, content: []const u8, start: usize) !Value {
    var pos = start;
    while (pos < content.len and std.ascii.isWhitespace(content[pos])) pos += 1;
    if (pos >= content.len) {
        try setPos(state, file, pos + 1);
        return .nil;
    }
    var token_end = pos;
    while (token_end < content.len and isNumberTokenByte(content[token_end])) token_end += 1;
    if (token_end - pos > 350) {
        try setPos(state, file, @min(token_end, pos + 4) + 1);
        return .nil;
    }
    if (invalidHexPrefix(content[pos..token_end])) {
        try setPos(state, file, pos + 3);
        return .nil;
    }
    if (invalidBareExponentToken(content[pos..token_end])) {
        try setPos(state, file, token_end + 1);
        return .nil;
    }
    const scan_end = @min(token_end, pos + 512);
    var end = scan_end;
    while (end > pos) : (end -= 1) {
        const slice = content[pos..end];
        if (runtime.parseIntegerStrict(slice)) |integer| {
            try setPos(state, file, end + 1);
            return .{ .integer = integer };
        }
        if (runtime.parseLuaNumber(slice)) |number| {
            try setPos(state, file, end + 1);
            return .{ .number = number };
        } else |_| {}
    }
    const consume = failedNumberPrefix(content[pos..]);
    try setPos(state, file, pos + consume + 1);
    return .nil;
}

fn failedNumberPrefix(text: []const u8) usize {
    if (text.len >= 2 and (text[0] == '+' or text[0] == '-') and text[1] == '-') return 1;
    if (text.len >= 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) return 2;
    if (text.len != 0 and (text[0] == '.' or text[0] == '+' or text[0] == '-')) return 1;
    return 0;
}

fn isNumberTokenByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '+' or byte == '-' or byte == '.';
}

fn invalidBareExponentToken(token: []const u8) bool {
    if (token.len < 2) return false;
    const last = token[token.len - 1];
    if (last != 'e' and last != 'E') return false;
    if (std.mem.indexOfScalar(u8, token, 'p') != null or std.mem.indexOfScalar(u8, token, 'P') != null) return false;
    return std.mem.indexOfScalar(u8, token[0 .. token.len - 1], 'e') == null and
        std.mem.indexOfScalar(u8, token[0 .. token.len - 1], 'E') == null;
}

fn invalidHexPrefix(token: []const u8) bool {
    if (token.len < 3) return false;
    const unsigned = if (token[0] == '+' or token[0] == '-') token[1..] else token;
    return unsigned.len >= 3 and unsigned[0] == '0' and (unsigned[1] == 'x' or unsigned[1] == 'X') and !std.ascii.isHex(unsigned[2]);
}

fn writeToFile(state: *State, thread: *Thread, op: bytecode.Call, file: *runtime.Table, first_arg: u16) !void {
    try ensureOpen(state, file);
    if (!fileWritable(file)) {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("file is not writable") }, .{ .integer = 9 } });
        return;
    }
    var wrote_newline = false;
    var index = first_arg;
    while (index < op.arg_count) : (index += 1) {
        var bytes = std.ArrayList(u8).empty;
        defer bytes.deinit(state.allocator);
        try runtime.appendLuaString(state.allocator, &bytes, runtime.argValue(state, thread, op, index));
        if (std.mem.indexOfScalar(u8, bytes.items, '\n') != null) wrote_newline = true;
        try writeBytes(state, file, bytes.items);
    }
    const buffer_mode = try fileString(state, file, "__zlua_file_buffer_mode");
    if (std.mem.eql(u8, buffer_mode, "no") or (std.mem.eql(u8, buffer_mode, "line") and wrote_newline)) try flushFile(state, file);
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .table = file }});
}

fn writeBytes(state: *State, file: *runtime.Table, bytes: []const u8) !void {
    const path = try fileString(state, file, "__zlua_file_path");
    if (std.mem.eql(u8, path, "stdout")) {
        try state.stdout.appendSlice(state.allocator, bytes);
        return;
    }
    if (std.mem.eql(u8, path, "stderr")) {
        try state.stderr.appendSlice(state.allocator, bytes);
        return;
    }
    if (std.mem.eql(u8, path, "/dev/null") or std.mem.eql(u8, path, "/dev/full")) return;
    var content = std.ArrayList(u8).empty;
    defer content.deinit(state.allocator);
    try content.appendSlice(state.allocator, try fileString(state, file, "__zlua_file_content"));
    const mode = try fileString(state, file, "__zlua_file_mode");
    const pos: usize = if (std.mem.indexOfScalar(u8, mode, 'a') != null)
        content.items.len
    else
        @intCast(@max((fileInteger(file, "__zlua_file_pos") orelse 1) - 1, 0));
    if (pos > content.items.len) {
        const old_len = content.items.len;
        try content.resize(state.allocator, pos);
        @memset(content.items[old_len..], 0);
    }
    const end = pos + bytes.len;
    if (end > content.items.len) try content.resize(state.allocator, end);
    @memcpy(content.items[pos..end], bytes);
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern(content.items) });
    try setPos(state, file, end + 1);
}

fn closeFileValue(state: *State, thread: *Thread, op: bytecode.Call, value: Value, from_iterator: bool) !void {
    const file = try expectFile(state, value);
    if (runtime.isClosedFileValue(value)) {
        if (from_iterator) return;
        return state.fail("closed file");
    }
    if (file.get(.{ .string = "__zlua_file_standard" }) == .boolean and file.get(.{ .string = "__zlua_file_standard" }).boolean) {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
        return;
    }
    try closeFile(state, file, from_iterator);
    if (!from_iterator) try state.returnValues(thread, op.base, op.return_count, &.{.{ .boolean = true }});
}

fn closeFile(state: *State, file: *runtime.Table, from_iterator: bool) !void {
    _ = from_iterator;
    if (fileWritable(file)) try flushFile(state, file);
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_closed") }, .{ .boolean = true });
}

fn flushFile(state: *State, file: *runtime.Table) !void {
    const path = try fileString(state, file, "__zlua_file_path");
    if (std.mem.eql(u8, path, "stdout") or std.mem.eql(u8, path, "stderr") or std.mem.eql(u8, path, "/dev/null") or std.mem.eql(u8, path, "/dev/full")) return;
    if (fileWritable(file)) try state.writeFile(path, try fileString(state, file, "__zlua_file_content"));
}

fn refreshReadable(state: *State, file: *runtime.Table) !void {
    if (!fileReadable(file)) return;
    const path = try fileString(state, file, "__zlua_file_path");
    if (std.mem.eql(u8, path, "stdin") or std.mem.eql(u8, path, "stdout") or std.mem.eql(u8, path, "stderr") or isSpecialDevice(path)) return;
    const contents = state.readFileAlloc(path) catch return;
    defer state.allocator.free(contents);
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern(contents) });
}

fn newFile(state: *State, path: []const u8, mode: []const u8, contents: []const u8, parsed: ParsedMode) !Value {
    const value = try state.newTableWithHints(0, 18);
    const file = value.table;
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file") }, .{ .boolean = true });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_path") }, .{ .string = try state.intern(path) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_mode") }, .{ .string = try state.intern(mode) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_content") }, .{ .string = try state.intern(contents) });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = if (parsed.append) @as(i64, @intCast(contents.len + 1)) else 1 });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_closed") }, .{ .boolean = false });
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_buffer_mode") }, .{ .string = try state.intern("full") });
    try file.set(state.allocator, .{ .string = try state.intern("read") }, .{ .native = .io_file_read });
    try file.set(state.allocator, .{ .string = try state.intern("write") }, .{ .native = .io_file_write });
    try file.set(state.allocator, .{ .string = try state.intern("close") }, .{ .native = .io_file_close });
    try file.set(state.allocator, .{ .string = try state.intern("seek") }, .{ .native = .io_file_seek });
    try file.set(state.allocator, .{ .string = try state.intern("flush") }, .{ .native = .io_file_flush });
    try file.set(state.allocator, .{ .string = try state.intern("lines") }, .{ .native = .io_file_lines });
    try file.set(state.allocator, .{ .string = try state.intern("setvbuf") }, .{ .native = .io_file_setvbuf });
    file.metatable = try state.fileMetatable();
    return value;
}

fn newLinesIterator(state: *State, thread: *Thread, file_value: Value, op: bytecode.Call, first_arg: u16, auto_close: bool) !Value {
    const value = try state.newTableWithHints(0, 4);
    const table = value.table;
    try table.set(state.allocator, .{ .string = try state.intern("__zlua_lines_iterator") }, .{ .boolean = true });
    try table.set(state.allocator, .{ .string = try state.intern("file") }, file_value);
    try table.set(state.allocator, .{ .string = try state.intern("auto_close") }, .{ .boolean = auto_close });
    if (op.arg_count > first_arg) {
        const specs = try state.newTableWithHints(op.arg_count - first_arg, 0);
        var index = first_arg;
        while (index < op.arg_count) : (index += 1) try specs.table.set(state.allocator, .{ .integer = @intCast(index - first_arg + 1) }, runtime.argValue(state, thread, op, index));
        try table.set(state.allocator, .{ .string = try state.intern("specs") }, specs);
    }
    return .{ .gmatch_iterator = table };
}

fn openFailure(state: *State, thread: *Thread, op: bytecode.Call, message: []const u8) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) }, .{ .integer = 2 } });
}

fn expectFile(state: *State, value: Value) !*runtime.Table {
    if (!runtime.isFileValue(value)) return state.fail("file expected");
    return value.table;
}

fn ensureOpen(state: *State, file: *runtime.Table) !void {
    const closed = file.get(.{ .string = "__zlua_file_closed" });
    if (closed == .boolean and closed.boolean) return state.fail("closed file");
}

fn ensureReadable(state: *State, file: *runtime.Table) !void {
    if (!fileReadable(file)) return state.fail("file is not readable");
}

fn fileReadable(file: *runtime.Table) bool {
    const mode = file.get(.{ .string = "__zlua_file_mode" });
    if (mode != .string or mode.string.len == 0) return false;
    return mode.string[0] == 'r' or std.mem.indexOfScalar(u8, mode.string, '+') != null;
}

fn fileWritable(file: *runtime.Table) bool {
    const mode = file.get(.{ .string = "__zlua_file_mode" });
    if (mode != .string or mode.string.len == 0) return false;
    return mode.string[0] == 'w' or mode.string[0] == 'a' or std.mem.indexOfScalar(u8, mode.string, '+') != null;
}

fn fileString(state: *State, file: *runtime.Table, name: []const u8) ![]const u8 {
    return state.expectString(file.get(.{ .string = name }));
}

fn fileInteger(file: *runtime.Table, comptime name: []const u8) ?i64 {
    return runtime.toInteger(file.get(.{ .string = name }));
}

fn setPos(state: *State, file: *runtime.Table, pos: usize) !void {
    try file.set(state.allocator, .{ .string = try state.intern("__zlua_file_pos") }, .{ .integer = @intCast(pos) });
}

const ParsedMode = struct {
    kind: u8,
    append: bool,
    reads_existing: bool,
};

fn parseMode(mode: []const u8) ?ParsedMode {
    if (mode.len == 0) return null;
    const kind = mode[0];
    if (kind != 'r' and kind != 'w' and kind != 'a') return null;
    var index: usize = 1;
    if (index < mode.len and mode[index] == '+') index += 1;
    if (index < mode.len and mode[index] == 'b') index += 1;
    if (index != mode.len) return null;
    return .{ .kind = kind, .append = kind == 'a', .reads_existing = kind == 'r' };
}

fn isSpecialDevice(path: []const u8) bool {
    return std.mem.eql(u8, path, "/dev/null") or std.mem.eql(u8, path, "/dev/full");
}

fn tmpPath(state: *State) ![]const u8 {
    const timestamp = state.currentTime() catch 0;
    return std.fmt.allocPrint(state.allocator, "zlua_tmp_{d}_{d}.tmp", .{ timestamp, state.table_allocations.items.len });
}
