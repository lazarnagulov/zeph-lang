const std = @import("std");
const l = @import("lexer.zig");
const t = @import("token.zig");
const p = @import("precedence.zig");

const ast = @import("ast.zig");

const Program = ast.Program;
const Statement = ast.Statement;
const Let = ast.Let;
const Return = ast.Return;
const Identifier = ast.Identifier;
const Expression = ast.Expression;
const ExpressionStatement = ast.ExpressionStatement;

const Precedence = p.Precedence;
const Lexer = l.Lexer;
const Token = t.Token;
const TokenType = t.TokenType;

pub const ParseError = error{
    ExpectedIdentifier,
    ExpectedAssign,
    InvalidProgram,
    InvalidExpression,
};

pub const Parser = struct {
    lexer: *Lexer,
    current_token: Token,
    peek_token: Token,
    allocator: *const std.mem.Allocator,

    const Self = @This();

    pub fn init(lexer: *Lexer, allocator: *const std.mem.Allocator) Parser {
        const current_token = lexer.GetNextToken();
        const peek_token = lexer.GetNextToken();

        return Parser{
            .lexer = lexer,
            .current_token = current_token,
            .peek_token = peek_token,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Self) !Program {
        var statemets = std.ArrayList(Statement).init(self.allocator.*);

        while (self.current_token.type != .eof) {
            const statement = try self.parseStatement();
            statemets.append(statement.*) catch return ParseError.InvalidProgram;
            self.nextToken();
        }
        return Program{ .statemets = statemets };
    }

    fn nextToken(self: *Self) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.GetNextToken();
    }

    fn parseStatement(self: *Self) !*const Statement {
        return switch (self.current_token.type) {
            .keyword_let => &Statement{ .let = try self.parseLetStatement() },
            .keyword_return => &Statement{ .ret = try self.parseReturnStatement() },
            else => &Statement{ .expression_statement = try self.parseExpressionStatement() },
        };
    }

    fn expectPeek(self: *Self, token_type: TokenType) bool {
        if (self.peek_token.type == token_type) {
            self.nextToken();
            return true;
        }
        return false;
    }

    fn parseLetStatement(self: *Self) !*const Let {
        const statement_token = self.current_token;

        if (!self.expectPeek(.identifier)) {
            return error.ExpectedIdentifier;
        }

        const statement_name = &Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        };

        if (!self.expectPeek(.assign)) {
            return error.ExpectedAssign;
        }

        while (self.current_token.type != .semicolon) {
            self.nextToken();
        }

        return &Let{
            .name = statement_name,
            .token = statement_token,
            .value = null,
        };
    }

    pub fn parseReturnStatement(self: *Self) !*const Return {
        const current_token = self.current_token;
        self.nextToken();

        while (self.current_token.type != .semicolon) {
            self.nextToken();
        }

        return &Return{
            .token = current_token,
            .return_value = null,
        };
    }

    fn parseExpressionByPrefix(self: *Self, token: Token) !*const Expression {
        return switch (token.type) {
            .identifier => &Expression{ .identifier = self.parseIdentifier() },
            else => return ParseError.InvalidExpression,
        };
    }

    fn parseExpressionStatement(self: *Self) !*const ExpressionStatement {
        const current_token = self.current_token;
        const expression = try self.parseExpression(.lowest);
        if (self.peek_token.type == .semicolon) {
            self.nextToken();
        }

        return &ExpressionStatement{
            .expression = expression,
            .token = current_token,
        };
    }

    fn parseExpression(self: *Self, precedence: Precedence) !*const Expression {
        _ = precedence;
        return try self.parseExpressionByPrefix(self.current_token);
    }

    fn parseIdentifier(self: *Self) *const Identifier {
        return &Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        };
    }
};

test "ParseLet" {
    const input =
        \\ let x = 5;
        \\ let y = 10;
        \\ let foobar = 41241;
    ;
    const allocator = std.testing.allocator;

    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();
    var parser = Parser.init(&lexer, &allocator);

    var program = try parser.parse();
    defer program.deinit();

    try std.testing.expect(program.statemets.items.len == 3);
}

test "ParseReturn" {
    const input =
        \\ return 5;
        \\ return 10;
        \\ return 9421421;
    ;

    const allocator = std.testing.allocator;

    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();
    var parser = Parser.init(&lexer, &allocator);

    var program = try parser.parse();
    defer program.deinit();

    try std.testing.expect(program.statemets.items.len == 3);
}
