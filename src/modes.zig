//! manipulate terminal modes
const std = @import("std");
const root = @import("root.zig");
const sig = @import("signal.zig");

const posix = std.posix;
pub const RawFlag = enum {
    CLEANEXIT,
};
/// enable raw terminal mode
pub fn raw() !void {
    const stdout = &root.terminal.stdout_wrapper.interface;
    const sa: posix.Sigaction = .{
        .handler = .{ .handler = sig.sigExit },
        .mask = posix.sigemptyset(),
        .flags = posix.SA.RESTART,
    };

    posix.sigaction(posix.SIG.TERM, &sa, null);
    posix.sigaction(posix.SIG.INT, &sa, null);

    root.termios.fd = std.Io.File.stdin().handle;

    root.termios.orig_termios = try posix.tcgetattr(root.termios.fd);

    var raw_mode = root.termios.orig_termios;
    raw_mode.lflag.ECHO = false;
    raw_mode.lflag.ICANON = false;

    // read instant timeout after 1 bytes
    raw_mode.cc[@intFromEnum(posix.system.V.MIN)] = 1;
    raw_mode.cc[@intFromEnum(posix.system.V.TIME)] = 0;

    try stdout.writeAll("\x1B[?1049h");
    try stdout.flush();

    try posix.tcsetattr(root.termios.fd, .NOW, raw_mode);

    root.termios.current_termios = raw_mode;
}
pub fn setClean() !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(root.terminal.io, &buf);
    const stdout = &writer.interface;

    try stdout.print("\x1B[?1049h\x1B[H", .{});
    try stdout.flush();
}

pub fn waitKeyPress() root.Key {
    var key: root.Key = undefined;
    defer root.terminal.last_bytes = null;
    while (true) {
        key = root.terminal.last_bytes orelse root.getCh() orelse continue;
        break;
    }
    return key;
}
