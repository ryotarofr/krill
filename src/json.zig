const std = @import("std");

const Allocator = std.mem.Allocator;

const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
    Critical,
};

const LogEntry = struct {
    level: LogLevel,
    message: []const u8,
};

const Logger = struct {
    // 3 桁ゼロ埋め
    id: [3]u8 = 0,
    // ログメッセージ
    message: []const u8,
    level: LogLevel,
};

const LoggerAllocator = struct {
    // ロガーのインスタンスを生成する
    pub fn create(id: [3]u8, message: []const u8, level: LogLevel) Logger {
        return Logger{
            .id = id,
            .message = message,
            .level = level,
        };
    }
};

const Json = struct {
    allocator: Allocator,
    logs: []const LogEntry,

    pub fn init(allocator: Allocator, logs: []const LogEntry) Json {
        return Json{ .allocator = allocator, .logs = logs };
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
    fn write(writer: anytype, id: []const u8, level: []const u8, message: []const u8) !void {
        try writer.print("{{\"id\":\"{s}\",\"level\":\"{s}\",\"message\":\"{s}\"}}", .{ id, level, message });
    }

    // JSON出力用の関数
    pub fn to(logger: Logger) void {
        var buf: [3]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{{\"id\":\"{s}\",\"level\":\"{s}\",\"message\":\"{s}\"}}", .{
            &logger.id,
            logLevelToString(logger.level),
            logger.message,
        }) catch unreachable;
        // return buf[0..len];
    }

    pub fn logsToJson(self: *Json, root_id: []const u8) ![]u8 {
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
            try list.writer().print("    \"{s}\": {{\n      \"level\": \"{s}\",\n      \"message\": \"{s}\"\n    }}", .{ &id_buf, level_str, log.message });
        }
        try list.appendSlice("\n  }\n}");
        return list.toOwnedSlice();
    }
};

const TargetLogLevel = []const LogLevel; // 出力するログレベルを指定

// pub fn Entry(comptime T: type) type {
//     return struct {
//         id: [3]u8,
//         message: []const u8,
//         level: LogLevel,

//         pub fn init(id: [3]u8, message: []const u8, level: LogLevel) Entry(T) {
//             return Entry(T){
//                 .id = id,
//                 .message = message,
//                 .level = level,
//             };
//         }
//     };
// }

export fn run_logger(pyfile_ptr: [*]const u8, pyfile_len: usize) void {
    const allocator = std.heap.page_allocator;
    const pyfile = pyfile_ptr[0..pyfile_len];

    var file = std.fs.cwd().openFile(pyfile, .{}) catch {
        return;
    };
    defer file.close();
    const source = file.readToEndAlloc(allocator, 10 * 1024 * 1024) catch {
        return;
    };
    defer allocator.free(source);

    var logs = std.ArrayList(LogEntry).init(allocator);
    defer logs.deinit();
    var it = std.mem.tokenizeAny(u8, source, "\n");
    while (it.next()) |line| {
        const levels = [_][]const u8{ "debug", "info", "warning", "error", "critical" };
        var idx: usize = 0;
        while (idx < levels.len) : (idx += 1) {
            const lvl = levels[idx];
            const prefix = std.fmt.allocPrint(allocator, "logger.{s}(\"", .{lvl}) catch {
                return;
            };
            defer allocator.free(prefix);
            if (std.mem.indexOf(u8, line, prefix)) |start| {
                const msg_start = start + prefix.len;
                if (std.mem.indexOfScalar(u8, line[msg_start..], '"')) |msg_end| {
                    const msg = line[msg_start .. msg_start + msg_end];
                    const level_enum = switch (idx) {
                        0 => LogLevel.Debug,
                        1 => LogLevel.Info,
                        2 => LogLevel.Warning,
                        3 => LogLevel.Error,
                        4 => LogLevel.Critical,
                        else => LogLevel.Info,
                    };
                    logs.append(.{ .level = level_enum, .message = msg }) catch {
                        return;
                    };
                }
            }
        }
    }
    var json_instance = Json.init(allocator, logs.items);
    const json = json_instance.logsToJson("SKIC05008E004") catch {
        return;
    };
    defer allocator.free(json);
    var out_file = std.fs.cwd().createFile("logger_output.json", .{ .truncate = true }) catch {
        return;
    };
    defer out_file.close();
    out_file.writeAll(json) catch {
        return;
    };

    // level+message→id のdict形式JSONも出力
    const allowed_levels = [_]LogLevel{ LogLevel.Error, LogLevel.Critical }; // 例: ErrorとCriticalのみ
    var dict_list = std.ArrayList(u8).init(allocator);
    defer dict_list.deinit();
    dict_list.append('{') catch {
        return;
    };
    var dict_first = true;
    var dict_id_num: u16 = 0;
    for (logs.items) |log| {
        var allowed = false;
        for (allowed_levels) |al| {
            if (log.level == al) allowed = true;
        }
        if (!allowed) continue;
        if (!dict_first) dict_list.appendSlice(",\n") catch {
            return;
        };
        dict_first = false;
        var id_buf: [3]u8 = undefined;
        _ = std.fmt.bufPrint(&id_buf, "{d:0>3}", .{dict_id_num}) catch {
            return;
        };
        dict_id_num += 1;
        dict_list.writer().print("    \"{s}\": \"{s}\"", .{ log.message, &id_buf }) catch {
            return;
        };
    }
    dict_list.appendSlice("\n}\n") catch {
        return;
    };
    var dict_file = std.fs.cwd().createFile("logger_output_dict.json", .{ .truncate = true }) catch {
        return;
    };
    defer dict_file.close();
    dict_file.writeAll(dict_list.items) catch {
        return;
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var args = std.process.args();
    _ = args.next(); // skip program name
    const pyfile = args.next() orelse {
        std.debug.print("Usage: zig run logger.zig <pythonfile>\n", .{});
        return;
    };
    // Pythonファイルを読み込む
    var file = try std.fs.cwd().openFile(pyfile, .{});
    defer file.close();
    const source = try file.readToEndAlloc(allocator, 10 * 1024 * 1024); // 最大10MB
    defer allocator.free(source);

    // logger.<level>("message") を抽出
    var logs = std.ArrayList(LogEntry).init(allocator);
    defer logs.deinit();
    var it = std.mem.tokenizeAny(u8, source, "\n");
    while (it.next()) |line| {
        // 探索: logger.<level>("message")
        const levels = [_][]const u8{ "debug", "info", "warning", "error", "critical" };
        var idx: usize = 0;
        while (idx < levels.len) : (idx += 1) {
            const lvl = levels[idx];
            const prefix = try std.fmt.allocPrint(allocator, "logger.{s}(\"", .{lvl});
            defer allocator.free(prefix);
            if (std.mem.indexOf(u8, line, prefix)) |start| {
                const msg_start = start + prefix.len;
                if (std.mem.indexOfScalar(u8, line[msg_start..], '"')) |msg_end| {
                    const msg = line[msg_start .. msg_start + msg_end];
                    const level_enum = switch (idx) {
                        0 => LogLevel.Debug,
                        1 => LogLevel.Info,
                        2 => LogLevel.Warning,
                        3 => LogLevel.Error,
                        4 => LogLevel.Critical,
                        else => LogLevel.Info,
                    };
                    try logs.append(.{ .level = level_enum, .message = msg });
                }
            }
        }
    }
    // const json = try Json.logsToJson(logs.items, allocator);
    var json_instance = Json.init(allocator, logs.items);
    const json = try json_instance.logsToJson("SKIC05008E004"); // TODO prefix に該当するもの。ユーザ側でパラメータを渡せるようにする
    defer allocator.free(json);
    // ファイルに出力（従来の配列JSON）
    var out_file = try std.fs.cwd().createFile("logger_output.json", .{ .truncate = true });
    defer out_file.close();
    try out_file.writeAll(json);

    // level+message→id のdict形式JSONも出力
    // ここで格納したいレベルのみを指定
    const allowed_levels = [_]LogLevel{ LogLevel.Error, LogLevel.Critical }; // 例: ErrorとCriticalのみ
    var dict_list = std.ArrayList(u8).init(allocator);
    defer dict_list.deinit();
    try dict_list.append('{');
    var dict_first = true;
    var dict_id_num: u16 = 0;
    for (logs.items) |log| {
        // allowed_levelsに含まれるレベルのみ格納
        var allowed = false;
        for (allowed_levels) |al| {
            if (log.level == al) allowed = true;
        }
        if (!allowed) continue;
        if (!dict_first) try dict_list.appendSlice(",\n");
        dict_first = false;
        var id_buf: [3]u8 = undefined;
        _ = std.fmt.bufPrint(&id_buf, "{d:0>3}", .{dict_id_num}) catch unreachable;
        dict_id_num += 1;
        try dict_list.writer().print("    \"{s}\": \"{s}\"", .{ log.message, &id_buf });
    }
    try dict_list.appendSlice("\n}\n");
    var dict_file = try std.fs.cwd().createFile("logger_output_dict.json", .{ .truncate = true });
    defer dict_file.close();
    try dict_file.writeAll(dict_list.items);
}
