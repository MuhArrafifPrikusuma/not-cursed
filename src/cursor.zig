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

pub fn getCursor() void {
    var buf: [32]u8 = undefined;
    var reader = std.Io.File.stdin().reader(root.terminal.io, &buf);
    const stdin = &reader.interface;

    root.terminal.stdout.writeAll("\x1B[6n") catch |err| std.log.err("{any}\n", .{err});

    const slice = stdin.takeDelimiterExclusive('R') catch return;

    std.debug.print("cursor position: {s}\n", .{slice});
}
