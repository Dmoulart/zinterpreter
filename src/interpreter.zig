const std = @import("std");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;
const Token = @import("./token.zig");
const report = @import("./error-reporter.zig").report;

const RuntimeError = error{
    WrongOperandType,
};

pub const Values = enum {
    Nil,
    Boolean,
    Number,
    String,
};

pub const Value = union(Values) {
    Nil: ?bool, // Null here
    Boolean: bool,
    Number: f64,
    String: []const u8,

    pub fn stringify(self: *Value, buf: []u8) []const u8 {
        return switch (self.*) {
            .Nil => "nil",
            .Boolean => |boolean| if (boolean) "true" else "false",
            .Number => |number| std.fmt.bufPrint(buf, "{d}", .{number}) catch "Number Printing Error",
            .String => |string| string,
        };
    }
};

pub fn interpret(stmts: []const Stmt) RuntimeError!void {
    for (stmts) |*stmt| {
        _ = try execute(stmt);
    }
}

fn execute(stmt: *const Stmt) !void {
    switch (stmt.*) {
        .Print => |*print| {
            var val = try eval(print);
            var buf: [1024]u8 = undefined;
            std.debug.print("{s}", .{val.stringify(&buf)});
        },
        .Expr => |*expr| {
            _ = try eval(expr);
        },
    }
}

fn eval(expr: *const Expr) RuntimeError!Value {
    return switch (expr.*) {
        .Literal => |*lit| literalCast(lit),
        .Grouping => |*group| try eval(group.expr),
        .Unary => |*unary| {
            var right = try eval(unary.right);

            return switch (unary.op.type) {
                .BANG => .{ .Boolean = !isTruthy(right) },
                .MINUS => {
                    try checkNumberOperand(unary.op, right);
                    return .{ .Number = -right.Number };
                },
                else => .{ .Nil = null },
            };
        },
        .Binary => |*binary| {
            var left = try eval(binary.left);
            var right = try eval(binary.right);

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
                else => .{ .Nil = null }, // todo ?
            };
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
        else => {
            report(operator.line, "", "Operand must be a number");
            return RuntimeError.WrongOperandType;
        },
    };
}

fn checkNumberOperands(operator: Token, left: Value, right: Value) RuntimeError!void {
    if (@as(Values, left) != Values.Number or @as(Values, right) != Values.Number) {
        report(operator.line, "", "Operands must be numbers");
        return RuntimeError.WrongOperandType;
    }
}
