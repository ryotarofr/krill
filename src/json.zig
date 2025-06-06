const std = @import("std");

const Allocator = std.mem.Allocator;
const LEVELS = [_][]const u8{ "debug", "info", "warning", "error", "critical" };

const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Critical,
};

const LogEntry = struct {
    /// The message is the log message.
    /// `logger.debug("debug message")` will be stored as `debug message`.
    /// `logger.info("info message")` will be stored as `info message`.
    /// `logger.warning("warning message")` will be stored as `warning message`.
    /// `logger.error("error message")` will be stored as `error message`.
    /// `logger.critical("critical message")` will be stored as `critical message`.
    message: []const u8,
    /// The level is the log level.
    /// `logger.debug("debug message")` will be stored as `LogLevel.Debug`.
    /// `logger.info("info message")` will be stored as `LogLevel.Info`.
    /// `logger.warning("warning message")` will be stored as `LogLevel.Warning`.
    /// `logger.error("error message")` will be stored as `LogLevel.Error`.
    /// `logger.critical("critical message")` will be stored as `LogLevel.Critical`.
    level: LogLevel,
};

const Logger = struct {
    /// Currently, three zeros are added to the end of numbers.
    /// It is necessary to allow users to configure this setting.
    id: [3]u8 = 0,
    entry: LogEntry,
};

const LoggerAllocator = struct {
    pub fn create(id: [3]u8, message: []const u8, level: LogLevel) Logger {
        return Logger{
            .id = id,
            .entry = LogEntry{
                .message = message,
                .level = level,
            },
        };
    }
};

pub fn Json() type {
    return struct {
        allocator: Allocator,
        logs: []const LogEntry,

        const Self = @This();

        pub fn init(allocator: Allocator, logs: []const LogEntry) Self {
            return Self{ .allocator = allocator, .logs = logs };
        }

        pub fn writeBody(list: *std.ArrayList(u8), id_buf: *const [3]u8, level_str: []const u8, message: []const u8) !void {
            try list.writer().print("    \"{s}\": {{\n      \"level\": \"{s}\",\n      \"message\": \"{s}\"\n    }}", .{ id_buf, level_str, message });
        }

        pub fn logsToJson(self: Self, root_id: []const u8) ![]u8 {
            if (self.logs.len == 0) {
                var list = std.ArrayList(u8).init(self.allocator);
                defer list.deinit();
                try list.append('{');
                try list.writer().print("\n  \"{s}\": {{}}\n}}", .{root_id});
                return list.toOwnedSlice();
            }
            var list = std.ArrayList(u8).init(self.allocator);
            defer list.deinit();
            try list.append('{');
            try list.writer().print("\n  \"{s}\": {{\n", .{root_id});
            var id_num: u16 = 1;
            var first = true;
            for (self.logs) |log| {
                if (!first) {
                    try list.appendSlice(",\n");
                }
                first = false;
                var id_buf: [3]u8 = undefined;
                _ = std.fmt.bufPrint(&id_buf, "{d:0>3}", .{id_num}) catch unreachable;
                id_num += 1;
                const level_str = logLevelToString(log.level);
                try Self.writeBody(&list, &id_buf, level_str, log.message);
            }
            try list.appendSlice("\n  }\n}");
            return list.toOwnedSlice();
        }
    };
}

fn logLevelToString(level: LogLevel) []const u8 {
    return switch (level) {
        LogLevel.Debug => "Debug",
        LogLevel.Info => "Info",
        LogLevel.Warning => "Warning",
        LogLevel.Error => "Error",
        LogLevel.Critical => "Critical",
    };
}

fn logLevelFromIdx(idx: usize) LogLevel {
    return switch (idx) {
        0 => LogLevel.Debug,
        1 => LogLevel.Info,
        2 => LogLevel.Warning,
        3 => LogLevel.Error,
        4 => LogLevel.Critical,
        else => LogLevel.Info,
    };
}

const TargetLogLevel = []const LogLevel;

fn tokenIter(source: []const u8) !std.mem.TokenIterator(u8, .any) {
    return std.mem.tokenizeAny(u8, source, "\n");
}

pub const EntryType = struct {
    pyfile_ptr: [*]const u8,
    pyfile_len: usize,
    root_id: []const u8,
    output_path: []const u8,
    allocator: Allocator,

    pub fn pyfile(self: @This()) []const u8 {
        return self.pyfile_ptr[0..self.pyfile_len];
    }
    pub fn openFile(self: @This()) !std.fs.File {
        return std.fs.cwd().openFile(self.pyfile(), .{});
    }
    pub fn readToEndAlloc(self: @This(), max_size: usize) ![]const u8 {
        var file = try self.openFile();
        defer file.close();
        return try file.readToEndAlloc(self.allocator, max_size);
    }
    pub fn run(self: @This()) !std.ArrayList(LogEntry) {
        const source = try self.readToEndAlloc(10 * 1024 * 1024);
        var logs = std.ArrayList(LogEntry).init(self.allocator);
        var it = try tokenIter(source);
        while (it.next()) |line| {
            var idx: usize = 0;
            while (idx < LEVELS.len) : (idx += 1) {
                const lvl = LEVELS[idx];
                const prefix = try std.fmt.allocPrint(self.allocator, "logger.{s}(\"", .{lvl});
                defer self.allocator.free(prefix);
                if (std.mem.indexOf(u8, line, prefix)) |start| {
                    const msg_start = start + prefix.len;
                    if (std.mem.indexOfScalar(u8, line[msg_start..], '"')) |msg_end| {
                        const msg = line[msg_start .. msg_start + msg_end];
                        const level_enum = logLevelFromIdx(idx);
                        try logs.append(.{ .level = level_enum, .message = msg });
                    }
                }
            }
        }
        return logs;
    }
};

pub fn LoggerZig() type {
    return struct {
        pyfile_ptr: [*]const u8,
        pyfile_len: usize,
        root_id: []const u8,
        output_path: []const u8,

        const Self = @This();
        const allocator = std.heap.page_allocator;

        fn createPile(self: Self) !std.fs.File {
            return try std.fs.cwd().createFile(self.output_path, .{ .truncate = true });
        }

        pub fn run(self: Self) void {
            var entry = EntryType{
                .pyfile_ptr = self.pyfile_ptr,
                .pyfile_len = self.pyfile_len,
                .root_id = self.root_id,
                .output_path = self.output_path,
                .allocator = Self.allocator,
            };
            var logs = entry.run() catch return;
            if (logs.items.len == 0) {
                std.debug.print("No log entries found. Skipping output.\n", .{});
                logs.deinit();
                return;
            }
            defer logs.deinit();
            var json_instance = Json().init(Self.allocator, logs.items);
            const json = json_instance.logsToJson(self.root_id) catch return;
            defer Self.allocator.free(json);
            var out_file = self.createPile() catch return;
            defer out_file.close();
            out_file.writeAll(json) catch return;
        }
    };
}

pub export fn loggerZig(pyfile_ptr: [*]const u8, pyfile_len: usize, root_id_ptr: [*]const u8, root_id_len: usize, output_path_ptr: [*]const u8, output_path_len: usize) void {
    const logger = LoggerZig(){
        .pyfile_ptr = pyfile_ptr,
        .pyfile_len = pyfile_len,
        .root_id = root_id_ptr[0..root_id_len],
        .output_path = output_path_ptr[0..output_path_len],
    };
    logger.run();
}
