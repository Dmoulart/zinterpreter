const Expr = @import("expr.zig").Expr;
const Token = @import("../token.zig");

pub const Stmt = union(enum) {
    Block: Block,
    Expr: Expr,
    If: If,
    Print: Expr,
    Var: Var,

    pub const Block = struct {
        stmts: []*Stmt,
    };

    pub const If = struct {
        condition: Expr, // @todo : what is pointer what is not pointer ????
        then_branch: *Stmt,
        else_branch: ?*Stmt,
    };

    pub const Var = struct {
        name: Token,
        initializer: ?Expr,
    };
};
