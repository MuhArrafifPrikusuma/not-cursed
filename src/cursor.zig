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
