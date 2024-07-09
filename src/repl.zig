const std = @import("std");
const l = @import("lexer.zig");
const p = @import("parser.zig");
const e = @import("evaluator.zig");

const Lexer = l.Lexer;
const Parser = p.Parser;
const Evaluator = e.Evaluator;

pub fn start() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var reader = std.io.bufferedReader(stdin.reader());
    var writer = std.io.bufferedWriter(stdout.writer());

    var buf: [1024]u8 = undefined;
    var buf_reader = reader.reader();
    var buf_writer = writer.writer();

    while (true) {
        try buf_writer.print("\n>> ", .{});
        try writer.flush();

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var arena = std.heap.ArenaAllocator.init(gpa.allocator());
        defer arena.deinit();

        const line = try buf_reader.readUntilDelimiter(&buf, '\n');
        var lexer = try Lexer.init(
            line,
            arena.allocator(),
        );
        defer lexer.deinit();

        var parser = Parser.init(&lexer, arena.allocator());
        var program = try parser.parse();
        std.debug.print("parsed...", .{});
        var evaluator = Evaluator.init(arena.allocator());

        const evaluated = try evaluator.evalProgram(&program);
        switch (evaluated.*) {
            .integer => |integer| try buf_writer.print("{}", .{integer.value}),
            .boolean => |boolean| try buf_writer.print("{}", .{boolean.value}),
            .null_val => |_| try buf_writer.print("null", .{}),
        }
        try writer.flush();
    }
}
