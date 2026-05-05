const std = @import("std");

pub const source = @import("frontend/source.zig");
pub const diagnostic = @import("frontend/diagnostic.zig");
pub const token = @import("frontend/token.zig");
pub const lexer = @import("frontend/lexer.zig");

pub const Lexer = lexer.Lexer;
pub const Token = token.Token;
pub const TokenTag = token.Tag;

pub fn lex(allocator: std.mem.Allocator, source_text: []const u8) ![]Token {
    return lexer.lex(allocator, source_text);
}

test {
    _ = source;
    _ = diagnostic;
    _ = token;
    _ = lexer;
}
