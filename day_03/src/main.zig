const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn tree_counter(map_lines: [][]const u8, x_steps: usize, y_steps: usize) usize {
    var map_w: usize = map_lines[0].len;
    var x_pos: usize = 0;
    var cnt: usize = 0;

    const tree_sym: u8 = '#';

    var i: usize = 0;
    for (map_lines) |line| {
        i += 1;
        if ((i - 1) % y_steps != 0) {
            continue;
        }

        if (line[x_pos] == tree_sym) {
            cnt += 1;
        }

        x_pos = (x_pos + x_steps) % map_w;
    }

    return cnt;
}

pub fn main() anyerror!void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const input_lines = try utils.read_input_lines(allo, "./input1");
    defer allo.free(input_lines);

    print("== got {} input lines ==\n", .{input_lines.len});

    // part1
    //

    const p1 = tree_counter(input_lines, 3, 1);
    print("part1 trees: {}\n", .{p1});

    // part2
    //

    const p2_input = [_][2]usize{
        [2]usize{ 1, 1 },
        [2]usize{ 3, 1 },
        [2]usize{ 5, 1 },
        [2]usize{ 7, 1 },
        [2]usize{ 1, 2 },
    };
    var p2_prod: usize = 1;
    for (p2_input) |p2_step| {
        const p2_factor = tree_counter(input_lines, p2_step[0], p2_step[1]);
        info("p2 factor: {}", .{p2_factor});
        p2_prod *= p2_factor;
    }
    print("part2 trees: {}\n", .{p2_prod});

    // cleanup
    //

    for (input_lines) |line| {
        allo.free(line);
    }
}
