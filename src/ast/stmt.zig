const Expr = @import("expr.zig").Expr;
const Token = @import("../token.zig");

pub const Stmt = union(enum) {
    Block: Block,
    Expr: Expr,
    Function: Function,
    If: If,
    Print: Expr,
    Var: Var,
    While: While,
    Break: Break,
    Continue: Continue,

    pub const Block = struct {
        stmts: []*Stmt,
    };

    pub const Function = struct {
        name: Token,
        args: []Token,
        body: []*Stmt,
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

    pub const While = struct {
        condition: Expr,
        body: *Stmt,
        inc: ?*Expr,
    };

    pub const Break = struct {};

    pub const Continue = struct {};
};
