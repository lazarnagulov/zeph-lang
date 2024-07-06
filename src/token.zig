pub const TokenType = enum {
    illegal,
    eof,
    identifier,
    int,
    assign,
    plus,
    comma,
    semicolon,
    colon,
    left_paren,
    right_paren,
    left_brace,
    right_brace,

    keyword_function,
    keyword_let,
    keyword_end,
};

pub const Token = struct {
    type: TokenType,
    literal: []const u8,

    pub fn init(tokenType: TokenType, literal: []const u8) Token {
        return Token{
            .type = tokenType,
            .literal = literal,
        };
    }
};
