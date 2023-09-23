const std = @import("std");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;
const Token = @import("./token.zig");
const Callable = @import("./callable.zig");
const Function = @import("./function.zig");
const Globals = @import("./globals.zig");
const report = @import("./error-reporter.zig").report;
const Environment = @import("./environment.zig");

const ErrorReporter = @import("./error-reporter.zig").ErrorReporter;
const Err = ErrorReporter(RuntimeError);

const jsonPrint = @import("json-printer.zig").jsonPrint;

const Self = @This();

global_environment: *Environment,
environment: *Environment,
environments: std.ArrayList(*Environment),
allocator: std.mem.Allocator,

pub const RuntimeError = error{
    WrongOperandType,
    UndefinedVariable,
    OutOfMemory,
    UninitializedVariable,
    WrongNumberOfArguments,
    NonCallableExpression,
};

pub const Values = enum {
    Nil,
    Boolean,
    Number,
    String,
    Uninitialized,
    Callable,
};

pub const Value = union(Values) {
    Nil: ?bool, // Null here
    Boolean: bool,
    Number: f64,
    String: []const u8,
    Uninitialized: ?bool,
    Callable: Callable,

    pub fn stringify(self: *Value, buf: []u8) []const u8 {
        return switch (self.*) {
            .Nil => "nil",
            .Boolean => |boolean| if (boolean) "true" else "false",
            .Number => |number| std.fmt.bufPrint(buf, "{d}", .{number}) catch "Number Printing Error",
            .String => |string| string,
            .Uninitialized => "uninitialized",
            .Callable => "<callable value>",
        };
    }
};

