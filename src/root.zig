//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");

pub const Modes = @import("modes.zig");
pub const Cursor = @import("cursor.zig");
pub const Sig = @import("signal.zig");
const Colors = @import("Color.zig");

const posix = std.posix;
const Io = std.Io;

// expose

pub var color: struct {
    resetColor: @TypeOf(Colors.resetColor()) = Colors.resetColor(),
    setColor: @TypeOf(Colors.setColor) = undefined,
    Color: Colors.Color = .{},
} = .{};

pub const Key = union(enum) {
    up,
    down,
    right,
    left,
    char: u8,
    escape,
    // NOTE: replace etc with all the other special key later
    etc,
};

// // structs
// const Cell = struct {
//     ch: u8,
//     fg_color: i32,
//     bg_color: i32,
// };

const Curs = struct {
    rows: usize,
    cols: usize,
    // add cursor configuration later, (like invisible blinking etc)
};

const Cursed = struct {
    rows: usize,
    cols: usize,
    virt_scr: []u8,
    physc_scr: []u8,
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

    support_true_color: bool = false,

    bufin: [1024]u8 = undefined,
    bufout: [1024]u8 = undefined,

    io: std.Io = undefined,
    stdout_wrapper: std.Io.File.Writer = undefined,
    stdin_wrapper: std.Io.File.Reader = undefined,

    pub fn init(self: *@This(), io: std.Io) void {
        self.stdout_wrapper = std.Io.File.stdout().writerStreaming(io, &self.bufout);
        self.stdin_wrapper = std.Io.File.stdin().readerStreaming(io, &self.bufin);
    }
} = .{};

//  NOTE: arena for screen remember to deinit later
var screen_arena: std.heap.ArenaAllocator = undefined;

// affected by signal
var window_resized: std.atomic.Value(bool) = .init(false);

/// NOTE: later on use terminal size for this one
pub fn init(env: *std.process.Environ.Map, io: std.Io) !void {
    terminal.io = io;
    getWinSize();

    const allocator = std.heap.smp_allocator;
    screen_arena = .init(allocator);
    getTermColorSupport(env);

    if (terminal.support_true_color) {
        color.setColor = Colors.setColorRGB;
    }

    terminal.init(io);

    terminal.screen.rows = terminal.winsize.row;
    terminal.screen.cols = terminal.winsize.col;

    const total_cells: usize = terminal.winsize.row * terminal.winsize.col + terminal.winsize.col;
    terminal.screen.virt_scr = try allocator.alloc(u8, total_cells);
    terminal.screen.physc_scr = try allocator.alloc(u8, total_cells);

    var i: usize = 0;
    while (i < total_cells) : (i += 1) {
        terminal.screen.virt_scr[i] = ' ';
        terminal.screen.physc_scr[i] = ' ';
    }
}

fn getTermColorSupport(env: *std.process.Environ.Map) void {
    if (env.get("COLORTERM")) |support| {
        if (std.ascii.eqlIgnoreCase(support, "truecolor"))
            terminal.support_true_color = true;
    }
}

// Expose functions
pub const mvaddch: *const fn (rows: i32, cols: i32, char: u8, fg: i32, bg: i32) void = mvaddch8;

fn mvaddch8(rows: i32, cols: i32, char: u8) void {
    if (rows >= 0 and rows <= terminal.screen.rows and cols >= 0 and cols <= terminal.screen.cols) {
        const idx: usize = @as(usize, @intCast(rows * terminal.winsize.col + cols));
        terminal.screen.virt_scr[idx] = char;
    }
}

fn mvaddchRGB() !void {}

pub fn refresh() !void {
    var buf: [4096]u8 = undefined;
    var writer = Io.File.stdout().writer(terminal.io, &buf);
    const stdout = &writer.interface;

    var r: usize = 0;
    while (r < terminal.screen.rows) : (r += 1) {
        var c: usize = 0;
        while (c < terminal.screen.cols) : (c += 1) {
            const idx: usize = r * terminal.screen.cols + c;

            const virt: u8 = terminal.screen.virt_scr[idx];
            const physc: u8 = terminal.screen.physc_scr[idx];

            if (virt == physc)
                continue;

            try stdout.print("\x1B[{d};{d}H", .{ r + 1, c + 1 });

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

const KeyError = error{
    UnknownKey,
};

/// NOTE: this isn't perfect yet it still need to handle special multi bytes characters
pub fn getCh() ?Key {
    terminal.last_bytes = null;
    const bytes_read = posix.read(termios.fd, &terminal.bufin) catch |err| {
        std.log.err("{any}\n", .{err});
        return null;
    };
    if (bytes_read == 0) return null;

    const key = parseKey(terminal.bufin[0..bytes_read]) catch return null;
    terminal.last_bytes = key;
    return key;
}

fn parseKey(seq: []const u8) !Key {
    if (seq.len == 0) return KeyError.UnknownKey;

    if (seq[0] == 0x1B) {
        if (seq.len == 1) return .escape;

        if (seq.len >= 3 and seq[1] == '[') {
            return switch (seq[2]) {
                'A' => .up,
                'B' => .down,
                'C' => .right,
                'D' => .left,
                else => KeyError.UnknownKey,
            };
        }
    }
    if (seq.len == 1) return .{ .char = seq[0] };
    return KeyError.UnknownKey;
}

/// safely exit raw mode and return to original terminal state
pub fn wellDone() !void {
    defer screen_arena.deinit();
    try posix.tcsetattr(termios.fd, .FLUSH, termios.orig_termios);
    const stdout = &terminal.stdout_wrapper.interface;
    try stdout.writeAll("\x1B[?1049l");
    try stdout.flush();
}
