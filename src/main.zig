const std = @import("std");
const fs = std.fs;
const io = std.io;
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
    std.debug.print("run file \n", .{});

    var file = try fs.cwd().openFile(filepath, .{});
    defer file.close();

    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        std.debug.print("{s}", .{line});
        // do something with line...
    }
}

fn runPrompt() !void {
    std.debug.print("run prompt", .{});
}
