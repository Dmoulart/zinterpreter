const std = @import("std");
const fs = std.fs;
const io = std.io;
const print = std.debug.print;
const Lexer = @import("./lexer.zig");
const Parser = @import("./parser.zig");

const Expr = @import("./ast/expr.zig").Expr;
const Tok = @import("./token.zig");
const astPrint = @import("./ast/printer.zig").print;
const Interpreter = @import("./interpreter.zig");
const interpret = @import("./interpreter.zig").interpret;

pub fn main() !void {
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
}

fn runPrompt() !void {
    const stdin = std.io.getStdIn().reader();

    var buf: [1024]u8 = undefined;

    while (true) {
        print("\n> ", .{});

        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |line| {
            if (std.mem.eql(u8, line, "exit")) {
                return;
            }

            try run(line);
        }
    }
}

fn run(src: []const u8) !void {
    var lexer = Lexer.init(src, std.heap.page_allocator);
    defer lexer.deinit();

    var tokens = try lexer.scan();

    var parser = Parser.init(tokens, std.heap.page_allocator);
    defer parser.deinit();

    if (parser.parse()) |ast| {
        // var buffer: [1024]u8 = undefined;
        // var ast_print = astPrint(ast, buffer[0..]);
        // print("\n ast_print : {s} \n", .{ast_print});

        var interpreter = Interpreter.init(std.heap.page_allocator);

        _ = interpreter.interpret(ast) catch {
            std.os.exit(70);
        };
    } else |_| {
        // Don't exit the repl when a parse error is raised.

        // print("\n Exit after error \n", .{});
        // std.os.exit(65);
        return;
    }
}

// pub fn main2() !void {
//     var expr = Expr{
//         .Binary = .{
//             .left = &Expr{
//                 .Unary = .{
//                     .op = Tok{
//                         .type = .MINUS,
//                         .lexeme = "-",
//                         .line = 1,
//                     },
//                     .right = &Expr{
//                         .Literal = .{
//                             .value = .{ .Integer = 123 },
//                         },
//                     },
//                 },
//             },
//             .op = Tok{
//                 .type = .STAR,
//                 .lexeme = "*",
//                 .line = 1,
//             },
//             .right = &Expr{
//                 .Grouping = .{
//                     .expr = &Expr{
//                         .Literal = .{
//                             .value = .{ .String = "45.67" },
//                         },
//                     },
//                 },
//             },
//         },
//     };
//     var buffer: [1024]u8 = undefined;
//     var ast_print = astPrint(&expr, buffer[0..]);
//     print("\nastprint : {s}\n", .{ast_print});
// }
