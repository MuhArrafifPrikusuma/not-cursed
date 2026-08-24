//! manipulate terminal modes
const std = @import("std");
const root = @import("root.zig");
const sig = @import("signal.zig");

const posix = std.posix;
pub const RawFlag = enum {
    CLEANEXIT,
};
/// enable raw terminal mode
pub fn raw(comptime flag: ?RawFlag) !void {
    const sa: posix.Sigaction = .{
        .handler = .{ .handler = if (flag) |_| sig.sigCleanExit else sig.sigExit },
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

// NOTE: later make a writer function to easily read and write safely
// without the headache of using the standard stdin writer
/// will block until any key is pressed
/// this function will automatically advance therefore please use `.peekByte()`  if you want to check for input
pub fn waitKeyPress() !void {
    while (true) {
        _ = root.terminal.last_bytes orelse root.getCh() orelse continue;
        break;
    }
}

/// safely exit raw mode and return to original terminal state
pub fn wellDone() !void {
    try posix.tcsetattr(root.termios.fd, .FLUSH, root.termios.orig_termios);
}
