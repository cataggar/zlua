const std = @import("std");
const source = @import("frontend/source.zig");
const token_mod = @import("frontend/token.zig");

pub const ZluaError = union(enum) {
    diagnostic: Diagnostic,
    host: HostError,
};

pub const HostError = union(enum) {
    out_of_memory,
    io,
    internal_bug,
};

pub const Diagnostic = union(enum) {
    syntax: SyntaxError,
    resolve: ResolveError,
    compile: CompileError,
};

pub const SyntaxError = union(enum) {
    unexpected: UnexpectedSyntax,
    expected_close: ExpectedClose,
};

pub const TokenRef = struct {
    tag: token_mod.Tag,
    lexeme: []const u8,
    span: source.Span,
    unquoted: bool = false,
};

pub const UnexpectedSyntax = struct {
    token: TokenRef,
    message: SyntaxMessage = .syntax_error,
};

pub const SyntaxMessage = enum {
    syntax_error,
    unexpected_symbol,
    malformed_number,
    unfinished_string,
    invalid_escape,
    unfinished_long_bracket,
};

pub const ExpectedClose = struct {
    expected: []const u8,
    opener: []const u8,
    opener_line: usize,
    near: TokenRef,
};

pub const ResolveError = union(enum) {
    duplicate_label: struct { name: []const u8, span: source.Span, previous_line: usize },
    missing_label: struct { name: []const u8, span: source.Span },
    goto_into_scope: struct { label: []const u8, decl: []const u8, span: source.Span },
    break_outside_loop: source.Span,
    assign_const: struct { name: []const u8, span: source.Span },
    undeclared_global: struct { name: []const u8, span: source.Span },
    invalid_close: struct { span: source.Span, global: bool = false, multiple: bool = false },
    unknown_attribute: struct { name: []const u8, span: source.Span },
    invalid_assignment_target: source.Span,
    invalid_environment: source.Span,
};

pub const CompileError = union(enum) {
    too_many_returns: source.Span,
    register_overflow: struct { line: usize },
    too_many_local_variables: struct { line: usize },
    too_many_upvalues: struct { line: usize },
    jump_out_of_range: struct { line: usize },
    invalid_ast: struct { line: usize },
};

pub fn tokenRef(token: token_mod.Token) TokenRef {
    return .{ .tag = token.tag, .lexeme = token.lexeme, .span = token.span };
}

pub fn eofToken(source_text: []const u8, line: usize, column: usize) TokenRef {
    const pos: source.Position = .{ .offset = source_text.len, .line = line, .column = column };
    return .{ .tag = .eof, .lexeme = "", .span = .{ .start = pos, .end = pos }, .unquoted = true };
}

pub fn renderLoadDiagnostic(
    allocator: std.mem.Allocator,
    source_name: ?[]const u8,
    source_text: []const u8,
    diagnostic: Diagnostic,
) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);

    const display = try sourceDisplay(allocator, source_name, source_text);
    defer allocator.free(display);

    const line = diagnosticLine(diagnostic);
    try out.appendSlice(allocator, display);
    try appendFmt(allocator, &out, ":{d}: ", .{line});
    try appendDiagnosticDetail(allocator, &out, diagnostic);
    return out.toOwnedSlice(allocator);
}

fn appendDiagnosticDetail(allocator: std.mem.Allocator, out: *std.ArrayList(u8), diagnostic: Diagnostic) !void {
    switch (diagnostic) {
        .syntax => |syntax| switch (syntax) {
            .unexpected => |unexpected| {
                try out.appendSlice(allocator, syntaxMessageText(unexpected.message));
                try out.appendSlice(allocator, " near ");
                try appendNearToken(allocator, out, unexpected.token);
            },
            .expected_close => |expected| {
                try appendFmt(allocator, out, "'{s}' expected (to close '{s}' at line {d}) near ", .{ expected.expected, expected.opener, expected.opener_line });
                try appendNearToken(allocator, out, expected.near);
            },
        },
        .resolve => |resolve| switch (resolve) {
            .duplicate_label => |err| try appendFmt(allocator, out, "label '{s}' already defined at line {d}", .{ err.name, err.previous_line }),
            .missing_label => |err| try appendFmt(allocator, out, "no visible label '{s}' for <goto> at line {d}", .{ err.name, err.span.start.line }),
            .goto_into_scope => |err| try appendFmt(allocator, out, "<goto {s}> jumps into the scope of local '{s}'", .{ err.label, err.decl }),
            .break_outside_loop => try out.appendSlice(allocator, "break outside loop"),
            .assign_const => |err| try appendFmt(allocator, out, "attempt to assign to const variable '{s}'", .{err.name}),
            .undeclared_global => |err| try appendFmt(allocator, out, "variable '{s}' is not declared", .{err.name}),
            .invalid_close => |err| if (err.global)
                try out.appendSlice(allocator, "global variable cannot be to-be-closed")
            else if (err.multiple)
                try out.appendSlice(allocator, "multiple to-be-closed variables in local list")
            else
                try out.appendSlice(allocator, "invalid to-be-closed variable"),
            .unknown_attribute => |err| try appendFmt(allocator, out, "unknown attribute '{s}'", .{err.name}),
            .invalid_assignment_target => try out.appendSlice(allocator, "syntax error"),
            .invalid_environment => try out.appendSlice(allocator, "variable '_ENV' is not declared"),
        },
        .compile => |compile| switch (compile) {
            .too_many_returns => try out.appendSlice(allocator, "too many returns"),
            .register_overflow => try out.appendSlice(allocator, "too many registers"),
            .too_many_local_variables => try out.appendSlice(allocator, "too many local variables"),
            .too_many_upvalues => try out.appendSlice(allocator, "too many upvalues"),
            .jump_out_of_range => try out.appendSlice(allocator, "control structure too long"),
            .invalid_ast => try out.appendSlice(allocator, "internal compiler error"),
        },
    }
}

