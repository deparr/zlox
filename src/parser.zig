const std = @import("std");
const Allocator = std.mem.Allocator;

const lex = @import("./lexer.zig");
const Token = lex.Token;
const Tag = Token.Tag;
const expr = @import("./expr.zig");
const Expr = expr.Expr;
const UnaryExpr = expr.UnaryExpr;
const BinaryExpr = expr.BinaryExpr;
const ExprTag = expr.ExprTag;

pub const ParseError = error{
    UnexpectedToken,
    UnterminatedParen,
    OutOfMemory,
};

pub const Parser = struct {
    tokens: std.ArrayList(Token),
    ally: Allocator,
    index: usize = 0,
    err: Token.Loc = undefined,

    pub fn parse(self: *Parser) ParseError!*Expr {
        // this seems wrong
        if (self.expression()) |tree| {
            return tree;
        } else |err| {
            self.err = self.at().loc;
            return err;
        }
    }

    inline fn at(self: *Parser) Token {
        return self.tokens.items[self.index];
    }

    inline fn atEnd(self: *Parser) bool {
        return self.index >= self.tokens.items.len;
    }

    fn match(self: *Parser, tag: Token.Tag) bool {
        return !self.atEnd() and self.at().tag == tag;
    }

    fn next(self: *Parser) Token {
        _ = self;
    }

    fn expression(self: *Parser) ParseError!*Expr {
        return self.equality();
    }

    fn equality(self: *Parser) ParseError!*Expr {
        var left = try self.comparison();

        while (self.match(Tag.bang_equal) or self.match(Tag.equal_equal)) {
            const op = self.at();
         self.index += 1;
            const right = try self.comparison();
            const new = try expr.new(ExprTag.binary, self.ally);
            switch (new.*) {
                .binary => |exp| {
                    exp.op = op.tag;
                    exp.lhs = left;
                    exp.rhs = right;
                },
                else => unreachable,
            }
            left = new;
        }

        return left;
    }

    fn comparison(self: *Parser) ParseError!*Expr {
        var left = try self.term();

        while (
            self.match(Tag.greater)
            or self.match(Tag.greater_equal)
            or self.match(Tag.less)
            or self.match(Tag.less_equal
        )) {
            const op = self.at();
            self.index += 1;
            const right = try self.term();
            const new = try expr.new(ExprTag.binary, self.ally);
            switch (new.*) {
                .binary => |exp| {
                    exp.op = op.tag;
                    exp.lhs = left;
                    exp.rhs = right;
                },
                else => unreachable,
            }
            left = new;
        }

        return left;
    }

    fn term(self: *Parser) ParseError!*Expr {
        var left = try self.factor();

        while (self.match(Tag.minus) or self.match(Tag.plus)) {
            const op = self.at();
            self.index += 1;
            const right = try self.factor();
            const new = try expr.new(ExprTag.binary, self.ally);
            switch (new.*) {
                .binary => |exp| {
                    exp.op = op.tag;
                    exp.lhs = left;
                    exp.rhs = right;
                },
                else => unreachable,
            }
            left = new;
        }

        return left;
    }

    fn factor(self: *Parser) ParseError!*Expr {
        var left = try self.unary();

        while (self.match(Tag.slash) or self.match(Tag.star)) {
            const op = self.at();
            self.index += 1;
            const right = try self.unary();
            const new = try expr.new(ExprTag.binary, self.ally);
            switch (new.*) {
                .binary => |exp| {
                    exp.op = op.tag;
                    exp.lhs = left;
                    exp.rhs = right;
                },
                else => unreachable,
            }
            left = new;
        }

        return left;
    }

    fn unary(self: *Parser) ParseError!*Expr {
        if (self.match(Tag.bang) or self.match(Tag.minus)) {
            const op = self.at();
            self.index += 1;
            const right = try self.unary();
            const new = try expr.new(ExprTag.unary, self.ally);
            switch (new.*) {
                .unary => |exp| {
                    exp.op = op.tag;
                    exp.expr = right;
                },
                else => unreachable,
            }

            return new;
        }

        return try self.primary();
    }

    fn primary(self: *Parser) ParseError!*Expr {
        var val: ?expr.Value = undefined;
        switch (self.at().tag) {
            Tag.keyword_false => val = expr.Value { .boolean = false },
            Tag.keyword_true => val = expr.Value { .boolean = true },
            Tag.keyword_nil => val = null,
            Tag.number, Tag.string => unreachable, // todo update lexer to store literals
            Tag.left_paren => return self.grouping(),
            else => return ParseError.UnexpectedToken,
        }
        self.index += 1;

        const object = try expr.new(ExprTag.literal, self.ally);
        switch (object.*) {
            .literal => |_| {
                object.literal = val;
            },
            else => unreachable,
        }
        return object;
    }

    fn grouping(self: *Parser) ParseError!*Expr {
        self.index += 1;
        const grouped_exp = try self.expression();
        errdefer self.ally.destroy(grouped_exp);

        if (!self.match(Tag.right_paren)) {
            return ParseError.UnterminatedParen;
        }

        const group = try expr.new(ExprTag.group, self.ally);
        switch (group.*) {
            .group => |_| {
                group.group = grouped_exp;
            },
            else => unreachable,
        }

        return group;
    }
};
