const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Self = @This();

const Call = *const fn (
    self: *const Self,
    interpreter: *Interpreter,
    args: *std.ArrayList(*const Interpreter.Value),
) Interpreter.Value;

arity: *const fn (
    self: *const Self,
) u8,
call: Call,
toString: *const fn (self: *Self) []const u8,

pub const Implementation = struct {
    arity: *const fn (
        self: *const Self,
    ) u8,
    call: Call,
    toString: *const fn (self: *const Self) []const u8,
};

pub fn init(comptime impl: Implementation) Self {
    return Self{
        .arity = impl.arity,
        .call = impl.call,
        .toString = impl.toString,
    };
}

pub fn call(
    self: *const Self,
    interpreter: *Interpreter,
    args: *std.ArrayList(*const Interpreter.Value),
) Interpreter.Value {
    self.impl.call(self, interpreter, args);
}

pub fn arity(self: *const Self) u8 {
    return self.impl.arity();
}

pub fn toString(self: *const Self) u8 {
    return self.impl.toString();
}