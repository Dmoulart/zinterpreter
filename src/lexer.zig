const std = @import("std");
const report = @import("./error-reporter.zig").report;
const Token = @import("./token.zig");
const ArrayList = @import("std").ArrayList;

const Self = @This();

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

    const maybe_tok: ?Token.Type = switch (char) {
        '(' => .LEFT_PAREN,
        ')' => .RIGHT_PAREN,
        '{' => .LEFT_BRACE,
        '}' => .RIGHT_BRACE,
        ',' => .COMMA,
        '.' => .DOT,
        '-' => .MINUS,
        '+' => .PLUS,
        ';' => .SEMICOLON,
        '*' => .STAR,
        else => blk: {
            self.had_error = true;
            report(self.line, "", "Unexpected character");
            break :blk null;
        },
    };

    if (maybe_tok) |tok| {
        try self.addToken(tok);
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

fn advance(self: *Self) u8 {
    self.current += 1;
    return self.src[self.current - 1];
}

fn isAtEnd(self: *Self) bool {
    return self.current >= self.src.len;
}
