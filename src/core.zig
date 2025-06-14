const std = @import("std");
const util = @import("util.zig");
const Struct = @import("struct.zig");

/// A thread-unsafe logger allocator for Python integration.
pub const LoggerAllocator = struct {
    allocator: std.mem.Allocator,
    map: std.AutoHashMap(i64, Struct.Logger),
    next_id: i64,

    /// Initialize a new LoggerAllocator.
    pub fn init(allocator: std.mem.Allocator) LoggerAllocator {
        return LoggerAllocator{
            .allocator = allocator,
            .map = std.AutoHashMap(i64, Struct.Logger).init(allocator),
            .next_id = 1,
        };
    }

    /// Generate the next numeric ID.
    fn nextId(self: *LoggerAllocator) i64 {
        const id = self.next_id;
        self.next_id += 1;
        return id;
    }

    /// Log a message at the given level. Allocates a copy of the message.
    pub fn log(self: *LoggerAllocator, message: []const u8, level: Struct.LogLevel) !void {
        const len = message.len;
        const buf = try self.allocator.alloc(u8, len);
        std.mem.copyForwards(u8, buf, message);

        const id = self.nextId();
        const logger = Struct.Logger{
            .id = util.toZeroPad3(id),
            .entry = Struct.LogEntry{ .message = buf, .level = level },
        };
        _ = try self.map.put(id, logger);
    }

    /// Return the latest (highest-key) logger entry.
    pub fn getLast(self: *LoggerAllocator, out_key: *i64, out_logger: *Struct.Logger) bool {
        if (self.map.count() == 0) return false;
        var maxKey: i64 = 0;
        var it = self.map.keyIterator();
        while (it.next()) |k| {
            if (k.* > maxKey) maxKey = k.*;
        }
        if (self.map.get(maxKey)) |logger| {
            out_key.* = maxKey;
            out_logger.* = logger;
            return true;
        }
        return false;
    }

    /// Retrieve a logger by its numeric key.
    pub fn get(self: *LoggerAllocator, key: i64) ?Struct.Logger {
        return self.map.get(key);
    }

    /// Expose the entire map (read-only copy).
    pub fn all(self: *LoggerAllocator) std.AutoHashMap(i64, Struct.Logger) {
        return self.map;
    }
};

var globalAlloc: ?*LoggerAllocator = null;

/// Initialize the global logger allocator on first use.
pub export fn init() void {
    if (globalAlloc == null) {
        const ptr = std.heap.page_allocator.create(LoggerAllocator) catch unreachable;
        ptr.* = LoggerAllocator.init(std.heap.page_allocator);
        globalAlloc = ptr;
    }
}

/// Python-callable auto-logging function.
pub export fn auto(
    message: [*:0]const u8,
    level: Struct.LogLevel,
) void {
    if (globalAlloc) |allocPtr| {
        allocPtr.log(std.mem.span(message), level) catch unreachable;
    }
}

/// Export the last logger entry back to Python.
pub export fn getLastLogger(
    out_key: *i64,
    out_id: [*]u8,
    out_message: [*]u8,
    out_message_size: usize,
    out_level: *u32,
) bool {
    if (globalAlloc) |allocPtr| {
        var logger: Struct.Logger = undefined;
        if (allocPtr.getLast(out_key, &logger)) {
            @memcpy(out_id, &logger.id);

            const msg = logger.entry.message;
            const copy_len = if (msg.len < out_message_size - 1) msg.len else out_message_size - 1;
            std.mem.copyForwards(u8, out_message[0..copy_len], msg[0..copy_len]);
            out_message[copy_len] = 0; // null terminate

            out_level.* = @intFromEnum(logger.entry.level);
            return true;
        }
    }
    return false;
}

/// Example standalone runner.
/// zig run src/core.zig
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var logAlloc = LoggerAllocator.init(allocator);

    try logAlloc.log("Hello, World!", Struct.LogLevel.Info);
    try logAlloc.log("Error occurred", Struct.LogLevel.Error);

    var out_key: i64 = 0;
    var out_logger: Struct.Logger = undefined;
    if (logAlloc.getLast(&out_key, &out_logger)) {
        std.debug.print("key: {s}, message: {s}, level {d}\n", .{
            util.toZeroPad3(out_key),
            out_logger.entry.message,
            @intFromEnum(out_logger.entry.level),
        });
    }
}
