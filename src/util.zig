const std = @import("std");

pub fn toZeroPad3(n: i64) [3]u8 {
    var buf: [3]u8 = undefined;
    var value = n;
    if (value < 0) value = 0;
    buf[0] = @as(u8, @intCast(@rem(@divTrunc(value, 100), 10))) + '0';
    buf[1] = @as(u8, @intCast(@rem(@divTrunc(value, 10), 10))) + '0';
    buf[2] = @as(u8, @intCast(@rem(value, 10))) + '0';
    return buf;
}
