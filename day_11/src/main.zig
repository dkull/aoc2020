const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const PartParams = struct {
    view_distance: ?usize,
    crowded: usize,
};

const State = enum {
    floor,
    chair,
    taken,
    edge,
};

fn printMap(map: [][]State) void {
    for (map) |row| {
        for (row) |col| {
            const repr = switch (col) {
                .floor => ".",
                .chair => "L",
                .taken => "#",
                .edge => "E",
            };
            print("{}", .{repr});
        }
        print("\n", .{});
    }
}

fn countState(state: State, map: [][]State) usize {
    var ret: usize = 0;
    for (map) |row| {
        for (row) |col| {
            if (col == state) {
                ret += 1;
            }
        }
    }

    return ret;
}

fn reset(map: [][]State) void {
    for (map) |row, i| {
        for (row) |*col, ii| {
            switch (col.*) {
                .taken => {
                    col.* = .chair;
                },
                else => {},
            }
        }
    }
}

fn getTile(y: usize, x: usize, delta_y: isize, delta_x: isize, view_dist: ?usize, map: [][]State) State {
    var pos = .{
        .y = @intCast(isize, y),
        .x = @intCast(isize, x),
    };

    var moved: usize = 0;

    while (true) {
        if (view_dist == moved) {
            return .floor;
        }
        moved += 1;

        pos.y += delta_y;
        pos.x += delta_x;

        const y_edge = pos.y < 0 or pos.y >= map.len;
        const x_edge = pos.x < 0 or pos.x >= map[0].len;

        if (y_edge or x_edge) {
            return .edge;
        }

        const seeing = map[@intCast(usize, pos.y)][@intCast(usize, pos.x)];

        switch (seeing) {
            .floor => continue,
            .chair => return .chair,
            .taken => return .taken,
            .edge => unreachable,
        }
    }
}

fn vision(y: usize, x: usize, map: [][]State, view_dist: ?usize) [8]State {
    const x_prim = @intCast(isize, x);
    const y_prim = @intCast(isize, y);

    const nbors = [8]State{
        getTile(y, x, -1, 0, view_dist, map),
        getTile(y, x, -1, 1, view_dist, map),
        getTile(y, x, 0, 1, view_dist, map),
        getTile(y, x, 1, 1, view_dist, map),
        getTile(y, x, 1, 0, view_dist, map),
        getTile(y, x, 1, -1, view_dist, map),
        getTile(y, x, 0, -1, view_dist, map),
        getTile(y, x, -1, -1, view_dist, map),
    };

    return nbors;
}

fn newState(state: State, nbors: [8]State, crowded: usize) State {
    var taken_nbor: usize = 0;

    for (nbors) |nbor| {
        if (nbor == .taken) {
            taken_nbor += 1;
        }
    }

    const ret = switch (state) {
        .floor => State.floor,
        .taken => if (taken_nbor >= crowded) blk: {
            break :blk State.chair;
        } else blk: {
            break :blk State.taken;
        },
        .chair => switch (taken_nbor) {
            0 => State.taken,
            else => State.chair,
        },
        .edge => unreachable,
    };

    return ret;
}

fn update(cur: [][]State, nxt: *[][]State, params: PartParams) usize {
    var update_cnt: usize = 0;
    for (cur) |cur_row, row_i| {
        for (cur_row) |*cur_col, col_i| {
            const visible = vision(row_i, col_i, cur, params.view_distance);
            const new_state = newState(cur_col.*, visible, params.crowded);
            if (new_state != cur_col.*) {
                update_cnt += 1;
            }
            nxt.*[row_i][col_i] = new_state;
        }
    }
    return update_cnt;
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    // allocate seats
    //

    var cur_seats: [][]State = allo.alloc([]State, 0) catch unreachable;
    defer allo.free(cur_seats);
    while (lines.next()) |line| {
        cur_seats = allo.realloc(cur_seats, cur_seats.len + 1) catch unreachable;

        const seats = allo.alloc(State, line.len) catch unreachable;
        cur_seats[cur_seats.len - 1] = seats;

        for (line) |token, i| {
            seats[i] = switch (token) {
                '.' => State.floor,
                'L' => State.chair,
                else => unreachable, // we cannot have filled seats as input
            };
        }
    }

    // allocate our other buffer
    //

    var nxt_seats: [][]State = allo.alloc([]State, cur_seats.len) catch unreachable;
    defer allo.free(nxt_seats);
    for (cur_seats) |seats, i| {
        nxt_seats[i] = allo.dupe(State, seats) catch unreachable;
    }

    // do p1 stuff
    //

    const p1_params = PartParams{
        .view_distance = 1,
        .crowded = 4,
    };

    while (true) {
        reset(nxt_seats);

        const update_cnt = update(
            cur_seats,
            &nxt_seats,
            p1_params,
        );

        if (update_cnt == 0) {
            // stabilized
            info("p1: {}", .{countState(.taken, nxt_seats)});
            break;
        }
        const tmp = cur_seats;
        cur_seats = nxt_seats;
        nxt_seats = tmp;
    }

    // do p2 stuff
    //

    const p2_params = PartParams{
        .view_distance = null,
        .crowded = 5,
    };

    // this reset means we can only take empty chairs as input
    reset(cur_seats);

    while (true) {
        reset(nxt_seats);

        const update_cnt = update(cur_seats, &nxt_seats, p2_params);

        if (update_cnt == 0) {
            // stabilized
            info("p2: {}", .{countState(.taken, nxt_seats)});
            break;
        }
        const tmp = cur_seats;
        cur_seats = nxt_seats;
        nxt_seats = tmp;
    }

    // end
    //

    for (cur_seats) |cur_seat| {
        allo.free(cur_seat);
    }

    for (nxt_seats) |nxt_seat| {
        allo.free(nxt_seat);
    }

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
