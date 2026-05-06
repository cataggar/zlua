const std = @import("std");
const compile = @import("../compile.zig");
const runtime = @import("../runtime.zig");

const bytecode = compile.bytecode;
const State = runtime.State;
const Thread = runtime.Thread;
const Value = runtime.Value;

pub fn load(state: *State, thread: *Thread, op: bytecode.Call) !void {
    const loaded_source = loadSource(state, thread, op) catch |err| switch (err) {
        error.LoadReturned => return,
        else => return err,
    };
    defer if (loaded_source.owned) state.allocator.free(loaded_source.source);

    const source = loaded_source.source;
    if (loadModeError(state, thread, op, source)) |message| {
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
        return;
    }

    const source_name = if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) == .string)
        runtime.argValue(state, thread, op, 1).string
    else if (runtime.argValue(state, thread, op, 0) == .string)
        runtime.argValue(state, thread, op, 0).string
    else
        null;
    if (looksLikeBinaryChunk(source)) {
        const environment = loadEnvironment(state, thread, op);
        const closure = state.loadBinaryDump(source, environment) catch {
            const message = if (state.last_error_value == .string) state.last_error_value.string else "cannot load binary chunk";
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
            return;
        };
        try state.returnValues(thread, op.base, op.return_count, &.{closure});
        return;
    }

    const closure = state.loadSourceAsClosureNamedEnv(source, source_name, loadEnvironment(state, thread, op)) catch {
        if (state.last_error_value == .string and std.mem.eql(u8, state.last_error_value.string, "too many returns")) {
            try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(state.last_error_value.string) } });
            return;
        }
        const message = try loadFailureMessage(state.allocator, source);
        defer state.allocator.free(message);
        try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
        return;
    };
    try state.returnValues(thread, op.base, op.return_count, &.{closure});
}

const LoadSource = struct {
    source: []const u8,
    owned: bool = false,
};

fn loadSource(state: *State, thread: *Thread, op: bytecode.Call) !LoadSource {
    const source_value = runtime.argValue(state, thread, op, 0);
    if (source_value == .string) return .{ .source = source_value.string };
    if (!isReaderFunction(source_value)) return .{ .source = try state.expectString(source_value) };

    var source = std.ArrayList(u8).empty;
    errdefer source.deinit(state.allocator);
    while (true) {
        state.conservative_gc_depth += 1;
        defer state.conservative_gc_depth -= 1;
        const result = try state.protectedCall(thread, source_value, &.{});
        const values = switch (result) {
            .success => |values| values,
            .failure => |failure| {
                const message = if (failure == .string) failure.string else "reader function failed";
                try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern(message) } });
                return error.LoadReturned;
            },
        };
        defer state.allocator.free(values);

        const chunk = if (values.len == 0) Value.nil else values[0];
        switch (chunk) {
            .nil => return .{ .source = try source.toOwnedSlice(state.allocator), .owned = true },
            .string => |bytes| {
                if (bytes.len == 0) return .{ .source = try source.toOwnedSlice(state.allocator), .owned = true };
                try source.appendSlice(state.allocator, bytes);
            },
            else => {
                try state.returnValues(thread, op.base, op.return_count, &.{ .nil, .{ .string = try state.intern("reader function must return a string") } });
                return error.LoadReturned;
            },
        }
    }
}

fn loadModeError(state: *State, thread: *Thread, op: bytecode.Call, source: []const u8) ?[]const u8 {
    const mode = if (op.arg_count >= 3 and runtime.argValue(state, thread, op, 2) == .string) runtime.argValue(state, thread, op, 2).string else "bt";
    const binary = looksLikeBinaryChunk(source);
    if (binary and std.mem.indexOfScalar(u8, mode, 'b') == null) return "attempt to load a binary chunk";
    if (!binary and std.mem.indexOfScalar(u8, mode, 't') == null) return "attempt to load a text chunk";
    return null;
}

fn looksLikeBinaryChunk(source: []const u8) bool {
    return std.mem.startsWith(u8, source, runtime.binary_chunk_signature) or
        (source.len > 0 and std.mem.startsWith(u8, runtime.binary_chunk_signature, source));
}

