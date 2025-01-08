const std = @import("std");
const Lexer = @import("./Lexer.zig");

fn usage(invoked: [:0]u8) void {
    const print = std.debug.print;

    print(
        \\usage {s}: [script]
        \\
        \\  - invoking with no script will start an interactive session
    , .{invoked});
}

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

        var lexer = Lexer{ .source = src };
        const tokens = lexer.lexAlloc(ally);
        for (tokens) |tok| {
            try stdout.print("{s}({s})\n", .{ @tagName(tok.tag), src[tok.loc.start..tok.loc.end] });
        }

    } else {
        const stdin_file = std.io.getStdIn().reader();
        var br = std.io.bufferedReader(stdin_file);
        const stdin = br.reader();

        // todo these really dont need to be heap
        const buf: []u8 = try ally.alloc(u8, 2048);
        defer ally.free(buf);
        var tokens = std.ArrayList(Lexer.Token).init(ally);
        defer tokens.deinit();

        _ = try stdout.write("> ");
        try bw.flush();
        while (try stdin.readUntilDelimiterOrEof(buf, '\n')) |line| {
            tokens.clearAndFree();
            _ = Lexer.lex(line, &tokens) catch unreachable;
            for (tokens.items) |tok| {
                try stdout.print("{s}({s})\n", .{ @tagName(tok.tag), line[tok.loc.start..tok.loc.end] });
            }

            _ = try stdout.write("> ");
            try bw.flush();
            @memset(buf, 0);
        }
    }
}

