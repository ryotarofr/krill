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

    fn extract(self: Self) !std.ArrayList(LogEntry) {
        const source = try util.readJsonFile(self.allocator, self.pyfile);
        var logs = std.ArrayList(LogEntry).init(self.allocator);
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
                            try logs.append(.{ .level = level, .message = msg });
                            break;
                        }
                    }
                }
            }
        }
        return logs;
    }
};

const JsonFormatter = struct {
    allocator: Allocator,
    logs: []const LogEntry,

    const Self = @This();

    fn init(allocator: Allocator, logs: []const LogEntry) Self {
        return .{ .allocator = allocator, .logs = logs };
    }

    fn format(self: Self, root_id: []const u8, is_lambda: bool) ![]u8 {
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();
        const writer = list.writer();

        try writer.print("{{\n  \"{s}\": {{\n", .{root_id});

        for (self.logs, 0..) |log, i| {
            const id_buf = try std.fmt.allocPrint(self.allocator, "{d:0>3}", .{i + 1});
            defer self.allocator.free(id_buf);

            if (i > 0) try writer.writeAll(",\n");

            if (is_lambda) {
                try writer.print("    \"{s}\": \"{s}\"", .{ log.message, id_buf });
            } else {
                try writer.print("    \"{s}\": {{\n      \"level\": \"{s}\",\n      \"message\": \"{s}\"\n    }}", .{ id_buf, logLevelToString(log.level), log.message });
            }
        }

        try writer.writeAll("\n  }\n}");
        return list.toOwnedSlice();
    }
};

pub const LoggerRunner = struct {
    pyfile: []const u8,
    root_id: []const u8,
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
        };

        var logs = extractor.extract() catch return;
        if (logs.items.len == 0) {
            std.debug.print("No log entries found. Skipping output.\n", .{});
            logs.deinit();
            return;
        }
        defer logs.deinit();

        const formatter = JsonFormatter.init(allocator, logs.items);
        const json = formatter.format(self.root_id, self.is_lambda) catch return;
        defer allocator.free(json);

        const out_file = std.fs.cwd().createFile(self.output_path, .{ .truncate = true }) catch return;
        defer out_file.close();
        out_file.writeAll(json) catch return;
    }
};
