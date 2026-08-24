const std = @import("std");
const nc = @import("not_cursed");
const builtin = @import("builtin");

pub fn main(init: std.process.Init) !void {
<<<<<<< HEAD
=======
    nc.terminal.io = init.io;
>>>>>>> 30189826588f31622b763efe18561568835d59f9

    // NOTE: later on take this and use it to determine what configuration it should be using
    if (init.environ_map.get("TERM")) |term| {
        std.log.info("using terminal: {s}\n", .{term});
    } else {
        std.log.err("unknown terminall using fallback", .{});
    }

<<<<<<< HEAD
    try nc.init(init.io);
    try nc.refresh();

    var bufin: [1]u8 = undefined;
    var reader = std.Io.File.stdin().reader(nc.terminal.io, &bufin);
    nc.terminal.stdin = &reader.interface;

    var bufout: [256]u8 = undefined;
    var writer = std.Io.File.stdin().writer(nc.terminal.io, &bufout);
    nc.terminal.stdout = &writer.interface;

    var root_progress = std.Progress.start(nc.terminal.io, .{
        .root_name = "loading idk",
        .estimated_total_items = 100,
    });

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try std.Io.sleep(nc.terminal.io, std.Io.Duration.fromMilliseconds(1), std.Io.Clock.real);

        root_progress.completeOne();
    }
    root_progress.end();

    try nc.Modes.raw(nc.Modes.RawFlag.CLEANEXIT);
    std.debug.print("{d}\n", .{nc.terminal.screen.virt_scr.len});

    nc.mvaddch(37, 167, '@', 7, 20);
    try nc.Modes.setClean();
    try nc.refresh();

    try nc.Cursor.home();
    while (true) {
        nc.autoResize();

        /// FIX: waitKeyPress is broken again
        const key = nc.getCh() orelse continue;
        nc.Modes.waitKeyPress();

        try nc.refresh();
        switch (key) {
            .char => |char| {
                if (char == 'q') {
                    try nc.Modes.wellDone();
                    break;
                }
                std.debug.print("{c}\n", .{char});
            },
            else => continue,
        }
    }
}