pub fn init(allocator: std.mem.Allocator) !Self {
    var environments = std.ArrayList(*Environment).init(allocator);
    var global_environment = try allocator.create(Environment);
    global_environment.* = Environment.init(allocator, null);
    global_environment.debug = "global";
    try environments.append(global_environment);

    try global_environment.define("now", .{ .Callable = Globals.Clock });
    try global_environment.define("typeof", .{ .Callable = Globals.TypeOf });

    return Self{
        .global_environment = global_environment,
        .environment = global_environment,
        .environments = environments,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.environments.deinit();
}

pub fn interpret(self: *Self, stmts: []const *Stmt) RuntimeError!void {
    for (stmts) |stmt| {
        _ = try self.execute(stmt);
    }
}

fn execute(self: *Self, stmt: *const Stmt) RuntimeError!?*const Stmt {
    switch (stmt.*) {
        .Print => |*print| {
            var val = try self.eval(print);
            var buf: [1024]u8 = undefined;
            std.debug.print("{s}\n", .{val.stringify(&buf)});
        },
        .Expr => |*expr| {
            _ = try self.eval(expr);
        },
        .Var => |*var_stmt| {
            const value: Value = if (var_stmt.initializer) |*initializer|
                try self.eval(initializer)
            else
                .{ .Uninitialized = null };

            self.environment.define(var_stmt.name.lexeme, value) catch |err| switch (err) {
                error.OutOfMemory => return Err.raise(
                    &var_stmt.name,
                    RuntimeError.OutOfMemory,
                    "Out of memory",
                ),
            };
        },
        .Block => |*block_stmt| {
            var new_environment = try self.allocator.create(Environment);
            new_environment.* = Environment.init(self.allocator, self.environment);
            new_environment.debug = "block env";
            try self.environments.append(new_environment);
            _ = try self.executeBlock(block_stmt.stmts, new_environment);
        },
        .If => |*if_stmt| {
            const condition_value = try self.eval(&if_stmt.condition);
            if (isTruthy(condition_value)) {
                return try self.execute(if_stmt.then_branch);
            } else if (if_stmt.else_branch) |else_branch| {
                return try self.execute(else_branch);
            }
        },
        .While => |*while_stmt| {
            whileloop: while (isTruthy(try self.eval(&while_stmt.condition))) {
                var maybe_stmt = try self.execute(while_stmt.body);

                if (maybe_stmt) |executed_stmt| {
                    switch (executed_stmt.*) {
                        .Break => break :whileloop,
                        .Continue => {
                            _ = if (while_stmt.inc) |inc| try self.eval(inc) else null;
                            continue :whileloop;
                        },
                        else => {},
                    }
                }
                _ = if (while_stmt.inc) |inc| try self.eval(inc) else null;
            }
            return stmt;
        },
        .Function => |*function_stmt| {
            var function = Function.init();
            function.declaration = function_stmt;

            function.closure = self.environment;
            // function.closure = self.environment;
            try self.environment.define(function_stmt.name.?.lexeme, .{ .Callable = function });
            return stmt;
        },
        .Return => return stmt,
        .Break => return stmt,
        .Continue => return stmt,
    }
    return stmt;
}

const BlockInterruption = union(enum) {
    Break,
    Continue,
    Return: ?Value,
};

pub fn executeBlock(self: *Self, stmts: []*Stmt, environment: *Environment) !?BlockInterruption {
    var previous = self.environment;
    self.environment = environment;

    var interrupt_stmt: ?BlockInterruption = null;

    loop: for (stmts) |stmt| {
        var maybe_interrupt = self.execute(stmt) catch |err| {
            self.environment = previous;
            return err;
        };
        if (maybe_interrupt) |brk_stmt| {
            switch (brk_stmt.*) {
                .Break => {
                    interrupt_stmt = .Break;
                    break :loop;
                },
                .Continue => {
                    interrupt_stmt = .Continue;
                    break :loop;
                },
                .Return => |*return_stmt| {
                    if (return_stmt.value) |return_expr| {
                        const val = try self.eval(return_expr);
                        interrupt_stmt = .{ .Return = val };
                    }
                    break :loop;
                },
                else => {},
            }
        }
    }

    self.environment = previous;
    return interrupt_stmt;
}

pub fn eval(self: *Self, expr: *const Expr) RuntimeError!Value {
    // std.debug.print("\neval\n", .{});
    return switch (expr.*) {
        .Literal => |*lit| literalCast(lit),
        .Grouping => |*group| try self.eval(group.expr),
        .Unary => |*unary| {
            const right = try self.eval(unary.right);

            return switch (unary.op.type) {
                .BANG => .{ .Boolean = !isTruthy(right) },
                .MINUS => {
                    try checkNumberOperand(unary.op, right);
                    return .{ .Number = -right.Number };
                },
                // else => .{ .Nil = null },
                else => unreachable,
            };
        },
        .Binary => |*binary| {
            var left = try self.eval(binary.left);
            var right = try self.eval(binary.right);

            return switch (binary.op.type) {
                .EQUAL_EQUAL => .{ .Boolean = isEqual(left, right) },
                .BANG_EQUAL => .{ .Boolean = !isEqual(left, right) },
                .GREATER => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Boolean = left.Number > right.Number };
                },
                .GREATER_EQUAL => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Boolean = left.Number >= right.Number };
                },
                .LESS => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Boolean = left.Number < right.Number };
                },
                .LESS_EQUAL => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Boolean = left.Number <= right.Number };
                },
                .MINUS => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Number = left.Number - right.Number };
                },
                .PLUS => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Number = left.Number + right.Number };
                },
                .SLASH => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Number = left.Number / right.Number };
                },
                .STAR => {
                    try checkNumberOperands(binary.op, left, right);
                    return .{ .Number = left.Number * right.Number };
                },
                else => unreachable, // todo ? .{ .Nil = null }
            };
        },
        .Variable => |*var_expr| {
            const value = self.environment.getOrFail(var_expr.name.lexeme) catch return Err.raise(
                &var_expr.name,
                RuntimeError.UndefinedVariable,
                "Undefined variable",
            );

            return switch (value.*) {
                .Uninitialized => Err.raise(&var_expr.name, RuntimeError.UninitializedVariable, "Uninitialized variable"),
                else => value.*,
            };
        },
        .Assign => |*assign_expr| {
            const value = try self.eval(assign_expr.value);
            // @todo: runtime error reporting ?
            self.environment.assign(assign_expr.name.lexeme, value) catch return Err.raise(
                &assign_expr.name,
                RuntimeError.UndefinedVariable,
                "Undefined variable",
            );
            return value;
        },
        .Logical => |*logical_expr| {
            const left = try self.eval(logical_expr.left);

            if (logical_expr.op.type == .OR) {
                if (isTruthy(left)) return left;
            } else {
                if (!isTruthy(left)) return left;
            }

            return try self.eval(logical_expr.right);
        },
        .Lambda => |*lambda_expr| {
            var function = Function.init();
            var decl = try self.allocator.create(Stmt.Function);
            decl.* = .{
                .name = null,
                .body = lambda_expr.body,
                .args = lambda_expr.args,
            };
            function.declaration = decl;

            function.closure = self.environment;

            return .{ .Callable = function };
        },
        .Call => |*call_expr| {
            const function = switch (try self.eval(call_expr.callee)) {
                .Callable => |function| function,
                else => return Err.raise(
                    call_expr.paren,
                    RuntimeError.NonCallableExpression,
                    "Non callable expression",
                ),
            };

            var args = std.ArrayList(*const Value).init(self.allocator);
            for (call_expr.args) |arg| {
                try args.append(&(try self.eval(arg))); // <- big crap !!
            }

            if (args.items.len != function.arity(&function)) {
                return Err.raise(
                    call_expr.paren,
                    RuntimeError.WrongNumberOfArguments,
                    "Wrong number of arguments",
                );
            }
            var ret = function.call(&function, self, &args);
            args.deinit();
            return ret;
        },
    };
}

fn literalCast(lit: *const Expr.Literal) Value {
    return switch (lit.value) {
        .String => |str| .{ .String = str },
        .Integer => |int| .{ .Number = @as(f64, @floatFromInt(int)) },
        .Float => |float| .{ .Number = float },
        .Nil => .{ .Nil = null },
        .Boolean => |boolean| .{ .Boolean = boolean },
    };
}

fn isEqual(a: Value, b: Value) bool {
    if (@as(Values, a) != @as(Values, b)) return false;

    return switch (a) {
        .Nil => false,
        .Boolean => a.Boolean == b.Boolean,
        .String => std.mem.eql(u8, a.String, b.String),
        .Number => a.Number == b.Number,
        .Uninitialized => false,
        .Callable => false, //<-- todo
    };
}

fn isTruthy(val: Value) bool {
    return switch (val) {
        .Nil => false,
        .Boolean => |boolean| boolean,
        else => true,
    };
}

fn checkNumberOperand(operator: Token, operand: Value) RuntimeError!void {
    return switch (operand) {
        .Number => return,
        else => Err.raise(
            &operator,
            RuntimeError.WrongOperandType,
            "Operand must be a number",
        ),
    };
}

fn checkNumberOperands(operator: Token, left: Value, right: Value) RuntimeError!void {
    if (@as(Values, left) != Values.Number or @as(Values, right) != Values.Number) {
        return Err.raise(
            &operator,
            RuntimeError.WrongOperandType,
            "Operands must be a number",
        );
    }
}
