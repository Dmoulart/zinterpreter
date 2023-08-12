const std = @import("std");
const Expr = @import("expr.zig").Expr;

var buffer: [1024]u8 = undefined;

pub fn print(expr: *const Expr, buf: []u8) []const u8 {
    return switch (expr.*) {
        inline .Binary => |*val| printBinary(val, buf),
        inline .Grouping => |*val| printGrouping(val, buf),
        inline .Literal => |*val| printLiteral(val, buf),
        inline .Unary => |*val| printUnary(val, buf),
    } catch "AST_Printer error";
}

pub fn printBinary(expr: *const Expr.Binary, buf: []u8) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &.{ expr.left, expr.right },
        buf,
    );
}

pub fn printGrouping(expr: *const Expr.Grouping, buf: []u8) ![]const u8 {
    return try parenthesize(
        "Group",
        &.{expr.expr},
        buf,
    );
}

pub fn printLiteral(expr: *const Expr.Literal, buf: []u8) ![]const u8 {
    return switch (expr.value) {
        inline .String => |val| val,
        inline .Integer, .Float => |val| try std.fmt.bufPrintZ(buf, "{d}", .{val}),
    };
}

pub fn printUnary(expr: *const Expr.Unary, buf: []u8) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &.{
            expr.right,
        },
        buf,
    );
}

fn parenthesize(name: []const u8, exprs: []const *const Expr, buf: []u8) ![]const u8 {
    var str = std.ArrayList(u8).init(std.heap.page_allocator);

    const inner = for (exprs) |expr|
        try str.appendSlice(print(expr, buf))
    else
        try str.toOwnedSlice();

    return try std.fmt.bufPrintZ(buf, "({s} {s})", .{ name, inner });
}
