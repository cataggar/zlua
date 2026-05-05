const std = @import("std");

pub const source = @import("frontend/source.zig");
pub const diagnostic = @import("frontend/diagnostic.zig");
pub const token = @import("frontend/token.zig");
pub const lexer = @import("frontend/lexer.zig");
pub const ast = @import("frontend/ast.zig");
pub const parser = @import("frontend/parser.zig");

pub const Lexer = lexer.Lexer;
pub const Token = token.Token;
pub const TokenTag = token.Tag;
pub const Ast = ast.Ast;

pub fn lex(allocator: std.mem.Allocator, source_text: []const u8) ![]Token {
    return lexer.lex(allocator, source_text);
}

pub fn parse(allocator: std.mem.Allocator, source_text: []const u8) !Ast {
    return parser.parse(allocator, source_text);
}

test {
    _ = source;
    _ = diagnostic;
    _ = token;
    _ = lexer;
    _ = ast;
    _ = parser;
}
