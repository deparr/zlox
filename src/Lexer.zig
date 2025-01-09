const std = @import("std");
const Allocator = std.mem.Allocator;

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
        keyword_and,
        keyword_class,
        keyword_else,
        keyword_false,
        keyword_fun,
        keyword_for,
        keyword_if,
        keyword_nil,
        keyword_or,
        keyword_print,
        keyword_return,
        keyword_super,
        keyword_this,
        keyword_true,
        keyword_var,
        keyword_while,

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

        pub fn lexeme(self: Tag) []const u8 {
            return switch(self) {
                .keyword_and => "and",
                .keyword_class => "class",
                .keyword_else => "else",
                .keyword_false => "false",
                .keyword_fun => "fun",
                .keyword_for => "for",
                .keyword_if => "if",
                .keyword_nil => "nil",
                .keyword_or => "or",
                .keyword_print => "print",
                .keyword_return => "return",
                .keyword_super => "super",
                .keyword_this => "this",
                .keyword_true => "true",
                .keyword_var => "var",
                .keyword_while => "while",

                // operators
                .bang => "!",
                .bang_equal => "!=",
                .equal => "=",
                .equal_equal => "==",
                .greater => ">",
                .greater_equal => ">=",
                .less => "<",
                .less_equal => "<=",
                .plus => "+",
                .minus => "-",
                .star => "*",
                .slash => "/",

                // delimiters
                .left_paren => "(",
                .right_paren => ")",
                .left_brace => "{",
                .right_brace => "}",
                .comma => ",",
                .dot => ".",
                .semicolon => ";",

                // literals
                .identifier => "(ident)",
                .string => "(string)",
                .number => "(number)",

                .invalid => "invalid",
                .eof => "(eof)",
            };
        }
    };

    pub const keywords = std.StaticStringMap(Tag).initComptime(.{
        .{ "and", .keyword_and },
        .{ "class", .keyword_class },
        .{ "else", .keyword_else },
        .{ "false", .keyword_false },
        .{ "fun", .keyword_fun },
        .{ "for", .keyword_for },
        .{ "if", .keyword_if },
        .{ "nil", .keyword_nil },
        .{ "or", .keyword_or },
        .{ "print", .keyword_print },
        .{ "return", .keyword_return },
        .{ "super", .keyword_super },
        .{ "this", .keyword_this },
        .{ "true", .keyword_true },
        .{ "var", .keyword_var },
        .{ "while", .keyword_while },
    });

    pub fn getKeyword(str: []const u8) ?Tag {
        return keywords.get(str);
    }
};

