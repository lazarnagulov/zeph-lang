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
const FunctionLiteral = ast.FunctionLiteral;
const Boolean = ast.Boolean;
const Expression = ast.Expression;
const ExpressionStatement = ast.ExpressionStatement;
const PrefixExpression = ast.PrefixExpression;
const InfixExpression = ast.InfixExpression;
const CallExpression = ast.CallExpression;
const IfExpression = ast.IfExpression;
const BlockStatement = ast.BlockStatement;

const Precedence = p.Precedence;
const Lexer = l.Lexer;
const Token = t.Token;
const TokenType = t.TokenType;

pub const ParseError = error{
    ExpectedIdentifier,
    ExpectedAssign,
    ExpectedRightParen,
    ExpectedLeftParen,
    ExpectedColon,
    ExpectedSemicolon,
    ExpectedEnd,
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
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(lexer: *Lexer, allocator: std.mem.Allocator) Parser {
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
        var statemets = std.ArrayList(Statement).init(self.allocator);

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

        self.nextToken();
        const expression = try self.parseExpression(.lowest);

        if (self.peek_token.type == .semicolon) {
            self.nextToken();
        }

        const value = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        value.* = expression;

        return Let{
            .name = statement_name,
            .token = statement_token,
            .value = value,
        };
    }

    pub fn parseReturnStatement(self: *Self) !Return {
        const current_token = self.current_token;
        self.nextToken();

        const expression = try self.parseExpression(.lowest);

        if (self.peek_token.type == .semicolon) {
            self.nextToken();
        }

        const return_value = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        return_value.* = expression;

        return Return{
            .token = current_token,
            .return_value = return_value,
        };
    }

    fn parseExpressionByPrefix(self: *Self, token: Token) !Expression {
        return switch (token.type) {
            .identifier => .{ .identifier = self.parseIdentifier() },
            .int => .{ .int_literal = try self.parseIntegerLiteral() },
            .bang, .minus => .{ .prefix_expression = try self.parsePrefixExpression() },
            .keyword_true, .keyword_false => .{ .boolean = self.parseBoolean() },
            .keyword_if => blk: {
                var if_expression = try self.parseIfExpression();
                break :blk .{ .if_expression = &if_expression };
            },
            .keyword_function => .{ .function_literal = try self.parseFunctionLiteral() },
            .left_paren => try self.parseGroupExpression(),
            else => return ParseError.InvalidExpression,
        };
    }

    fn parseInfixExpressionByToken(self: *Self, token: Token, left: *Expression) !Expression {
        self.nextToken();
        return switch (token.type) {
            .plus, .minus, .asterisk, .slash, .equal, .not_equal, .gt, .lt, .geq, .leq => Expression{ .infix_expression = try self.parseInfixExpression(left) },
            .left_paren => .{ .call_expression = try self.parseCallExpression(left) },
            else => ParseError.InvalidInfix,
        };
    }

    fn parseExpressionStatement(self: *Self) !ExpressionStatement {
        const current_token = self.current_token;
        const expression = try self.parseExpression(.lowest);
        if (self.peek_token.type == .semicolon) {
            self.nextToken();
        }

        const return_expression = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        return_expression.* = expression;
        return .{
            .expression = return_expression,
            .token = current_token,
        };
    }

    fn parseExpression(self: *Self, precedence: Precedence) !Expression {
        var left_expression = try self.parseExpressionByPrefix(self.current_token);
        while (self.current_token.type != .semicolon and precedence.lessThen(Precedence.fromToken(self.peek_token))) {
            const left_expression_mem = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
            left_expression_mem.* = left_expression;
            left_expression = try self.parseInfixExpressionByToken(self.current_token, left_expression_mem);
        }

        return left_expression;
    }

    fn parseCallExpression(self: *Self, function: *Expression) !CallExpression {
        const current_token = self.current_token;
        var arguments = std.ArrayList(Expression).init(self.allocator);
        try self.parseCallArguments(&arguments);

        return CallExpression{
            .arguments = arguments,
            .token = current_token,
            .function = function,
        };
    }

    fn parseCallArguments(self: *Self, arguments: *std.ArrayList(Expression)) ParseError!void {
        if (self.peek_token.type == .right_paren) {
            self.nextToken();
            return;
        }

        self.nextToken();
        try arguments.*.append(try self.parseExpression(.lowest));

        while (self.peek_token.type == .comma) {
            self.nextToken();
            self.nextToken();
            try arguments.*.append(try self.parseExpression(.lowest));
        }

        if (!self.expectPeek(.right_paren)) {
            return ParseError.ExpectedRightParen;
        }
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

    fn parseFunctionLiteral(self: *Self) ParseError!FunctionLiteral {
        const current_token = self.current_token;
        if (!self.expectPeek(.left_paren)) {
            return ParseError.ExpectedLeftParen;
        }
        var parameters = std.ArrayList(Identifier).init(self.allocator);
        try self.parseFunctionParameters(&parameters);

        if (!self.expectPeek(.colon)) {
            return ParseError.ExpectedColon;
        }

        const body = try self.parseBlockStatement();

        return FunctionLiteral{
            .body = body,
            .parameters = parameters,
            .token = current_token,
        };
    }

    fn parseFunctionParameters(self: *Self, parameters: *std.ArrayList(Identifier)) !void {
        if (self.peek_token.type == .right_paren) {
            self.nextToken();
            return;
        }
        self.nextToken();
        try parameters.*.append(Identifier{
            .token = self.current_token,
            .value = self.current_token.literal,
        });

        while (self.peek_token.type == .comma) {
            self.nextToken();
            self.nextToken();
            try parameters.*.append(Identifier{
                .token = self.current_token,
                .value = self.current_token.literal,
            });
        }

        if (!self.expectPeek(.right_paren)) {
            return ParseError.ExpectedRightParen;
        }
    }

    fn parsePrefixExpression(self: *Self) ParseError!PrefixExpression {
        const current_token = self.current_token;
        self.nextToken();
        const expression = try self.parseExpression(.prefix);
        const right = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        right.* = expression;

        return PrefixExpression{
            .token = current_token,
            .operator = current_token.literal,
            .right = right,
        };
    }

    fn parseInfixExpression(self: *Self, left: *Expression) ParseError!InfixExpression {
        const current_token = self.current_token;
        self.nextToken();
        const expression = try self.parseExpression(Precedence.fromToken(current_token));
        const right = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        right.* = expression;

        return .{
            .token = current_token,
            .left = left,
            .operator = current_token.literal,
            .right = right,
        };
    }

    fn parseGroupExpression(self: *Self) ParseError!Expression {
        self.nextToken();

        const expression = self.parseExpression(.lowest);

        if (!self.expectPeek(.right_paren)) {
            return ParseError.ExpectedRightParen;
        }

        return expression;
    }

    fn parseIfExpression(self: *Self) ParseError!IfExpression {
        const current_token = self.current_token;

        if (!self.expectPeek(.left_paren)) {
            return ParseError.ExpectedLeftParen;
        }

        const condition = self.allocator.create(Expression) catch return ParseError.OutOfMemory;
        condition.* = try self.parseExpression(.lowest);
        if (self.current_token.type != .right_paren) {
            return ParseError.ExpectedRightParen;
        }

        if (!self.expectPeek(.colon)) {
            return ParseError.ExpectedColon;
        }

        const consequence = try self.parseBlockStatementOnDelimiter(.keyword_else);
        var alternative: ?BlockStatement = null;

        if (self.current_token.type == .keyword_else) {
            alternative = try self.parseBlockStatement();
        }

        return IfExpression{
            .token = current_token,
            .condition = condition,
            .consequence = consequence,
            .alternative = alternative,
        };
    }

    fn parseBlockStatementOnDelimiter(self: *Self, delimter: TokenType) !BlockStatement {
        var statements = std.ArrayList(Statement).init(self.allocator);

        self.nextToken();

        while (self.current_token.type != .keyword_end and self.current_token.type != delimter and self.current_token.type != .eof) {
            const statement = try self.parseStatement();
            try statements.append(statement);
            self.nextToken();
        }

        if (self.current_token.type != delimter and self.current_token.type != .keyword_end) {
            return ParseError.ExpectedEnd;
        }

        return BlockStatement{
            .statements = statements,
        };
    }

    fn parseBlockStatement(self: *Self) !BlockStatement {
        return try self.parseBlockStatementOnDelimiter(.keyword_end);
    }
};

test "ParseLet" {
    const input =
        \\ let x = 5;
        \\ let y = 15 + 20;
        \\ let foobar = 41241;
    ;
    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();
    var parser = Parser.init(&lexer, allocator.allocator());

    var program = try parser.parse();
    defer program.deinit();

    try std.testing.expect(program.statemets.items.len == 3);
}

test "ParseReturn" {
    //TODO: return;
    const input =
        \\ return 5;
        \\ return 10;
        \\ return 9421421;
    ;

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();
    var parser = Parser.init(&lexer, allocator.allocator());

    var program = try parser.parse();
    defer program.deinit();
    try std.testing.expect(program.statemets.items.len == 3);
}

test "ParseExpression" {
    const input = "5; 10; 20;";

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
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

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
    var program = try parser.parse();
    defer program.deinit();

    try std.testing.expectEqualStrings(program.statemets.items[0].expression_statement.expression.prefix_expression.operator, "!");
    try std.testing.expectEqualStrings(program.statemets.items[1].expression_statement.expression.prefix_expression.operator, "-");
    try std.testing.expectEqualStrings(program.statemets.items[2].expression_statement.expression.prefix_expression.operator, "-");
}

test "SegIf" {
    const input =
        \\ if (2 > 1):
        \\      5;
        \\ end;
    ;

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
    var program = try parser.parse();
    defer program.deinit();
}

test "ParseIf" {
    const input =
        \\if (a < b):
        \\    return false;
        \\else
        \\   if (b == a):
        \\      return false;
        \\   else
        \\      return true;
        \\   end;
        \\end;
    ;

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
    var program = try parser.parse();
    defer program.deinit();
}

test "ParseFunctionLiteral" {
    const input =
        \\let my_function = fn(a,b,c):
        \\    return a + b + c;
        \\end;
    ;

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
    var program = try parser.parse();
    defer program.deinit();
}

test "ParseCall" {
    const input = "add(a,b,c);";

    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();

    var lexer = try Lexer.init(input, allocator.allocator());
    defer lexer.deinit();

    var parser = Parser.init(&lexer, allocator.allocator());
    var program = try parser.parse();
    defer program.deinit();
}
