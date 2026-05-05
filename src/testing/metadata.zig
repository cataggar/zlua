const std = @import("std");

pub const Expect = enum { pass, fail, skip };
pub const Stage = enum { lex, parse, resolve, compile, runtime, stdlib, official };
pub const Normalize = enum { none, paths };

pub const Metadata = struct {
    expect: Expect = .pass,
    stage: Stage = .runtime,
    feature: []const u8 = "uncategorized",
    normalize: Normalize = .none,
    reason: []const u8 = "",
    issue: []const u8 = "",
};

pub fn parse(source: []const u8) !Metadata {
    var result: Metadata = .{};
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        if (!std.mem.startsWith(u8, line, "--")) break;

        const comment = std.mem.trim(u8, line[2..], " \t");
        const colon = std.mem.indexOfScalar(u8, comment, ':') orelse continue;
        const key = std.mem.trim(u8, comment[0..colon], " \t");
        const value = std.mem.trim(u8, comment[colon + 1 ..], " \t");

        if (std.mem.eql(u8, key, "expect")) {
            result.expect = try parseEnum(Expect, value);
        } else if (std.mem.eql(u8, key, "stage")) {
            result.stage = try parseEnum(Stage, value);
        } else if (std.mem.eql(u8, key, "feature")) {
            result.feature = value;
        } else if (std.mem.eql(u8, key, "normalize")) {
            result.normalize = try parseEnum(Normalize, value);
        } else if (std.mem.eql(u8, key, "reason")) {
            result.reason = value;
        } else if (std.mem.eql(u8, key, "issue")) {
            result.issue = value;
        }
    }
    return result;
}

fn parseEnum(comptime T: type, value: []const u8) !T {
    inline for (@typeInfo(T).@"enum".fields) |field| {
        if (std.mem.eql(u8, value, field.name)) {
            return @field(T, field.name);
        }
    }
    return error.InvalidMetadataValue;
}

pub fn parseStage(value: []const u8) !Stage {
    return parseEnum(Stage, value);
}

test "parses top-of-file metadata" {
    const meta = try parse(
        \\-- expect: fail
        \\-- stage: parse
        \\-- feature: strings
        \\-- normalize: paths
        \\
        \\print('x')
    );
    try std.testing.expectEqual(Expect.fail, meta.expect);
    try std.testing.expectEqual(Stage.parse, meta.stage);
    try std.testing.expectEqual(Normalize.paths, meta.normalize);
    try std.testing.expect(std.mem.eql(u8, meta.feature, "strings"));
}
