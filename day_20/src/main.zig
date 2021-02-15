const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const DIM: usize = 10;

const Edge = enum {
    left, right, top, bottom
};

fn cmpPalindrome(a: []const u8, b: []const u8) bool {
    for (a) |aa, i| {
        if (aa != b[i]) {
            break;
        }
    } else {
        return true;
    }

    for (a) |aa, j| {
        if (aa != b[DIM - 1 - j]) {
            break;
        }
    } else {
        return true;
    }

    return false;
}

const ProcessResponse = struct {
    neighbors_cnt: usize,
    is_topleft_corner: bool,
};

const Tile = struct {
    id: usize,
    data: [DIM][DIM]u8 = undefined,
    links: struct {
        top: ?*Tile, lef: ?*Tile, bot: ?*Tile, rig: ?*Tile
    } = undefined,

    pub fn init(line: []const u8) !Tile {
        const id = try std.fmt.parseInt(usize, line[5 .. line.len - 1], 10);
        return Tile{ .id = id };
    }

    pub fn load_line(self: *Tile, line: []const u8, row: usize) !void {
        std.mem.copy(u8, self.data[row][0..], line[0..line.len]);
    }

    fn can_rotate(self: *Tile) bool {
        return self.top == null and self.lef == null and self.rig == null and self.bot == null;
    }

    fn rotate_r(self: *Tile) void {
        var new_data: [DIM][DIM]u8 = undefined;

        var i = 0;
        var j = 0;
        while (i < DIM) : (i += 1) {
            while (j < DIM) : (j += 1) {
                new_data[i][j] = self.data[n - j - 1][i];
            }
        }

        var k = 0;
        while (k < DIM) : (k += 1) {
            std.mem.copy(u8, self.data[k], new_data[k]);
        }
    }

    pub fn process(self: *Tile, others: []Tile) usize {
        var matches: usize = 0;

        for (others) |other| {
            const done = other.rotate_match_to_direction(self.data[0], .bottom);
            if (!done) continue;
            self.top_link = other;
            other.process(others);
            break;
        }

        for (self.links) |link, i| {
            // rotate the whole image
            self.rotate_r();
            for (others) |other| {
                other.rotate_r();
            }

            // skip if my other edge already bound
            if (link != null) continue;

            const row = self.data[DIM - 1];

            for (others) |other| {
                // don't do myself
                if (other.id == self.id) continue;

                for (other.links) |other_link| {
                    // skip if this other edge already bound
                    if (other_link != null) continue;

                    const are_palindromes = cmpPalindrome(edge[0..], other_edge[0..]);
                    if (are_palindromes) {
                        const tgt = switch (i) {
                            0 => &self.links.top,
                            1 => &self.links.bot,
                            2 => &self.links.rig,
                            3 => &self.links.lef,
                            else => unreachable,
                        };
                        tgt.* = other.id;

                        matches += @as(usize, 1);
                    }
                }
            }
        }

        // p1
        return matches;
    }

    pub fn monster_tail_tips(self: *Tile) usize {
        return 1;
    }
};

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    var p1: usize = 1;

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var tiles = try allo.alloc(Tile, 0);
    defer allo.free(tiles);

    var row: usize = 0;
    var cur_tile: Tile = undefined;
    while (lines.next()) |line| {
        //info("line[{}]: >{}<", .{ row, line });
        if (std.mem.indexOf(u8, line, "Tile")) |_| {
            cur_tile = try Tile.init(line);

            tiles = try allo.realloc(tiles, tiles.len + 1);
            tiles[tiles.len - 1] = cur_tile;
            row = 0;
            continue;
        }

        try tiles[tiles.len - 1].load_line(line, row);

        row += 1;
    }

    // do p1

    for (tiles) |*tile| {
        const neighbors = tile.process(tiles);
        // find tiles that have only 2 neighbors - thus are in the corners
        if (neighbors == 2) {
            p1 *= tile.id;
        }
    }

    print("p1: {}\n", .{p1});

    // do p2

    // the dragon as depicted in task
    // steps: {x, y}
    const p2_pattern = [_][2]i32{
        [_]i32{ 0, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 2, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 1, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 2, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 1, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 2, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 1, 1 },
        [_]i32{ 0, -1 },
        [_]i32{ 1, 0 },
    };

    var monster_count: usize = 0;
    for (tiles) |*tile| {
        //info("topleft: {} {}", .{ tile.id, tile.links });
        //if (tile.links.top == null and tile.links.lef == null) {
        //    info("topleft: {} {}", .{ tile.id, tile.links });
        //}
        monster_count += tile.monster_tail_tips();
    }
    print("monster count: {}\n", .{monster_count});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
