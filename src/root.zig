//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");

pub const Modes = @import("modes.zig");
pub const Cursor = @import("cursor.zig");
pub const Sig = @import("signal.zig");

const posix = std.posix;
const Io = std.Io;

pub const Key = union(enum) {
    up,
    down,
    right,
    left,
    char: u8,
    escape,
    // NOTE: replace etc with all the other special key later
    etc,
    unknown,
};

// structs
const Cell = struct {
    ch: u8,
    fg_color: i32,
    bg_color: i32,
};

const Curs = struct {
    rows: usize,
    cols: usize,
    // add cursor configuration later, (like invisible blinking etc)
};

const Cursed = struct {
    rows: usize,
    cols: usize,
    virt_scr: []Cell,
    physc_scr: []Cell,
};

pub var termios: struct {
    fd: i32 = undefined,
    orig_termios: posix.termios = undefined,
    current_termios: posix.termios = undefined,
} = .{};

pub var terminal: struct {
    winsize: posix.winsize = undefined,
    screen: Cursed = undefined,

    cursor: Curs = Curs{ .rows = 0, .cols = 0 },
    last_bytes: ?Key = null,

    bufin: [1024]u8 = undefined,
    bufout: [1024]u8 = undefined,

    io: std.Io = undefined,
    stdin: *std.Io.Reader = undefined,
    stdout: *std.Io.Writer = undefined,
    stdin: *std.Io.Reader = undefined,
    last_bytes: ?u8 = null,
    io: std.Io = undefined,
} = .{};

//  NOTE: arena for screen remember to deinit later
var screen_arena: std.heap.ArenaAllocator = undefined;

// affected by signal
var window_resized: std.atomic.Value(bool) = .init(false);

/// NOTE: later on use terminal size for this one
pub fn init(io: std.Io) !void {
    terminal.io = io;
    getWinSize();

    const allocator = std.heap.smp_allocator;
    screen_arena = .init(allocator);

    var reader = std.Io.File.stdin().reader(terminal.io, &terminal.bufin);
    terminal.stdin = &reader.interface;

    var writer = std.Io.File.stdout().writer(terminal.io, &terminal.bufout);
    terminal.stdout = &writer.interface;

    terminal.screen.rows = terminal.winsize.row;
    terminal.screen.cols = terminal.winsize.col;

    const total_cells: usize = terminal.winsize.row * terminal.winsize.col + terminal.winsize.col;
    terminal.screen.virt_scr = try allocator.alloc(Cell, total_cells);
    terminal.screen.physc_scr = try allocator.alloc(Cell, total_cells);

    var i: usize = 0;
    while (i < total_cells) : (i += 1) {
        terminal.screen.virt_scr[i] = Cell{ .ch = ' ', .fg_color = 7, .bg_color = 20 };
        terminal.screen.physc_scr[i] = Cell{ .ch = ' ', .fg_color = 7, .bg_color = 20 };
    }
}

pub fn mvaddch(rows: i32, cols: i32, char: u8, fg: i32, bg: i32) void {
    if (rows >= 0 and rows <= terminal.screen.rows and cols >= 0 and cols <= terminal.screen.cols) {
        const idx: usize = @as(usize, @intCast(rows * terminal.winsize.col + cols));
        terminal.screen.virt_scr[idx] = Cell{ .ch = char, .fg_color = fg, .bg_color = bg };
    }
}

pub fn refresh() !void {
    var buf: [4096]u8 = undefined;
    var writer = Io.File.stdout().writer(terminal.io, &buf);
    const stdout = &writer.interface;

    var last_fg: i32 = -1;
    var last_bg: i32 = -1;

    var r: usize = 0;
    while (r < terminal.screen.rows) : (r += 1) {
        var c: usize = 0;
        while (c < terminal.screen.cols) : (c += 1) {
            const idx: usize = r * terminal.screen.cols + c;

            const virt: Cell = terminal.screen.virt_scr[idx];
            const physc: Cell = terminal.screen.physc_scr[idx];

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
            terminal.screen.physc_scr[idx] = virt;
        }
    }
    try stdout.flush();
}

/// handle window resizing automatically or pass your own function to handle it
fn handleResize(func: switch (builtin.os.tag) {
    .linux => ?*const fn (posix.SIG) callconv(.c) void,
    else => @compileError("not supported\n"),
}) void {
    switch (builtin.os.tag) {
        .linux => {
            const sa: posix.Sigaction = .{
                .handler = .{ .handler = if (func) |fun| fun else Sig.sigWinCh },
                .mask = posix.sigemptyset(),
                .flags = posix.SA.RESTART,
            };

            posix.sigaction(posix.SIG.WINCH, &sa, null);
        },
    }
}

/// NOTE: finish later
pub fn autoResize() void {
    if (!window_resized.load(.monotonic)) return;
    //
    // const old_size: usize = terminal.screen.rows * terminal.screen.cols + terminal.screen.cols;
    // const new_size: usize = terminal.winsize.row * terminal.winsize.col + terminal.winsize.col;
    // const diff = old_size - new_size;
    //
    // var r: usize = 0;
    // while (r < terminal.screen.rows) : (r += 1) {
    //     var c: usize = 0;
    //     while (c < terminal.screen.cols) : (c += 1) {
    //         const idx: usize = r * terminal.screen.cols + c;
    //
    //
    //     }
    // }
}

/// get current window size
pub fn getWinSize() void {
    const out_fd = Io.File.stdout().handle;
    switch (builtin.os.tag) {
        .linux => {
            var size: posix.winsize = .{
                .col = 0,
                .row = 0,
                .xpixel = 0,
                .ypixel = 0,
            };

            const result = posix.system.ioctl(out_fd, posix.T.IOCGWINSZ, @intFromPtr(&size));

            if (result != 0) {
                std.log.err("failed to read terminal size\n", .{});
                return;
            }

            terminal.winsize.col = size.col;
            terminal.winsize.row = size.row;
            terminal.winsize.xpixel = size.xpixel;
            terminal.winsize.ypixel = size.ypixel;

            std.debug.print("now size: {any}\n", .{size});
            return;
        },
        else => @compileError("not supported\n"),
    }
}

/// NOTE: this isn't perfect yet it still need to handle special multi bytes characters
pub fn getCh() ?Key {
    const bytes_read = posix.read(termios.fd, &terminal.bufin) catch |err| {
        std.log.err("{any}\n", .{err});
        return null;
    };
    // if (bytes_read == 0) return null;

    const key = parseKey(terminal.bufin[0..bytes_read]);
    return key;
}

fn parseKey(seq: []const u8) Key {
    if (seq.len == 0) return .unknown;

    if (seq[0] == 0x1B) {
        if (seq.len == 1) return .escape;

        if (seq.len >= 3 and seq[1] == '[') {
            return switch (seq[2]) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                else => .unknown,
            };
        }
    }
    if (seq.len == 1) return .{ .char = seq[0] };
    return .unknown;
pub fn getCh() ?u8 {
    terminal.last_bytes = terminal.stdin.takeByte() catch return null;
    return terminal.last_bytes;
}
