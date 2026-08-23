//! manipulate terminal modes
const std = @import("std");
const root = @import("root.zig");
const sig = @import("signal.zig");

/// enable raw terminal mode
pub fn raw() !void {
    const sa: std.posix.Sigaction = .{
        .handler = .{ .handler = sig.sigExit },
        .mask = std.posix.sigemptyset(),
        .flags = std.posix.SA.RESTART,
    };

    std.posix.sigaction(std.posix.SIG.TERM, &sa, null);
    std.posix.sigaction(std.posix.SIG.INT, &sa, null);

    root.termios.fd = std.Io.File.stdin().handle;

    root.termios.orig_termios = try std.posix.tcgetattr(root.termios.fd);

    var raw_mode = root.termios.orig_termios;
    raw_mode.lflag.ECHO = false;
    raw_mode.lflag.ICANON = false;

    try std.posix.tcsetattr(root.termios.fd, .FLUSH, raw_mode);

    root.termios.current_termios = raw_mode;
}
pub fn setClean(io: std.Io) !void {
    var buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    try stdout.print("\x1B[?1049h\x1B[H", .{});
    try stdout.flush();
}

// NOTE: later make a writer function to easily read and write safely
// without the headache of using the standard stdin writer
/// will block until any key is pressed
/// this function will automatically advance therefore please use `.peekByte()`  if you want to check for input
pub fn waitKeyPress(reader: *std.Io.Reader) !void {
    const stdin = reader;

    while (true) {
        _ = stdin.takeByte() catch continue;
        break;
    }
}

/// safely exit raw mode and return to original terminal state
pub fn wellDone() !void {
    try std.posix.tcsetattr(root.termios.fd, .FLUSH, root.termios.orig_termios);
}
