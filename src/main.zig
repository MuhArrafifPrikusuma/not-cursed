const std = @import("std");
const nc = @import("not_cursed");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // NOTE: later on take this and use it to determine what configuration it should be using
    if (init.environ_map.get("TERM")) |term| {
        std.log.info("using terminal: {s}\n", .{term});
    } else {
        std.log.err("unknown terminall using fallback", .{});
    }

    try nc.init();
    try nc.refresh(io);
    var buf: [1]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &buf);
    const stdin = &reader.interface;

    var root_progress = std.Progress.start(io, .{
        .root_name = "loading idk",
        .estimated_total_items = 100,
    });

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(1), std.Io.Clock.real);

        root_progress.completeOne();
    }
    root_progress.end();

    try nc.Modes.raw();

    nc.mvaddch(0, 0, '@', 7, 0);
    try nc.Modes.setClean(io);
    try nc.refresh(io);

    try nc.Cursor.home(io);
    while (true) {
        nc.autoResize();
        const char = try stdin.peekByte();
        nc.Modes.waitKeyPress(stdin) catch continue;

        std.debug.print("{c}", .{char});
        if (char == 'q') {
            try nc.Modes.wellDone();
            break;
        }
    }
}
