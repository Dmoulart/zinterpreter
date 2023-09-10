const std = @import("std");
const StringHashMap = std.hash_map.StringHashMap;
const Value = @import("interpreter.zig").Value;
const RuntimeError = @import("interpreter.zig").RuntimeError;
const Self = @This();

values: StringHashMap(Value),

enclosing: ?*Self,
debug: []const u8 = "",

pub fn init(allocator: std.mem.Allocator, enclosing: ?*Self) Self {
    return .{
        .values = StringHashMap(Value).init(allocator),
        .enclosing = enclosing,
    };
}

pub fn getOrFail(self: *Self, name: []const u8) RuntimeError!*Value {
    return self.values.getPtr(name) orelse if (self.enclosing) |enclosing| enclosing.getOrFail(name) else RuntimeError.UndefinedVariable;
}

pub fn define(self: *Self, name: []const u8, value: Value) !void {
    try self.values.put(name, value);
}

pub fn assign(self: *Self, name: []const u8, value: Value) RuntimeError!void {
    if (self.values.contains(name)) {
        try self.values.put(name, value);
    } else if (self.enclosing) |enclosing| {
        try enclosing.assign(name, value);
    } else {
        return RuntimeError.UndefinedVariable;
    }
}