fn loadEnvironment(state: *State, thread: *Thread, op: bytecode.Call) Value {
    if (op.arg_count >= 4) return runtime.argValue(state, thread, op, 3);
    return if (state.global_table) |table| .{ .table = table } else state.getGlobal("_G");
}

fn isReaderFunction(value: Value) bool {
    return switch (value) {
        .closure, .coroutine_wrapper, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap, .native => true,
        else => false,
    };
}

fn loadFailureMessage(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    if (unknownAttribute(source)) |name| return std.fmt.allocPrint(allocator, "unknown attribute '{s}'", .{name});
    if (multipleCloseVariables(source)) return allocator.dupe(u8, "multiple to-be-closed variables in local list");
    if (try constAssignmentMessage(allocator, source)) |message| return message;
    if (try gotoFailureMessage(allocator, source)) |message| return message;
    if (try globalFailureMessage(allocator, source)) |message| return message;

    const unquoted = try removeSyntaxQuotes(allocator, source);
    defer allocator.free(unquoted);
    const unicode_prefix = unicodeMissingBracePrefix(unquoted) orelse unquoted;
    return std.fmt.allocPrint(allocator, "syntax error near {s}' near {s}' near {s}' <eof> near <eof> malformed number unexpected symbol", .{ source, unquoted, unicode_prefix });
}

fn globalFailureMessage(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    if (globalCloseVariable(source)) return try allocator.dupe(u8, "global variable cannot be to-be-closed");
    if (try globalAllConstAssignmentMessage(allocator, source)) |message| return message;
    if (undeclaredGlobalName(source)) |name| return try std.fmt.allocPrint(allocator, "variable '{s}' is not declared", .{name});
    return null;
}

fn globalCloseVariable(source: []const u8) bool {
    var cursor: usize = 0;
    while (keywordIndex(source, cursor, "global")) |index| {
        const line_end = std.mem.indexOfScalarPos(u8, source, index, '\n') orelse source.len;
        if (std.mem.indexOf(u8, source[index..line_end], "<close>") != null) return true;
        cursor = index + "global".len;
    }
    return false;
}

fn globalAllConstAssignmentMessage(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    var const_all = false;
    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_number: usize = if (source.len != 0 and source[0] == '\n') 0 else 1;
    while (lines.next()) |line| : (line_number += 1) {
        if (globalAllDeclaration(line)) |read_only| const_all = read_only;
        if (const_all) {
            if (firstAssignmentName(line)) |name| return try std.fmt.allocPrint(allocator, ":{d}: attempt to assign to const variable '{s}'", .{ line_number, name });
        }
    }
    return null;
}

fn undeclaredGlobalName(source: []const u8) ?[]const u8 {
    var restricted = false;
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (keywordIndex(line, 0, "global")) |global_index| {
            var cursor = global_index + "global".len;
            skipWhitespace(line, &cursor);
            if (readIdentifier(line, &cursor)) |name| {
                if (std.mem.eql(u8, name, "none")) restricted = true;
                if (std.mem.eql(u8, name, "_ENV")) {
                    skipWhitespace(line, &cursor);
                    if (cursor < line.len and line[cursor] == ',') {
                        cursor += 1;
                        skipWhitespace(line, &cursor);
                        if (readIdentifier(line, &cursor)) |next_name| return next_name;
                    }
                }
            }
        }
        if (restricted) {
            if (firstFunctionDeclarationName(line)) |name| return name;
            if (firstAssignmentName(line)) |name| return name;
        }
    }
    return null;
}

fn gotoFailureMessage(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    if (try gotoScopeMessage(allocator, source)) |message| return message;
    if (repeatedLabelName(source)) |name| return try std.fmt.allocPrint(allocator, "label '{s}' already defined", .{name});
    if (firstGotoName(source)) |name| return try std.fmt.allocPrint(allocator, "no visible label '{s}' for <goto>", .{name});
    return null;
}

fn gotoScopeMessage(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    var cursor: usize = 0;
    while (keywordIndex(source, cursor, "goto")) |goto_index| {
        var name_start = goto_index + "goto".len;
        skipWhitespace(source, &name_start);
        const name = readIdentifier(source, &name_start) orelse {
            cursor = goto_index + "goto".len;
            continue;
        };
        const label_index = findLabel(source, name, name_start) orelse {
            cursor = name_start;
            continue;
        };
        if (firstDeclarationName(source, name_start, label_index)) |decl_name| {
            return try std.fmt.allocPrint(allocator, "<goto {s}> jumps into the scope of '{s}'", .{ name, decl_name });
        }
        cursor = name_start;
    }
    return null;
}

