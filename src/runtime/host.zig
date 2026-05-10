const std = @import("std");

pub const MemoryFile = struct {
    path: []const u8,
    contents: []const u8,
};

pub const MemoryFilesystem = struct {
    pub const default_max_path_len: usize = 4096;

    pub const Options = struct {
        max_path_len: usize = default_max_path_len,
        max_bytes: ?usize = null,
    };

    allocator: std.mem.Allocator,
    files: std.ArrayList(MemoryFile) = .empty,
    options: Options = .{},
    bytes_used: usize = 0,

    pub fn init(allocator: std.mem.Allocator) MemoryFilesystem {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) MemoryFilesystem {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn initWithFiles(allocator: std.mem.Allocator, files: []const MemoryFile) !MemoryFilesystem {
        return initWithFilesAndOptions(allocator, files, .{});
    }

    pub fn initWithFilesAndOptions(allocator: std.mem.Allocator, files: []const MemoryFile, options: Options) !MemoryFilesystem {
        var filesystem = initWithOptions(allocator, options);
        errdefer filesystem.deinit();
        for (files) |file| try filesystem.writeFile(file.path, file.contents);
        return filesystem;
    }

    pub fn deinit(self: *MemoryFilesystem) void {
        for (self.files.items) |file| {
            self.allocator.free(file.path);
            self.allocator.free(file.contents);
        }
        self.files.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn readFileAlloc(self: *const MemoryFilesystem, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
        const normalized = try normalizePathAlloc(self.allocator, path, self.options.max_path_len);
        defer self.allocator.free(normalized);
        const index = self.findNormalized(normalized) orelse return error.FileNotFound;
        return allocator.dupe(u8, self.files.items[index].contents);
    }

    pub fn writeFile(self: *MemoryFilesystem, path: []const u8, contents: []const u8) !void {
        const normalized = try normalizePathAlloc(self.allocator, path, self.options.max_path_len);
        errdefer self.allocator.free(normalized);

        if (self.findNormalized(normalized)) |index| {
            const contents_copy = try self.allocator.dupe(u8, contents);
            errdefer self.allocator.free(contents_copy);
            const old_len = self.files.items[index].contents.len;
            try self.ensureQuota(old_len, contents_copy.len);
            self.allocator.free(self.files.items[index].contents);
            self.bytes_used = self.bytes_used - old_len + contents_copy.len;
            self.files.items[index].contents = contents_copy;
            self.allocator.free(normalized);
            return;
        }

        const contents_copy = try self.allocator.dupe(u8, contents);
        errdefer self.allocator.free(contents_copy);
        try self.ensureQuota(0, contents_copy.len);
        try self.files.append(self.allocator, .{ .path = normalized, .contents = contents_copy });
        self.bytes_used += contents_copy.len;
    }

    pub fn removeFile(self: *MemoryFilesystem, path: []const u8) !void {
        const normalized = try normalizePathAlloc(self.allocator, path, self.options.max_path_len);
        defer self.allocator.free(normalized);
        const index = self.findNormalized(normalized) orelse return error.FileNotFound;
        self.removeAt(index);
    }

    fn removeAt(self: *MemoryFilesystem, index: usize) void {
        const file = self.files.swapRemove(index);
        self.bytes_used -= @min(self.bytes_used, file.contents.len);
        self.allocator.free(file.path);
        self.allocator.free(file.contents);
    }

    pub fn renameFile(self: *MemoryFilesystem, old_path: []const u8, new_path: []const u8) !void {
        const old_normalized = try normalizePathAlloc(self.allocator, old_path, self.options.max_path_len);
        defer self.allocator.free(old_normalized);
        const new_normalized = try normalizePathAlloc(self.allocator, new_path, self.options.max_path_len);
        errdefer self.allocator.free(new_normalized);

        _ = self.findNormalized(old_normalized) orelse return error.FileNotFound;
        if (std.mem.eql(u8, old_normalized, new_normalized)) {
            self.allocator.free(new_normalized);
            return;
        }
        if (self.findNormalized(new_normalized)) |index| self.removeAt(index);

        const index = self.findNormalized(old_normalized) orelse return error.FileNotFound;
        self.allocator.free(self.files.items[index].path);
        self.files.items[index].path = new_normalized;
    }

    fn findNormalized(self: *const MemoryFilesystem, path: []const u8) ?usize {
        for (self.files.items, 0..) |file, index| {
            if (std.mem.eql(u8, file.path, path)) return index;
        }
        return null;
    }

    fn ensureQuota(self: *const MemoryFilesystem, old_len: usize, new_len: usize) !void {
        const max_bytes = self.options.max_bytes orelse return;
        if (self.bytes_used - old_len + new_len > max_bytes) return error.QuotaExceeded;
    }

    pub fn normalizePathAlloc(allocator: std.mem.Allocator, path: []const u8, max_path_len: usize) ![]u8 {
        if (path.len == 0 or path[0] == '/') return error.InvalidPath;

        var normalized = std.ArrayList(u8).empty;
        errdefer normalized.deinit(allocator);

        var parts = std.mem.splitScalar(u8, path, '/');
        while (parts.next()) |part| {
            if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
            if (std.mem.eql(u8, part, "..")) return error.InvalidPath;
            if (std.mem.indexOfScalar(u8, part, '\\') != null) return error.InvalidPath;
            if (std.mem.indexOfScalar(u8, part, 0) != null) return error.InvalidPath;

            if (normalized.items.len != 0) try normalized.append(allocator, '/');
            try normalized.appendSlice(allocator, part);
            if (normalized.items.len > max_path_len) return error.PathTooLong;
        }

        if (normalized.items.len == 0) return error.InvalidPath;
        return normalized.toOwnedSlice(allocator);
    }
};

pub const FilesystemCapability = union(enum) {
    disabled,
    memory: []const MemoryFile,
    memory_rw: *MemoryFilesystem,
    host_cwd,
};

pub const ClockCapability = union(enum) {
    disabled,
    fixed: i64,
    system,
};

pub const ProcessCapability = enum {
    disabled,
    enabled,
};

test "memory filesystem normalizes relative paths" {
    var filesystem = MemoryFilesystem.init(std.testing.allocator);
    defer filesystem.deinit();

    try filesystem.writeFile("./plugins//main.lua", "return 42");
    const source = try filesystem.readFileAlloc(std.testing.allocator, "plugins/main.lua");
    defer std.testing.allocator.free(source);
    try std.testing.expectEqualStrings("return 42", source);
}

test "memory filesystem rejects sandbox escape paths" {
    var filesystem = MemoryFilesystem.init(std.testing.allocator);
    defer filesystem.deinit();

    try std.testing.expectError(error.InvalidPath, filesystem.writeFile("/tmp/plugin.lua", ""));
    try std.testing.expectError(error.InvalidPath, filesystem.writeFile("plugins/../secret.lua", ""));
    try std.testing.expectError(error.InvalidPath, filesystem.writeFile("plugins\\secret.lua", ""));
}

test "memory filesystem enforces path length and byte quota" {
    var filesystem = MemoryFilesystem.initWithOptions(std.testing.allocator, .{
        .max_path_len = 8,
        .max_bytes = 5,
    });
    defer filesystem.deinit();

    try std.testing.expectError(error.PathTooLong, filesystem.writeFile("too-long-name.lua", "x"));
    try filesystem.writeFile("a.lua", "123");
    try std.testing.expectError(error.QuotaExceeded, filesystem.writeFile("b.lua", "456"));
    try filesystem.writeFile("a.lua", "12345");
    try std.testing.expectError(error.QuotaExceeded, filesystem.writeFile("a.lua", "123456"));
}

test "memory filesystem enforces byte quota while seeding files" {
    const files = [_]MemoryFile{
        .{ .path = "a.lua", .contents = "123" },
        .{ .path = "b.lua", .contents = "456" },
    };

    try std.testing.expectError(error.QuotaExceeded, MemoryFilesystem.initWithFilesAndOptions(std.testing.allocator, &files, .{
        .max_bytes = 5,
    }));
}

test "memory filesystem rename overwrites normalized target" {
    var filesystem = MemoryFilesystem.init(std.testing.allocator);
    defer filesystem.deinit();

    try filesystem.writeFile("old.lua", "old");
    try filesystem.writeFile("dir/target.lua", "target");
    try filesystem.renameFile("./old.lua", "dir//target.lua");

    const source = try filesystem.readFileAlloc(std.testing.allocator, "dir/target.lua");
    defer std.testing.allocator.free(source);
    try std.testing.expectEqualStrings("old", source);
    try std.testing.expectError(error.FileNotFound, filesystem.readFileAlloc(std.testing.allocator, "old.lua"));
}
