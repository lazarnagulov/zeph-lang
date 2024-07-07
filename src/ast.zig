const std = @import("std");
const t = @import("token.zig");

const Token = t.Token;

pub const Node = union(enum) {};

pub const Program = struct {
    statemets: std.ArrayList(Statement),

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.statemets.deinit();
    }
};

pub const Expression = union(enum) {
    identifier: *const Identifier,
    int_literal: *const IntegerLiteral,
};

pub const Statement = union(enum) {
    let: *const Let,
    ret: *const Return,
    expression_statement: *const ExpressionStatement,
};

pub const Let = struct {
    token: Token,
    name: *const Identifier,
    value: ?*Expression,

    const Self = @This();

    pub fn tokenLiteral(self: *const Self) []const u8 {
        return self.token.literal;
    }
};

pub const Return = struct {
    token: Token,
    return_value: ?*Expression,
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    const Self = @This();

    pub fn tokenLiteral(self: *Self) []const u8 {
        return self.token.literal;
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,
};

pub const ExpressionStatement = struct { token: Token, expression: *const Expression };