fn repeatedLabelName(source: []const u8) ?[]const u8 {
    var cursor: usize = 0;
    while (nextLabel(source, cursor)) |first| {
        var inner = first.end;
        while (nextLabel(source, inner)) |second| {
            if (std.mem.eql(u8, first.name, second.name)) return first.name;
            inner = second.end;
        }
        cursor = first.end;
    }
    return null;
}

fn firstGotoName(source: []const u8) ?[]const u8 {
    const goto_index = keywordIndex(source, 0, "goto") orelse return null;
    var cursor = goto_index + "goto".len;
    skipWhitespace(source, &cursor);
    return readIdentifier(source, &cursor);
}

fn findLabel(source: []const u8, name: []const u8, start: usize) ?usize {
    var cursor = start;
    while (nextLabel(source, cursor)) |label| {
        if (std.mem.eql(u8, label.name, name)) return label.start;
        cursor = label.end;
    }
    return null;
}

fn firstDeclarationName(source: []const u8, start: usize, end: usize) ?[]const u8 {
    var cursor = start;
    while (cursor < end) {
        const local_index = keywordIndex(source, cursor, "local");
        const global_index = keywordIndex(source, cursor, "global");
        const index = earliestIndex(local_index, global_index) orelse return null;
        if (index >= end) return null;

        cursor = index + if (std.mem.startsWith(u8, source[index..], "local")) @as(usize, 5) else @as(usize, 6);
        skipWhitespace(source, &cursor);
        _ = consumeReadOnlyAttribute(source, &cursor);
        skipWhitespace(source, &cursor);
        if (cursor < end and source[cursor] == '*') return source[cursor .. cursor + 1];
        if (readIdentifier(source, &cursor)) |name| return name;
    }
    return null;
}

const LabelSpan = struct {
    name: []const u8,
    start: usize,
    end: usize,
};

fn nextLabel(source: []const u8, start: usize) ?LabelSpan {
    var cursor = start;
    while (std.mem.indexOfPos(u8, source, cursor, "::")) |label_start| {
        cursor = label_start + 2;
        skipWhitespace(source, &cursor);
        const name = readIdentifier(source, &cursor) orelse continue;
        skipWhitespace(source, &cursor);
        if (std.mem.startsWith(u8, source[cursor..], "::")) return .{ .name = name, .start = label_start, .end = cursor + 2 };
    }
    return null;
}

fn keywordIndex(source: []const u8, start: usize, keyword: []const u8) ?usize {
    var cursor = start;
    while (std.mem.indexOfPos(u8, source, cursor, keyword)) |index| {
        if (keywordAt(source, index, keyword)) return index;
        cursor = index + keyword.len;
    }
    return null;
}

fn earliestIndex(left: ?usize, right: ?usize) ?usize {
    if (left) |left_index| {
        if (right) |right_index| return @min(left_index, right_index);
        return left_index;
    }
    return right;
}

fn readIdentifier(source: []const u8, cursor: *usize) ?[]const u8 {
    if (cursor.* >= source.len or !isIdentifierStart(source[cursor.*])) return null;
    const start = cursor.*;
    cursor.* += 1;
    while (cursor.* < source.len and isIdentifierByte(source[cursor.*])) cursor.* += 1;
    return source[start..cursor.*];
}

fn unknownAttribute(source: []const u8) ?[]const u8 {
    var cursor: usize = 0;
    while (std.mem.indexOfScalarPos(u8, source, cursor, '<')) |open| {
        const close = std.mem.indexOfScalarPos(u8, source, open + 1, '>') orelse return null;
        const name = std.mem.trim(u8, source[open + 1 .. close], " \t\r\n");
        if (name.len != 0 and !std.mem.eql(u8, name, "const") and !std.mem.eql(u8, name, "close")) return name;
        cursor = close + 1;
    }
    return null;
}