pub const Lexer = struct {
    index: usize = 0,
    line: usize = 1,
    source: []const u8 = undefined,

    pub fn init(src: []const u8) Lexer {
        return Lexer{ .source = src, .index = 0, .line = 1 };
    }


    pub fn atEnd(self: *Lexer) bool {
        return self.index >= self.source.len;
    }

    inline fn at(self: Lexer) u8 {
        if (self.index >= self.source.len) {
            return 0;
        }
        return self.source[self.index];
    }

    const State = enum {
        start,
        maybe_equal,
        slash,
        string,
        comment,
        int,
        int_dot,
        float,
        identifier,
    };

    pub fn next(self: *Lexer) ?Token {
        var result: Token = .{ .loc = .{
            .start = self.index,
            .line = self.line,
        } };

        lexing: switch (State.start) {
            .start => {
                switch (self.at()) {
                    // todo this isnt correct start pos
                    0 => return null,
                    ' ', '\r', '\t', '\n' => {
                        if (self.at() == '\n')
                            self.line += 1;
                        result.loc.line += 1;
                        self.index += 1;
                        result.loc.start += 1;
                        continue :lexing .start;
                    },

                    '(' => {
                        self.index += 1;
                        result.tag = .left_paren;
                    },
                    ')' => {
                        self.index += 1;
                        result.tag = .right_paren;
                    },
                    '{' => {
                        self.index += 1;
                        result.tag = .left_brace;
                    },
                    '}' => {
                        self.index += 1;
                        result.tag = .right_brace;
                    },
                    ',' => {
                        self.index += 1;
                        result.tag = .comma;
                    },
                    '.' => {
                        self.index += 1;
                        result.tag = .dot;
                    },
                    ';' => {
                        self.index += 1;
                        result.tag = .semicolon;
                    },
                    '+' => {
                        self.index += 1;
                        result.tag = .plus;
                    },
                    '-' => {
                        self.index += 1;
                        result.tag = .minus;
                    },
                    '*' => {
                        self.index += 1;
                        result.tag = .star;
                    },

                    '!' => {
                        self.index += 1;
                        result.tag = .bang;
                        continue :lexing .maybe_equal;
                    },
                    '=' => {
                        self.index += 1;
                        result.tag = .equal;
                        continue :lexing .maybe_equal;
                    },
                    '>' => {
                        self.index += 1;
                        result.tag = .greater;
                        continue :lexing .maybe_equal;
                    },
                    '<' => {
                        self.index += 1;
                        result.tag = .less;
                        continue :lexing .maybe_equal;
                    },

                    '/' => {
                        self.index += 1;
                        result.tag = .slash;
                        continue :lexing .slash;
                    },

                    '"' => {
                        result.tag = .string;
                        continue :lexing .string;
                    },

                    '0'...'9' => {
                        result.tag = .number;
                        continue :lexing .int;
                    },

                    'A'...'Z', 'a'...'z', '_' => {
                        result.tag = .identifier;
                        continue :lexing .identifier;
                    },

                    else => result.tag = .invalid,
                }
            },

            .maybe_equal => {
                if (self.at() == '=') {
                    self.index += 1;
                    result.tag = result.tag.appendEqual();
                }
            },

            .slash => {
                // check for comment...
                if (self.at() == '/') {
                    continue :lexing .comment;
                }
            },

            .comment => {
                self.index += 1;
                switch (self.at()) {
                    '\n', 0 => continue :lexing .start,
                    else => continue :lexing .comment,
                }
            },

            .string => {
                self.index += 1;

                // a little strange
                switch (self.at()) {
                    '"' => {
                        // end string
                        self.index += 1;
                    },
                    0 => {
                        // todo error reporting
                        result.tag = .invalid;
                    },
                    '\n' => {
                        self.line += 1;
                        continue :lexing .string;
                    },
                    else => {
                        continue :lexing .string;
                    }
                }
            },

            .int => {
                self.index += 1;

                if (self.index >= self.source.len) {
                    std.debug.print("self.index: {d}, line: {d}, self.source: |{s}|\n", .{ self.index, self.line, self.source });
                    break :lexing;
                }

                switch (self.source[self.index]) {
                    '0'...'9' => continue :lexing .int,
                    '.' => continue :lexing .int_dot,
                    else => {},
                }
            },

            .int_dot => {
                if (self.index + 1 < self.source.len and std.ascii.isDigit(self.source[self.index + 1])) {
                    continue :lexing .float;
                }
            },

            .float => {
                self.index += 1;
                if (self.index < self.source.len and std.ascii.isDigit(self.at())) {
                    continue :lexing .float;
                }
            },

            .identifier => {
                self.index += 1;
                switch (self.at()) {
                    'A'...'Z', 'a'...'z', '_' => {
                        continue :lexing .identifier;
                    },
                    else => {
                        const str = self.source[result.loc.start..self.index];
                        if (Token.getKeyword(str)) |tag| {
                            result.tag = tag;
                        }
                    },
                }
            },
        }

        result.loc.end = self.index;
        return result;
    }

    /// calls self.next() to fill `tokens`
    /// always appends at least an eof token to `tokens`
    pub fn collect(self: *Lexer, tokens: *std.ArrayList(Token)) !void {
        while (self.next()) |token| {
            try tokens.append(token);
        }
        try tokens.append(Token{ .tag = .eof, .loc = .{ .start = self.index, .end = self.index, .line = self.line } });
    }

    /// consumes lexer into a `std.ArrayList(Token)`
    /// the returned ArrayList always contains at least an eof token
    pub fn collectAlloc(self: *Lexer, ally: Allocator) !std.ArrayList(Token) {
        var tokens = std.ArrayList(Token).init(ally);
        // todo dont just do this
        errdefer tokens.deinit();

        while (self.next()) |token| {
            try tokens.append(token);
        }
        try tokens.append(Token{ .tag = .eof, .loc = .{ .start = self.index, .end = self.index, .line = self.line } });

        return tokens;
    }
};
