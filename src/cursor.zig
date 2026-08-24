const std = @import("std");
const root = @import("root.zig");

/// move cursor 0,0
pub fn home() !void {
    var buf: [6]u8 = undefined;
    var writer = std.Io.File.stdout().writer(root.terminal.io, &buf);
    const stdout = &writer.interface;

    try stdout.print("\x1B[H", .{});
    try stdout.flush();
}

pub fn mv(rows: i32, cols: i32) void {
    _ = rows;
    _ = cols;
    getCursor();
}

// NOTE: unfinished
pub fn getCursor() void {
    const stdin = &root.terminal.reader;
    const stdout = &root.terminal.writer;

    stdout.writeAll("\x1B[6n") catch |err| std.log.err("{any}\n", .{err});

    const slice = stdin.takeDelimiterExclusive('R') catch return;

    std.debug.print("cursor position: {s}\n", .{slice});
}
