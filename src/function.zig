const std = @import("std");
const Interpreter = @import("./interpreter.zig");
const Environment = @import("./environment.zig");
const Callable = @import("./callable.zig");
const Stmt = @import("./ast/stmt.zig").Stmt;
const Expr = @import("./ast/expr.zig").Expr;

declaration: *Stmt.Function,

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
    var env = Environment.init(interpreter.allocator, interpreter.global_environment);

    for (args.items, 0..) |arg, i| {
        env.define(self.declaration.?.args[i].lexeme, arg.*) catch unreachable;
    }

    const maybe_return = interpreter.executeBlock(self.declaration.?.body, &env) catch unreachable;

    const ret_val = if (maybe_return) |stmt| switch (stmt.*) {
        .Return => |ret| if (ret.value) |val| interpreter.eval(val) catch unreachable else null,
        else => null,
    } else null;

    return if (ret_val) |ret| ret else Interpreter.Value{ .Nil = null };
}

fn toString(self: *const Callable) []const u8 {
    return self.declaration.?.name.lexeme;
}
