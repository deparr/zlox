const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @This();

pub const Token = struct {
    loc: Loc,
    tag: Tag = .invalid,
    // final Object literal // how to represent this

    pub const Loc = struct {
        start: usize = 0,
        end: usize = 0,
        line: usize = 1,
    };

    pub const Tag = enum {
        // keywords
        kw_and,
        kw_class,
        kw_else,
        kw_false,
        kw_fun,
        kw_for,
        kw_if,
        kw_nil,
        kw_or,
        kw_print,
        kw_return,
        kw_super,
        kw_this,
        kw_true,
        kw_var,
        kw_while,

        // operators
        bang,
        bang_equal,
        equal,
        equal_equal,
        greater,
        greater_equal,
        less,
        less_equal,
        plus,
        minus,
        star,
        slash,

        // delimiters
        left_paren,
        right_paren,
        left_brace,
        right_brace,
        comma,
        dot,
        semicolon,

        // literals
        identifier,
        string,
        number,

        invalid,
        eof,

        pub fn appendEqual(self: Tag) Tag {
            switch (self) {
                .bang => return .bang_equal,
                .equal => return .equal_equal,
                .greater => return .greater_equal,
                .less => return .less_equal,
                else => return self,
            }
        }
    };
};

source: []const u8 = undefined,

pub fn init(src: []const u8) Lexer {
    return Lexer{ .source = src };
}

pub fn lexAlloc(self: *Lexer, ally: Allocator) []Token {
    _ = self;
    _ = ally;
    return undefined;
}

const State = enum {
    start,
    maybe_equal,
    slash,
    string,
    int,
    int_dot,
    float,
};

pub fn lex(src: []const u8, tokens: *std.ArrayList(Token)) !*std.ArrayList(Token) {
    var current: usize = 0;
    var line: usize = 1;

    loop: while (current < src.len) {
        var result: Token = .{
            .loc = . {
                .start = current,
                .line = line,
            },
        };
        blk: switch (State.start) {
            .start => {
                switch (src[current]) {
                    // todo this isnt correct start pos
                    ' ', '\r', '\t', '\n' => {
                        if (src[current] == '\n')
                            line += 1;
                            result.loc.line += 1;
                        current += 1;
                        result.loc.start += 1;
                        continue :blk .start;
                    },

                    '(' => result.tag = .left_paren,
                    ')' => result.tag = .right_paren,
                    '{' => result.tag = .left_brace,
                    '}' => result.tag = .right_brace,
                    ',' => result.tag = .comma,
                    '.' => result.tag = .dot,
                    ';' => result.tag = .semicolon,
                    '+' => result.tag = .plus,
                    '-' => result.tag = .minus,
                    '*' => result.tag = .star,

                    '!' => {
                        result.tag = .bang;
                        continue :blk .maybe_equal;
                    },
                    '=' => {
                        result.tag = .equal;
                        continue :blk .maybe_equal;
                    },
                    '>' => {
                        result.tag = .greater;
                        continue :blk .maybe_equal;
                    },
                    '<' => {
                        result.tag = .less;
                        continue :blk .maybe_equal;
                    },

                    '/' => {
                        result.tag = .slash;
                        continue :blk .slash;
                    },

                    '"' => {
                        result.tag = .string;
                        continue :blk .string;
                    },

                    '0'...'9' => {
                        result.tag = .number;
                        continue :blk .int;
                    },

                    else => result.tag = .invalid,
                }
            },

            .maybe_equal => {
                if (current + 1 < src.len and src[current + 1] == '=') {
                    current += 1;
                    result.tag = result.tag.appendEqual();
                }
            },

            // todo don't inline the loops here, use the switch states
            .slash => {
                // check for comment...
                if (current + 1 < src.len and src[current + 1] == '/') {
                    current += 2;
                    while (current < src.len and src[current] != '\n') current += 1;

                    // todo better setup for this
                    if (current >= src.len) {
                        break :loop;
                    }

                    continue :blk .start;
                }
            },

            .string => {
                current += 1;

                // a little strange
                while (current < src.len and src[current] != '"') {
                    if (src[current] == '\n') {
                        line += 1;
                    }
                    current += 1;
                }

                if (current >= src.len) {
                    break :loop;
                }
            },

            .int => {
                current += 1;

                // todo left off with this weird problem
                if (current >= src.len) {
                    std.debug.print("current: {s}, line: {d}, src: |{s}|\n", .{current, line, src});
                    break :loop;
                }
                switch (src[current]) {
                    '0'...'9' => continue :blk .int,
                    '.' => continue :blk .int_dot,
                    else => {},
                }
                continue :blk .int;
            },

            .int_dot => {
                if (current + 1 < src.len and std.ascii.isDigit(src[current])) {
                    current += 1;
                    continue :blk .float;
                } else {
                    // this shoudl be invalid token
                }
            },

            .float => {
                current += 1;
                if (current < src.len and std.ascii.isDigit(src[current])) {
                    continue :blk .float;
                }
            }
        }

        current += 1;

        result.loc.end = current;
        // todo handle these instead of bubbling
        try tokens.append(result);
    }

    try tokens.append(Token{
        .tag = .eof,
        .loc = .{ .start = current, .end = current, .line = line }
    });

    return tokens;
}
