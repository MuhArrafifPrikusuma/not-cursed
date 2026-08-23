//! used only for internal library function do not expose this
const std = @import("std");
const root = @import("root.zig");
const posix = std.posix;

pub fn sigExit(sig: posix.SIG) callconv(.c) void {
    switch (sig) {
        posix.SIG.TERM, posix.SIG.INT => {
            root.Modes.wellDone() catch |err| std.log.err("{any}\n", .{err});
            std.process.exit(1);
        },
        else => {
            std.log.err("unhandled signal {any}\n", .{sig});
        },
    }
}
pub fn sigCleanExit(sig: posix.SIG) callconv(.c) void {
    switch (sig) {
        posix.SIG.TERM, posix.SIG.INT => {
            root.Modes.wellDone() catch |err| std.log.err("{any}\n", .{err});
            root.Modes.setClean() catch |err| std.log.err("{any}\n", .{err});
            std.process.exit(1);
        },
        else => {
            std.log.err("unhandled signal {any}\n", .{sig});
        },
    }
}

pub fn sigWinCh(_: posix.SIG) callconv(.c) void {
    std.debug.print("test\n", .{});
    root.window_resized.store(true, .monotonic);
}
