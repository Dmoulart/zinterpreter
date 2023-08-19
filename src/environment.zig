const std = @import("std");
const StringHashMap = std.hash_map.StringHashMap;
const Value = @import("interpreter.zig").Value;
const RuntimeError = @import("interpreter.zig").RuntimeError;
const Self = @This();

values: StringHashMap(Value),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .values = StringHashMap(Value).init(allocator) };
}

pub fn getOrFail(self: *Self, name: []const u8) RuntimeError!*Value {
    return self.values.getPtr(name) orelse RuntimeError.UndefinedVariable;
}

pub fn define(self: *Self, name: []const u8, value: Value) !void {
    try self.values.put(name, value);
}
