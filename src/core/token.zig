pub const TokenType = enum {
    illegal,
    eof,

    identifier,
    int,

    assign,
    plus,
    minus,
    bang,
    asterisk,
    slash,
    gt,
    geq,
    lt,
    leq,
    equal,
    not_equal,

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
    keyword_return,
    keyword_else,
    keyword_if,
    keyword_true,
    keyword_false,
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
