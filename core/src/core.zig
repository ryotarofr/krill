const std = @import("std");
const util = @import("util.zig");
const Struct = @import("struct.zig");

pub fn parseJsonContent(allocator: std.mem.Allocator, json_bytes: []const u8) !void {
    var stream = std.json.TokenStream.init(json_bytes);
    const root = try std.json.parseFromTokenStream(std.json.Value, &stream, allocator);
    defer root.deinit();

    if (root.value != .Object) return error.InvalidJsonFormat;

    const obj = root.value.Object;
    for (obj.entries) |entry| {
        std.debug.print("key: {s}, value: {}\n", .{ entry.key, entry.value });
    }
}
