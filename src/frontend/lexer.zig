const std = @import("std");
const diagnostic = @import("diagnostic.zig");
const source_mod = @import("source.zig");
const token_mod = @import("token.zig");

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    index: usize = 0,
    line: usize = 1,
    column: usize = 1,
    diagnostics: std.ArrayList(diagnostic.Diagnostic) = .empty,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{ .allocator = allocator, .source = source };
    }

    pub fn deinit(self: *Lexer) void {
        self.diagnostics.deinit(self.allocator);
    }

    pub fn next(self: *Lexer) !token_mod.Token {
        try self.skipTrivia();

        const start = self.position();
        if (self.atEnd()) {
            return self.makeToken(.eof, start);
        }

        const byte = self.peek().?;
        if (isIdentifierStart(byte)) return self.identifier(start);
        if (isDigit(byte) or (byte == '.' and isDigit(self.peekN(1)))) return self.number(start);

        return switch (byte) {
            '\'', '"' => self.shortString(start),
            '[' => if (self.longBracketLevel()) |_| self.longString(start) else self.single(.left_bracket, start),
            '+' => self.single(.plus, start),
            '-' => self.single(.minus, start),
            '*' => self.single(.star, start),
            '/' => self.oneOrTwo(.slash, .double_slash, '/', start),
            '%' => self.single(.percent, start),
            '^' => self.single(.caret, start),
            '#' => self.single(.hash, start),
            '&' => self.single(.ampersand, start),
            '|' => self.single(.pipe, start),
            '~' => self.oneOrTwo(.tilde, .tilde_equal, '=', start),
            '<' => self.oneOfThree(.less, .less_equal, '=', .double_less, '<', start),
            '>' => self.oneOfThree(.greater, .greater_equal, '=', .double_greater, '>', start),
            '=' => self.oneOrTwo(.equal, .double_equal, '=', start),
            '(' => self.single(.left_paren, start),
            ')' => self.single(.right_paren, start),
            '{' => self.single(.left_brace, start),
            '}' => self.single(.right_brace, start),
            ']' => self.single(.right_bracket, start),
            ';' => self.single(.semicolon, start),
            ':' => self.oneOrTwo(.colon, .double_colon, ':', start),
            ',' => self.single(.comma, start),
            '.' => self.dots(start),
            else => self.fail(.unexpected_character, start, self.positionAfterOne(), "unexpected character"),
        };
    }

    fn skipTrivia(self: *Lexer) !void {
        while (!self.atEnd()) {
            const byte = self.peek().?;
            if (isWhitespace(byte)) {
                _ = self.advance();
                continue;
            }

            if (byte == '-' and self.peekN(1) == '-') {
                _ = self.advance();
                _ = self.advance();
                if (self.longBracketLevel()) |_| {
                    try self.consumeLongBracket(self.position());
                } else {
                    while (!self.atEnd() and !isNewline(self.peek().?)) _ = self.advance();
                }
                continue;
            }

            break;
        }
    }

    fn identifier(self: *Lexer, start: source_mod.Position) token_mod.Token {
        while (!self.atEnd() and isIdentifierContinue(self.peek().?)) _ = self.advance();
        const lexeme = self.source[start.offset..self.index];
        return .{
            .tag = token_mod.keywordTag(lexeme) orelse .identifier,
            .lexeme = lexeme,
            .span = .{ .start = start, .end = self.position() },
        };
    }

    fn number(self: *Lexer, start: source_mod.Position) !token_mod.Token {
        var tag: token_mod.Tag = .integer_literal;
        var malformed = false;

        if (self.peek() == '.') {
            tag = .float_literal;
            _ = self.advance();
            self.consumeDigits();
            malformed = !(try self.consumeDecimalExponentIfPresent());
        } else if (self.peek() == '0' and (self.peekN(1) == 'x' or self.peekN(1) == 'X')) {
            _ = self.advance();
            _ = self.advance();
            const before_dot = self.consumeHexDigits();
            var after_dot: usize = 0;
            if (self.peek() == '.' and self.peekN(1) != '.') {
                tag = .float_literal;
                _ = self.advance();
                after_dot = self.consumeHexDigits();
            }
            if (before_dot + after_dot == 0) malformed = true;
            if (self.peek() == 'p' or self.peek() == 'P') {
                tag = .float_literal;
                malformed = !(try self.consumeHexExponent());
            }
        } else {
            self.consumeDigits();
            if (self.peek() == '.' and self.peekN(1) != '.') {
                tag = .float_literal;
                _ = self.advance();
                self.consumeDigits();
            }
            if (self.peek() == 'e' or self.peek() == 'E') {
                tag = .float_literal;
                malformed = !(try self.consumeDecimalExponentIfPresent());
            }
        }

        while (!self.atEnd() and (isIdentifierContinue(self.peek().?) or (self.peek().? == '.' and self.peekN(1) != '.'))) {
            malformed = true;
            _ = self.advance();
        }

        if (malformed) return self.fail(.malformed_number, start, self.position(), "malformed number");
        return .{ .tag = tag, .lexeme = self.source[start.offset..self.index], .span = .{ .start = start, .end = self.position() } };
    }

    fn consumeDecimalExponentIfPresent(self: *Lexer) !bool {
        if (!(self.peek() == 'e' or self.peek() == 'E')) return true;
        _ = self.advance();
        if (self.peek() == '+' or self.peek() == '-') _ = self.advance();
        if (!isDigit(self.peek())) return false;
        self.consumeDigits();
        return true;
    }

    fn consumeHexExponent(self: *Lexer) !bool {
        _ = self.advance();
        if (self.peek() == '+' or self.peek() == '-') _ = self.advance();
        if (!isHexDigit(self.peek())) return false;
        _ = self.consumeHexDigits();
        return true;
    }

    fn consumeDigits(self: *Lexer) void {
        while (isDigit(self.peek())) _ = self.advance();
    }

    fn consumeHexDigits(self: *Lexer) usize {
        var count: usize = 0;
        while (isHexDigit(self.peek())) : (count += 1) _ = self.advance();
        return count;
    }

    fn shortString(self: *Lexer, start: source_mod.Position) !token_mod.Token {
        const quote = self.advance().?;
        while (!self.atEnd()) {
            const byte = self.peek().?;
            if (byte == quote) {
                _ = self.advance();
                return .{ .tag = .string_literal, .lexeme = self.source[start.offset..self.index], .span = .{ .start = start, .end = self.position() } };
            }
            if (isNewline(byte)) return self.fail(.unfinished_string, start, self.position(), "unfinished string");
            if (byte == '\\') {
                try self.escape(start);
            } else {
                _ = self.advance();
            }
        }
        return self.fail(.unfinished_string, start, self.position(), "unfinished string");
    }

    fn escape(self: *Lexer, start: source_mod.Position) !void {
        _ = self.advance();
        const escaped = self.peek() orelse return self.failVoid(.unfinished_string, start, self.position(), "unfinished string");
        switch (escaped) {
            'a', 'b', 'f', 'n', 'r', 't', 'v', '\\', '"', '\'' => _ = self.advance(),
            '\n', '\r' => _ = self.advance(),
            'z' => {
                _ = self.advance();
                while (isWhitespace(self.peek())) _ = self.advance();
            },
            'x' => {
                _ = self.advance();
                if (!isHexDigit(self.peek())) return self.failVoid(.invalid_escape, start, self.position(), "invalid hexadecimal escape");
                _ = self.advance();
                if (!isHexDigit(self.peek())) return self.failVoid(.invalid_escape, start, self.position(), "invalid hexadecimal escape");
                _ = self.advance();
            },
            'u' => try self.unicodeEscape(start),
            '0'...'9' => try self.decimalEscape(start),
            else => return self.failVoid(.invalid_escape, start, self.positionAfterOne(), "invalid escape sequence"),
        }
    }

    fn unicodeEscape(self: *Lexer, start: source_mod.Position) !void {
        _ = self.advance();
        if (self.peek() != '{') return self.failVoid(.invalid_escape, start, self.position(), "invalid unicode escape");
        _ = self.advance();
        var count: usize = 0;
        var value: u32 = 0;
        while (isHexDigit(self.peek())) {
            const digit = hexValue(self.advance().?);
            value = appendUnicodeEscapeDigit(value, digit);
            count += 1;
        }
        if (count == 0 or self.peek() != '}' or value > max_lua_utf8_codepoint) return self.failVoid(.invalid_escape, start, self.position(), "invalid unicode escape");
        _ = self.advance();
    }

    fn decimalEscape(self: *Lexer, start: source_mod.Position) !void {
        var value: u32 = 0;
        var count: usize = 0;
        while (count < 3 and isDigit(self.peek())) : (count += 1) {
            value = value * 10 + @as(u32, self.advance().? - '0');
        }
        if (value > 255) return self.failVoid(.invalid_escape, start, self.position(), "decimal escape too large");
    }

    fn longString(self: *Lexer, start: source_mod.Position) !token_mod.Token {
        try self.consumeLongBracket(start);
        return .{ .tag = .string_literal, .lexeme = self.source[start.offset..self.index], .span = .{ .start = start, .end = self.position() } };
    }

    fn consumeLongBracket(self: *Lexer, start: source_mod.Position) !void {
        const level = self.longBracketLevel().?;
        _ = self.advance();
        for (0..level) |_| _ = self.advance();
        _ = self.advance();

        if (isNewline(self.peek())) _ = self.advance();

        while (!self.atEnd()) {
            if (self.peek() == ']' and self.closingLongBracketMatches(level)) {
                _ = self.advance();
                for (0..level) |_| _ = self.advance();
                _ = self.advance();
                return;
            }
            _ = self.advance();
        }
        return self.failVoid(.unfinished_long_bracket, start, self.position(), "unfinished long bracket");
    }

    fn longBracketLevel(self: *Lexer) ?usize {
        if (self.peek() != '[') return null;
        var cursor = self.index + 1;
        while (cursor < self.source.len and self.source[cursor] == '=') cursor += 1;
        if (cursor < self.source.len and self.source[cursor] == '[') return cursor - self.index - 1;
        return null;
    }

    fn closingLongBracketMatches(self: *Lexer, level: usize) bool {
        if (self.peek() != ']') return false;
        var cursor = self.index + 1;
        var equals: usize = 0;
        while (cursor < self.source.len and self.source[cursor] == '=') : (cursor += 1) equals += 1;
        return equals == level and cursor < self.source.len and self.source[cursor] == ']';
    }

    fn single(self: *Lexer, tag: token_mod.Tag, start: source_mod.Position) token_mod.Token {
        _ = self.advance();
        return self.makeToken(tag, start);
    }

    fn oneOrTwo(self: *Lexer, one: token_mod.Tag, two: token_mod.Tag, second: u8, start: source_mod.Position) token_mod.Token {
        _ = self.advance();
        if (self.peek() == second) {
            _ = self.advance();
            return self.makeToken(two, start);
        }
        return self.makeToken(one, start);
    }

    fn oneOfThree(self: *Lexer, one: token_mod.Tag, two_a: token_mod.Tag, byte_a: u8, two_b: token_mod.Tag, byte_b: u8, start: source_mod.Position) token_mod.Token {
        _ = self.advance();
        if (self.peek() == byte_a) {
            _ = self.advance();
            return self.makeToken(two_a, start);
        }
        if (self.peek() == byte_b) {
            _ = self.advance();
            return self.makeToken(two_b, start);
        }
        return self.makeToken(one, start);
    }

    fn dots(self: *Lexer, start: source_mod.Position) token_mod.Token {
        _ = self.advance();
        if (self.peek() == '.') {
            _ = self.advance();
            if (self.peek() == '.') {
                _ = self.advance();
                return self.makeToken(.ellipsis, start);
            }
            return self.makeToken(.double_dot, start);
        }
        return self.makeToken(.dot, start);
    }

    fn makeToken(self: *Lexer, tag: token_mod.Tag, start: source_mod.Position) token_mod.Token {
        return .{ .tag = tag, .lexeme = self.source[start.offset..self.index], .span = .{ .start = start, .end = self.position() } };
    }

    fn fail(self: *Lexer, code: diagnostic.Code, start: source_mod.Position, end: source_mod.Position, message: []const u8) !token_mod.Token {
        try self.addDiagnostic(code, start, end, message);
        return error.LexError;
    }

    fn failVoid(self: *Lexer, code: diagnostic.Code, start: source_mod.Position, end: source_mod.Position, message: []const u8) !void {
        try self.addDiagnostic(code, start, end, message);
        return error.LexError;
    }

    fn addDiagnostic(self: *Lexer, code: diagnostic.Code, start: source_mod.Position, end: source_mod.Position, message: []const u8) !void {
        try self.diagnostics.append(self.allocator, .{ .code = code, .span = .{ .start = start, .end = end }, .message = message });
    }

    fn position(self: Lexer) source_mod.Position {
        return .{ .offset = self.index, .line = self.line, .column = self.column };
    }

    fn positionAfterOne(self: Lexer) source_mod.Position {
        var pos = self.position();
        pos.offset += 1;
        pos.column += 1;
        return pos;
    }

    fn advance(self: *Lexer) ?u8 {
        if (self.atEnd()) return null;
        const byte = self.source[self.index];
        self.index += 1;
        if (byte == '\n' or byte == '\r') {
            if ((byte == '\r' and self.peek() == '\n') or (byte == '\n' and self.peek() == '\r')) self.index += 1;
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
        return byte;
    }

    fn peek(self: Lexer) ?u8 {
        if (self.index >= self.source.len) return null;
        return self.source[self.index];
    }

    fn peekN(self: Lexer, n: usize) ?u8 {
        const offset = self.index + n;
        if (offset >= self.source.len) return null;
        return self.source[offset];
    }

    fn atEnd(self: Lexer) bool {
        return self.index >= self.source.len;
    }
};

