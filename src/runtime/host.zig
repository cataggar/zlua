const std = @import("std");

pub const MemoryFile = struct {
    path: []const u8,
    contents: []const u8,
};

pub const MemoryFilesystem = struct {
    allocator: std.mem.Allocator,
    files: std.ArrayList(MemoryFile) = .empty,

    pub fn init(allocator: std.mem.Allocator) MemoryFilesystem {
        return .{ .allocator = allocator };
    }

    pub fn initWithFiles(allocator: std.mem.Allocator, files: []const MemoryFile) !MemoryFilesystem {
        var filesystem = init(allocator);
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
        const index = self.find(path) orelse return error.FileNotFound;
        return allocator.dupe(u8, self.files.items[index].contents);
    }

    pub fn writeFile(self: *MemoryFilesystem, path: []const u8, contents: []const u8) !void {
        if (self.find(path)) |index| {
            const contents_copy = try self.allocator.dupe(u8, contents);
            self.allocator.free(self.files.items[index].contents);
            self.files.items[index].contents = contents_copy;
            return;
        }

        const path_copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(path_copy);
        const contents_copy = try self.allocator.dupe(u8, contents);
        errdefer self.allocator.free(contents_copy);
        try self.files.append(self.allocator, .{ .path = path_copy, .contents = contents_copy });
    }

    pub fn removeFile(self: *MemoryFilesystem, path: []const u8) !void {
        const index = self.find(path) orelse return error.FileNotFound;
        const file = self.files.swapRemove(index);
        self.allocator.free(file.path);
        self.allocator.free(file.contents);
    }

    pub fn renameFile(self: *MemoryFilesystem, old_path: []const u8, new_path: []const u8) !void {
        _ = self.find(old_path) orelse return error.FileNotFound;
        if (std.mem.eql(u8, old_path, new_path)) return;
        if (self.find(new_path) != null) try self.removeFile(new_path);

        const index = self.find(old_path) orelse return error.FileNotFound;
        const path_copy = try self.allocator.dupe(u8, new_path);
        self.allocator.free(self.files.items[index].path);
        self.files.items[index].path = path_copy;
    }

    fn find(self: *const MemoryFilesystem, path: []const u8) ?usize {
        for (self.files.items, 0..) |file, index| {
            if (std.mem.eql(u8, file.path, path)) return index;
        }
        return null;
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
