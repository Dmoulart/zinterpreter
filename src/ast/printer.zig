const std = @import("std");
const Expr = @import("expr.zig").Expr;

var buffer: [1024]u8 = undefined;

pub fn print(expr: *const Expr, buf: []u8) []const u8 {
    return switch (expr.*) {
        inline .Binary => |*val| printBinary(val, buf),
        inline .Grouping => |*val| printGrouping(val, buf),
        inline .Literal => |*val| printLiteral(val, buf),
        inline .Unary => |*val| printUnary(val, buf),
    } catch "Print error";
}

pub fn printBinary(expr: *const Expr.Binary, buf: []u8) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &[_]*const Expr{ expr.left, expr.right },
        buf,
    );
}

pub fn printGrouping(expr: *const Expr.Grouping, buf: []u8) ![]const u8 {
    return try parenthesize(
        "Group",
        &[_]*const Expr{expr.expr},
        buf,
    );
}

pub fn printLiteral(expr: *const Expr.Literal, buf: []u8) []const u8 {
    _ = buf;
    return expr.value;
}

pub fn printUnary(expr: *const Expr.Unary, buf: []u8) ![]const u8 {
    return try parenthesize(
        expr.op.lexeme,
        &[_]*const Expr{
            expr.right,
        },
        buf,
    );
}

fn parenthesize(name: []const u8, exprs: []*const Expr, buf: []u8) ![]const u8 {
    var str = std.ArrayList(u8).init(std.heap.page_allocator);

    const inner = for (exprs) |expr| {
        var info = print(expr, buf);

        try str.appendSlice(info);
    } else str.toOwnedSlice();
    // var log_i: usize = 0;
    // // while (log_i <= log.len - 1) : (log_i += 1) {
    // //     buf[buf_count + log_i] = log[log_i];
    // // }
    //     buf[buf_count + log.len + 1] = '_';
    //     buf_count += log.len + 1;
    // } else buf[0..buf_count];

    return try std.fmt.bufPrintZ(buf, "({s} {s})", .{ name, inner });
}
