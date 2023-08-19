const Expr = @import("expr.zig").Expr;

pub const Stmt = union(enum) {
    Expr: Expr,
    Print: Expr,
};
