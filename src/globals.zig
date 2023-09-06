const std = @import("std");
const Callable = @import("./callable.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Interpreter = @import("./interpreter.zig");

const ClockImpl = struct {
    pub fn arity(self: *Callable) u8 {
        _ = self;
        return 0;
    }
    pub fn call(self: *Callable, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) i64 {
        _ = args;
        _ = interpreter;
        _ = self;

        return std.time.timestamp();
    }

    pub fn toString() []const u8 {
        return "<native fn>";
    }
};

pub const Clock = Callable.init(.{
    .call = ClockImpl.call,
    .arity = ClockImpl.arity,
    .toString = ClockImpl.toString,
});
