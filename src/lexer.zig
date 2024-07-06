const t = @import("token.zig");
const std = @import("std");

const Token = t.Token;
const TokenType = t.TokenType;

pub const Lexer = struct {
    input: []const u8,
    position: usize,
    readPosition: usize,
    char: u8,
    keywords: std.StringHashMap(TokenType),

    const Self = @This();

    pub fn init(input: []const u8, allocator: *const std.mem.Allocator) !Lexer {
        var keywords_map = std.StringHashMap(TokenType).init(allocator.*);
        try initKeywords(&keywords_map);

        var lexer = Lexer{ .input = input, .position = 0, .readPosition = 0, .char = '0', .keywords = keywords_map };
        lexer.readChar();

        return lexer;
    }

    pub fn deinit(self: *Self) void {
        self.keywords.deinit();
    }

    pub fn GetNextToken(self: *Self) Token {
        self.skipWhitespaces();
        const token = switch (self.char) {
            '=' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk Token.init(.equal, "==");
                }
                break :blk Token.init(.assign, "=");
            },
            ';' => Token.init(.semicolon, ";"),
            ':' => Token.init(.colon, ":"),
            ',' => Token.init(.comma, ","),
            '(' => Token.init(.left_paren, "("),
            ')' => Token.init(.right_paren, ")"),
            '{' => Token.init(.left_brace, "{"),
            '}' => Token.init(.right_brace, "}"),
            '+' => Token.init(.plus, "+"),
            '-' => Token.init(.minus, "-"),
            '*' => Token.init(.asterisk, "*"),
            '/' => Token.init(.slash, "/"),
            '!' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk Token.init(.not_equal, "!=");
                }
                break :blk Token.init(.bang, "!");
            },
            '>' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk Token.init(.geq, ">=");
                }
                break :blk Token.init(.gt, &[_]u8{self.char});
            },
            '<' => blk: {
                if (self.peekChar() == '=') {
                    self.readChar();
                    break :blk Token.init(.leq, "<=");
                }
                break :blk Token.init(.lt, &[_]u8{self.char});
            },
            'a'...'z', 'A'...'Z' => {
                const identifier = self.readIdentifier();
                return Token.init(self.checkIdentifier(identifier), identifier);
            },
            '0'...'9' => blk: {
                if (self.position >= self.input.len) {
                    break :blk Token.init(.eof, "eof");
                }
                const number = self.readNumber();
                return Token.init(.int, number);
            },
            else => Token.init(.illegal, "illegal"),
        };

        self.readChar();
        return token;
    }

    fn initKeywords(map: *std.StringHashMap(TokenType)) !void {
        try map.put("fn", .keyword_function);
        try map.put("let", .keyword_let);
        try map.put("if", .keyword_if);
        try map.put("else", .keyword_else);
        try map.put("true", .keyword_true);
        try map.put("false", .keyword_false);
        try map.put("return", .keyword_return);
        try map.put("end", .keyword_end);
    }

    fn skipWhitespaces(self: *Self) void {
        while (std.ascii.isWhitespace(self.char)) {
            self.readChar();
        }
    }

    fn peekChar(self: *Self) u8 {
        if (self.readPosition >= self.input.len) {
            return '0';
        } else {
            return self.input[self.readPosition];
        }
    }

    fn checkIdentifier(self: *Self, identifier: []const u8) TokenType {
        if (self.keywords.get(identifier)) |token_type| {
            return token_type;
        }
        return .identifier;
    }

    fn readIdentifier(self: *Self) []const u8 {
        const position = self.position;
        while (std.ascii.isAlphabetic(self.char)) {
            self.readChar();
        }
        return self.input[position..self.position];
    }

    fn readNumber(self: *Self) []const u8 {
        const position = self.position;
        while (std.ascii.isDigit(self.char)) {
            self.readChar();
        }
        return self.input[position..self.position];
    }

    fn readChar(self: *Self) void {
        if (self.readPosition >= self.input.len) {
            self.char = '0';
        } else {
            self.char = self.input[self.readPosition];
        }
        self.position = self.readPosition;
        self.readPosition += 1;
    }
};

test "NextToken" {
    const input =
        \\ let check = fn():
        \\      let a = 5;
        \\      let b = 10;
        \\      if(a + b >= 15):
        \\          return true;
        \\      end;
        \\      return false;
        \\ end;
    ;
    const result = [_]Token{
        Token.init(.keyword_let, "let"),
        Token.init(.identifier, "check"),
        Token.init(.assign, "="),
        Token.init(.keyword_function, "fn"),
        Token.init(.left_paren, "("),
        Token.init(.right_paren, ")"),
        Token.init(.colon, ":"),
        Token.init(.keyword_let, "let"),
        Token.init(.identifier, "a"),
        Token.init(.assign, "="),
        Token.init(.int, "5"),
        Token.init(.semicolon, ";"),
        Token.init(.keyword_let, "let"),
        Token.init(.identifier, "b"),
        Token.init(.assign, "="),
        Token.init(.int, "10"),
        Token.init(.semicolon, ";"),
        Token.init(.keyword_if, "if"),
        Token.init(.left_paren, "("),
        Token.init(.identifier, "a"),
        Token.init(.plus, "+"),
        Token.init(.identifier, "b"),
        Token.init(.geq, ">="),
        Token.init(.int, "15"),
        Token.init(.right_paren, ")"),
        Token.init(.colon, ":"),
        Token.init(.keyword_return, "return"),
        Token.init(.keyword_true, "true"),
        Token.init(.semicolon, ";"),
        Token.init(.keyword_end, "end"),
        Token.init(.semicolon, ";"),
        Token.init(.keyword_return, "return"),
        Token.init(.keyword_false, "false"),
        Token.init(.semicolon, ";"),
        Token.init(.keyword_end, "end"),
        Token.init(.semicolon, ";"),
        Token.init(.eof, "eof"),
    };

    const allocator = std.testing.allocator;
    var lexer = try Lexer.init(input, &allocator);
    defer lexer.deinit();

    for (result) |token| {
        const current_token = lexer.GetNextToken();
        try std.testing.expectEqual(token.type, current_token.type);
        try std.testing.expectEqualStrings(token.literal, current_token.literal);
    }
}
