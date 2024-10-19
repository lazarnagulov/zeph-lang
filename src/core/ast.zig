const std = @import("std");
const t = @import("token.zig");

const Token = t.Token;

pub const Node = union(enum) {
    program: *Program,
    statement: *Statement,
    expression: *Expression,
};

pub const Program = struct {
    statemets: std.ArrayList(Statement),

    const Self = @This();

    pub fn init(statements: *std.ArrayList(Statement)) Program {
        return Program{ .statemets = statements.* };
    }

    pub fn deinit(self: *Self) void {
        self.statemets.deinit();
    }
};

pub const Expression = union(enum) {
    identifier: Identifier,
    int_literal: IntegerLiteral,
    function_literal: FunctionLiteral,
    boolean: Boolean,
    prefix_expression: PrefixExpression,
    call_expression: CallExpression,
    infix_expression: InfixExpression,
    if_expression: *IfExpression,
};

pub const Statement = union(enum) {
    let: Let,
    ret: Return,
    expression_statement: ExpressionStatement,
    block_statement: BlockStatement,
};

pub const Let = struct {
    token: Token,
    name: Identifier,
    value: *Expression,

    const Self = @This();

    pub fn tokenLiteral(self: *const Self) []const u8 {
        return self.token.literal;
    }
};

pub const Return = struct {
    token: Token,
    return_value: *Expression,
};

pub const Identifier = struct {
    token: Token,
    value: []const u8,

    const Self = @This();

    pub fn tokenLiteral(self: *const Self) []const u8 {
        return self.token.literal;
    }
};

pub const IntegerLiteral = struct {
    token: Token,
    value: i64,
};

pub const FunctionLiteral = struct {
    token: Token,
    parameters: std.ArrayList(Identifier),
    body: BlockStatement,
};

pub const Boolean = struct {
    token: Token,
    value: bool,
};

pub const ExpressionStatement = struct { token: Token, expression: *Expression };

pub const PrefixExpression = struct {
    token: Token,
    operator: []const u8,
    right: *Expression,
};

pub const InfixExpression = struct {
    token: Token,
    left: *Expression,
    operator: []const u8,
    right: *Expression,
};

pub const IfExpression = struct {
    token: Token,
    condition: *Expression,
    consequence: BlockStatement,
    alternative: ?BlockStatement,
};

pub const CallExpression = struct {
    token: Token,
    function: *Expression,
    arguments: std.ArrayList(Expression),
};

pub const BlockStatement = struct {
    statements: std.ArrayList(Statement),
};