fn diagnosticLine(diagnostic: Diagnostic) usize {
    return switch (diagnostic) {
        .syntax => |syntax| switch (syntax) {
            .unexpected => |unexpected| unexpected.token.span.start.line,
            .expected_close => |expected| expected.near.span.start.line,
        },
        .resolve => |resolve| switch (resolve) {
            .duplicate_label => |err| err.span.start.line,
            .missing_label => |err| err.span.start.line,
            .goto_into_scope => |err| err.span.start.line,
            .break_outside_loop => |span| span.start.line,
            .assign_const => |err| err.span.start.line,
            .undeclared_global => |err| err.span.start.line,
            .invalid_close => |err| err.span.start.line,
            .unknown_attribute => |err| err.span.start.line,
            .invalid_assignment_target => |span| span.start.line,
            .invalid_environment => |span| span.start.line,
        },
        .compile => |compile| switch (compile) {
            .too_many_returns => |span| span.start.line,
            .register_overflow => |err| err.line,
            .too_many_local_variables => |err| err.line,
            .too_many_upvalues => |err| err.line,
            .jump_out_of_range => |err| err.line,
            .invalid_ast => |err| err.line,
        },
    };
}

fn syntaxMessageText(message: SyntaxMessage) []const u8 {
    return switch (message) {
        .syntax_error => "syntax error",
        .unexpected_symbol => "unexpected symbol",
        .malformed_number => "malformed number",
        .unfinished_string => "unfinished string",
        .invalid_escape => "invalid escape sequence",
        .unfinished_long_bracket => "unfinished long string",
    };
}

fn appendNearToken(allocator: std.mem.Allocator, out: *std.ArrayList(u8), token: TokenRef) !void {
    if (token.unquoted or token.tag == .eof) {
        if (token.unquoted and token.lexeme.len == 1) {
            try appendFmt(allocator, out, "<\\{d}>", .{token.lexeme[0]});
        } else {
            try out.appendSlice(allocator, tokenText(token));
        }
        return;
    }
    try out.append(allocator, '\'');
    try out.appendSlice(allocator, tokenText(token));
    try out.append(allocator, '\'');
}

fn tokenText(token: TokenRef) []const u8 {
    if (token.tag == .eof) return "<eof>";
    if (token.lexeme.len == 0) return "<eof>";
    return token.lexeme;
}

fn sourceDisplay(allocator: std.mem.Allocator, source_name: ?[]const u8, source_text: []const u8) ![]u8 {
    const name = source_name orelse source_text;
    if (name.len > 0 and name[0] == '=') return trimSourceId(allocator, name[1..]);
    if (name.len > 0 and name[0] == '@') return trimSourceId(allocator, name[1..]);
    return stringSourceDisplay(allocator, name);
}

fn trimSourceId(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    if (name.len <= lua_id_size - 1) return allocator.dupe(u8, name);
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, "...");
    try out.appendSlice(allocator, name[name.len - (lua_id_size - 4) ..]);
    return out.toOwnedSlice(allocator);
}

fn stringSourceDisplay(allocator: std.mem.Allocator, source_text: []const u8) ![]u8 {
    const first_line_end = std.mem.indexOfAny(u8, source_text, "\r\n") orelse source_text.len;
    const line = source_text[0..first_line_end];
    const prefix = "[string \"";
    const suffix = "\"]";
    const max_preview = lua_id_size - 1 - prefix.len - suffix.len;
    const preview = if (line.len <= max_preview) line else line[0 .. max_preview - 3];

    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, prefix);
    try appendEscapedPreview(allocator, &out, preview);
    if (line.len > max_preview) try out.appendSlice(allocator, "...");
    try out.appendSlice(allocator, suffix);
    return out.toOwnedSlice(allocator);
}

fn appendEscapedPreview(allocator: std.mem.Allocator, out: *std.ArrayList(u8), text: []const u8) !void {
    for (text) |byte| {
        switch (byte) {
            '"' => try out.appendSlice(allocator, "\\\""),
            '\\' => try out.appendSlice(allocator, "\\\\"),
            else => try out.append(allocator, byte),
        }
    }
}

fn appendFmt(allocator: std.mem.Allocator, out: *std.ArrayList(u8), comptime fmt: []const u8, args: anytype) !void {
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try out.appendSlice(allocator, text);
}

const lua_id_size: usize = 60;
