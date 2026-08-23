//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const root = @import("root");

pub const Modes = @import("modes.zig");
pub const Cursor = @import("cursor.zig");

const Cell = struct {
    ch: u8,
    fg_color: i32,
    bg_color: i32,
};

const cursed = struct {
    rows: i32,
    cols: i32,
    virt_scr: []Cell,
    physc_scr: []Cell,
};

pub var screen: cursed = undefined;
//  NOTE: arena for screen remember to deinit later
var screen_arena: std.heap.ArenaAllocator = undefined;

pub var termios: struct {
    fd: i32 = undefined,
    orig_termios: std.posix.termios = undefined,
    current_termios: std.posix.termios = undefined,
} = .{};

/// NOTE: later on use terminal size for this one
pub fn init(rows: i32, cols: i32) !void {
    const allocator = std.heap.smp_allocator;
    screen_arena = .init(allocator);

    screen.rows = rows;
    screen.cols = cols;

    const total_cells: usize = @intCast(rows * cols);
    screen.virt_scr = try allocator.alloc(Cell, total_cells);
    screen.physc_scr = try allocator.alloc(Cell, total_cells);

    var i: usize = 0;
    while (i < rows * cols) : (i += 1) {
        screen.virt_scr[i] = Cell{ .ch = ' ', .fg_color = 7, .bg_color = 0 };
        screen.physc_scr[i] = Cell{ .ch = ' ', .fg_color = 7, .bg_color = 0 };
    }
}

pub fn mvaddch(rows: i32, cols: i32, char: u8, fg: i32, bg: i32) void {
    if (rows >= 0 and rows <= screen.rows and cols >= 0 and cols <= screen.cols) {
        const idx: usize = @as(usize, @intCast(rows * screen.cols + cols));
        screen.virt_scr[idx] = Cell{ .ch = char, .fg_color = fg, .bg_color = bg };
    }
}

pub fn refresh(io: std.Io) !void {
    var buf: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buf);
    const stdout = &writer.interface;

    var last_fg: i32 = -1;
    var last_bg: i32 = -1;

    var r: usize = 0;
    while (r < screen.rows) : (r += 1) {
        var c: usize = 0;
        while (c < screen.cols) : (c += 1) {
            const idx: usize = r * @as(usize, @intCast(screen.cols)) + c;

            const virt: Cell = screen.virt_scr[idx];
            const physc: Cell = screen.physc_scr[idx];

            if (virt.ch == physc.ch and virt.bg_color == physc.bg_color and virt.fg_color == physc.fg_color)
                continue;

            try stdout.print("\x1B[{d};{d}H", .{ r + 1, c + 1 });
            if (virt.fg_color != last_fg or virt.bg_color != last_bg) {
                // 5 is color format change it later to automatically fit user terminal
                try stdout.print("\x1B[38;5;{d}m\x1B[48;5;{d}m", .{ virt.fg_color, virt.bg_color });
                last_fg = virt.fg_color;
                last_bg = virt.bg_color;
            }

            try stdout.print("{c}", .{virt.ch});
            try stdout.print("\x1B[0m", .{});
            screen.physc_scr[idx] = virt;
        }
    }
    try stdout.flush();
}
/// Accepting an `Io.Writer` instance is a handy way to write reusable code.
pub fn printAnotherMessage(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print("Run `zig build test` to run the tests.\n", .{});
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}
