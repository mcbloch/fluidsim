const std = @import("std");

const time = std.time;
const print = std.debug.print;

pub const io_mode = .evented;

pub fn range(len: usize) []const u0 {
    return @as([*]u0, undefined)[0..len];
}

//ansi escape codes
const esc = "\x1B";
const csi = esc ++ "[";

const cursor_show = csi ++ "?25h"; //h=high
const cursor_hide = csi ++ "?25l"; //l=low
const cursor_home = csi ++ "1;1H"; //1,1

const color_fg = "38;5;";
const color_bg = "48;5;";
const color_fg_def = csi ++ color_fg ++ "15m"; // white
const color_bg_def = csi ++ color_bg ++ "0m"; // black
const color_def = color_bg_def ++ color_fg_def;

const screen_clear = csi ++ "2J";
const screen_buf_on = csi ++ "?1049h"; //h=high
const screen_buf_off = csi ++ "?1049l"; //l=low

const nl = "\n";

const term_on = screen_buf_on ++ cursor_hide ++ cursor_home ++ screen_clear ++ color_def;
const term_off = screen_buf_off ++ cursor_show ++ nl;

const stdin = std.io.getStdIn();

const width = 10;
const height = 10;

var world = @Vector(width*height, bool){};
var cursor: usize = 0;
var log = "";

fn world_insert(x: usize, y: usize, value: bool) void {
    var normalised_y: usize = 0;
    var normalised_x: usize = 0;

    if (y >= height) {
        normalised_y = height - (y % height) - 1;
    } else {
        normalised_y = y;
    }

    if (x >= width) {
        normalised_x = width - (x % width) - 1;
    } else {
        normalised_x = x;
    }

    world[normalised_y*width + normalised_x] = value;
}

fn world_lookup(x: usize, y: usize) bool {
    var normalised_y: usize = 0;
    var normalised_x: usize = 0;

    if (y >= height) {
        normalised_y = height - (y % height) - 1;
    } else {
        normalised_y = y;
    }

    if (x >= width) {
        normalised_x = width - (x % width) - 1;
    } else {
        normalised_x = x;
    }

    return world[normalised_y*width + normalised_x];
}

fn render_frame() void {
    print("{s}", .{"\x1B[2J\x1B[H"});
    print("\n", .{});
    
    for (range(height)) |_, y| {
        for (range(width)) |_, x| {
            var chr = " ";
            if (world_lookup(x, y)) {
                chr = "x";
            }

            print("{s}", .{chr});
        }
        
        print("\n", .{});
    }
    // print("{s}", .{log});
}

fn physics_step() void {
    for (range(height-1)) |_, h| {
        const y = height - h - 2;

        //var allocator = std.heap.page_allocator;
        //var repr = std.fmt.allocPrint(
        //    allocator,
        //    "{d}",
        //    .{y},
        //);
        
        // print("{s} {d}\t", .{repr, y});
        // log = log ++ repr;

        for (range(width)) |_, x| {
            var below_y: usize = y + 1;
            
            var below_x: usize = 0;
            var below_left_x: usize = 0;
            var below_right_x: usize = 0;

            if (x == 0) {
                below_x = 0;
                below_left_x = 0;
                below_right_x = 1;
            } else if (x == width - 1) {
                below_x = width - 1;
                below_left_x = width - 2;
                below_right_x = width - 1;
            } else {
                below_x = x;
                below_left_x = x - 1;
                below_right_x = x + 1;
            }

            if (world_lookup(x, y)) {
                if(world_lookup(below_x, below_y)){
                    if (!world_lookup(below_left_x, below_y)) {
                        world_insert(x, y, false);
                        world_insert(below_left_x, below_y, true);
                    } else if (!world_lookup(below_right_x, below_y)) {
                        world_insert(x, y, false);
                        world_insert(below_right_x, below_y, true);
                    }
                } else {
                    world_insert(x, y, false);
                    world_insert(below_x, below_y, true);
                }
            }
        }
    }
}

const debug = std.debug;
const fs = std.fs;
const io = std.io;
const mem = std.mem;
const os = std.os;

const Channel = std.event.Channel;

fn do_io(tty: fs.File, out: *Channel(u8)) void {
    var buffer: [1]u8 = undefined;
    // tty.read(&buffer) catch |e| { debug.print("{s}", .{e}); };
    tty.read(&buffer) catch {};
    out.put(buffer[0]);
}

pub fn main() !void {
    // Initiate channels for io chars
    const allocator = std.heap.page_allocator;

    // var arena = std.heap.ArenaAllocator.init(allocator);
    // const arenaAllocator = &arena.allocator;

    var buffer = try allocator.alloc(u8, 1000);
    var out = try allocator.create(Channel(u8));
    out.init(buffer);

    // Initiate io stuff
    var tty = try fs.cwd().openFile("/dev/tty", .{ .read = true, .write = true });
    defer tty.close();

    const original = try os.tcgetattr(tty.handle);
    var raw = original;
    raw.lflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.ECHO | os.linux.ICANON | os.linux.ISIG | os.linux.IEXTEN,
    );
    raw.iflag &= ~@as(
        os.linux.tcflag_t,
        os.linux.IXON | os.linux.ICRNL | os.linux.BRKINT | os.linux.INPCK | os.linux.ISTRIP,
    );
    raw.cc[os.system.V.TIME] = 0;
    raw.cc[os.system.V.MIN] = 1;
    try os.tcsetattr(tty.handle, .FLUSH, raw);

    _ = async do_io(tty, out);

    // print("{s}", .{term_on});

    // world_insert(9, 0, true);
    // world_insert(9, 1, true);
    // world_insert(9, 2, true);
    // world_insert(9, 3, true);
    // world_insert(9, 4, true);
    // world_insert(9, 5, true);
    // world_insert(9, 6, true);
    // world_insert(9, 7, true);
    // world_insert(9, 8, true);
    // world_insert(9, 9, true);
    // render_frame(stdscr);
    // time.sleep(250000000);
    
    var time_cnt: u64 = 0;
    const time_delta: u64 = 2;

    while(true) {

        if (out.getOrNull()) |char| {
            if (char == 'q') {
                try os.tcsetattr(tty.handle, .FLUSH, original);
                return;
            } else if (char == '\x1B') {
                debug.print("input: escape\r\n", .{});
            } else if (char == '\n' or char == '\r') {
                debug.print("input: return\r\n", .{});
            } else {
                debug.print("input: {d}\r\n", .{ char });
            }
        }
        
        if (time_cnt >= time_delta) {
            physics_step();
            debug.print("step\n", .{});
            time_cnt = 0;
        }
        
        // render_frame(stdscr);
        // time.sleep(250000000);

        time_cnt += 1;
    }
}