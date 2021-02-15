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
    left, right, top, bot
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
    top_link: ?*Tile = null,
    bot_link: ?*Tile = null,
    left_link: ?*Tile = null,
    right_link: ?*Tile = null,
    //links: struct {
    //    top: ?*Tile, lef: ?*Tile, bot: ?*Tile, rig: ?*Tile
    //} = undefined,

    pub fn init(line: []const u8) !Tile {
        const id = try std.fmt.parseInt(usize, line[5 .. line.len - 1], 10);
        return Tile{ .id = id };
    }

    pub fn load_line(self: *Tile, line: []const u8, row: usize) !void {
        std.mem.copy(u8, self.data[row][0..], line[0..line.len]);
    }

    fn can_rotate(self: *Tile) bool {
        return self.top_link == null and self.left_link == null and self.right_link == null and self.bot_link == null;
    }

    fn rotate_r(self: *Tile) void {
        var new_data: [DIM][DIM]u8 = undefined;

        var i: u32 = 0;
        while (i < DIM) : (i += 1) {
            var j: u32 = 0;
            while (j < DIM) : (j += 1) {
                new_data[i][j] = self.data[DIM - j - 1][i];
            }
        }

        var k: u32 = 0;
        while (k < DIM) : (k += 1) {
            std.mem.copy(u8, &self.data[k], &new_data[k]);
        }
    }

    fn flip_v(self: *Tile) void {
        for (self.data) |*row| {
            std.mem.reverse(u8, row);
        }
    }

    fn flip_h(self: *Tile) void {
        std.mem.reverse([DIM]u8, &self.data);
    }

    pub fn match_edge(self: *Tile, target: [DIM]u8, edge: Edge) bool {
        var i: u32 = 0;
        var buf: [DIM]u8 = undefined;
        while (i < 4) : (i += 1) {
            self.get_edge(edge, &buf, false);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_v();
            self.get_edge(edge, &buf, false);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_h();
            self.get_edge(edge, &buf, false);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_v();
            self.get_edge(edge, &buf, false);
            if (std.mem.eql(u8, &target, &buf)) return true;

            if (!self.can_rotate()) { // no rotations allowed
                break;
            }

            self.rotate_r();
        }

        return false;
    }

    pub fn get_edge(self: *Tile, edge: Edge, output: []u8, reversed: bool) void {
        _ = switch (edge) {
            .top => std.mem.copy(u8, output, &self.data[0]),
            .bot => std.mem.copy(u8, output, &self.data[DIM - 1]),
            .left => for (self.data) |row, i| {
                output[i] = row[0];
            },
            .right => for (self.data) |row, i| {
                output[i] = row[DIM - 1];
            },
        };

        if (reversed) {
            std.mem.reverse(u8, output);
        }
    }

    pub fn process(self: *Tile, others: []Tile) usize {
        info("=== tile {} ===", .{self.id});

        var matches: usize = 0;
        var buf: [DIM]u8 = undefined;

        for (self.data) |row| {
            info(">> {}", .{row});
        }

        for (others) |*other| {
            if (other.id == self.id) continue;

            info("  -- in other {}", .{other.id});

            self.get_edge(.top, &buf, false);
            info("  find top {}", .{buf});
            if (other.match_edge(buf, .bot)) {
                info("  !! {} got top {} >> {}", .{ self.id, other.id, buf });
                self.top_link = other;
                other.bot_link = self;
                matches += 1;
                continue;
            }

            self.get_edge(.bot, &buf, false);
            info("  find bot {}", .{buf});
            if (other.match_edge(buf, .top)) {
                info("  !! {} got bot {} >> {}", .{ self.id, other.id, buf });
                self.bot_link = other;
                other.top_link = self;
                matches += 1;
                continue;
            }

            self.get_edge(.left, &buf, false);
            info("  find left {}", .{buf});
            if (other.match_edge(buf, .right)) {
                info("  !! {} got left {} >> {}", .{ self.id, other.id, buf });
                self.left_link = other;
                other.right_link = self;
                matches += 1;
                continue;
            }

            self.get_edge(.right, &buf, false);
            info("  find right {}", .{buf});
            if (other.match_edge(buf, .left)) {
                info("  !! {} got right {} >> {}", .{ self.id, other.id, buf });
                self.right_link = other;
                other.left_link = self;
                matches += 1;
                continue;
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
    // NOT DONE AT ALL YET!

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
