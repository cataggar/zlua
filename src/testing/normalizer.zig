const std = @import("std");
const metadata = @import("metadata.zig");

pub fn normalizeText(
    allocator: std.mem.Allocator,
    input: []const u8,
    mode: metadata.Normalize,
    cwd: []const u8,
) ![]u8 {
    switch (mode) {
        .none => return allocator.dupe(u8, input),
        .paths => return replaceAll(allocator, input, cwd, "<cwd>"),
    }
}

fn replaceAll(
    allocator: std.mem.Allocator,
    input: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    if (needle.len == 0) return allocator.dupe(u8, input);

    var count: usize = 0;
    var rest = input;
    while (std.mem.indexOf(u8, rest, needle)) |index| {
        count += 1;
        rest = rest[index + needle.len ..];
    }

    const new_len = input.len - count * needle.len + count * replacement.len;
    var output = try allocator.alloc(u8, new_len);
    var write_index: usize = 0;
    rest = input;
    while (std.mem.indexOf(u8, rest, needle)) |index| {
        @memcpy(output[write_index .. write_index + index], rest[0..index]);
        write_index += index;
        @memcpy(output[write_index .. write_index + replacement.len], replacement);
        write_index += replacement.len;
        rest = rest[index + needle.len ..];
    }
    @memcpy(output[write_index .. write_index + rest.len], rest);
    return output;
}

test "path normalizer replaces cwd" {
    const out = try normalizeText(std.testing.allocator, "/tmp/project/file.lua", .paths, "/tmp/project");
    defer std.testing.allocator.free(out);
    try std.testing.expect(std.mem.eql(u8, out, "<cwd>/file.lua"));
}
