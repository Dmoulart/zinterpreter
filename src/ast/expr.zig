const Token = @import("../token.zig");

pub const Expr = union(enum) {
    Binary: Binary,
    Grouping: Grouping,
    Literal: Literal,
    Unary: Unary,
    Variable: Variable,

    pub const Binary = struct {
        left: *const Expr,
        op: Token,
        right: *const Expr,
    };

    pub const Grouping = struct {
        expr: *const Expr,
    };

    pub const Literal = struct {
        const Value = union(enum) {
            String: []const u8,
            Integer: i64,
            Float: f64,
            Boolean: bool,
            Nil: ?bool, // what type should we use to represent null values ?
        };

        value: Value,
    };

    pub const Unary = struct {
        op: Token,
        right: *const Expr,
    };

    pub const Variable = struct {
        name: Token,
    };
};
