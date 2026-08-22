const std = @import("std");
const nc = @import("not_cursed");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buf: [1]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &buf);
    const stdin = &reader.interface;

    try nc.Modes.raw();
    std.debug.print("entering raw mode\n", .{});

    while (true) {
        const char = try stdin.peekByte();
        try nc.Modes.waitKeyPress(stdin);

        std.debug.print("{c}", .{char});
        if (char == 'q') {
            try nc.Modes.wellDone();
            break;
        }
    }
}
