const t = @import("token.zig");
const std = @import("std");

const Token = t.Token;
const TokenType = t.TokenType;

pub const Lexer = struct {
    input: []const u8,
    position: usize,
    readPosition: usize,
    char: u8,

    const Self = @This();

    pub fn init(input: []const u8) Lexer {
        var lexer = Lexer{
            .input = input,
            .position = 0,
            .readPosition = 0,
            .char = '0',
        };
        lexer.readChar();
        return lexer;
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
            'a'...'z', 'A'...'Z' => Token.init(.identifier, self.readIdentifier()),
            else => Token.init(.illegal, ""),
        };

        self.readChar();
        return token;
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
