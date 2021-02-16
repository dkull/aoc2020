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

    pub fn init(line: []const u8) !Tile {
        const id = try std.fmt.parseInt(usize, line[5 .. line.len - 1], 10);
        return Tile{ .id = id };
    }

    pub fn load_line(self: *Tile, line: []const u8, row: usize) !void {
        std.mem.copy(u8, self.data[row][0..], line[0..line.len]);
    }

    fn can_transform(self: *Tile) bool {
        return self.top_link == null and self.left_link == null and self.right_link == null and self.bot_link == null;
    }

    fn rotate_r(self: *Tile) void {
        var new_data: [DIM][DIM]u8 = undefined;

        var i: usize = 0;
        while (i < DIM) : (i += 1) {
            var j: usize = 0;
            while (j < DIM) : (j += 1) {
                new_data[i][j] = self.data[DIM - j - 1][i];
            }
        }

        var k: usize = 0;
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
        var buf: [DIM]u8 = undefined;

        // FANK: Remove me
        var sanity_check: [DIM]u8 = undefined;
        std.mem.copy(u8, &sanity_check, &self.data[DIM - 1]);

        var i: usize = 0;
        while (i < 4) : (i += 1) {
            self.get_edge(edge, &buf);
            if (std.mem.eql(u8, &target, &buf)) return true;

            if (!self.can_transform()) { // can't transform this piece
                break;
            }

            self.flip_v();
            self.get_edge(edge, &buf);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_h();
            self.get_edge(edge, &buf);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_v();
            self.get_edge(edge, &buf);
            if (std.mem.eql(u8, &target, &buf)) return true;

            self.flip_h(); // restore

            self.rotate_r();
        }

        assert(std.mem.eql(u8, &sanity_check, &self.data[DIM - 1]));

        return false;
    }

    pub fn get_edge(self: *Tile, edge: Edge, output: []u8) void {
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
    }

    pub fn count_neighbors(self: *Tile) usize {
        var result: usize = 0;
        if (self.top_link != null) result += 1;
        if (self.bot_link != null) result += 1;
        if (self.left_link != null) result += 1;
        if (self.right_link != null) result += 1;
        return result;
    }

    pub fn process(self: *Tile, others: []Tile) void {
        info("=== tile {} === (can transform: {})", .{ self.id, self.can_transform() });

        var buf: [DIM]u8 = undefined;

        for (self.data) |row| {
            info(">> {}", .{row});
        }

        for (others) |*other| {
            if (other.id == self.id) continue;

            self.get_edge(.top, &buf);
            if (self.top_link == null and other.bot_link == null and other.match_edge(buf, .bot)) {
                assert(other.bot_link == null);
                //info("  !! {} got top {} >> {}", .{ self.id, other.id, buf });
                self.top_link = other;
                other.bot_link = self;
                other.process(others);
                continue;
            }

            self.get_edge(.bot, &buf);
            if (self.bot_link == null and other.top_link == null and other.match_edge(buf, .top)) {
                assert(other.top_link == null);
                //info("  !! {} got bot {} >> {}", .{ self.id, other.id, buf });
                self.bot_link = other;
                other.top_link = self;
                other.process(others);
                continue;
            }

            self.get_edge(.left, &buf);
            if (self.left_link == null and other.right_link == null and other.match_edge(buf, .right)) {
                //info("  !! {} got left {} >> {}", .{ self.id, other.id, buf });
                assert(other.right_link == null);
                self.left_link = other;
                other.right_link = self;
                other.process(others);
                continue;
            }

            self.get_edge(.right, &buf);
            if (self.right_link == null and other.left_link == null and other.match_edge(buf, .left)) {
                //info("  !! {} got right {} >> {}", .{ self.id, other.id, buf });
                assert(other.left_link == null);
                self.right_link = other;
                other.left_link = self;
                other.process(others);
                continue;
            }
        }
    }

    pub fn distance_from_top(self: *Tile) usize {
        if (self.top_link == null) {
            return 0;
        } else {
            return (self.top_link orelse unreachable).distance_from_top() + 1;
        }
    }

    pub fn distance_from_left(self: *Tile) usize {
        if (self.left_link == null) {
            return 0;
        } else {
            return (self.left_link orelse unreachable).distance_from_left() + 1;
        }
    }

    pub fn monster_tail_tips(self: *Tile) usize {
        return 1;
    }
};

