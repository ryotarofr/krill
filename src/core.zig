///
/// This is the content that is expected to be executed within the Python source.
///
const std = @import("std");
const util = @import("util.zig");
const Struct = @import("struct.zig");

const Allocator = std.mem.Allocator;
const LogLevel = Struct.LogLevel;
const LogEntry = Struct.LogEntry;
const Logger = Struct.Logger;

pub fn LoggerAllocator() type {
    return struct {
        allocator: Allocator,
        map: std.AutoHashMap(i64, Logger),

        next_id: i64,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return Self{ .allocator = allocator, .map = std.AutoHashMap(i64, Logger).init(allocator), .next_id = 1 };
        }

        pub fn _nextId(self: *Self) i64 {
            const id = self.next_id;
            self.next_id += 1;
            return id;
        }

        pub fn createId(self: Self) [3]u8 {
            return util.toZeroPad3(self.next_id);
        }

        pub fn getLogger(self: Self, id: i64) ?Logger {
            return self.map.get(id);
        }

        pub fn setLogger(
            self: Self,
            id: [3]u8,
            message: []const u8,
            level: LogLevel,
        ) Logger {
            // メッセージ領域をアロケータから確保してコピー
            const buf = self.allocator.alloc(u8, message.len) catch unreachable;
            std.mem.copyForwards(u8, buf, message);
            return Logger{
                .id = id,
                .entry = LogEntry{
                    .message = buf,
                    .level = level,
                },
            };
        }

        pub fn getMaxKey(self: Self) i64 {
            if (self.map.count() == 0) return 0;
            var max_key: i64 = 0;
            var it = self.map.keyIterator();
            while (it.next()) |k| {
                if (k.* > max_key) {
                    max_key = k.*;
                }
            }
            return max_key;
        }

        pub fn getLastLogger(self: Self) ?Logger {
            const max_key = self.getMaxKey();
            if (max_key == 0) return null;
            return self.getLogger(max_key);
        }

        pub fn getMap(self: Self) std.AutoHashMap(i64, Logger) {
            return self.map;
        }

        pub fn setMap(self: *Self, logger: Logger) void {
            self.map.put(self._nextId(), logger) catch unreachable;
        }
    };
}

// TODO これを export 関数にする
// logger.info("Hello, World!", True);
// 第二引数が True のやつを検知して発火するようにする
// 内部で allocator を作成し、いつでも取り出せるようにする
var global_logger_allocator: ?*LoggerAllocatorType = null;
const LoggerAllocatorType = LoggerAllocator();
pub export fn init() void {
    if (global_logger_allocator == null) {
        // 1) 生のポインタを確保して…
        const ptr = std.heap.page_allocator.create(LoggerAllocatorType) catch unreachable;
        // 2) ptr が非 null であることが保証された上でデリファレンスして初期化
        ptr.* = LoggerAllocatorType.init(std.heap.page_allocator);
        // 3) global_logger_allocator に格納
        global_logger_allocator = ptr;
    }
}

pub export fn auto(
    // id: [*]u8,
    message: [*:0]const u8,
    level: LogLevel,
) void {
    if (global_logger_allocator) |allocator_ptr| {
        // var id_fixed: [3]u8 = .{ 0, 0, 0 };
        // @memcpy(&id_fixed, id);
        const msg_slice = std.mem.span(message);
        allocator_ptr.setMap(allocator_ptr.setLogger(allocator_ptr.createId(), msg_slice, level));
    }
}

// TODO id を取得するコードも作成する
pub export fn getLastLogger(
    out_key: *i64, // mapのキー
    out_id: [*]u8, // Logger構造体のidフィールド
    out_message: [*]u8, // メッセージ（constを外す！）
    out_message_size: usize, // Python側で確保したバッファサイズを追加
    out_level: *u32, // レベル
) bool {
    if (global_logger_allocator) |allocator_ptr| {
        const max_key = allocator_ptr.getMaxKey();
        if (max_key == 0) return false;
        if (allocator_ptr.getLogger(max_key)) |logger| {
            out_key.* = max_key;
            @memcpy(out_id, &logger.id);
            const msg_len = logger.entry.message.len;
            const copy_len = if (msg_len < out_message_size - 1) msg_len else out_message_size - 1;
            var i: usize = 0;
            while (i < copy_len) : (i += 1) {
                out_message[i] = logger.entry.message[i];
            }
            out_message[copy_len] = 0; // null-terminate
            out_level.* = @intFromEnum(logger.entry.level);
            return true;
        }
    }
    return false;
}

// 実行： zig run src/core.zig
pub fn main() !void {
    // インスタンスを作ってから呼び出す
    const allocator = std.heap.page_allocator;
    var logger_allocator = LoggerAllocator().init(allocator);
    // 例として、ログを追加
    // const AllocType = LoggerAllocator();
    logger_allocator.setMap(logger_allocator.setLogger(logger_allocator.createId(), "Hello, World!", LogLevel.Info));
    logger_allocator.setMap(logger_allocator.setLogger(logger_allocator.createId(), "Hello, World222!", LogLevel.Error));
    const get_logger = logger_allocator.getLastLogger();
    if (get_logger) |logger| {
        std.debug.print("Logger ID: {s}, Message: {s}, Level: {}\n", .{
            logger.id,
            logger.entry.message,
            @intFromEnum(logger.entry.level),
        });
    } else {
        std.debug.print("No logger found.\n", .{});
    }
}
