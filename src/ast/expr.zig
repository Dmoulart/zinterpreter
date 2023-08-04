const Token = @import("../token.zig");

pub const Expr = union(enum) {
    Binary: Binary,
    Grouping: Grouping,
    Literal: Literal,
    Unary: Unary,

    pub const Binary = struct {
        left: *const Expr,
        op: Token,
        right: *const Expr,
    };

    pub const Grouping = struct {
        expr: *const Expr,
    };

    pub const Literal = struct {
        value: []const u8,
    };

    pub const Unary = struct {
        op: Token,
        right: *const Expr,
    };
};
