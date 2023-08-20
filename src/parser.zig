const std = @import("std");
const report = @import("./error-reporter.zig").report;
const Token = @import("./token.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;

const Self = @This();

pub const ParseError = error{
    OutOfMemory,
    MissingExpression,
    MissingRightParen,
    MissingSemiColonAfterValue,
    MissingSemiColonAfterVarDeclaration,
    MissingVariableName,
    InvalidAssignmentTarget,
    MissingClosingBrace,
};

tokens: []Token,
current: u32 = 0,

allocator: std.mem.Allocator,

stmts: std.ArrayList(*Stmt),

pub fn init(tokens: []Token, allocator: std.mem.Allocator) Self {
    return Self{
        .tokens = tokens,
        .allocator = allocator,
        .stmts = std.ArrayList(*Stmt).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    for (self.stmts.items) |stmt| {
        self.allocator.destroy(stmt);
    }
    self.stmts.deinit();
}

pub fn parse(self: *Self) ParseError![]*Stmt {
    while (!self.isAtEnd()) {
        var maybe_stmt = try self.declaration();
        if (maybe_stmt) |stmt| {
            try self.stmts.append(stmt);
        }
    }

    return self.stmts.toOwnedSlice();
}

fn declaration(self: *Self) ParseError!?*Stmt {
    if (self.match(&.{.VAR})) {
        return self.varDeclaration() catch {
            try self.synchronize();
            return null;
        };
    }
    return try self.statement();
}

fn varDeclaration(self: *Self) ParseError!*Stmt {
    var name = try self.consume(
        .IDENTIFIER,
        ParseError.MissingVariableName,
        "Expect variable name.",
    );
    var initializer: ?Expr = null;

    if (self.match(&.{.EQUAL})) {
        initializer = (try self.expression()).*;
    }

    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterVarDeclaration,
        "Expect ';' after variable declaration.",
    );

    return try self.createStatement(.{ .Var = .{
        .name = name.*,
        .initializer = initializer,
    } });
}

fn statement(self: *Self) ParseError!*Stmt {
    if (self.match(&.{.PRINT})) {
        return try self.printStatement();
    }

    if (self.match(&.{.LEFT_BRACE})) {
        return try self.createStatement(.{
            .Block = .{
                .stmts = try self.block(),
            },
        });
    }

    return try self.expressionStatement();
}

fn printStatement(self: *Self) ParseError!*Stmt {
    var value = try self.expression();
    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterValue,
        "Expect ';' after value.",
    );
    return try self.createStatement(.{ .Print = value.* });
}

fn block(self: *Self) ParseError![]*Stmt {
    var stmts = std.ArrayList(*Stmt).init(self.allocator);

    while (!self.check(.RIGHT_BRACE) and !self.isAtEnd()) {
        if (self.declaration()) |maybe_decl| {
            if (maybe_decl) |decl| {
                stmts.append(decl) catch |decl_err| switch (decl_err) {
                    error.OutOfMemory => return ParseError.OutOfMemory,
                };
            }
        } else |decl_err| {
            return decl_err;
        }
    }

    _ = try self.consume(
        .RIGHT_BRACE,
        ParseError.MissingClosingBrace,
        "Expect '}' after block.",
    );

    return stmts.toOwnedSlice();
}

fn expression(self: *Self) ParseError!*Expr {
    return try self.assignment();
}

fn assignment(self: *Self) ParseError!*Expr {
    var expr = try self.equality();

    if (self.match(&.{.EQUAL})) {
        var equals = self.previous();
        var value = try self.assignment();

        return switch (expr.*) {
            .Variable => |*var_expr| {
                var name = var_expr.name;
                return try self.createExpression(.{
                    .Assign = .{
                        .name = name,
                        .value = value,
                    },
                });
            },
            else => {
                return self.err(
                    equals,
                    ParseError.InvalidAssignmentTarget,
                    "Invalid assignment target.",
                );
            },
        };
    }

    return expr;
}

fn expressionStatement(self: *Self) ParseError!*Stmt {
    var expr = try self.expression();

    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterValue,
        "Expect ';' after value.",
    );

    return try self.createStatement(.{ .Expr = expr.* });
}

