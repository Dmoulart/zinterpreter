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
        pub const Value = union(enum) {
            String: []const u8,
            Integer: i64,
            Float: f64,
        };

        value: Value,
    };

    pub const Unary = struct {
        op: Token,
        right: *const Expr,
    };
};
