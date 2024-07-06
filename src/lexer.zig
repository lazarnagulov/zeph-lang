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
        const token = switch (self.char) {
            '=' => Token.init(.assign, &[_]u8{self.char}),
            ';' => Token.init(.semicolon, &[_]u8{self.char}),
            ':' => Token.init(.colon, &[_]u8{self.char}),
            '(' => Token.init(.left_paren, &[_]u8{self.char}),
            ')' => Token.init(.right_paren, &[_]u8{self.char}),
            '{' => Token.init(.left_brace, &[_]u8{self.char}),
            '}' => Token.init(.right_brace, &[_]u8{self.char}),
            '0' => Token.init(.eof, &[_]u8{self.char}),
            'a'...'z', 'A'...'Z' => blk: {
                const identifier = self.readIdentifier();
                break :blk Token.init(self.checkIdentifier(identifier), identifier);
            },
            else => Token.init(.illegal, ""),
        };

        self.readChar();
        return token;
    }

    fn initKeywords(map: *std.StringHashMap(TokenType)) !void {
        try map.put("fn", .keyword_function);
        try map.put("let", .keyword_let);
        try map.put("end", .keyword_end);
    }

    fn checkIdentifier(self: *Self, identifier: []const u8) TokenType {
        if (self.keywords.get(identifier)) |token| {
            return token;
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

    fn readChar(self: *Self) void {
        if (self.readPosition > self.input.len) {
            self.char = '0';
        } else {
            self.char = self.input[self.readPosition];
        }
        self.position = self.readPosition;
        self.readPosition += 1;
    }
};

test "NextToken" {}
