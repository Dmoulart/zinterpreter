const std = @import("std");
const print = std.debug.print;

pub fn report(line: u32, where: []const u8, msg: []const u8) void {
    print("\n[line {}] {s} : {s} ", .{ line, msg, where });
}
