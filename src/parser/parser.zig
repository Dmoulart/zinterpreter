const std = @import("std");
const report = @import("../error-reporter.zig").report;
const Token = @import("../token.zig");
const Expr = @import("../ast/expr.zig").Expr;

const Self = @This();

pub const ParseError = error{
    OutOfMemory, // not a parse error i know...
    MissingExpression,
    MissingRightParen,
};

tokens: []Token,
current: u32 = 0,

allocator: std.mem.Allocator,

exprs: std.ArrayList(Expr),

pub fn init(tokens: []Token, allocator: std.mem.Allocator) Self {
    return Self{
        .tokens = tokens,
        .allocator = allocator,
        .exprs = std.ArrayList(Expr).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.exprs.deinit();
}

pub fn parse(self: *Self) ParseError!*Expr {
    return try self.expression();
}

fn expression(self: *Self) ParseError!*Expr {
    return try self.equality();
}

fn equality(self: *Self) ParseError!*Expr {
    var expr = try self.comparison();

    while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        expr = try self.create(.{
            .Binary = .{
                .left = expr,
                .op = self.previous().*,
                .right = (try self.comparison()),
            },
        });
    }

    return expr;
}

fn comparison(self: *Self) ParseError!*Expr {
    var expr = try self.term();

    while (self.match(&.{ .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL })) {
        expr = try self.create(.{
            .Binary = .{
                .left = expr,
                .op = self.previous().*,
                .right = (try self.term()),
            },
        });
    }
    return expr;
}

fn term(self: *Self) ParseError!*Expr {
    var expr = try self.factor();

    while (self.match(&.{ .MINUS, .PLUS })) {
        expr = try self.create(.{
            .Binary = .{
                .left = expr,
                .op = self.previous().*,
                .right = (try self.term()),
            },
        });
    }

    return expr;
}

fn factor(self: *Self) ParseError!*Expr {
    var expr = try self.unary();

    while (self.match(&.{ .SLASH, .STAR })) {
        expr = try self.create(.{
            .Binary = .{
                .left = expr,
                .op = self.previous().*,
                .right = (try self.term()),
            },
        });
    }
    return expr;
}

fn unary(self: *Self) ParseError!*Expr {
    if (self.match(&.{ .BANG, .MINUS })) {
        return try self.create(.{
            .Unary = .{
                .op = self.previous().*,
                .right = (try self.term()),
            },
        });
    }

    return try self.primary();
}

fn match(self: *Self, comptime types: anytype) bool {
    inline for (types.*) |*token_type| {
        if (self.check(@as(Token.Tokens, token_type.*))) {
            _ = self.advance();
            return true;
        }
    }

    return false;
}

fn primary(self: *Self) !*Expr {
    if (self.match(&.{.FALSE})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .String = "false" },
            },
        });
    }

    if (self.match(&.{.TRUE})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .String = "true" },
            },
        });
    }

    if (self.match(&.{.NIL})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .String = "null" },
            },
        });
    }

    if (self.match(&.{.NUMBER})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .Float = self.previous().type.NUMBER },
            },
        });
    }

    if (self.match(&.{.STRING})) {
        return try self.create(.{
            .Literal = .{
                .value = .{
                    .String = self.previous().type.STRING,
                },
            },
        });
    }

    if (self.match(&.{.LEFT_PAREN})) {
        var expr = try self.expression();

        _ = try self.consume(
            .RIGHT_PAREN,
            ParseError.MissingRightParen,
            "Expect ) after expression",
        );

        return try self.create(.{
            .Grouping = .{
                .expr = expr,
            },
        });
    }

    return ParseError.MissingExpression;
}

fn create(self: *Self, expr: anytype) std.mem.Allocator.Error!*Expr {
    var ptr = self.exprs.addOne() catch return ParseError.OutOfMemory;
    ptr.* = expr;
    return ptr;
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

fn check(self: *Self, token_type: Token.Tokens) bool {
    if (self.isAtEnd()) return false;
    // std.debug.print(
    //     "\n- token_type {any} match peek {any} : {any}\n",
    //     .{ token_type, self.peek(), token_type == @as(
    //         Token.Tokens,
    //         self.peek().type,
    //     ) },
    // );
    return token_type == @as(Token.Tokens, self.peek().type);
}

fn advance(self: *Self) *Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }

    return self.previous();
}

fn consume(self: *Self, token_type: Token.Type, parse_err: ParseError, comptime msg: []const u8) ParseError!*Token {
    if (self.check(token_type)) return self.advance();

    var curr_tok = self.peek();
    report(curr_tok.line, curr_tok.lexeme, msg);

    return parse_err;
}

fn isAtEnd(self: *Self) bool {
    return self.peek().type == .EOF;
}

fn peek(self: *Self) *Token {
    return &self.tokens[self.current];
}

fn previous(self: *Self) *Token {
    return &self.tokens[self.current - 1];
}
