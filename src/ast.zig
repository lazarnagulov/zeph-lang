const std = @import("std");
const t = @import("token.zig");

const Token = t.Token;

pub const Node = union(enum) {};

pub const Program = struct {
    statemets: *std.ArrayList(Statement),

    const Self = @This();

    pub fn tokenLiteral(self: Self) []const u8 {
        if (self.statemets.items.len > 0) {
            return self.statemets[0].tokenLiteral();
        } else {
            return "";
        }
    }

    pub fn deinit(self: *Self) void {
        self.statemets.deinit();
    }
};

pub const Expression = union(enum) {
    token: Token,
};

pub const Statement = union(enum) {
    let: *const Let,
};

pub const Let = struct {
    token: Token,
    name: *const Identifier,
    value: *const Expression,

    const Self = @This();

    pub fn tokenLiteral(self: Self) []const u8 {
        return self.token.literal;
    }
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    const Self = @This();

    pub fn tokenLiteral(self: Self) []const u8 {
        return self.token.literal;
    }
};
