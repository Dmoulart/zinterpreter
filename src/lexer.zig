const std = @import("std");
const report = @import("./error-reporter.zig").report;
const Token = @import("./token.zig");
const ArrayList = @import("std").ArrayList;
const ComptimeStringMap = @import("std").ComptimeStringMap;

const Self = @This();

const keywords = ComptimeStringMap(Token.Type, .{
    .{ "and", .AND },
    .{ "class", .CLASS },
    .{ "else", .ELSE },
    .{ "false", .FALSE },
    .{ "for", .FOR },
    .{ "fun", .FUN },
    .{ "if", .IF },
    .{ "nil", .NIL },
    .{ "or", .OR },
    .{ "print", .PRINT },
    .{ "return", .RETURN },
    .{ "super", .SUPER },
    .{ "this", .THIS },
    .{ "true", .TRUE },
    .{ "var", .VAR },
    .{ "while", .WHILE },
});

src: []const u8,

tokens: ArrayList(Token),

start: u32 = 0,
current: u32 = 0,
line: u32 = 1,

had_error: bool = false,

pub fn init(src: []const u8, allocator: std.mem.Allocator) Self {
    return Self{
        .src = src,
        .tokens = ArrayList(Token).init(allocator),
    };
}

pub fn scan(self: *Self) !*ArrayList(Token) {
    while (!self.isAtEnd()) {
        self.start = self.current;
        try self.scanToken();
    }

    try self.tokens.append(Token{
        .type = Token.Type.EOF,
        .lexeme = "",
        .line = self.line,
    });

    return &self.tokens;
}

fn scanToken(self: *Self) !void {
    const char: u8 = self.advance();

    const maybe_token: ?Token.Type = switch (char) {
        '(' => .LEFT_PAREN,
        ')' => .RIGHT_PAREN,
        '{' => .LEFT_BRACE,
        '}' => .RIGHT_BRACE,
        ',' => .COMMA,
        '.' => .DOT,
        '-' => .MINUS,
        '+' => .PLUS,
        ';' => .SEMICOLON,
        '/' => blk: {
            if (self.match('/')) {
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    _ = self.advance();
                }
                break :blk null;
            } else if (self.match('*')) {
                self.commentBlock();
                break :blk null;
            } else {
                break :blk .SLASH;
            }
        },
        '*' => .STAR,
        '!' => if (self.match('=')) .BANG_EQUAL else .BANG,
        '=' => if (self.match('=')) .EQUAL_EQUAL else .EQUAL,
        '<' => if (self.match('=')) .LESS_EQUAL else .LESS,
        '>' => if (self.match('=')) .GREATER_EQUAL else .GREATER,
        ' ', '\r', '\t' => null,
        '\n' => blk: {
            self.line += 1;
            break :blk null;
        },
        '"' => self.string(),
        '0'...'9' => try self.number(),
        'a'...'z', 'A'...'Z', '_' => self.identifier(),
        else => blk: {
            self.had_error = true;
            report(self.line, self.src[self.start..self.current], "Unexpected character");
            break :blk null;
        },
    };

    if (maybe_token) |token| {
        try self.addToken(token);
    }
}

fn addToken(self: *Self, tok_type: Token.Type) !void {
    var text = self.src[self.start..self.current];

    try self.tokens.append(Token{
        .type = tok_type,
        .lexeme = text,
        .line = self.line,
    });
}

fn match(self: *Self, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.src[self.current] != expected) return false;

    self.current += 1;
    return true;
}

fn advance(self: *Self) u8 {
    self.current += 1;
    return self.src[self.current - 1];
}

fn peek(self: *Self) u8 {
    if (self.isAtEnd()) return 0;
    return self.src[self.current];
}

fn peekNext(self: *Self) u8 {
    if (self.current + 1 >= self.src.len) return 0;
    return self.src[self.current + 1];
}

fn commentBlock(self: *Self) void {
    while (!self.isAtEnd()) {

        // nested comment block
        if (self.peek() == '/' and self.peekNext() == '*') {
            _ = self.advance();
            _ = self.advance();
            self.commentBlock();
        } else if (self.peek() == '*' and self.peekNext() == '/') {
            _ = self.advance();
            _ = self.advance();
            return;
        }
        if (self.peek() == '\n') {
            self.line += 1;
        }

        if (self.current + 1 <= self.src.len) {
            _ = self.advance();
        }
    }
    report(self.line, "", "Unterminated comment block");
    self.had_error = true;
}

fn string(self: *Self) ?Token.Type {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n') {
            self.line += 1;
        }
        _ = self.advance();
    }

    if (self.isAtEnd()) {
        report(self.line, "", "Unterminated string.");
        return null;
    }

    _ = self.advance();

    const value = self.src[(self.start + 1)..(self.current - 1)];

    return Token.Type{
        .STRING = value,
    };
}

fn number(self: *Self) !Token.Type {
    while (isDigit(self.peek())) _ = self.advance();

    // Look for a fractional part
    if (self.peek() == '.' and isDigit(self.peekNext())) {
        // Consume the "."
        _ = self.advance();

        while (isDigit(self.peek())) _ = self.advance();
    }

    return Token.Type{
        .NUMBER = try std.fmt.parseFloat(f64, self.src[self.start..self.current]),
    };
}

fn identifier(self: *Self) Token.Type {
    while (isAlphaNumeric(self.peek())) _ = self.advance();

    const text = self.src[self.start..self.current];

    return if (keywords.get(text)) |keyword_type| keyword_type else .IDENTIFIER;
}

fn isAtEnd(self: *Self) bool {
    return self.current >= self.src.len;
}

fn isDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn isAlphaNumeric(char: u8) bool {
    return isAlpha(char) or isDigit(char);
}

fn isAlpha(char: u8) bool {
    return (char >= 'a' and char <= 'z') or
        (char >= 'A' and char <= 'Z') or
        char == '_';
}
