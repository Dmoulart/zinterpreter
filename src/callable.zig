const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;
const Self = @This();

const Call = *const fn (
    self: *const Self,
    interpreter: *Interpreter,
    args: *std.ArrayList(*const Interpreter.Value),
) Interpreter.Value;

const Arity = *const fn (
    self: *const Self,
) usize;

const ToString = *const fn (self: *Self) []const u8;

arity: Arity,
call: Call,
declaration: ?*const Stmt.Function,

toString: ToString,

pub const Implementation = struct {
    arity: Arity,
    call: Call,
    toString: ToString,
    declaration: ?*const Stmt.Function = null,
};

pub fn init(comptime impl: Implementation) Self {
    return Self{
        .arity = impl.arity,
        .call = impl.call,
        .toString = impl.toString,
        .declaration = impl.declaration,
    };
}

pub fn call(
    self: *const Self,
    interpreter: *Interpreter,
    args: *std.ArrayList(*const Interpreter.Value),
) Interpreter.Value {
    self.impl.call(self, interpreter, args);
}

pub fn arity(self: *const Self) usize {
    return self.impl.arity();
}

pub fn toString(self: *const Self) u8 {
    return self.impl.toString();
}
