const std = @import("std");
const report = @import("./error-reporter.zig").report;
const Token = @import("./token.zig");
const Expr = @import("./ast/expr.zig").Expr;
const Stmt = @import("./ast/stmt.zig").Stmt;

const ErrorReporter = @import("./error-reporter.zig").ErrorReporter;
const Err = ErrorReporter(ParseError);

const Self = @This();

pub const ParseError = error{
    OutOfMemory,
    MissingExpression,
    MissingClosingParen,
    MissingSemiColonAfterValue,
    MissingSemiColonAfterReturnValue,
    MissingSemiColonAfterVarDeclaration,
    MissingVariableName,
    MissingFunctionName,
    MissingParameterName,
    InvalidAssignmentTarget,
    MissingClosingBrace,
    MissingOpeningParenBeforeIfCondition,
    MissingClosingParenAfterIfCondition,
    MissingOpeningParenBeforeWhileCondition,
    MissingOpeningParenAfterWhileCondition,
    MissingOpeningParenBeforeForCondition,
    MissingClosingParenAfterForCondition,
    MissingClosingParenAfterParameters,
    MissingSemiColonAfterForCondition,
    MissingSemiColonAfterBreak,
    MissingSemiColonAfterContinue,
    MissingOpeningParenBeforeParameters,
    MissingClosingParenAfterArguments,
    MissingOpeningBraceBeforeFunctionBody,
    MissingClosingBraceAfterFunctionBody,
    TooMuchArguments,
};

tokens: []Token,
current: u32 = 0,

allocator: std.mem.Allocator,

stmts: std.ArrayList(*Stmt),
// args: std.ArrayList(*Expr),

