const std = @import("std");
const Callable = @import("./callable.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Interpreter = @import("./interpreter.zig");

const ClockImpl = struct {
    pub fn arity(self: *const Callable) usize {
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

const TypeOfImpl = struct {
    pub fn arity(self: *const Callable) usize {
        _ = self;
        return 1;
    }
    pub fn call(self: *const Callable, interpreter: *Interpreter, args: *std.ArrayList(*const Interpreter.Value)) Interpreter.Value {
        _ = self;
        _ = interpreter;
        var arg = args.items[0];
        var arg_type = switch (arg.*) {
            .Nil => "nil",
            .Boolean => "bool",
            .Number => "number",
            .String => "string",
            .Uninitialized => "uninitialized",
            .Callable => "callable",
        };
        return .{ .String = arg_type };
    }

    pub fn toString(self: *const Callable) []const u8 {
        _ = self;
        return "<native fn: typeof>";
    }
};

pub const TypeOf = Callable.init(.{
    .call = &TypeOfImpl.call,
    .arity = &TypeOfImpl.arity,
    .toString = &TypeOfImpl.toString,
});
