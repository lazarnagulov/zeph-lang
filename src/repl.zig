const std = @import("std");
const l = @import("lexer.zig");
const p = @import("parser.zig");
const e = @import("evaluator.zig");

const Lexer = l.Lexer;
const Parser = p.Parser;
const Evaluator = e.Evaluator;
const Environment = @import("environment.zig").Environment;

pub fn start() !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    var reader = std.io.bufferedReader(stdin.reader());
    var writer = std.io.bufferedWriter(stdout.writer());

    var buf: [1024]u8 = undefined;
    var buf_reader = reader.reader();
    var buf_writer = writer.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var environment = Environment.init(arena.allocator());

    while (true) {
        try buf_writer.print("\n>> ", .{});
        try writer.flush();

        const line = try buf_reader.readUntilDelimiterOrEof(&buf, '\n');
        var lexer = Lexer.init(line.?, arena.allocator()) catch |err| {
            std.debug.print("Lexer error: {}", .{err});
            continue;
        };
        defer lexer.deinit();

        var parser = Parser.init(&lexer, arena.allocator());
        var program = parser.parse() catch |err| {
            std.debug.print("Parser error: {}", .{err});
            continue;
        };

        var evaluator = Evaluator.init(arena.allocator());

        const evaluated = evaluator.evalProgram(&program, &environment) catch |err| {
            std.debug.print("Evaluator error: {}", .{err});
            continue;
        };

        switch (evaluated) {
            .integer => |integer| try buf_writer.print("{}", .{integer.value}),
            .boolean => |boolean| try buf_writer.print("{}", .{boolean.value}),
            else => |_| try buf_writer.print("null", .{}),
        }
        try writer.flush();
    }
}
