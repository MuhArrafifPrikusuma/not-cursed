//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const root = @import("root");

pub const Modes = @import("modes.zig");
const Io = std.Io;

pub var termios: struct {
    fd: i32 = undefined,
    orig_termios: std.posix.termios = undefined,
    current_termios: std.posix.termios = undefined,
} = .{};

// pub fn init(proc_init: std.process.Init) !void {
//     const allocator = proc_init.arena.allocator();
//
//     const io = proc_init.io;
// }
// pub const config = struct {
//     pub const enable_cache: bool = if (@hasDecl(root, "")) {}
// };
/// This is a documentation comment to explain the `printAnotherMessage` function below.
///
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
