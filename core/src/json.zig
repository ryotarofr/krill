const std = @import("std");
const Struct = @import("struct.zig");
const Config = @import("config.zig");
const util = @import("util.zig");

const LogLevel = Struct.LogLevel;
const LogEntry = Struct.LogEntry;
const Allocator = std.mem.Allocator;

fn logLevelToString(level: LogLevel) []const u8 {
    return switch (level) {
        .Debug => "debug",
        .Info => "info",
        .Warning => "warning",
        .Error => "error",
        .Critical => "critical",
    };
}

fn logLevelPrefix(prefix: []const u8, level: LogLevel, allocator: Allocator) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}.{s}(\"", .{ prefix, logLevelToString(level) });
}

/// take a null-terminated [*]const u8 and return a []const u8 slice.
fn cStrSlice(cstr: [*]const u8) []const u8 {
    var len: usize = 0;
    // count until NUL
    while (cstr[len] != 0) : (len += 1) {}
    // now build a slice of that length
    return cstr[0..len];
}

const ApiKeyLogGroup = struct {
    api_key: []u8,
    logs: std.ArrayList(LogEntry),
};

const LogExtractor = struct {
    /// Path to the Python file.
    /// If a directory is specified, recursively search for python files within it.
    pyfile: []const u8, // TODO これは comtime T でよいのでは？ ディレクトリ指定の場合は、除外するファイル群の指定をするパラメータを付与
    /// Temporary memory allocation for dynamic data
    allocator: Allocator,
    /// Any string specified by the application side.
    /// Normally, this will be a string such as `logger` or `logging`.
    prefix: []const u8,
    /// Target log levels to extract.
    /// This is a list of strings such as `["debug", "info", ...]`.
    target_loglevel: []const [*]const u8,
    /// List of files that were skipped (no CKRILL_API_KEY found)
    skipped_files: std.ArrayList([]u8),

    const Self = @This();

    /// If `target_loglevel` is empty, extract all log levels.
    /// Extract only log levels that match the log level strings specified in `target_loglevel`.
    /// Example: If `target_loglevel` is `[“debug”, “info”]`, extract only logs with the log levels ‘debug’ and “info”.
    fn filterLog(self: *const LogExtractor, level_str: []const u8) bool {
        if (self.target_loglevel.len == 0) return true;

        for (self.target_loglevel) |target| {
            const ts = cStrSlice(target);
            if (std.mem.eql(u8, level_str, ts)) return true;
        }
        return false;
    }

    fn extractByApiKey(self: *Self) !std.ArrayList(ApiKeyLogGroup) {
        var api_key_groups = std.ArrayList(ApiKeyLogGroup).init(self.allocator);
        
        const is_dir = util.isDirectory(self.pyfile) catch false;
        
        if (is_dir) {
            const python_files = try util.collectPythonFiles(self.allocator, self.pyfile);
            defer {
                for (python_files) |file| {
                    self.allocator.free(file);
                }
                self.allocator.free(python_files);
            }
            
            for (python_files) |file_path| {
                try self.extractFromFileByApiKey(file_path, &api_key_groups);
            }
        } else {
            try self.extractFromFileByApiKey(self.pyfile, &api_key_groups);
        }
        
        return api_key_groups;
    }
    
    fn extractFromFileByApiKey(self: *Self, file_path: []const u8, api_key_groups: *std.ArrayList(ApiKeyLogGroup)) !void {
        // Check if file has CKRILL_API_KEY and import c_crill
        if (util.findCKrillApiKey(self.allocator, file_path) catch null) |api_key| {
            // Find existing group with the same API key or create new one
            var target_group: ?*ApiKeyLogGroup = null;
            for (api_key_groups.items) |*group| {
                if (std.mem.eql(u8, group.api_key, api_key)) {
                    target_group = group;
                    break;
                }
            }
            
            if (target_group == null) {
                // Create new group
                const new_group = ApiKeyLogGroup{
                    .api_key = api_key,
                    .logs = std.ArrayList(LogEntry).init(self.allocator),
                };
                try api_key_groups.append(new_group);
                target_group = &api_key_groups.items[api_key_groups.items.len - 1];
            } else {
                // Free the duplicate api_key since we already have it
                self.allocator.free(api_key);
            }
            
            const source = util.readFile(self.allocator, file_path) catch |err| switch (err) {
                error.FileNotFound => return,
                else => return err,
            };
            defer self.allocator.free(source);
            
            var it = std.mem.tokenizeAny(u8, source, "\n");

            while (it.next()) |line| {
                const trimmed = std.mem.trim(u8, line, " \t");
                const info = @typeInfo(LogLevel);
                inline for (info.@"enum".fields) |field| {
                    const level: LogLevel = @enumFromInt(field.value);
                    const level_str = logLevelToString(level);

                    // wrap the body in a runtime‐guard instead of compile‐time continue
                    if (self.filterLog(level_str)) {
                        const prefix = try logLevelPrefix(self.prefix, level, self.allocator);
                        defer self.allocator.free(prefix);

                        if (std.mem.indexOf(u8, trimmed, prefix)) |start| {
                            const msg_start = start + prefix.len;
                            if (std.mem.indexOfScalar(u8, trimmed[msg_start..], '"')) |msg_end| {
                                const msg = trimmed[msg_start .. msg_start + msg_end];
                                // Create a copy of the message to avoid dangling pointer after source is freed
                                const msg_copy = try self.allocator.dupe(u8, msg);
                                try target_group.?.logs.append(.{ .level = level, .message = msg_copy });
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            // File doesn't have CKRILL_API_KEY, skip it and add to skipped list
            const file_path_copy = try self.allocator.dupe(u8, file_path);
            try self.skipped_files.append(file_path_copy);
        }
    }
};

const JsonFormatter = struct {
    allocator: Allocator,
    api_key_groups: []const ApiKeyLogGroup,

    const Self = @This();

    fn init(allocator: Allocator, api_key_groups: []const ApiKeyLogGroup) Self {
        return .{ .allocator = allocator, .api_key_groups = api_key_groups };
    }

    fn format(self: Self, is_lambda: bool) ![]u8 {
        var list = std.ArrayList(u8).init(self.allocator);
        const writer = list.writer();

        try writer.writeAll("{\n");

        for (self.api_key_groups, 0..) |group, group_idx| {
            if (group_idx > 0) try writer.writeAll(",\n");
            
            try writer.print("  \"{s}\": {{\n", .{group.api_key});

            for (group.logs.items, 0..) |log, i| {
                const id_buf = try std.fmt.allocPrint(self.allocator, "{d:0>3}", .{i + 1});
                defer self.allocator.free(id_buf);

                if (i > 0) try writer.writeAll(",\n");

                if (is_lambda) {
                    try writer.print("    \"{s}\": \"{s}\"", .{ log.message, id_buf });
                } else {
                    try writer.print("    \"{s}\": {{\n      \"level\": \"{s}\",\n      \"message\": \"{s}\"\n    }}", .{ id_buf, logLevelToString(log.level), log.message });
                }
            }

            try writer.writeAll("\n  }");
        }

        try writer.writeAll("\n}");
        return list.toOwnedSlice();
    }
};

pub const LoggerRunner = struct {
    pyfile: []const u8,
    output_path: []const u8,
    prefix: []const u8,
    target_loglevel: []const [*]const u8,
    is_lambda: bool,

    const Self = @This();
    const allocator = std.heap.page_allocator;

    pub fn run(self: Self) void {
        var extractor = LogExtractor{
            .pyfile = self.pyfile,
            .allocator = allocator,
            .prefix = self.prefix,
            .target_loglevel = self.target_loglevel,
            .skipped_files = std.ArrayList([]u8).init(allocator),
        };
        defer {
            // Free skipped files list
            for (extractor.skipped_files.items) |file_path| {
                allocator.free(file_path);
            }
            extractor.skipped_files.deinit();
        }

        var api_key_groups = extractor.extractByApiKey() catch return;
        defer {
            // Free api key groups
            for (api_key_groups.items) |*group| {
                allocator.free(group.api_key);
                for (group.logs.items) |log_entry| {
                    allocator.free(log_entry.message);
                }
                group.logs.deinit();
            }
            api_key_groups.deinit();
        }
        
        // Print skipped files if any
        if (extractor.skipped_files.items.len > 0) {
            std.debug.print("Skipped {} files without CKRILL_API_KEY:\n", .{extractor.skipped_files.items.len});
            for (extractor.skipped_files.items) |file_path| {
                std.debug.print("  - {s}\n", .{file_path});
            }
        }
        
        if (api_key_groups.items.len == 0) {
            std.debug.print("No files with CKRILL_API_KEY found. Skipping JSON generation.\n", .{});
            return;
        }

        const formatter = JsonFormatter.init(allocator, api_key_groups.items);
        const json = formatter.format(self.is_lambda) catch return;
        defer allocator.free(json);

        const out_file = std.fs.cwd().createFile(self.output_path, .{ .truncate = true }) catch return;
        defer out_file.close();
        out_file.writeAll(json) catch return;
    }
};
