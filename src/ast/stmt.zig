const Expr = @import("expr.zig").Expr;
const Token = @import("../token.zig");

pub const Stmt = union(enum) {
    Block: Block,
    Expr: Expr,
    Print: Expr,
    Var: Var,

    pub const Block = struct {
        stmts: []*Stmt,
    };

    pub const Var = struct {
        name: Token,
        initializer: ?Expr,
    };
};