pub fn lex(allocator: std.mem.Allocator, source: []const u8) ![]token_mod.Token {
    var lexer = Lexer.init(allocator, source);
    defer lexer.deinit();
    var tokens = std.ArrayList(token_mod.Token).empty;
    errdefer tokens.deinit(allocator);
    while (true) {
        const tok = try lexer.next();
        try tokens.append(allocator, tok);
        if (tok.tag == .eof) break;
    }
    return tokens.toOwnedSlice(allocator);
}

fn isWhitespace(byte: ?u8) bool {
    const value = byte orelse return false;
    return value == ' ' or value == '\t' or value == '\n' or value == '\r' or value == 0x0b or value == 0x0c;
}

fn isNewline(byte: ?u8) bool {
    const value = byte orelse return false;
    return value == '\n' or value == '\r';
}

fn isDigit(byte: ?u8) bool {
    const value = byte orelse return false;
    return value >= '0' and value <= '9';
}

fn isHexDigit(byte: ?u8) bool {
    const value = byte orelse return false;
    return isDigit(value) or (value >= 'a' and value <= 'f') or (value >= 'A' and value <= 'F');
}

fn hexValue(byte: u8) u32 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => 10 + byte - 'a',
        'A'...'F' => 10 + byte - 'A',
        else => unreachable,
    };
}

