const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Environment = @import("./environment.zig");
const Callable = @import("./callable.zig");
const Stmt = @import("./ast/stmt.zig").Stmt;
const Expr = @import("./ast/expr.zig").Expr;

pub fn init() Callable {
    return Callable.init(.{
        .call = &call,
        .arity = &arity,
        .toString = &toString,
    });
}

fn arity(self: *const Callable) usize {
    return self.declaration.?.args.len;
}

fn call(self: *const Callable, interpreter: *Interpreter, args: *std.ArrayList(*const Interpreter.Value)) Interpreter.Value {
    //memleak ?
    var env = interpreter.allocator.create(Environment) catch unreachable;
    env.* = Environment.init(interpreter.allocator, self.closure.?);
    interpreter.environments.append(env) catch unreachable;
    env.debug = self.declaration.?.name.lexeme;

    for (args.items, 0..) |arg, i| {
        env.define(self.declaration.?.args[i].lexeme, arg.*) catch unreachable;
    }

    const return_value = interpreter.executeBlock(self.declaration.?.body, env) catch unreachable;

    return if (return_value) |val| switch (val) {
        .Return => |maybe_ret| if (maybe_ret) |ret| ret else Interpreter.Value{ .Nil = null },
        else => Interpreter.Value{ .Nil = null },
    } else Interpreter.Value{ .Nil = null };
}

fn toString(self: *const Callable) []const u8 {
    return self.declaration.?.name.lexeme;
}
