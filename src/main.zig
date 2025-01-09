const std = @import("std");
const lex = @import("./lexer.zig");
const Lexer = lex.Lexer;
const parse = @import("./parser.zig");
const Parser = parse.Parser;

fn usage(invoked: [:0]u8) void {
    const print = std.debug.print;

    print(
        \\usage {s}: [script]
        \\
        \\  - invoking with no script will start an interactive session
    , .{invoked});
}

const prompt = "zlox> ";

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const ally = gpa.allocator();

    const args = try std.process.argsAlloc(ally);
    defer std.process.argsFree(ally, args);

    if (args.len >= 2 and std.mem.eql(u8, args[1], "-h")) {
        usage(args[0]);
        return;
    } else if (args.len >= 2) {
        const file = try std.fs.cwd().openFile(args[1], .{});
        const src = try file.readToEndAlloc(ally, 1 << 16);
        file.close();

        var lexer = Lexer.init(src);
        const tokens = try lexer.collectAlloc(ally);
        defer tokens.deinit();
        for (tokens.items) |tok| {
            try stdout.print("{s} ({s})\n", .{ @tagName(tok.tag), src[tok.loc.start..tok.loc.end] });
        }
        try bw.flush();
    } else {
        const stdin_file = std.io.getStdIn().reader();
        var br = std.io.bufferedReader(stdin_file);
        const stdin = br.reader();

        const buf = try ally.alloc(u8, 512);
        defer ally.free(buf);
        var tokens = std.ArrayList(lex.Token).init(ally);
        defer tokens.deinit();

        _ = try stdout.write(prompt);
        try bw.flush();
        while (try stdin.readUntilDelimiterOrEof(buf, '\n')) |line| {
            var lexer = Lexer.init(line);
            _ = lexer.collect(&tokens) catch unreachable;
            for (tokens.items) |tok| {
                try stdout.print("{s}('{s}') .{{ start={d} end={d} }}\n", .{ @tagName(tok.tag), line[tok.loc.start..tok.loc.end], tok.loc.start, tok.loc.end });
            }

            var parser = Parser{ .tokens = tokens, .ally = ally };

            const tree = try parser.parse();
            tree.walk();
            std.debug.print("\n", .{});

            tokens.clearAndFree();
            _ = try stdout.write(prompt);
            try bw.flush();
        }
    }
}
