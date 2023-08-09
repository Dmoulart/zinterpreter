const std = @import("std");
const Token = @import("../token.zig");
const Expr = @import("../ast/expr.zig").Expr;
const Self = @This();

const ParseError = error{
    Error,
};

tokens: *std.ArrayList(Token),
current: u32 = 0,

pub fn init(tokens: *std.ArrayList(Token)) Self {
    return Self{
        .tokens = tokens,
    };
}

pub fn parse(self: *Self) !Expr {
    return try self.expression();
}

fn expression(self: *Self) !Expr {
    return try self.equality();
}

fn equality(self: *Self) !Expr {
    var expr = try self.comparison();

    while (self.match(.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.comparison(),
        };
    }

    return expr;
}

fn comparison(self: *Self) !Expr {
    var expr = try self.term();
    while (self.match(.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn term(self: *Self) !Expr {
    var expr = try self.factor();
    while (self.match(.{ .MINUS, .PLUS })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn factor(self: *Self) !Expr {
    var expr = try self.unary();
    while (self.match(.{ .SLASH, .STAR })) {
        expr = Expr.Binary{
            .left = &expr,
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return expr;
}

fn unary(self: *Self) !Expr {
    if (self.match(.{ .BANG, .MINUS })) {
        return Expr.Unary{
            .op = self.previous(),
            .right = self.term(),
        };
    }
    return try self.primary();
}

fn match(self: *Self, comptime types: anytype) bool {
    inline for (types) |tok_type| {
        if (self.check(tok_type)) {
            _ = self.advance();
            return true;
        }
    }
    // for (types) |tok_type| {
    //     if (self.check(tok_type)) {
    //         _ = self.advance();
    //         return true;
    //     }
    // }

    return false;
}

fn primary(self: *Self) !Expr {
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
        // consume(RIGHT_PAREN, "Expect ')' after expression.");
        _ = self.consume(.RIGHT_PAREN, "Expect ) after expression") catch "err";
        return Expr.Grouping{
            .expr = &expr,
        };
    }

    // "Expect expression."
    return ParseError.Error;
}

fn synchronize(self: *Self) !void {
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

fn check(self: *Self, tok_type: Token.Type) bool {
    if (self.isAtEnd()) return false;
    // err : replace this crap by real enum member comparison
    return std.mem.eql(u8, @tagName(tok_type), @tagName(self.peek().type));
    // return @intToEnum(Token.Type, self.peek().type) == @intToEnum(Token.Type, tok_type);
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
