const Expr = @import("expr.zig").Expr;

pub const Stmt = union(enum) {
    expr: Expr,
    print: Expr,
};
