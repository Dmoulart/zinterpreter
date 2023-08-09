const std = @import("std");
const Token = @import("../token.zig");
const Expr = @import("../ast/expr.zig").Expr;
const Self = @This();

tokens: *std.ArrayList(Token),
current: u32,

pub const ParseError = error{
    Error,
};

fn expression(self: *Self) Expr {
    return self.equality();
}

fn equality(self: *Self) Expr {
    var expr = self.comparison();
    while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.comparison(),
        };
    }
    return expr;
}

fn comparison(self: *Self) Expr {
    var expr = self.term();
    while (self.match(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn term(self: *Self) Expr {
    var expr = self.factor();
    while (self.match(&.{ .MINUS, .PLUS })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn factor(self: *Self) Expr {
    var expr = self.unary();
    while (self.match(&.{ .SLASH, .STAR })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn unary(self: *Self) Expr {
    if (self.match(&.{ .BANG, .MINUS })) {
        return Expr.Unary{
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return self.primary();
}

fn match(self: *Self, types: []Token.Type) bool {
    for (types) |tok_type| {
        if (self.check(tok_type)) {
            self.advance();
            return true;
        }
    }

    return false;
}

fn primary(self: *Self) Expr {
    if (self.match(&.{.FALSE})) {
        return Expr.Literal{
            .value = .{ .String = "false" },
        };
    }

    if (self.match(&.{.TRUE})) {
        return Expr.Literal{
            .value = .{ .String = "true" },
        };
    }

    if (self.match(&.{.NIL})) {
        return Expr.Literal{
            .value = .{ .String = "null" },
        };
    }

    // if (self.match(&.{.NUMBER})) {
    //     return Expr.Literal{
    //         .value = .{ .Number = self.previous() },
    //     };
    // }

    // if (self.match(&.{.String})) {
    //     return Expr.Literal{
    //         .value = .{ .Number = self.previous() },
    //     };
    // }

    // ...

    if (self.match(&.{.LEFT_PAREN})) {
        var expr = self.expression();
        return Expr.Grouping{
            .expr = &expr,
        };
    }
}

fn check(self: *Self, tok_type: Token.Type) bool {
    if (self.isAtEnd()) return false;
    return self.peek().type == tok_type;
}

fn advance(self: *Self) *Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }
    return self.previous();
}

fn consume(self: *Self, tok_type: Token.Type, msg: []const u8) !Token {
    if (self.check(tok_type)) return self.advance();

    std.debug.print("{}", .{msg});
    return ParseError.Error;
    // throw error(peek(), message);
}

fn isAtEnd(self: *Self) bool {
    return self.peek().type == .EOF;
}

fn peek(self: *Self) bool {
    return self.tokens.get(self.current);
}

fn previous(self: *Self) *Token {
    return &self.tokens.get(self.current - 1);
}
