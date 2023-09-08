const std = @import("std");
const Callable = @import("./callable.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Interpreter = @import("./interpreter.zig");

const ClockImpl = struct {
    pub fn arity(self: *const Callable) u8 {
        _ = self;
        return 0;
    }
    pub fn call(self: *const Callable, interpreter: *Interpreter, args: *std.ArrayList(*const Interpreter.Value)) Interpreter.Value {
        _ = args;
        _ = interpreter;
        _ = self;

        return .{ .Number = @as(f64, @floatFromInt(std.time.timestamp())) };
    }

    pub fn toString(self: *const Callable) []const u8 {
        _ = self;
        return "<native fn>";
    }
};

pub const Clock = Callable.init(.{
    .call = &ClockImpl.call,
    .arity = &ClockImpl.arity,
    .toString = &ClockImpl.toString,
});

