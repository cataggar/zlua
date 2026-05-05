const std = @import("std");

pub const Position = struct {
    offset: usize = 0,
    line: usize = 1,
    column: usize = 1,
};

pub const Span = struct {
    start: Position,
    end: Position,

    pub fn slice(self: Span, source: []const u8) []const u8 {
        std.debug.assert(self.start.offset <= self.end.offset);
        std.debug.assert(self.end.offset <= source.len);
        return source[self.start.offset..self.end.offset];
    }
};
