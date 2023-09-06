const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Self = @This();

arity: *const fn () u8,
call: *const fn (self: *Self, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) void,
toString: *const fn () []const u8,

pub const Implementation = struct {
    arity: *const fn () u8,
    call: *const fn (self: *Self, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) void,
    toString: *const fn () []const u8,
};

pub fn init(comptime impl: Implementation) Self {
    return Self{
        .arity = impl.arity,
        .call = impl.call,
        .toString = impl.toString,
    };
}

pub fn call(self: *Self, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) void {
    self.impl.call(self, interpreter, args);
}

pub fn arity(self: *Self) u8 {
    return self.impl.arity();
}

pub fn toString(self: *Self) u8 {
    return self.impl.toString();
}

// pub fn call(self: *Self, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) void {
//     _ = args;
//     _ = interpreter;
//     _ = self;
// }

// pub fn arity() u8 {
//     return 0;
// }

// pub fn Callable(comptime impl: Implementation) type {
//     return struct {
//         const Self = @This();

//         pub fn call(self: *Self, interpreter: *Interpreter, args: *std.ArrayList(*Expr)) void {
//             impl.call(self, interpreter, args);
//         }

//         pub fn arity() u8 {
//             return impl.arity();
//         }

//         pub fn toString() u8 {
//             return impl.toString();
//         }
//     };
// }
