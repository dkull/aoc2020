const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn parseRow(inp: []const u8) u8 {
    var res: u8 = 0;
    for (inp[0..7]) |sym| {
        res <<= 1;
        if (sym == 'B') {
            res |= 0x01;
        }
    }
    return res;
}

pub fn parseCol(inp: []const u8) u8 {
    var res: u8 = 0;
    for (inp[7..10]) |sym| {
        res <<= 1;
        if (sym == 'R') {
            res |= 0x01;
        }
    }
    return res;
}

pub fn calcSeatId(row: usize, col: usize) usize {
    return row * 8 + col;
}

pub fn main() !void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const lines: [][]const u8 = try utils.read_input_lines(allo, "./input1");
    defer allo.free(lines);

    print("== got {} input lines ==\n", .{lines.len});

    // part1
    //
    //var seats = [_][8]usize{[_]usize{0} ** 8} ** 127;
    var seats = [_]bool{false} ** (127 * 8);
    var p1_res: usize = 0;
    for (lines) |line, i| {
        defer allo.free(line);
        if (line.len == 0) {
            continue;
        }
        info("--- line {}/{} {}", .{ i, lines.len, line });

        const row = parseRow(line);
        const col = parseCol(line);
        const id = calcSeatId(row, col);
        info("row: {} col: {} id: {}", .{ row, col, id });

        p1_res = if (id > p1_res) id else p1_res;

        // needed for part_2
        seats[id] = true;
    }
    print("p1: largest seat id: {}\n", .{p1_res});

    //part 2
    for (seats) |occupied, i| {
        if (!occupied and i > 0) {
            if (seats[i - 1] and seats[i + 1]) {
                print("p2: my seat id: {}\n", .{i});
                break;
            }
        }
    }
}
