const source = @import("source.zig");

pub const Code = enum {
    unexpected_character,
    unfinished_string,
    invalid_escape,
    malformed_number,
    unfinished_long_bracket,
};

pub const Diagnostic = struct {
    code: Code,
    span: source.Span,
    message: []const u8,
};
