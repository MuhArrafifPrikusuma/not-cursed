const std = @import("std");
const root = @import("root.zig");

pub const Color = struct {
    red: ?u8 = 0,
    green: ?u8 = 0,
    blue: ?u8 = 0,
    /// 8 bits color for fallback if terminal doesn't support
    /// if doesn't set it will default to 0 for bg and 7 for fg
    fallback: ?u8 = 0,
};

const default_fg: Color = .{ .fallback = 7, .red = 255, .blue = 255, .green = 255 };
const default_bg: Color = .{ .fallback = 0, .red = 255, .blue = 255, .green = 255 };

pub const setColor: *const fn (fg: Color, bg: Color) anyerror!void = setColor8bits;

/// set color for everything below it until resetColor is called
pub fn setColorRGB(fg: Color, bg: Color) !void {
    const foreground: Color = .{
        .red = fg.red orelse default_fg.red,
        .green = fg.green orelse default_fg.green,
        .blue = fg.blue orelse default_fg.blue,
    };

    const background: Color = .{
        .red = bg.red orelse default_bg.red,
        .green = bg.green orelse default_bg.green,
        .blue = bg.blue orelse default_bg.blue,
    };

    const stdout = &root.terminal.stdout_wrapper.interface;
    try stdout.print("\x1B[38;2;{d};{d};{d}m\x1B[48;2;{d};{d};{d}m", .{
        foreground.red.?,
        foreground.green.?,
        foreground.blue.?,
        background.red.?,
        background.green.?,
        background.blue.?,
    });
    try stdout.flush();
}

pub fn setColor8bits(fg: Color, bg: Color) !void {
    const foreground = fg.fallback orelse default_fg.fallback;
    const background = bg.fallback orelse default_bg.fallback;

    const stdout = &root.terminal.stdout_wrapper.interface;
    try stdout.print("\x1B[38;5;{d}m\x1B[48;5;{d}m", .{ foreground.?, background.? });
    try stdout.flush();
}

pub fn resetColor() !void {
    const stdout = &root.terminal.stdout_wrapper.interface;
    try stdout.print("\x1B[0m", .{});
    try stdout.flush();
}
