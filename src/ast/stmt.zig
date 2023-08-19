const Expr = @import("expr.zig").Expr;
const Token = @import("../token.zig");

pub const Stmt = union(enum) {
    Expr: Expr,
    Print: Expr,
    Var: Var,

    pub const Var = struct {
        name: Token,
        initializer: ?Expr,
    };
};
