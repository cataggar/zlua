const std = @import("std");

const Dir = std.Io.Dir;

pub const Registry = struct {
    failures: std.StringHashMap([]u8),

    pub fn init(allocator: std.mem.Allocator) Registry {
        return .{ .failures = std.StringHashMap([]u8).init(allocator) };
    }

    pub fn deinit(self: *Registry) void {
        var iter = self.failures.iterator();
        while (iter.next()) |entry| {
            self.failures.allocator.free(entry.key_ptr.*);
            self.failures.allocator.free(entry.value_ptr.*);
        }
        self.failures.deinit();
    }

    pub fn contains(self: Registry, path: []const u8) bool {
        return self.failures.contains(path);
    }

    pub fn reason(self: Registry, path: []const u8) ?[]const u8 {
        return self.failures.get(path);
    }
};

pub fn load(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Registry {
    var registry = Registry.init(allocator);
    errdefer registry.deinit();

    const content = Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return registry,
        else => return err,
    };
    defer allocator.free(content);

    var current_path: ?[]const u8 = null;
    var current_reason: []const u8 = "";

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or std.mem.startsWith(u8, line, "#")) continue;
        if (std.mem.eql(u8, line, "[[failure]]")) {
            try flush(allocator, &registry, &current_path, current_reason);
            current_reason = "";
        } else if (std.mem.startsWith(u8, line, "path")) {
            current_path = parseStringValue(line);
        } else if (std.mem.startsWith(u8, line, "reason")) {
            current_reason = parseStringValue(line) orelse "";
        }
    }
    try flush(allocator, &registry, &current_path, current_reason);

    return registry;
}

fn flush(
    allocator: std.mem.Allocator,
    registry: *Registry,
    current_path: *?[]const u8,
    reason: []const u8,
) !void {
    if (current_path.*) |path| {
        try registry.failures.put(try allocator.dupe(u8, path), try allocator.dupe(u8, reason));
        current_path.* = null;
    }
}

fn parseStringValue(line: []const u8) ?[]const u8 {
    const equals = std.mem.indexOfScalar(u8, line, '=') orelse return null;
    const value = std.mem.trim(u8, line[equals + 1 ..], " \t");
    if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
        return value[1 .. value.len - 1];
    }
    return value;
}

test "parses quoted string values" {
    const parsed = parseStringValue("path = \"tests/diff/runtime/not_implemented.lua\"").?;
    try std.testing.expect(std.mem.eql(u8, parsed, "tests/diff/runtime/not_implemented.lua"));
}
