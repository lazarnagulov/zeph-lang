const std = @import("std");
const repl = @import("repl.zig");
const parser = @import("parser.zig");

pub fn main() !void {
    try repl.start();
    _ = parser.ParseError;
}