pub fn rotate_2d_array(allo: *std.mem.Allocator, data: [][]u8) !void {
    var result = try allo.alloc([]u8, data[0].len);
    for (result) |_, i_| {
        result[i_] = try allo.alloc(u8, data.len);
    }

    for (data) |row, i| {
        for (row) |col, j| {
            result[i][j] = data[data.len - j - 1][i];
        }
    }

    for (data) |row, i| {
        std.mem.copy(u8, data[i], result[i]);
        allo.free(result[i]);
    }
    allo.free(result);
}

pub fn trace_dragon(data: [][]u8, y: usize, x: usize, steps: [][2]i32) bool {
    if (steps.len == 0) {
        return true;
    }

    const new_x = @intCast(i32, x) + steps[0][0];
    const new_y = @intCast(i32, y) + steps[0][1];

    if (new_y < 0 or new_y >= data.len or new_x < 0 or new_x >= data[0].len) {
        return false;
    }

    const tile = data[@intCast(usize, new_y)][@intCast(usize, new_x)];
    if (tile != '#') {
        return false;
    }

    return trace_dragon(data, @intCast(usize, new_y), @intCast(usize, new_x), steps[1..]);
}

pub fn part2(data: [][]u8, steps: [][2]i32) usize {
    var dragon_count: usize = 0;

    var y: usize = 0;
    while (y < data.len) : (y += 1) {
        var x: usize = 0;
        while (x < data[0].len) : (x += 1) {
            //info("tracing dragon from {}x{}", .{ y, x });
            const is_dragon_tail_tip = trace_dragon(data, y, x, steps);
            if (is_dragon_tail_tip) dragon_count += 1;
        }
    }
    return dragon_count;
}

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

    tiles[0].process(tiles);

    info(" ===================== PROCESS ================================", .{});
    for (tiles) |*tile, i| {
        // find tiles that have only 2 neighbors - thus are in the corners
        // info("p1 in prog ({}/{}): {}", .{ i + 1, tiles.len, p1 });
        const neighbors = tile.count_neighbors();
        assert(neighbors == 2 or neighbors == 3 or neighbors == 4);
        if (neighbors == 2) {
            p1 *= tile.id;
        }
    }

    print("p1: {}\n", .{p1});

    // do p2

    var width: usize = 0;
    var height: usize = 0;

    // determine large dimensions
    for (tiles) |*tile| {
        const dist_top = tile.distance_from_top();
        const dist_left = tile.distance_from_left();
        if (dist_top > height) {
            height = dist_top;
        }
        if (dist_left > width) {
            width = dist_left;
        }
    }

    info("we have {}x{} tiles", .{ width, height });

    // allocate one big 2d-array
    var allmap = try allo.alloc([]u8, (height + 1) * (DIM - 2));
    for (allmap) |_, i| {
        allmap[i] = try allo.alloc(u8, (width + 1) * (DIM - 2));
    }

    info("allocated big map {}x{}", .{ allmap.len, allmap[0].len });

    // draw all tiles into correct coordinates
    for (tiles) |*tile| {
        const dist_top = tile.distance_from_top();
        const dist_left = tile.distance_from_left();

        for (tile.data) |row2, i| {
            if (i == 0 or i == DIM - 1) continue; // skip first and last row

            const top = dist_top * (DIM - 2);
            const left = dist_left * (DIM - 2);
            std.mem.copy(u8, allmap[top + i - 1][left .. left + DIM - 2], row2[1 .. DIM - 1]);
        }
    }

    // the dragon as depicted in task
    // steps: {x, y}
    // fixme, make this const
    var p2_pattern = [_][2]i32{
        [_]i32{ 0, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 3, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 1, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 3, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 1, 0 },
        [_]i32{ 1, 1 },
        [_]i32{ 3, 0 },
        [_]i32{ 1, -1 },
        [_]i32{ 1, -1 },
        [_]i32{ 0, 1 },
        [_]i32{ 1, 0 },
    };

    var monster_count: usize = 0;

    var fin_rot: usize = 0;
    while (fin_rot < 4) : (fin_rot += 1) {
        info("====", .{});
        for (allmap) |row3, i| {
            info(">row: {}> {}", .{ i, row3 });
        }

        monster_count += part2(allmap, p2_pattern[0..]);
        rotate_2d_array(allo, allmap) catch unreachable;
    }
    print("monster count: {}\n", .{monster_count});

    var hash_count: usize = 0;
    for (allmap) |row4| {
        hash_count += std.mem.count(u8, row4, "#");
    }
    print("p2: {}\n", .{hash_count - (monster_count * p2_pattern.len)});

    // end
    for (allmap) |_, i| {
        allo.free(allmap[i]);
    }
    allo.free(allmap);
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
