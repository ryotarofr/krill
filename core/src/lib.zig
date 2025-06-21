const std = @import("std");
const util = @import("util.zig");
const Struct = @import("struct.zig");
const Json = @import("json.zig");

pub export fn find(
    json_ptr: [*]const u8,
    json_len: usize,
    key_ptr: [*]const u8,
    key_len: usize,
    subkey_ptr: [*]const u8,
    subkey_len: usize,
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

    if (found) {
        const result = out_buf[0..std.mem.indexOfScalar(u8, &out_buf, 0).?];
        try std.testing.expectEqualStrings("001", result);
    } else {
        try std.testing.expect(false);
    }
}

pub export fn toJson(
    pyfile_ptr: [*]const u8,
    pyfile_len: usize,
    root_id_ptr: [*]const u8,
    root_id_len: usize,
    output_path_ptr: [*]const u8,
    output_path_len: usize,
    prefix: [*]const u8,
    prefix_len: usize,
    /// Whether the logger is running in a Lambda environment
    env_identifier: bool,
) void {
    const runner = Json.LoggerRunner{
        .pyfile = pyfile_ptr[0..pyfile_len],
        .root_id = root_id_ptr[0..root_id_len],
        .output_path = output_path_ptr[0..output_path_len],
        .prefix = prefix[0..prefix_len],
        .is_lambda = env_identifier,
    };
    runner.run();
}

test "toJson generates logger_output.json" {
    const pyfile = "./test/logger.py";
    const root_id = "API_ROOT_ID";
    const output_path = "./dist/logger_output.json";
    const prefix = "logger";
    const env_identifier = true;
    toJson(pyfile.ptr, pyfile.len, root_id.ptr, root_id.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

test "toJson generates logger_output2.json" {
    const pyfile = "./test/logger.py";
    const root_id = "API_ROOT_ID";
    const output_path = "./dist/logger_output2.json";
    const prefix = "logger";
    const env_identifier = false;
    toJson(pyfile.ptr, pyfile.len, root_id.ptr, root_id.len, output_path.ptr, output_path.len, prefix.ptr, prefix.len, env_identifier);
    const allocator = std.testing.allocator;
    const file = try std.fs.cwd().openFile(output_path, .{});
    defer file.close();
    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);
    try std.testing.expect(content.len > 0);
}

pub fn main() !void {}