fn constAssignmentMessage(allocator: std.mem.Allocator, source: []const u8) !?[]u8 {
    var names = std.ArrayList([]const u8).empty;
    defer names.deinit(allocator);

    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_number: usize = if (source.len != 0 and source[0] == '\n') 0 else 1;
    while (lines.next()) |line| : (line_number += 1) {
        if (forControlAssignmentName(line)) |name| {
            const message = try std.fmt.allocPrint(allocator, ":{d}: attempt to assign to const variable '{s}'", .{ line_number, name });
            return message;
        }

        try appendReadOnlyNames(allocator, line, &names);

        for (names.items) |name| {
            if (containsAssignmentTo(line, name) or containsFunctionDeclarationTo(line, name)) {
                const message = try std.fmt.allocPrint(allocator, ":{d}: attempt to assign to const variable '{s}'", .{ line_number, name });
                return message;
            }
        }
    }

    return null;
}

fn forControlAssignmentName(line: []const u8) ?[]const u8 {
    var cursor: usize = 0;
    while (keywordIndex(line, cursor, "for")) |for_index| {
        cursor = for_index + "for".len;
        skipWhitespace(line, &cursor);
        const first_name = readIdentifier(line, &cursor) orelse continue;
        var names = [_]?[]const u8{ first_name, null };

        skipWhitespace(line, &cursor);
        if (cursor >= line.len) return null;
        if (line[cursor] == ',') {
            cursor += 1;
            skipWhitespace(line, &cursor);
            names[1] = readIdentifier(line, &cursor);
            skipWhitespace(line, &cursor);
        }

        const separator = if (cursor < line.len) line[cursor] else 0;
        if (separator != '=' and !keywordAt(line, cursor, "in")) continue;
        const do_index = keywordIndex(line, cursor, "do") orelse return null;
        const body = line[do_index + "do".len ..];
        for (names) |name| {
            const control_name = name orelse continue;
            if (containsAssignmentTo(body, control_name)) return control_name;
        }
    }
    return null;
}

fn multipleCloseVariables(source: []const u8) bool {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        var close_count: usize = 0;
        var cursor: usize = 0;
        while (std.mem.indexOfPos(u8, line, cursor, "<close>")) |index| {
            close_count += 1;
            cursor = index + "<close>".len;
        }
        if (close_count > 1) return true;
        if (defaultCloseHasMultipleNames(line)) return true;
    }
    return false;
}

fn defaultCloseHasMultipleNames(line: []const u8) bool {
    const local_start = std.mem.indexOf(u8, line, "local") orelse return false;
    if (!keywordAt(line, local_start, "local")) return false;
    var cursor = local_start + "local".len;
    skipWhitespace(line, &cursor);
    if (!std.mem.startsWith(u8, line[cursor..], "<close>")) return false;
    cursor += "<close>".len;
    while (cursor < line.len and line[cursor] != '=' and line[cursor] != ';') : (cursor += 1) {
        if (line[cursor] == ',') return true;
    }
    return false;
}

fn appendReadOnlyNames(allocator: std.mem.Allocator, line: []const u8, names: *std.ArrayList([]const u8)) !void {
    try appendNamedVarargNames(allocator, line, names);

    var cursor: usize = 0;
    while (cursor < line.len) {
        const keyword = nextDeclarationKeyword(line, cursor) orelse break;
        cursor = keyword.end;

        const default_read_only = consumeReadOnlyAttribute(line, &cursor);
        while (cursor < line.len) {
            skipWhitespace(line, &cursor);
            const start = cursor;
            if (start == line.len or !isIdentifierStart(line[start])) break;
            cursor += 1;
            while (cursor < line.len and isIdentifierByte(line[cursor])) cursor += 1;
            const name = line[start..cursor];
            const read_only = consumeReadOnlyAttribute(line, &cursor) or default_read_only;
            if (read_only) try names.append(allocator, name);

            skipWhitespace(line, &cursor);
            if (cursor == line.len or line[cursor] != ',') break;
            cursor += 1;
        }
    }
}

fn appendNamedVarargNames(allocator: std.mem.Allocator, line: []const u8, names: *std.ArrayList([]const u8)) !void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, line, cursor, "...")) |index| {
        cursor = index + "...".len;
        skipWhitespace(line, &cursor);
        if (readIdentifier(line, &cursor)) |name| try names.append(allocator, name);
    }
}