fn isIdentifierStart(byte: u8) bool {
    return byte == '_' or (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z');
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or isDigit(byte);
}

const max_lua_utf8_codepoint: u32 = 0x7fffffff;

fn appendUnicodeEscapeDigit(value: u32, digit: u32) u32 {
    if (value > max_lua_utf8_codepoint / 16) return max_lua_utf8_codepoint + 1;
    const next = value * 16 + digit;
    if (next > max_lua_utf8_codepoint) return max_lua_utf8_codepoint + 1;
    return next;
}

fn expectTags(source: []const u8, expected: []const token_mod.Tag) !void {
    const tokens = try lex(std.testing.allocator, source);
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(expected.len + 1, tokens.len);
    for (expected, 0..) |tag, index| try std.testing.expectEqual(tag, tokens[index].tag);
    try std.testing.expectEqual(token_mod.Tag.eof, tokens[tokens.len - 1].tag);
}

test "lexes identifiers keywords and punctuation" {
    try expectTags("local globalx = andromeda + 1", &.{ .keyword_local, .identifier, .equal, .identifier, .plus, .integer_literal });
    try expectTags("and break do else elseif end false for function global goto if in local nil not or repeat return then true until while", &.{
        .keyword_and,
        .keyword_break,
        .keyword_do,
        .keyword_else,
        .keyword_elseif,
        .keyword_end,
        .keyword_false,
        .keyword_for,
        .keyword_function,
        .keyword_global,
        .keyword_goto,
        .keyword_if,
        .keyword_in,
        .keyword_local,
        .keyword_nil,
        .keyword_not,
        .keyword_or,
        .keyword_repeat,
        .keyword_return,
        .keyword_then,
        .keyword_true,
        .keyword_until,
        .keyword_while,
    });
    try expectTags("// ~= == <= >= << >> :: ... .. .", &.{ .double_slash, .tilde_equal, .double_equal, .less_equal, .greater_equal, .double_less, .double_greater, .double_colon, .ellipsis, .double_dot, .dot });
}

test "tracks source spans" {
    const tokens = try lex(std.testing.allocator, "\n  local x");
    defer std.testing.allocator.free(tokens);
    try std.testing.expectEqual(@as(usize, 2), tokens[0].span.start.line);
    try std.testing.expectEqual(@as(usize, 3), tokens[0].span.start.column);
    try std.testing.expectEqual(@as(usize, 2), tokens[1].span.start.line);
    try std.testing.expectEqual(@as(usize, 9), tokens[1].span.start.column);
}

test "lexes decimal and hexadecimal numerals" {
    try expectTags("0 123 1.25 .5 1e-3 0xff 0x1p4 0x1.8p+2", &.{
        .integer_literal,
        .integer_literal,
        .float_literal,
        .float_literal,
        .float_literal,
        .integer_literal,
        .float_literal,
        .float_literal,
    });
}

test "rejects malformed numerals" {
    const cases = [_][]const u8{ "1e+", "0x", "123abc", "0x1p" };
    for (cases) |case| {
        var lexer = Lexer.init(std.testing.allocator, case);
        defer lexer.deinit();
        try std.testing.expectError(error.LexError, lexer.next());
        try std.testing.expectEqual(diagnostic.Code.malformed_number, lexer.diagnostics.items[0].code);
    }
}

test "lexes short strings and escape sequences" {
    try expectTags("'a' \"b\" '\\n' '\\x41' '\\255' '\\u{7fffffff}' '\\z  \n  x'", &.{
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
        .string_literal,
    });
}

test "rejects invalid strings" {
    const cases = [_][]const u8{ "'unterminated", "'bad\\q'", "'bad\\x4g'", "'bad\\300'" };
    for (cases) |case| {
        var lexer = Lexer.init(std.testing.allocator, case);
        defer lexer.deinit();
        try std.testing.expectError(error.LexError, lexer.next());
    }
}

test "lexes long strings and comments" {
    try expectTags("-- short\n--[=[ long ]=]\n[==[text]=] still string?]==]", &.{.string_literal});
}

test "rejects unfinished long brackets" {
    var lexer = Lexer.init(std.testing.allocator, "[=[unfinished");
    defer lexer.deinit();
    try std.testing.expectError(error.LexError, lexer.next());
    try std.testing.expectEqual(diagnostic.Code.unfinished_long_bracket, lexer.diagnostics.items[0].code);
}
