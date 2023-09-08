const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Callable = @import("./callable.zig");
const Stmt = @import("./ast/stmt.zig").Stmt;
const Expr = @import("./ast/expr.zig").Expr;
// usingnamespace Callable;

declaration: *Stmt.Function,
// callable: Callable,

fn createFunction(declaration: *Stmt.Function) type {
    _ = declaration;
    return struct {
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
}

const Function = struct {
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

// pub const Clock = Callable.init(.{
//     .call = &ClockImpl.call,
//     .arity = &ClockImpl.arity,
//     .toString = &ClockImpl.toString,
// });
