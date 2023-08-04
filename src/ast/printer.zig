const std = @import("std");
const Expr = @import("expr.zig").Expr;

var buffer: [1024]u8 = undefined;

pub fn print(expr: anytype) []const u8 {
    if (@TypeOf(expr) == *const Expr or @TypeOf(expr) == *Expr) {
        return switch (expr.*) {
            inline .Binary => |*val| printBinary(val) catch "![print error]!",
            inline .Grouping => |*val| printGrouping(val) catch "![print error]!",
            inline .Literal => |*val| printLiteral(val) catch "![print error]!",
            inline .Unary => |*val| printUnary(val) catch "![print error]!",
        };
    } else {
        std.debug.print("typeof expr {}", .{@TypeOf(expr)});
        // @compileError("Cannot print non expression");
        return "faffff";
    }
}

pub fn printBinary(expr: *const Expr.Binary) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &[_]*const Expr{ expr.left, expr.right },
        &buffer,
    );
}

pub fn printGrouping(expr: *const Expr.Grouping) ![]const u8 {
    return try parenthesize(
        "Group",
        &[_]*const Expr{expr.expr},
        &buffer,
    );
}

pub fn printLiteral(expr: *const Expr.Literal) ![]const u8 {
    return try parenthesize(
        "Group",
        &[_]*const Expr.Literal{expr},
        &buffer,
    );
}

pub fn printUnary(expr: *const Expr.Unary) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &[_]*const Expr{expr.right},
        &buffer,
    );
}

fn parenthesize(name: []const u8, exprs: anytype, buf: []u8) ![]const u8 {
    var buf_count: usize = 0;

    const inner = for (exprs) |expr| {
        var log = print(expr);
        var log_i: usize = 0;
        while (log_i <= log.len - 1) : (log_i += 1) {
            buf[buf_count + log_i] = log[log_i];
        }
        buf[buf_count + log.len + 1] = '_';
        buf_count += log.len + 1;
    } else buf[0..buf_count];

    return try std.fmt.bufPrintZ(buf, "({s} {s} )", .{ name, inner });
}