pub fn init(tokens: []Token, allocator: std.mem.Allocator) Self {
    return Self{
        .tokens = tokens,
        .allocator = allocator,
        .stmts = std.ArrayList(*Stmt).init(allocator),
        // .args = std.ArrayList(*Expr).init(allocator),
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
    if (self.match(&.{.FUN})) {
        return self.function("function") catch {
            try self.synchronize();
            return null;
        };
    }

    if (self.match(&.{.VAR})) {
        return self.varDeclaration() catch {
            try self.synchronize();
            return null;
        };
    }

    return try self.statement();
}

fn varDeclaration(self: *Self) ParseError!*Stmt {
    const name = try self.consume(
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

fn function(self: *Self, comptime kind: []const u8) ParseError!*Stmt {
    const name = try self.consume(
        .IDENTIFIER,
        ParseError.MissingFunctionName,
        "Expect " ++ kind ++ " name.",
    );

    _ = try self.consume(
        .LEFT_PAREN,
        ParseError.MissingOpeningParenBeforeParameters,
        "Expect ( before parameters.",
    );

    var args = std.ArrayList(Token).init(self.allocator);

    if (!self.check(.RIGHT_PAREN)) {
        // @todo: do while would have been great in this case
        if (args.items.len >= 255) {
            return Err.raise(
                self.peek(),
                ParseError.TooMuchArguments,
                "Functions cannot have more than 255 arguments",
            );
        }

        const first_ident = try self.consume(
            .IDENTIFIER,
            ParseError.MissingParameterName,
            "Expect parameter name.",
        );
        try args.append(first_ident.*);

        while (self.match(&.{.COMMA})) {
            if (args.items.len >= 255) {
                return Err.raise(
                    self.peek(),
                    ParseError.TooMuchArguments,
                    "Functions cannot have more than 255 arguments",
                );
            }

            const ident = try self.consume(
                .IDENTIFIER,
                ParseError.MissingParameterName,
                "Expect parameter name.",
            );
            try args.append(ident.*);
        }
    }

    _ = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingClosingParenAfterParameters,
        "Expect ) after parameters.",
    );

    _ = try self.consume(
        .LEFT_BRACE,
        ParseError.MissingOpeningBraceBeforeFunctionBody,
        "Expect { before function body.",
    );

    var body = try self.block();

    return try self.createStatement(.{
        .Function = .{
            .name = name.*,
            .args = args.toOwnedSlice() catch return Err.raise(
                self.peek(),
                ParseError.OutOfMemory,
                "Out of memory during function arguments definition",
            ),
            .body = body,
        },
    });
}

fn statement(self: *Self) ParseError!*Stmt {
    if (self.match(&.{.FOR})) {
        return try self.forStatement();
    }

    if (self.match(&.{.BREAK})) {
        return try self.breakStatement();
    }

    if (self.match(&.{.CONTINUE})) {
        return try self.continueStatement();
    }

    if (self.match(&.{.IF})) {
        return try self.ifStatement();
    }

    if (self.match(&.{.PRINT})) {
        return try self.printStatement();
    }

    if (self.match(&.{.RETURN})) {
        return try self.returnStatement();
    }

    if (self.match(&.{.WHILE})) {
        return try self.whileStatement();
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

fn forStatement(self: *Self) ParseError!*Stmt {
    _ = try self.consume(
        .LEFT_PAREN,
        ParseError.MissingOpeningParenBeforeForCondition,
        "Expect '(' before for condition.",
    );

    const maybe_initializer = if (self.match(&.{.SEMICOLON})) null else if (self.match(&.{.VAR})) try self.varDeclaration() else try self.statement();

    const condition = if (self.match(&.{.SEMICOLON}))
        try self.createExpression(
            .{
                .Literal = .{
                    .value = .{ .Boolean = true },
                },
            },
        )
    else
        try self.expression();

    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterForCondition,
        "Expect ';' after loop condition.",
    );
    const maybe_increment = if (!self.check(.RIGHT_PAREN)) try self.expression() else null;

    _ = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingClosingParenAfterForCondition,
        "Expect ')' after for condition.",
    );

    var body = try self.statement();

    body = try self.createStatement(
        .{
            .While = .{
                .condition = condition.*,
                .body = body,
                .inc = if (maybe_increment) |increment| increment else null,
            },
        },
    );

    if (maybe_initializer) |initializer| {
        var stmts = try self.allocator.alloc(*Stmt, 2); // @todo: cleanup memory ???
        stmts[0] = initializer;
        stmts[1] = body;
        body = try self.createStatement(.{ .Block = .{ .stmts = stmts } });
    }

    return body;
}

fn continueStatement(self: *Self) ParseError!*Stmt {
    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterContinue,
        "Expect ';' after break continue statement.",
    );
    return try self.createStatement(.{ .Continue = .{} });
}

fn breakStatement(self: *Self) ParseError!*Stmt {
    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterBreak,
        "Expect ';' after break statement.",
    );
    return try self.createStatement(.{ .Break = .{} });
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

fn returnStatement(self: *Self) ParseError!*Stmt {
    const keyword = self.previous().*;
    var value: ?*Expr = if (!self.check(.SEMICOLON)) try self.expression() else null;

    _ = try self.consume(
        .SEMICOLON,
        ParseError.MissingSemiColonAfterReturnValue,
        "Expect ';' after return value.",
    );
    return try self.createStatement(.{
        .Return = .{
            .keyword = keyword,
            .value = value,
        },
    });
}

fn whileStatement(self: *Self) ParseError!*Stmt {
    _ = try self.consume(
        .LEFT_PAREN,
        ParseError.MissingOpeningParenBeforeWhileCondition,
        "Expect '(' after 'while'.",
    );

    var condition = try self.expression();

    _ = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingOpeningParenAfterWhileCondition,
        "Expect ')' after 'condition'.",
    );

    var body = try self.statement();

    return try self.createStatement(.{ .While = .{
        .condition = condition.*,
        .body = body,
        .inc = null,
    } });
}

fn ifStatement(self: *Self) ParseError!*Stmt {
    _ = try self.consume(
        .LEFT_PAREN,
        ParseError.MissingOpeningParenBeforeIfCondition,
        "Expect '(' after 'if'.",
    );

    var condition = try self.expression();

    _ = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingClosingParenAfterIfCondition,
        "Expect ')' after if condition.",
    );

    var then_branch = try self.statement();

    var else_branch = if (self.match(&.{.ELSE})) try self.statement() else null;

    return try self.createStatement(.{ .If = .{
        .condition = condition.*,
        .then_branch = then_branch,
        .else_branch = else_branch,
    } });
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
    if (self.match(&.{.FUN})) {
        return try self.lambda();
    }
    return try self.orExpression();
}

