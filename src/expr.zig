const std = @import("std");
const Allocator = std.mem.Allocator;
const lex = @import("./lexer.zig");
const Token = lex.Token;
const Operator = lex.Token.Tag;

pub const Value = union(enum) {
    string: []u8,
    number: f64,
    boolean: bool,
    // object
};

pub const ExprTag = enum {
    binary,
    group,
    literal,
    unary,
};

pub const Expr = union(ExprTag) {
    binary: *BinExpr,
    group: *Expr,
    literal: ?Value,
    unary: *UnaryExpr,

    /// dump expr tree to stderr 
    pub fn walk(self: *Expr) void {
        const print = std.debug.print;
        switch (self.*) {
            .binary => |e| {
                print("({s} ", .{e.op.lexeme()});
                e.lhs.walk();
                print(" ", .{});
                e.rhs.walk();
                print(")", .{});
            },
            .unary => |e| {
                print("({s} ", .{e.op.lexeme()});
                e.expr.walk();
                print(")", .{});
            },
            .literal => |val| {
                if (val) |v| {
                    switch (v) {
                        .boolean => |b| print("{}", .{b}),
                        else => unreachable,
                    }
                } else {
                    print("nil", .{});
                }
            },
            .group => |e| {
                print("(group ", .{});
                e.walk();
                print(")", .{});
            },
        }
    }
};

pub const BinExpr = struct {
    op: Token.Tag,
    lhs: *Expr,
    rhs: *Expr,
};

pub const UnaryExpr = struct {
    op: Operator,
    expr: *Expr,
};

// pub fn new(kind: ExprTag, ally: Allocator)  !*Expr {
//     var expr = try ally.create(Expr);
//     switch (kind) {
//         .binary => expr.binary = try ally.create(BinExpr),
//         .group => expr.group = undefined,
//         .unary => expr.unary = try ally.create(UnaryExpr),
//         .literal => expr.literal = undefined,
//     }
//     return expr;
// }

pub fn new(kind: ExprTag, ally: Allocator) !*Expr {
    const expr = try ally.create(Expr);
    switch (kind) {
        .binary => expr.* = Expr{ .binary = try ally.create(BinExpr) },
        .group => expr.* = Expr{ .group = undefined },
        .unary => expr.* = Expr{ .unary = try ally.create(UnaryExpr) },
        .literal => expr.* = Expr{ .literal = null },
    }
    return expr;
}

