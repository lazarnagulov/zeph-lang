const std = @import("std");
const l = @import("lexer.zig");

const Lexer = l.Lexer;

pub fn start() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var reader = std.io.bufferedReader(stdin.reader());
    var writer = std.io.bufferedWriter(stdout.writer());

    var buf: [1024]u8 = undefined;
    var buf_reader = reader.reader();
    var buf_writer = writer.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const line = try buf_reader.readUntilDelimiter(&buf, '\n');
    var lexer = try Lexer.init(
        line,
        &gpa.allocator(),
    );
    defer lexer.deinit();

    var current_token = lexer.GetNextToken();
    while (current_token.type != .eof) {
        try buf_writer.print("{s}\t[{any}]\n", .{ current_token.literal, current_token.type });
        current_token = lexer.GetNextToken();
    }
    try writer.flush();
}
