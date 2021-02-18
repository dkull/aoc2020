const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Step = enum {
    e, se, sw, w, nw, ne
};

const Coordinate = struct {
    x: isize,
    y: isize,
};

fn parse_steps(allo: *std.mem.Allocator, line: []const u8) ArrayList(Step) {
    // foo
    var output = ArrayList(Step).init(allo);
    var ptr: usize = 0;
    while (ptr < line.len) {
        if (std.mem.startsWith(u8, line[ptr..], "se")) {
            output.append(Step.se) catch unreachable;
            ptr += 2;
        } else if (std.mem.startsWith(u8, line[ptr..], "sw")) {
            output.append(Step.sw) catch unreachable;
            ptr += 2;
        } else if (std.mem.startsWith(u8, line[ptr..], "ne")) {
            output.append(Step.ne) catch unreachable;
            ptr += 2;
        } else if (std.mem.startsWith(u8, line[ptr..], "nw")) {
            output.append(Step.nw) catch unreachable;
            ptr += 2;
        } else if (std.mem.startsWith(u8, line[ptr..], "e")) {
            output.append(Step.e) catch unreachable;
            ptr += 1;
        } else if (std.mem.startsWith(u8, line[ptr..], "w")) {
            output.append(Step.w) catch unreachable;
            ptr += 1;
        }
    }
    return output;
}

fn follow_steps(steps: []Step, output: *Coordinate) void {
    for (steps) |step| {
        switch (step) {
            .e => output.x += 2,
            .w => output.x -= 2,
            .se => {
                output.x += 1;
                output.y += 1;
            },
            .sw => {
                output.x -= 1;
                output.y += 1;
            },
            .ne => {
                output.x += 1;
                output.y -= 1;
            },
            .nw => {
                output.x -= 1;
                output.y -= 1;
            },
        }
    }
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    // setup
    //

    // p1
    var seen_tiles = std.AutoHashMap(Coordinate, bool).init(allo);
    defer seen_tiles.deinit();

    while (lines.next()) |line| {
        const parsed_steps = parse_steps(allo, line);
        defer parsed_steps.deinit();

        var coordinate = Coordinate{ .x = 0, .y = 0 };
        follow_steps(parsed_steps.items, &coordinate);

        var maybe_seen_tile = seen_tiles.get(coordinate);
        // flip tile if it exists
        if (maybe_seen_tile) |*seen_tile| {
            seen_tiles.put(coordinate, !seen_tile.*) catch unreachable;
        } else {
            seen_tiles.put(coordinate, true) catch unreachable;
        }
    }

    var p1: usize = 0;
    var iter = seen_tiles.iterator();
    while (iter.next()) |key_val| {
        if (key_val.value) p1 += 1;
    }
    print("p1: {}\n", .{p1});

    // end
    //
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
