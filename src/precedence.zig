const t = @import("token.zig");

const Token = t.Token;

pub const Precedence = enum(u4) {
    lowest = 0,
    equals = 1,
    less_greater = 2,
    sum = 3,
    product = 4,
    prefix = 5,
    call = 6,

    pub fn fromToken(token: Token) Precedence {
        return switch (token.type) {
            .equal => .equals,
            .not_equal => .equals,
            .lt => .less_greater,
            .gt => .less_greater,
            .geq => .less_greater,
            .leq => .less_greater,
            .plus => .sum,
            .minus => .sum,
            .slash => .product,
            .asterisk => .product,
            .left_paren => .call,
            else => .lowest,
        };
    }
};