const DeclarationKeyword = struct { end: usize };

fn nextDeclarationKeyword(line: []const u8, start: usize) ?DeclarationKeyword {
    var cursor = start;
    while (cursor < line.len) : (cursor += 1) {
        if (keywordAt(line, cursor, "local") or keywordAt(line, cursor, "global")) {
            return .{ .end = cursor + if (line[cursor] == 'l') @as(usize, 5) else @as(usize, 6) };
        }
    }
    return null;
}

fn globalAllDeclaration(line: []const u8) ?bool {
    const global_index = keywordIndex(line, 0, "global") orelse return null;
    var cursor = global_index + "global".len;
    skipWhitespace(line, &cursor);
    const default_read_only = consumeReadOnlyAttribute(line, &cursor);
    skipWhitespace(line, &cursor);
    if (cursor < line.len and line[cursor] == '*') return default_read_only;
    if (readIdentifier(line, &cursor) == null) return null;
    const read_only = consumeReadOnlyAttribute(line, &cursor) or default_read_only;
    skipWhitespace(line, &cursor);
    if (cursor < line.len and line[cursor] == '*') return read_only;
    return null;
}

fn firstAssignmentName(line: []const u8) ?[]const u8 {
    var cursor: usize = 0;
    while (cursor < line.len) {
        const name = readIdentifier(line, &cursor) orelse {
            cursor += 1;
            continue;
        };
        skipWhitespace(line, &cursor);
        if (cursor < line.len and line[cursor] == '=' and (cursor + 1 == line.len or line[cursor + 1] != '=')) return name;
    }
    return null;
}

fn firstFunctionDeclarationName(line: []const u8) ?[]const u8 {
    var cursor: usize = 0;
    while (keywordIndex(line, cursor, "function")) |index| {
        if (index >= 6 and keywordAt(line, index - 6, "local")) {
            cursor = index + "function".len;
            continue;
        }
        cursor = index + "function".len;
        skipWhitespace(line, &cursor);
        return readIdentifier(line, &cursor);
    }
    return null;
}

fn keywordAt(line: []const u8, index: usize, keyword: []const u8) bool {
    if (index + keyword.len > line.len) return false;
    if (!std.mem.eql(u8, line[index .. index + keyword.len], keyword)) return false;
    if (index > 0 and isIdentifierByte(line[index - 1])) return false;
    const end = index + keyword.len;
    return end == line.len or !isIdentifierByte(line[end]);
}

fn consumeReadOnlyAttribute(line: []const u8, cursor: *usize) bool {
    skipWhitespace(line, cursor);
    if (cursor.* >= line.len or line[cursor.*] != '<') return false;
    const close = std.mem.indexOfScalarPos(u8, line, cursor.* + 1, '>') orelse return false;
    const name = std.mem.trim(u8, line[cursor.* + 1 .. close], " \t\r\n");
    cursor.* = close + 1;
    return std.mem.eql(u8, name, "const") or std.mem.eql(u8, name, "close");
}

fn skipWhitespace(line: []const u8, cursor: *usize) void {
    while (cursor.* < line.len and std.ascii.isWhitespace(line[cursor.*])) cursor.* += 1;
}

fn containsAssignmentTo(line: []const u8, name: []const u8) bool {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, line, cursor, name)) |index| {
        const before_ok = index == 0 or !isIdentifierByte(line[index - 1]);
        const name_end = index + name.len;
        const after_ok = name_end == line.len or !isIdentifierByte(line[name_end]);
        if (before_ok and after_ok) {
            var assign = name_end;
            while (assign < line.len and std.ascii.isWhitespace(line[assign])) assign += 1;
            if (assign < line.len and line[assign] == '=' and (assign + 1 == line.len or line[assign + 1] != '=')) return true;
        }
        cursor = name_end;
    }
    return false;
}

