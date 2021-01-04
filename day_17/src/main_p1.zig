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

const Coord = [3]isize;

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
    x: isize,
    y: isize,
    z: isize,
    state: State,
    next_state: ?State = null,
    near_coords: ?[26]Coord = null,

    pub fn init(coord: Coord, state: State) Cube {
        return Cube{
            .x = coord[0],
            .y = coord[1],
            .z = coord[2],
            .state = state,
        };
    }

    pub fn getNearCoords(self: *Cube) [26]Coord {
        if (self.near_coords) |nc| {
            return nc;
        }

        const self_coords = Coord{ self.x, self.y, self.z };

        var res = [_]Coord{undefined} ** 26;
        var i: usize = 0;
        var idx: usize = 0;
        while (i < 27) : (i += 1) {
            const ii = @intCast(isize, i);
            if (i == 13) {
                continue;
            }

            const cube_coords: Coord = .{
                self.x + @mod(ii, 3) - 1,
                self.y + @mod(@divTrunc(ii, 3), 3) - 1,
                self.z + @divTrunc(ii, 9) - 1,
            };

            res[idx] = cube_coords;
            idx += 1;
        }

        self.near_coords = res;
        return res;
    }

    pub fn calcNextState(self: *Cube, neighbors: std.AutoHashMap(Coord, Cube)) void {
        const neighbor_coords = self.getNearCoords();
        var actives: usize = 0;
        for (neighbor_coords) |nc, i| {
            // active block must have all neighboring blocks
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

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var cubes = std.AutoHashMap([3]isize, Cube).init(allo);
    defer cubes.deinit();

    // load initial cubes

    var y: isize = 0;
    while (lines.next()) |line| : (y += 1) {
        for (line) |char, _x| {
            const x = @intCast(isize, _x);
            if (char == '.') {
                continue;
            }
            const cube = Cube.init(.{ x, y, 0 }, .active);
            cubes.put(.{ x, y, 0 }, cube) catch unreachable;
        }
    }

    // do p1

    var cycle: usize = 0;
    while (cycle < 6) : (cycle += 1) {
        // add all inactive neighoring cubes
        info("cycle: {} cubes: {}", .{ cycle, countActiveCubes(cubes) });

        var new_cubes = ArrayList(Cube).init(allo);
        defer new_cubes.deinit();

        var iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            if (cube.value.state == .inactive) {
                continue;
            }

            const near_coords = cube.value.getNearCoords();
            for (near_coords) |near_coord| {
                if (cubes.get(near_coord)) |existing_cube| {
                    continue;
                }

                // init all non-existant cubes as inactive
                const new_cube = Cube.init(near_coord, .inactive);
                new_cubes.append(new_cube) catch unreachable;
            }
        }

        for (new_cubes.items) |new_cube| {
            cubes.put(Coord{
                new_cube.x,
                new_cube.y,
                new_cube.z,
            }, new_cube) catch unreachable;
        }

        iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            cube.value.calcNextState(cubes);
        }

        iter_cubes = cubes.iterator();
        while (iter_cubes.next()) |cube| {
            cube.value.commit();
        }
    }
    info("p1: {}", .{countActiveCubes(cubes)});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
