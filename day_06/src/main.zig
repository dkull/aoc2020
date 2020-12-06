const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const lines: [][]const u8 = try utils.read_input_lines(allo, "./input1");
    defer allo.free(lines);

    print("== got {} input lines ==\n", .{lines.len});

    // solutions

    var p1_group: u32 = 0;
    var p1_sum: usize = 0;

    var p2_group: u32 = 0;
    var p2_sum: usize = 0;
    var p2_first: bool = true;

    for (lines) |line, i| {
        defer allo.free(line);

        // finish group
        if (line.len == 0) {
            p1_sum += @popCount(u32, p1_group);
            p1_group = 0;

            p2_sum += @popCount(u32, p2_group);
            p2_group = 0;

            p2_first = true;
            continue;
        }

        // do calcs
        var p2_person: u32 = 0x00;
        for (line) |c| {
            const c_idx = c - 0x61;
            const c_bit = std.math.pow(u32, 2, c_idx);

            // apply directly to group
            p1_group |= c_bit;
            // apply to intermediate object
            p2_person |= c_bit;
        }

        if (p2_first) {
            p2_group = p2_person;
        } else {
            p2_group &= p2_person;
        }

        p2_first = false;
    }

    print("p1 sum: {}\n", .{p1_sum});
    print("p2 sum: {}\n", .{p2_sum});
}
