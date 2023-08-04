const std = @import("std");
const fs = std.fs;
const io = std.io;
const print = std.debug.print;
const Lexer = @import("./lex/lexer.zig");

const Expr = @import("./ast/expr.zig").Expr;
const Tok = @import("./token.zig");
const astPrint = @import("./ast/printer.zig").print;

pub fn main() !void {
    var expr = Expr{
        .Binary = .{
            .left = &Expr{
                .Unary = .{
                    .op = Tok{
                        .type = .MINUS,
                        .lexeme = "-",
                        .line = 1,
                    },
                    .right = &Expr{
                        .Literal = .{ .value = "123" },
                    },
                },
            },
            .op = Tok{
                .type = .STAR,
                .lexeme = "*",
                .line = 1,
            },
            .right = &Expr{
                .Grouping = .{
                    .expr = &Expr{
                        .Literal = .{ .value = "52.27" },
                    },
                },
            },
        },
    };
    // const ast_print = expr.print();
    var ast_print = astPrint(&expr);
    print("{s}", .{ast_print});
}
pub fn main2() !void {
    const alloc = std.heap.page_allocator;
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len > 1) {
        try runFile(args[1]);
    } else {
        try runPrompt();
    }
}

fn runFile(filepath: [:0]u8) !void {
    var file = try fs.cwd().openFile(filepath, .{});
    defer file.close();

    var allocator = std.heap.page_allocator;
    const file_size = (try file.stat()).size;
    var buf = try allocator.alloc(u8, file_size);

    try file.reader().readNoEof(buf);
    try run(buf);
    print("{s}", .{buf});
}

fn runPrompt() !void {
    const stdin = std.io.getStdIn().reader();

    var buf: [1024]u8 = undefined;

    var exit = false;

    while (!exit) {
        print("\n> ", .{});

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
            if (std.mem.eql(u8, line, "exit")) {
                return;
            }

            print("{s}", .{line});

            try run(line);
        }
    }
}

fn run(src: []const u8) !void {
    var lexer = Lexer.init(src, std.heap.page_allocator);
    var tokens = try lexer.scan();

    for (tokens.items) |tok| {
        print("\n - type: {} | lexeme: {s}\n", .{ tok.type, tok.lexeme });
    }
}
