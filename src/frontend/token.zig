const source = @import("source.zig");

pub const Tag = enum {
    eof,
    identifier,
    integer_literal,
    float_literal,
    string_literal,

    keyword_and,
    keyword_break,
    keyword_do,
    keyword_else,
    keyword_elseif,
    keyword_end,
    keyword_false,
    keyword_for,
    keyword_function,
    keyword_global,
    keyword_goto,
    keyword_if,
    keyword_in,
    keyword_local,
    keyword_nil,
    keyword_not,
    keyword_or,
    keyword_repeat,
    keyword_return,
    keyword_then,
    keyword_true,
    keyword_until,
    keyword_while,

    plus,
    minus,
    star,
    slash,
    double_slash,
    percent,
    caret,
    hash,
    ampersand,
    pipe,
    tilde,
    double_less,
    double_greater,
    double_equal,
    tilde_equal,
    less,
    less_equal,
    greater,
    greater_equal,
    equal,
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    left_bracket,
    right_bracket,
    semicolon,
    colon,
    double_colon,
    comma,
    dot,
    double_dot,
    ellipsis,
};

pub const Token = struct {
    tag: Tag,
    lexeme: []const u8,
    span: source.Span,
};

pub fn keywordTag(identifier: []const u8) ?Tag {
    if (identifier.len == 0) return null;
    return switch (identifier[0]) {
        'a' => if (eql(identifier, "and")) .keyword_and else null,
        'b' => if (eql(identifier, "break")) .keyword_break else null,
        'd' => if (eql(identifier, "do")) .keyword_do else null,
        'e' => if (eql(identifier, "else")) .keyword_else else if (eql(identifier, "elseif")) .keyword_elseif else if (eql(identifier, "end")) .keyword_end else null,
        'f' => if (eql(identifier, "false")) .keyword_false else if (eql(identifier, "for")) .keyword_for else if (eql(identifier, "function")) .keyword_function else null,
        'g' => if (eql(identifier, "global")) .keyword_global else if (eql(identifier, "goto")) .keyword_goto else null,
        'i' => if (eql(identifier, "if")) .keyword_if else if (eql(identifier, "in")) .keyword_in else null,
        'l' => if (eql(identifier, "local")) .keyword_local else null,
        'n' => if (eql(identifier, "nil")) .keyword_nil else if (eql(identifier, "not")) .keyword_not else null,
        'o' => if (eql(identifier, "or")) .keyword_or else null,
        'r' => if (eql(identifier, "repeat")) .keyword_repeat else if (eql(identifier, "return")) .keyword_return else null,
        't' => if (eql(identifier, "then")) .keyword_then else if (eql(identifier, "true")) .keyword_true else null,
        'u' => if (eql(identifier, "until")) .keyword_until else null,
        'w' => if (eql(identifier, "while")) .keyword_while else null,
        else => null,
    };
}

fn eql(lhs: []const u8, rhs: []const u8) bool {
    if (lhs.len != rhs.len) return false;
    for (lhs, rhs) |a, b| {
        if (a != b) return false;
    }
    return true;
}