fn lambda(self: *Self) ParseError!*Expr {
    _ = try self.consume(
        .LEFT_PAREN,
        ParseError.MissingOpeningParenBeforeParameters,
        "Expect ( before parameters.",
    );

    var args = try self.allocator.alloc(Token, 255);
    // var args = std.ArrayList(Token).init(self.allocator);
    var args_nb: usize = 0;

    if (!self.check(.RIGHT_PAREN)) {
        const first_ident = try self.consume(
            .IDENTIFIER,
            ParseError.MissingParameterName,
            "Expect parameter name.",
        );
        args[args_nb] = first_ident.*;
        // try args.append(first_ident.*);
        args_nb += 1;
        while (self.match(&.{.COMMA})) {
            if (args_nb >= 255) {
                return Err.raise(
                    self.peek(),
                    ParseError.TooMuchArguments,
                    "Functions cannot have more than 255 arguments",
                );
            }

            const ident = try self.consume(
                .IDENTIFIER,
                ParseError.MissingParameterName,
                "Expect parameter name.",
            );
            // try args.append(ident.*);
            args[args_nb] = ident.*;
            args_nb += 1;
        }
    }

    _ = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingClosingParenAfterParameters,
        "Expect ) after parameters.",
    );
    _ = try self.consume(
        .LEFT_BRACE,
        ParseError.MissingOpeningBraceBeforeFunctionBody,
        "Expect { before function body.",
    );

    var body = try self.block();

    return try self.createExpression(.{
        .Lambda = .{
            .args = args[0..args_nb],
            .body = body,
        },
    });
}

fn assignment(self: *Self) ParseError!*Expr {
    var expr = try self.orExpression();

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
            else => Err.raise(
                equals,
                ParseError.InvalidAssignmentTarget,
                "Invalid assignment target.",
            ),
        };
    }

    return expr;
}

fn orExpression(self: *Self) ParseError!*Expr {
    var expr = try self.andExpression();

    while (self.match(&.{.OR})) {
        var op = self.previous();
        var right = try self.andExpression();
        expr = try self.createExpression(.{ .Logical = .{
            .left = expr,
            .op = op.*,
            .right = right,
        } });
    }

    return expr;
}

fn andExpression(self: *Self) ParseError!*Expr {
    var expr = try self.equality();

    while (self.match(&.{.AND})) {
        var op = self.previous();
        var right = try self.andExpression();
        expr = try self.createExpression(.{ .Logical = .{
            .left = expr,
            .op = op.*,
            .right = right,
        } });
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

    return try self.call();
}

fn call(self: *Self) ParseError!*Expr {
    var expr = try self.primary();

    while (true) {
        if (self.match(&.{.LEFT_PAREN})) {
            expr = try self.finishCall(expr);
        } else {
            break;
        }
    }

    return expr;
}

fn finishCall(self: *Self, callee: *const Expr) ParseError!*Expr {
    var args = std.ArrayList(*const Expr).init(self.allocator);

    if (!self.check(.RIGHT_PAREN)) {
        var first_expr = try self.expression();

        try args.append(first_expr);

        while (self.match(&.{.COMMA})) {
            var expr = try self.expression();
            try args.append(expr);
        }
    }

    const paren = try self.consume(
        .RIGHT_PAREN,
        ParseError.MissingClosingParenAfterArguments,
        "Expect ')' after arguments.",
    );

    if (args.items.len > 255) {
        return Err.raise(
            self.peek(),
            ParseError.TooMuchArguments,
            "Functions cannot have more than 255 arguments",
        );
    }

    return try self.createExpression(
        .{
            .Call = .{
                .callee = callee,
                .paren = paren,
                .args = args.toOwnedSlice() catch return Err.raise(
                    self.peek(),
                    ParseError.OutOfMemory,
                    "Out of memory during function arguments definition",
                ),
            },
        },
    );
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
            ParseError.MissingClosingParen,
            "Expect ) after expression",
        );

        return try self.createExpression(.{
            .Grouping = .{
                .expr = expr,
            },
        });
    }

    return Err.raise(
        self.peek(),
        ParseError.MissingExpression,
        "Missing expression",
    );
}

//@todo: deallocation ??
fn createStatement(self: *Self, stmt: Stmt) std.mem.Allocator.Error!*Stmt {
    var ptr = self.allocator.create(Stmt) catch return ParseError.OutOfMemory;
    ptr.* = stmt;
    return ptr;
}
//@todo: deallocation ??
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

fn consume(self: *Self, token_type: Token.Types, comptime parse_error: ParseError, comptime msg: []const u8) ParseError!*Token {
    if (self.check(token_type)) return self.advance();
    return Err.raise(self.peek(), parse_error, msg);
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

// fn err(self: *Self, token: *Token, parse_error: ParseError, comptime msg: []const u8) ParseError {
//     if (token.type == .EOF) {
//         report(token.line, "at end of file", msg);
//     } else {
//         var where = try std.fmt.allocPrint(self.allocator, "at {s}", .{token.lexeme});
//         report(token.line, where, msg);
//     }

//     return parse_error;
// }

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
