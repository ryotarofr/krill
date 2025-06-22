const std = @import("std");
const Config = @import("config.zig");

pub fn toZeroPad3(n: i64) [3]u8 {
    var buf: [3]u8 = undefined;
    var value = n;
    if (value < 0) value = 0;
    buf[0] = @as(u8, @intCast(@rem(@divTrunc(value, 100), 10))) + '0';
    buf[1] = @as(u8, @intCast(@rem(@divTrunc(value, 10), 10))) + '0';
    buf[2] = @as(u8, @intCast(@rem(value, 10))) + '0';
    return buf;
}

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, Config.MAX_BYTES);
}

pub fn readJsonFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return readFile(allocator, path);
}

pub fn isPythonFile(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".py");
}

pub fn isDirectory(path: []const u8) !bool {
    const stat = std.fs.cwd().statFile(path) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return err,
    };
    return stat.kind == .directory;
}

pub fn findCKrillApiKey(allocator: std.mem.Allocator, file_path: []const u8) !?[]u8 {
    const content = readFile(allocator, file_path) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer allocator.free(content);

    const import_line = "import c_crill";
    const api_key_prefix = "CKRILL_API_KEY = \"";
    const api_key_suffix = "\"";

    var has_import = false;
    var lines = std.mem.tokenizeAny(u8, content, "\n");
    
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (std.mem.indexOf(u8, trimmed, import_line) != null) {
            has_import = true;
            break;
        }
    }

    if (!has_import) return null;

    lines.reset();
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t");
        if (std.mem.indexOf(u8, trimmed, api_key_prefix)) |start| {
            const value_start = start + api_key_prefix.len;
            if (std.mem.indexOf(u8, trimmed[value_start..], api_key_suffix)) |end| {
                const value = trimmed[value_start .. value_start + end];
                return try allocator.dupe(u8, value);
            }
        }
    }

    return null;
}

pub fn collectPythonFiles(allocator: std.mem.Allocator, dir_path: []const u8) ![][]u8 {
    var files = std.ArrayList([]u8).init(allocator);
    errdefer {
        for (files.items) |file| {
            allocator.free(file);
        }
        files.deinit();
    }

    try collectPythonFilesRecursive(allocator, &files, dir_path);
    return files.toOwnedSlice();
}

fn collectPythonFilesRecursive(allocator: std.mem.Allocator, files: *std.ArrayList([]u8), dir_path: []const u8) !void {
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        error.NotDir => {
            if (isPythonFile(dir_path)) {
                const file_path = try allocator.dupe(u8, dir_path);
                try files.append(file_path);
            }
            return;
        },
        else => return err,
    };
    defer dir.close();

    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        defer allocator.free(full_path);

        switch (entry.kind) {
            .file => {
                if (isPythonFile(entry.name)) {
                    const file_path = try allocator.dupe(u8, full_path);
                    try files.append(file_path);
                }
            },
            .directory => {
                try collectPythonFilesRecursive(allocator, files, full_path);
            },
            else => {},
        }
    }
}
