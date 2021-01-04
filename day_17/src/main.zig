const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const State = enum {
    active,
    inactive,
};

const Coord = ArrayList(isize);

fn getCoordNeighbors(allo: *std.mem.Allocator, coord: Coord) !ArrayList(Coord) {
    var res = ArrayList(Coord).init(allo);

    // 3 because we want -1,0,1 of coord
    const range = 3;
    const offset = -1;

    const dims = coord.items.len;
    const elems = std.math.pow(usize, range, dims);

    info("GETTING NEIGHBORS FOR {} {} {}", .{ coord[0], coord[1], coord[2] });
    var i: usize = 0;
    while (i < elems) : (i += 1) {
        var new_coord = ArrayList(isize).init(allo);
        for (coord.items) |_, j| {
            const val: usize = @divTrunc(i, std.math.pow(usize, range, j)) % range;
            const modded_val = @intCast(isize, val) + offset;
            try new_coord.append(modded_val);
        }

        if (!std.mem.eql(isize, new_coord.items, coord.items)) {
            info("  found neighbor {} {} {}", .{ new_coord[0], new_coord[1], new_coord[2] });
            try res.append(new_coord);
        } else {
            new_coord.deinit();
        }
    }

    return res;
}

fn countActiveCubes(cubes: std.AutoHashMap(Coord, Cube)) usize {
    var res: usize = 0;
    var cubes_iter = cubes.iterator();
    while (cubes_iter.next()) |cube| {
        if (cube.value.state == .active) {
            res += 1;
        }
    }
    return res;
}

const Cube = struct {
    allo: *std.mem.Allocator,
    coord: Coord,
    state: State,
    next_state: ?State = null,
    near_coords: ArrayList(Coord),

    pub fn init(allo: *std.mem.Allocator, coord: Coord, state: State) Cube {
        return Cube{
            .allo = allo,
            .coord = coord,
            .state = state,
            .near_coords = getCoordNeighbors(allo, coord) catch unreachable,
        };
    }

    pub fn deinit(self: *Cube) void {
        self.coord.deinit();
        for (self.near_coords.items) |item| {
            item.deinit();
        }
        self.near_coords.deinit();
    }

    pub fn getNearCoords(self: *Cube) ArrayList(Coord) {
        return self.near_coords;
    }

    pub fn calcNextState(self: *Cube, neighbors: std.AutoHashMap(Coord, Cube)) void {
        const neighbor_coords = self.getNearCoords();
        var actives: usize = 0;
        for (neighbor_coords.items) |nc, i| {
            // active block must have all neighboring blocks
            info("calcing on {} {} {}", .{ nc.items[0], nc.items[1], nc.items[2] });
            const neighbor = neighbors.get(nc) orelse {
                if (self.state == .inactive) {
                    continue;
                } else {
                    unreachable;
                }
            };
            if (neighbor.state == .active) {
                actives += 1;
            }
        }

        if (self.state == .active) {
            if (actives == 2 or actives == 3) {
                // remain active
            } else {
                self.next_state = .inactive;
            }
        } else {
            if (actives == 3) {
                self.next_state = .active;
            }
        }
    }

    pub fn commit(self: *Cube) void {
        if (self.next_state) |ns| {
            self.state = ns;
            self.next_state = null;
        }
    }
};

fn doTask(allo: *std.mem.Allocator, cubes: *std.AutoHashMap(Coord, Cube)) void {
    var cycle: usize = 0;
    while (cycle < 6) : (cycle += 1) {
        // add all inactive neighoring cubes
        info("cycle: {} cubes: {}", .{ cycle, countActiveCubes(cubes.*) });

        var new_cubes = ArrayList(Cube).init(allo);
        defer new_cubes.deinit();

        var iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            if (cube.value.state == .inactive) {
                continue;
            }

            const near_coords = cube.value.getNearCoords();
            for (near_coords.items) |near_coord| {
                if (cubes.get(near_coord)) |existing_cube| {
                    continue;
                }

                var cube_coord = ArrayList(isize).init(allo);
                cube_coord.appendSlice(near_coord.items) catch unreachable;

                // init all non-existant cubes as inactive
                const new_cube = Cube.init(allo, cube_coord, .inactive);
                new_cubes.append(new_cube) catch unreachable;
            }
        }

        for (new_cubes.items) |new_cube| {
            cubes.put(new_cube.coord, new_cube) catch unreachable;
        }

        iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            cube.value.calcNextState(cubes.*);
        }

        iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            cube.value.commit();
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

    var p1_cubes = std.AutoHashMap(Coord, Cube).init(allo);
    defer {
        var p1_iter = p1_cubes.iterator();
        while (p1_iter.next()) |kv| {
            kv.value.deinit();
        }
        p1_cubes.deinit();
    }

    var p2_cubes = std.AutoHashMap(Coord, Cube).init(allo);
    defer p2_cubes.deinit();

    // load initial cubes

    var y: isize = 0;
    while (lines.next()) |line| : (y += 1) {
        for (line) |char, _x| {
            const x = @intCast(isize, _x);
            if (char == '.') {
                continue;
            }

            var p1_coord_slic = [_]isize{ x, y, 0 };
            var p1_coord = ArrayList(isize).init(allo);
            p1_coord.appendSlice(p1_coord_slic[0..]) catch unreachable;

            const p1_cube = Cube.init(allo, p1_coord, .active);
            p1_cubes.put(p1_cube.coord, p1_cube) catch unreachable;

            //var p2_coord = ArrayList(isize).init(allo);
            //p2_coord.append(x) catch unreachable;
            //p2_coord.append(y) catch unreachable;
            //p2_coord.append(0) catch unreachable;
            //p2_coord.append(0) catch unreachable;
            //const p2_cube = Cube.init(allo, p2_coord, .active);
            //p2_cubes.put(p2_coord, p2_cube) catch unreachable;
        }
    }

    // task

    doTask(allo, &p1_cubes);
    info("p1: {}", .{countActiveCubes(p1_cubes)});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
