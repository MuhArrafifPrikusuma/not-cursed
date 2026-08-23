//! used only for internal library function do not expose this
const std = @import("std");
const root = @import("root.zig");

pub fn sigExit(sig: std.posix.SIG) callconv(.c) void {
    switch (sig) {
        std.posix.SIG.TERM, std.posix.SIG.INT => {
            root.Modes.wellDone() catch |err| std.log.err("{any}\n", .{err});
            std.process.exit(1);
        },
        else => {
            std.log.err("unhandled signal {any}\n", .{sig});
        },
    }
}
