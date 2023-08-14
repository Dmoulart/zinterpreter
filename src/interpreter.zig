const std = @import("std");
const Expr = @import("./ast/expr.zig").Expr;

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

pub fn interpret(expr: *const Expr) Value {
    var val = eval(expr);
    std.debug.print("\nval {}\n", .{val});
    return val;
}

fn eval(expr: *const Expr) Value {
    return switch (expr.*) {
        .Literal => |*lit| literalCast(lit),
        .Grouping => eval(expr),
        .Unary => |*unary| {
            var right = eval(unary.right);

            return switch (unary.*.op.type) {
                .BANG => .{ .Boolean = !isTruthy(right) },
                .MINUS => .{ .Number = -right.Number },
                else => .{ .Nil = null },
            };
        },
        .Binary => |*binary| {
            var left = eval(binary.left);
            var right = eval(binary.right);

            return switch (binary.op.type) {
                .EQUAL_EQUAL => .{ .Boolean = isEqual(left, right) },
                .BANG_EQUAL => .{ .Boolean = !isEqual(left, right) },
                .GREATER => .{ .Boolean = left.Number > right.Number },
                .GREATER_EQUAL => .{ .Boolean = left.Number >= right.Number },
                .LESS => .{ .Boolean = left.Number < right.Number },
                .LESS_EQUAL => .{ .Boolean = left.Number <= right.Number },
                .MINUS => .{ .Number = left.Number - right.Number },
                .PLUS => .{ .Number = left.Number + right.Number },
                .SLASH => .{ .Number = left.Number / right.Number },
                .STAR => .{ .Number = left.Number * right.Number },
                else => .{ .Nil = null }, // todo
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