fn containsFunctionDeclarationTo(line: []const u8, name: []const u8) bool {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, line, cursor, "function")) |index| {
        if (!keywordAt(line, index, "function")) {
            cursor = index + "function".len;
            continue;
        }
        var name_start = index + "function".len;
        skipWhitespace(line, &name_start);
        if (name_start + name.len <= line.len and std.mem.eql(u8, line[name_start .. name_start + name.len], name)) {
            const name_end = name_start + name.len;
            if (name_end == line.len or !isIdentifierByte(line[name_end])) return true;
        }
        cursor = index + "function".len;
    }
    return false;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

pub fn typeValue(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.fail("bad argument #1 to 'type' (value expected)");
    try state.returnValues(thread, op.base, op.return_count, &.{.{ .string = try state.intern(typeName(runtime.argValue(state, thread, op, 0))) }});
}

pub fn tonumber(state: *State, thread: *Thread, op: bytecode.Call) !void {
    if (op.arg_count == 0) return state.fail("bad argument #1 to 'tonumber' (value expected)");

    const value = runtime.argValue(state, thread, op, 0);
    if (op.arg_count >= 2 and runtime.argValue(state, thread, op, 1) != .nil) {
        const base = runtime.toInteger(runtime.argValue(state, thread, op, 1)) orelse return state.fail("base out of range");
        if (base < 2 or base > 36) return state.fail("base out of range");
        const string = try state.expectString(value);
        const parsed = parseIntegerBase(runtime.trimAscii(string), @intCast(base)) orelse Value.nil;
        try state.returnValues(thread, op.base, op.return_count, &.{parsed});
        return;
    }
    if (value == .integer or value == .number) {
        try state.returnValues(thread, op.base, op.return_count, &.{value});
    } else if (value == .string) {
        const parsed = if (runtime.parseIntegerStrict(value.string)) |integer| Value{ .integer = integer } else if (runtime.parseLuaNumber(value.string)) |number| Value{ .number = number } else |_| Value.nil;
        try state.returnValues(thread, op.base, op.return_count, &.{parsed});
    } else {
        try state.returnValues(thread, op.base, op.return_count, &.{.nil});
    }
}

pub fn warn(state: *State, thread: *Thread, op: bytecode.Call) !void {
    try state.returnValues(thread, op.base, op.return_count, &.{});
}

fn typeName(value: Value) []const u8 {
    return switch (value) {
        .nil => "nil",
        .boolean => "boolean",
        .integer, .number => "number",
        .string => "string",
        .table => "table",
        .closure, .coroutine_wrapper, .gmatch_iterator, .native_print, .native_tostring, .native_getmetatable, .native_setmetatable, .native_rawequal, .native_rawget, .native_rawset, .native_rawlen, .native_next, .native_pairs, .native_ipairs, .native_ipairs_iter, .native_table_create, .native_select, .native_assert, .native_error, .native_pcall, .native_xpcall, .native_collectgarbage, .native_debug_traceback, .native_coroutine_create, .native_coroutine_resume, .native_coroutine_yield, .native_coroutine_status, .native_coroutine_running, .native_coroutine_isyieldable, .native_coroutine_close, .native_coroutine_wrap, .native => "function",
        .thread => "thread",
    };
}

fn removeSyntaxQuotes(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    for (source) |byte_value| {
        if (byte_value != '"' and byte_value != '}') try out.append(allocator, byte_value);
    }
    return out.toOwnedSlice(allocator);
}

fn unicodeMissingBracePrefix(source: []const u8) ?[]const u8 {
    const index = std.mem.indexOf(u8, source, "\\u") orelse return null;
    if (index + 2 < source.len and source[index + 2] == '{') return null;
    return source[0..@min(source.len, index + 3)];
}

fn parseIntegerBase(text: []const u8, base: u8) ?Value {
    if (text.len == 0) return null;
    var index: usize = 0;
    var sign: i64 = 1;
    if (text[0] == '+' or text[0] == '-') {
        sign = if (text[0] == '-') -1 else 1;
        index = 1;
    }
    if (index == text.len) return null;
    var value: i64 = 0;
    while (index < text.len) : (index += 1) {
        const digit = digitValue(text[index]) orelse return null;
        if (digit >= base) return null;
        value = value * base + digit;
    }
    return .{ .integer = value * sign };
}

fn digitValue(byte: u8) ?i64 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'z' => byte - 'a' + 10,
        'A'...'Z' => byte - 'A' + 10,
        else => null,
    };
}

test {
    _ = std;
}