fn equality(self: *Self) ParseError!*Expr {
    var expr = try self.comparison();

    while (self.match(&.{ .BANG_EQUAL, .EQUAL_EQUAL })) {
        expr = try self.createExpression(.{
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
        expr = try self.createExpression(.{
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
        expr = try self.createExpression(.{
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
        expr = try self.createExpression(.{
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
        return try self.createExpression(.{
            .Unary = .{
                .op = self.previous().*,
                .right = (try self.term()),
            },
        });
    }

    return try self.primary();
}

fn match(self: *Self, comptime types: []const Token.Types) bool {
    return inline for (types) |token_type| {
        if (self.check(@as(Token.Types, token_type))) {
            _ = self.advance();
            break true;
        }
    } else false;
}

fn primary(self: *Self) !*Expr {
    if (self.match(&.{.FALSE})) {
        return try self.createExpression(.{
            .Literal = .{
                .value = .{ .Boolean = false },
            },
        });
    }

    if (self.match(&.{.TRUE})) {
        return try self.createExpression(.{
            .Literal = .{
                .value = .{ .Boolean = true },
            },
        });
    }

    if (self.match(&.{.NIL})) {
        return try self.createExpression(.{
            .Literal = .{
                .value = .{ .Nil = null },
            },
        });
    }

    if (self.match(&.{.NUMBER})) {
        return try self.createExpression(.{
            .Literal = .{
                .value = .{ .Float = self.previous().type.NUMBER },
            },
        });
    }

    if (self.match(&.{.STRING})) {
        return try self.createExpression(.{
            .Literal = .{
                .value = .{
                    .String = self.previous().type.STRING,
                },
            },
        });
    }

    if (self.match(&.{.IDENTIFIER})) {
        return try self.createExpression(
            .{
                .Variable = .{
                    .name = self.previous().*,
                },
            },
        );
    }

    if (self.match(&.{.LEFT_PAREN})) {
        var expr = try self.expression();
        _ = try self.consume(
            .RIGHT_PAREN,
            ParseError.MissingRightParen,
            "Expect ) after expression",
        );

        return try self.createExpression(.{
            .Grouping = .{
                .expr = expr,
            },
        });
    }

    return self.err(self.peek(), ParseError.MissingExpression, "Missing expression");
}

fn createStatement(self: *Self, stmt: Stmt) std.mem.Allocator.Error!*Stmt {
    // var ptr = self.stmts.addOne() catch return ParseError.OutOfMemory;
    var ptr = self.allocator.create(Stmt) catch return ParseError.OutOfMemory;
    ptr.* = stmt;
    return ptr;
}

fn createExpression(self: *Self, expr: Expr) std.mem.Allocator.Error!*Expr {
    var ptr = self.allocator.create(Expr) catch return ParseError.OutOfMemory;
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
            else => {},
        }
        _ = self.advance();
    }
}

fn check(self: *Self, token_type: Token.Types) bool {
    if (self.isAtEnd()) return false;
    // if (token_type == @as(Token.Types, self.peek().type)) {
    //     std.debug.print("\nmatch : peek {any} tok {any}", .{ self.peek().type, token_type });
    // }
    return token_type == @as(Token.Types, self.peek().type);
}

fn advance(self: *Self) *Token {
    if (!self.isAtEnd()) {
        self.current += 1;
    }

    return self.previous();
}

fn consume(self: *Self, token_type: Token.Types, parse_error: ParseError, comptime msg: []const u8) ParseError!*Token {
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

// test "can parse" {
//     var toks = [_]Token{
//         .{
//             .type = .{ .NUMBER = 100 },
//             .lexeme = "100",
//             .line = 1,
//         },
//         .{
//             .type = .STAR,
//             .lexeme = "*",
//             .line = 1,
//         },
//         .{
//             .type = .{ .NUMBER = 100 },
//             .lexeme = "100",
//             .line = 1,
//         },
//         .{
//             .type = .EOF,
//             .lexeme = "",
//             .line = 1,
//         },
//     };
//     var parser = init(&toks, std.testing.allocator);
//     defer parser.deinit();

//     var ast = try parser.parse();

//     try expect(switch (ast[0]) {
//         .Binary => true,
//         else => false,
//     });
// }
