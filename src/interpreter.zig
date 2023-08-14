const std = @import("std");
const Expr = @import("./ast/expr.zig").Expr;
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
};

pub fn interpret(expr: *const Expr) RuntimeError!Value {
    var val = try eval(expr);
    std.debug.print("\nval {}\n", .{val});
    return val;
}

fn eval(expr: *const Expr) RuntimeError!Value {
    return switch (expr.*) {
        .Literal => |*lit| literalCast(lit),
        .Grouping => try eval(expr),
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

// fn eval(expr: *const Expr) void {
//     var val = switch (expr.*) {
//         // inline .Literal => |*lit| switch (lit.*) {
//         //     .Integer => |int| int,
//         //     .Float => |float| float,
//         //     .String => |str| str,
//         // },
//         inline .Literal => |*lit| lit,
//         inline .Grouping => |*group| eval(group),
//         inline .Unary => |*unary| {
//             var right = eval(unary.right);
//             return switch (unary.*.op.type) {
//                 .BANG => !isTruthy(right),
//                 .MINUS => -right,
//                 else => null,
//             };
//         },
//         else => null,
//     };
//     _ = val;
// }

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
    _ = right;
    if (@as(Values, left) != Values.Number or @as(Values, left) != Values.Number) {
        report(operator.line, "", "Operands must be numbers");
        return RuntimeError.WrongOperandType;
    }
}
