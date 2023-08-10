const std = @import("std");
const Token = @import("../token.zig");
const Expr = @import("../ast/expr.zig").Expr;
const Self = @This();

pub const ParseError = error{
    MissingExpression,
    MissingRightParen,
};

tokens: *std.ArrayList(Token),
current: u32 = 0,

pub fn init(tokens: *std.ArrayList(Token)) Self {
    return Self{
        .tokens = tokens,
    };
}

pub fn parse(self: *Self) ParseError!Expr {
    return try self.expression();
}

fn expression(self: *Self) ParseError!Expr {
    return try self.equality();
}

fn equality(self: *Self) ParseError!Expr {
    var expr = try self.comparison();

    while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        expr = Expr{
            .Binary = .{
                .left = &expr,
                .op = self.previous().*,
                .right = &(try self.comparison()),
            },
        };
    }

    return expr;
}

fn comparison(self: *Self) ParseError!Expr {
    var expr = try self.term();

    while (self.match(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
        expr = Expr{
            .Binary = .{
                .left = &expr,
                .op = self.previous().*,
                .right = &(try self.term()),
            },
        };
    }
    return expr;
}

fn term(self: *Self) ParseError!Expr {
    var expr = try self.factor();

    while (self.match(&.{ .MINUS, .PLUS })) {
        expr = .{
            .Binary = .{
                .left = &expr,
                .op = self.previous().*,
                .right = &(try self.term()),
            },
        };
    }

    return expr;
}

fn factor(self: *Self) ParseError!Expr {
    var expr = try self.unary();
    while (self.match(&.{ .SLASH, .STAR })) {
        expr = Expr{
            .Binary = .{
                .left = &expr,
                .op = self.previous().*,
                .right = &(try self.term()),
            },
        };
    }
    return expr;
}

fn unary(self: *Self) ParseError!Expr {
    if (self.match(&.{ .BANG, .MINUS })) {
        return .{
            .Unary = .{
                .op = self.previous().*,
                .right = &(try self.term()),
            },
        };
    }

    return try self.primary();
}

fn match(self: *Self, comptime types: anytype) bool {
    inline for (types.*) |*tok_type| {
        if (self.check(@as(Token.Tokens, tok_type.*))) {
            _ = self.advance();
            return true;
        }
    }

    return false;
}

fn primary(self: *Self) !Expr {
    if (self.match(&.{.FALSE})) {
        return .{
            .Literal = .{
                .value = .{ .String = "false" },
            },
        };
    }

    if (self.match(&.{.TRUE})) {
        return .{
            .Literal = .{
                .value = .{ .String = "true" },
            },
        };
    }

    if (self.match(&.{.NIL})) {
        return .{
            .Literal = .{
                .value = .{ .String = "null" },
            },
        };
    }

    if (self.match(&.{.NUMBER})) {
        return .{
            .Literal = .{
                .value = .{ .Float = self.previous().type.NUMBER },
            },
        };
    }

    if (self.match(&.{.STRING})) {
        return .{
            .Literal = .{
                .value = .{ .String = self.previous().type.STRING },
            },
        };
    }

    if (self.match(&.{.LEFT_PAREN})) {
        var expr = try self.expression();

        _ = try self.consume(
            .RIGHT_PAREN,
            ParseError.MissingRightParen,
            "Expect ) after expression",
        );

        return .{
            .Grouping = .{
                .expr = &expr,
            },
        };
    }

    return ParseError.MissingExpression;
}

fn synchronize(self: *Self) ParseError!void {
    _ = self.advance();

    while (!self.isAtEnd()) {
        if (self.previous().type == .SEMICOLON) return;

        switch (self.peek().type) {
            .CLASS,
            .FUN,
            .VAR,
            .FOR,
            .IF,
            .WHILE,
            .PRINT,
            .RETURN,
            => return,
        }
        _ = self.advance();
    }
}

fn check(self: *Self, tok_type: Token.Tokens) bool {
    if (self.isAtEnd()) return false;

    return tok_type == @as(Token.Tokens, self.peek().type);
}

fn advance(self: *Self) *Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }

    return self.previous();
}

fn consume(self: *Self, tok_type: Token.Type, parse_err: ParseError, msg: []const u8) ParseError!*Token {
    if (self.check(tok_type)) return self.advance();

    std.debug.print("{s}", .{msg});

    return parse_err;
}

fn isAtEnd(self: *Self) bool {
    return self.peek().type == .EOF;
}

fn peek(self: *Self) *Token {
    return &self.tokens.items[self.current];
}

fn previous(self: *Self) *Token {
    return &self.tokens.items[self.current - 1];
}
