const std = @import("std");
const root = @import("root.zig");

/// move cursor 0,0
pub fn home(io: std.Io) !void {
    var buf: [256]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    try stdout.print("\x1B[H", .{});
    try stdout.flush();
}
