const std = @import("std");
const l = @import("lexer.zig");

const Lexer = l.Lexer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var lexer = try Lexer.init(
        "fn() let a; end;",
        &gpa.allocator(),
    );
    defer lexer.deinit();
}
