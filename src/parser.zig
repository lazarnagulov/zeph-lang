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
const IntegerLiteral = ast.IntegerLiteral;
const Boolean = ast.Boolean;
const Expression = ast.Expression;
const ExpressionStatement = ast.ExpressionStatement;
const PrefixExpression = ast.PrefixExpression;
const InfixExpression = ast.InfixExpression;

const Precedence = p.Precedence;
const Lexer = l.Lexer;
const Token = t.Token;
const TokenType = t.TokenType;

pub const ParseError = error{
    ExpectedIdentifier,
    ExpectedAssign,
    ExprectedRightParen,
    InvalidProgram,
    InvalidExpression,
    InvalidInteger,
    InvalidInfix,
    OutOfMemory,
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
            statemets.append(statement) catch return ParseError.InvalidProgram;
            self.nextToken();
        }
        return Program.init(&statemets);
    }

    fn nextToken(self: *Self) void {
        self.current_token = self.peek_token;
        self.peek_token = self.lexer.GetNextToken();
    }

    fn parseStatement(self: *Self) !Statement {
        return switch (self.current_token.type) {
            .keyword_let => Statement{ .let = try self.parseLetStatement() },
            .keyword_return => Statement{ .ret = try self.parseReturnStatement() },
            else => Statement{ .expression_statement = try self.parseExpressionStatement() },
        };
    }

    fn expectPeek(self: *Self, token_type: TokenType) bool {
        if (self.peek_token.type == token_type) {
            self.nextToken();
            return true;
        }
        return false;
    }

    fn parseLetStatement(self: *Self) !Let {
        const statement_token = self.current_token;

        if (!self.expectPeek(.identifier)) {
            return error.ExpectedIdentifier;
        }

        const statement_name = Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        };

        if (!self.expectPeek(.assign)) {
            return error.ExpectedAssign;
        }

        while (self.current_token.type != .semicolon) {
            self.nextToken();
        }

        return Let{
            .name = statement_name,
            .token = statement_token,
            .value = null,
        };
    }

    pub fn parseReturnStatement(self: *Self) !Return {
        const current_token = self.current_token;
        self.nextToken();

        while (self.current_token.type != .semicolon) {
            self.nextToken();
        }

        return Return{
            .token = current_token,
            .return_value = null,
        };
    }

    fn parseExpressionByPrefix(self: *Self, token: Token) !Expression {
        return switch (token.type) {
            .identifier => .{ .identifier = self.parseIdentifier() },
            .int => .{ .int_literal = try self.parseIntegerLiteral() },
            .bang, .minus => .{ .prefix_expression = try self.parsePrefixExpression() },
            .keyword_true, .keyword_false => .{ .boolean = self.parseBoolean() },
            .left_paren => try self.parseGroupExpression(),
            else => return ParseError.InvalidExpression,
        };
    }

    fn parseInfixExpressionByToken(self: *Self, token: Token, left: *Expression) !Expression {
        self.nextToken();
        return switch (token.type) {
            .plus, .minus, .asterisk, .slash, .equal, .not_equal, .gt, .lt, .geq, .leq => Expression{ .infix_expression = try self.parseInfixExpression(left) },
            else => ParseError.InvalidInfix,
        };
    }

    fn parseExpressionStatement(self: *Self) !ExpressionStatement {
        const current_token = self.current_token;
        const expression = try self.parseExpression(.lowest);
        if (self.peek_token.type == .semicolon) {
            self.nextToken();
        }

        return .{
            .expression = expression,
            .token = current_token,
        };
    }

    fn parseExpression(self: *Self, precedence: Precedence) !Expression {
        var left_expression = try self.parseExpressionByPrefix(self.current_token);
        while (self.current_token.type != .semicolon and precedence.lessThen(Precedence.fromToken(self.peek_token))) {
            left_expression = try self.parseInfixExpressionByToken(self.current_token, &left_expression);
        }

        return left_expression;
    }

    fn parseIdentifier(self: *Self) Identifier {
        return Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        };
    }

    fn parseIntegerLiteral(self: *Self) !IntegerLiteral {
        const value = std.fmt.parseInt(i64, self.current_token.literal, 10) catch return ParseError.InvalidInteger;
        return IntegerLiteral{
            .token = self.current_token,
            .value = value,
        };
    }

    fn parseBoolean(self: *Self) Boolean {
        return .{
            .token = self.current_token,
            .value = self.current_token.type == .keyword_true,
        };
    }

    fn parsePrefixExpression(self: *Self) ParseError!PrefixExpression {
        const current_token = self.current_token;
        self.nextToken();
        var expression = try self.parseExpression(.prefix);

        return PrefixExpression{
            .token = current_token,
            .operator = current_token.literal,
            .right = &expression,
        };
    }

    fn parseInfixExpression(self: *Self, left: *Expression) ParseError!InfixExpression {
        const current_token = self.current_token;
        self.nextToken();
        var right = try self.parseExpression(Precedence.fromToken(current_token));
        return .{
            .token = current_token,
            .left = left,
            .operator = current_token.literal,
            .right = &right,
        };
    }

    fn parseGroupExpression(self: *Self) ParseError!Expression {
        self.nextToken();
        const expression = self.parseExpression(.lowest);

        if (self.expectPeek(.right_paren)) {
            return ParseError.ExprectedRightParen;
        }

        return expression;
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

test "ParseExpression" {
    const input = "5; 10; 20;";

    const allocator = std.testing.allocator;

    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();

    var parser = Parser.init(&lexer, &allocator);
    var program = try parser.parse();
    defer program.deinit();

    for (program.statemets.items) |statement| {
        try std.testing.expect(statement.expression_statement.token.type == .int);
    }
}

test "ParsePrefix" {
    const input =
        \\ !5;
        \\ -foobar;
        \\ -5;
    ;

    const allocator = std.testing.allocator;

    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();

    var parser = Parser.init(&lexer, &allocator);
    var program = try parser.parse();
    defer program.deinit();

    try std.testing.expectEqualStrings(program.statemets.items[0].expression_statement.expression.prefix_expression.operator, "!");
    try std.testing.expectEqualStrings(program.statemets.items[1].expression_statement.expression.prefix_expression.operator, "-");
    try std.testing.expectEqualStrings(program.statemets.items[2].expression_statement.expression.prefix_expression.operator, "-");
}

test "ParseInfix" {
    const input = "true;";
    const allocator = std.testing.allocator;

    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();

    var parser = Parser.init(&lexer, &allocator);
    var program = try parser.parse();
    defer program.deinit();
}
