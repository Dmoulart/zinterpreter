const std = @import("std");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;
const Token = @import("./token.zig");
const report = @import("./error-reporter.zig").report;
const Environment = @import("./environment.zig");

const ErrorReporter = @import("./error-reporter.zig").ErrorReporter;
const Err = ErrorReporter(RuntimeError);

const Self = @This();

environment: *Environment,
environments: std.ArrayList(*Environment),
allocator: std.mem.Allocator,

pub const RuntimeError = error{
    WrongOperandType,
    UndefinedVariable,
    OutOfMemory,
    UninitializedVariable,
};

pub const Values = enum {
    Nil,
    Boolean,
    Number,
    String,
    Uninitialized,
};

pub const Value = union(Values) {
    Nil: ?bool, // Null here
    Boolean: bool,
    Number: f64,
    String: []const u8,
    Uninitialized: ?bool,

    pub fn stringify(self: *Value, buf: []u8) []const u8 {
        return switch (self.*) {
            .Nil => "nil",
            .Boolean => |boolean| if (boolean) "true" else "false",
            .Number => |number| std.fmt.bufPrint(buf, "{d}", .{number}) catch "Number Printing Error",
            .String => |string| string,
            .Uninitialized => "uninitialized",
        };
    }
};

pub fn init(allocator: std.mem.Allocator) !Self {
    var environments = std.ArrayList(*Environment).init(allocator);
    var global_environment = try allocator.create(Environment);
    global_environment.* = Environment.init(allocator, null);
    try environments.append(global_environment);

    return Self{
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

fn execute(self: *Self, stmt: *const Stmt) RuntimeError!void {
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
            var value: Value = if (var_stmt.initializer) |*initializer|
                try self.eval(initializer)
            else
                .{ .Uninitialized = null };

            self.environment.define(var_stmt.name.lexeme, value) catch |err| switch (err) {
                error.OutOfMemory => return Err.raise(&var_stmt.name, RuntimeError.OutOfMemory, "Out of memory"),
            };
        },
        .Block => |*block_stmt| {
            var new_environment = try self.allocator.create(Environment);
            new_environment.* = Environment.init(self.allocator, self.environment);

            try self.environments.append(new_environment);
            try self.executeBlock(block_stmt.stmts, new_environment);
        },
        .If => |*if_stmt| {
            var condition_value = try self.eval(&if_stmt.condition);
            if (isTruthy(condition_value)) {
                try self.execute(if_stmt.then_branch);
            } else if (if_stmt.else_branch) |else_branch| {
                try self.execute(else_branch);
            }
        },
        .While => |*while_stmt| {
            while (isTruthy(try self.eval(&while_stmt.condition))) {
                _ = try self.execute(while_stmt.body);
            }
        },
        .Break => {
            // self.environment = self.environment.enclosing.?;
        },
    }
}

fn executeBlock(self: *Self, stmts: []*Stmt, environment: *Environment) !void {
    var previous = self.environment;
    self.environment = environment;

    loop: for (stmts) |stmt| {
        switch (stmt.*) {
            .Break => {
                std.debug.print("break", .{});
                break :loop;
            },
            else => |*block_stmt| self.execute(block_stmt) catch |err| {
                self.environment = previous;
                return err;
            },
        }
    }

    self.environment = previous;
}

fn eval(self: *Self, expr: *const Expr) RuntimeError!Value {
    return switch (expr.*) {
        .Literal => |*lit| literalCast(lit),
        .Grouping => |*group| try self.eval(group.expr),
        .Unary => |*unary| {
            var right = try self.eval(unary.right);

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
            var value = self.environment.getOrFail(var_expr.name.lexeme) catch return Err.raise(
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
            var left = try self.eval(logical_expr.left);

            if (logical_expr.op.type == .OR) {
                if (isTruthy(left)) return left;
            } else {
                if (!isTruthy(left)) return left;
            }

            return try self.eval(logical_expr.right);
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
