const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Waypoint = struct {
    y: isize,
    x: isize,
    pub fn swap(self: *Waypoint) void {
        const tmp = self.x;
        self.x = self.y;
        self.y = tmp;
    }
};

const Action = union(enum) {
    l: isize,
    r: isize,
    n: isize,
    s: isize,
    e: isize,
    w: isize,
    f: isize,

    pub fn fromLine(line: []const u8) Action {
        const name = line[0];
        const val = fmt.parseInt(isize, line[1..line.len], 10) catch unreachable;

        return switch (name) {
            'L' => Action{ .l = val },
            'R' => Action{ .r = val },
            'N' => Action{ .n = val },
            'S' => Action{ .s = val },
            'E' => Action{ .e = val },
            'W' => Action{ .w = val },
            'F' => Action{ .f = val },
            else => unreachable,
        };
    }
};

const Ship = struct {
    y: isize = 0,
    x: isize = 0,
    facing: isize = 90,
    waypoint: ?Waypoint = undefined,

    pub fn init(x: isize, y: isize, facing: isize, waypoint: ?Waypoint) Ship {
        return Ship{
            .y = y,
            .x = x,
            .facing = facing,
            .waypoint = waypoint,
        };
    }

    pub fn move(self: *Ship, action: Action) void {
        if (self.waypoint) |*waypoint| {
            // move the ship and waypoint as in p2
            return switch (action) {
                .l => |val| self.move(Action{ .r = 360 - val }),
                .r => |val| {
                    if (val != 0) {
                        // fix sign
                        const x = waypoint.x;
                        const y = waypoint.y;

                        waypoint.swap();
                        waypoint.x = -waypoint.x;

                        // rotate 90 degrees right
                        self.move(Action{ .r = val - 90 });
                    }
                },
                .n => |val| waypoint.y -= val,
                .s => |val| waypoint.y += val,
                .e => |val| waypoint.x += val,
                .w => |val| waypoint.x -= val,
                .f => |val| {
                    self.x += waypoint.x * val;
                    self.y += waypoint.y * val;
                },
            };
        } else {
            // just move the ship as in p1
            return switch (action) {
                .l => |val| self.facing = @mod(self.facing - val, 360),
                .r => |val| self.facing = @mod(self.facing + val, 360),
                .n => |val| self.y -= val,
                .s => |val| self.y += val,
                .e => |val| self.x += val,
                .w => |val| self.x -= val,
                .f => |val| {
                    switch (self.facing) {
                        0 => self.y -= val,
                        90 => self.x += val,
                        180 => self.y += val,
                        270 => self.x -= val,
                        else => unreachable,
                    }
                },
            };
        }
        info("ship now at: y: {} x: {} [facing {}]", .{ self.y, self.x, self.facing });
    }

    pub fn distanceFrom(self: Ship, y: isize, x: isize) isize {
        const a = self.y - y;
        const b = self.x - x;
        const aa = if (a >= 0) a else -a;
        const bb = if (b >= 0) b else -b;
        return aa + bb;
    }
};

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    // p1

    var ship1 = Ship.init(0, 0, 90, null);
    var ship2 = Ship.init(0, 0, 90, Waypoint{
        .x = 10,
        .y = -1,
    });

    while (lines.next()) |line| {
        const action = Action.fromLine(line);
        ship1.move(action);
        ship2.move(action);
    }
    print("p1: {}\n", .{ship1.distanceFrom(0, 0)});
    print("p2: {}\n", .{ship2.distanceFrom(0, 0)});

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
