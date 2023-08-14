const std = @import("std");
const report = @import("./error-reporter.zig").report;
const Token = @import("./token.zig");
const Expr = @import("./ast/expr.zig").Expr;

const Self = @This();

pub const ParseError = error{
    OutOfMemory,
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
    return inline for (types) |token_type| {
        if (self.check(@as(Token.Tokens, token_type))) {
            _ = self.advance();
            break true;
        }
    } else false;
}

fn primary(self: *Self) !*Expr {
    if (self.match(&.{.FALSE})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .Boolean = false },
            },
        });
    }

    if (self.match(&.{.TRUE})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .Boolean = true },
            },
        });
    }

    if (self.match(&.{.NIL})) {
        return try self.create(.{
            .Literal = .{
                .value = .{ .Nil = null },
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

    return self.err(self.peek(), ParseError.MissingExpression, "Missing expression");
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
    return token_type == @as(Token.Tokens, self.peek().type);
}

fn advance(self: *Self) *Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }

    return self.previous();
}

fn consume(self: *Self, token_type: Token.Type, parse_error: ParseError, comptime msg: []const u8) ParseError!*Token {
    if (self.check(token_type)) return self.advance();

    return self.err(self.peek(), parse_error, msg);
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

fn err(self: *Self, token: *Token, parse_error: ParseError, comptime msg: []const u8) ParseError {
    if (token.type == .EOF) {
        report(token.line, "at end of file", msg);
    } else {
        var where = try std.fmt.allocPrint(self.allocator, "at {s}", .{token.lexeme});
        report(token.line, where, msg);
    }

    return parse_error;
}

const expect = std.testing.expect;

test "can parse" {
    var toks = [_]Token{
        .{
            .type = .{ .NUMBER = 100 },
            .lexeme = "100",
            .line = 1,
        },
        .{
            .type = .STAR,
            .lexeme = "*",
            .line = 1,
        },
        .{
            .type = .{ .NUMBER = 100 },
            .lexeme = "100",
            .line = 1,
        },
        .{
            .type = .EOF,
            .lexeme = "",
            .line = 1,
        },
    };
    var parser = init(&toks, std.testing.allocator);
    defer parser.deinit();

    var ast = try parser.parse();

    try expect(switch (ast.*) {
        .Binary => true,
        else => false,
    });
}
