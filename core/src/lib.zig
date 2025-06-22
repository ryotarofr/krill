const std = @import("std");
const util = @import("util.zig");
const Struct = @import("struct.zig");
const Json = @import("json.zig");

pub export fn find(
    /// The JSON content as a byte slice
    /// e.g., "./dist/logger_output.json"
    json_ptr: [*]const u8,
    json_len: usize,
    /// The key to search for in the JSON object
    /// e.g., "API_ROOT_ID"
    key_ptr: [*]const u8,
    key_len: usize,
    /// The subkey to search for in the nested JSON object
    /// e.g., "debug message"
    subkey_ptr: [*]const u8,
    subkey_len: usize,
    /// The output buffer to store the found value
    /// The buffer should be large enough to hold the expected value
    /// e.g., a buffer of size 256 bytes
    /// The buffer will be null-terminated
    /// e.g., [256]u8
    out_buf: [*]u8,
    out_buf_len: usize,
) bool {
    const allocator = std.heap.page_allocator;
    const json_bytes = json_ptr[0..json_len];
    const key = key_ptr[0..key_len];
    const subkey = subkey_ptr[0..subkey_len];

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{}) catch return false;
    defer parsed.deinit();

    if (parsed.value == .object) {
        var it = parsed.value.object.iterator();
        while (it.next()) |entry| {
            const k = entry.key_ptr.*;
            const v = entry.value_ptr.*;
            if (std.mem.eql(u8, k, key) and v == .object) {
                var subit = v.object.iterator();
                while (subit.next()) |subentry| {
                    const sk = subentry.key_ptr.*;
                    const sv = subentry.value_ptr.*;
                    if (std.mem.eql(u8, sk, subkey) and sv == .string) {
                        const val = sv.string;
                        const copy_len = if (val.len < out_buf_len - 1) val.len else out_buf_len - 1;
                        std.mem.copyForwards(u8, out_buf[0..copy_len], val[0..copy_len]);
                        out_buf[copy_len] = 0; // null terminate
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

test "find_json_value returns correct value" {
    const allocator = std.testing.allocator;
    const json_path = "./dist/logger_output.json";
    const json_bytes = try util.readJsonFile(allocator, json_path);
    defer allocator.free(json_bytes);

    const key = "API_ROOT_ID";
    const subkey = "debug message";
    var out_buf: [256]u8 = undefined;

    const found = find(json_bytes.ptr, json_bytes.len, key.ptr, key.len, subkey.ptr, subkey.len, &out_buf, out_buf.len);

    try std.testing.expect(found);

    if (found) {
        const result = out_buf[0..std.mem.indexOfScalar(u8, &out_buf, 0).?];
        try std.testing.expectEqualStrings("001", result);
    }
}

pub export fn toJson(
    /// The path to the Python file that contains the logger
    /// e.g., "./test/logger.py"
    pyfile_ptr: [*]const u8,
    pyfile_len: usize,
    /// The path where the output JSON file will be saved
    /// e.g., "./dist/logger_output.json"
    output_path_ptr: [*]const u8,
    output_path_len: usize,
    /// The prefix for the logger, e.g., "logger"
    prefix: [*]const u8,
    prefix_len: usize,
    /// The target log level, e.g., ["debug", "info", "warning", etc.].
    target_loglevel: [*]const [*]const u8,
    target_loglevel_len: usize,
    /// Whether the logger is running in a Lambda environment
    env_identifier: bool,
) void {
    const runner = Json.LoggerRunner{
        .pyfile = pyfile_ptr[0..pyfile_len],
        .output_path = output_path_ptr[0..output_path_len],
        .prefix = prefix[0..prefix_len],
        .target_loglevel = target_loglevel[0..target_loglevel_len],
        .is_lambda = env_identifier,
    };
    runner.run();
}

test "toJson generates logger_output.json" {
    const pyfile = "./test/logger.py";
    const output_path = "./dist/logger_output.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    // try target_loglevel.append("debug".ptr);
    // try target_loglevel.append("info".ptr);
    const env_identifier = true;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output2.json" {
    const pyfile = "./test/logger.py";
    const output_path = "./dist/logger_output2.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    // try target_loglevel.append("debug".ptr);
    // try target_loglevel.append("info".ptr);
    const env_identifier = false;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output3.json" {
    const pyfile = "./test/logger.py";
    const output_path = "./dist/logger_output3.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    try target_loglevel.append("debug".ptr);
    try target_loglevel.append("info".ptr);
    const env_identifier = true;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output4.json" {
    const pyfile = "./test/logger.py";
    const output_path = "./dist/logger_output4.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    try target_loglevel.append("debug".ptr);
    try target_loglevel.append("info".ptr);
    const env_identifier = false;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output5.json" {
    const pyfile = "./test";
    const output_path = "./dist/logger_output5.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    // try target_loglevel.append("debug".ptr);
    // try target_loglevel.append("info".ptr);
    const env_identifier = true;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output6.json" {
    const pyfile = "./test";
    const output_path = "./dist/logger_output6.json";
    const prefix = "logger";
    var target_loglevel = std.ArrayList([*]const u8).init(std.testing.allocator);
    defer target_loglevel.deinit();
    // try target_loglevel.append("debug".ptr);
    // try target_loglevel.append("info".ptr);
    const env_identifier = false;
    toJson(pyfile.ptr, pyfile.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, target_loglevel.items.ptr, target_loglevel.items.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

pub fn main() !void {}
