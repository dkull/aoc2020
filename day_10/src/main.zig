const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const SEEBACK: usize = 25;

const sort_by = std.sort.asc(usize);

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var nums = allo.alloc(usize, 0) catch unreachable;
    defer allo.free(nums);

    while (lines.next()) |line| {
        nums = allo.realloc(nums, nums.len + 1) catch unreachable;
        nums[nums.len - 1] = fmt.parseUnsigned(usize, line, 10) catch unreachable;
    }

    std.sort.sort(usize, nums, {}, sort_by);

    // part 1
    //

    var jmp_1: u32 = 0;
    var jmp_3: u32 = 1; // last jump always exists
    var prev: usize = 0;

    const target = for (nums) |num| {
        const jmp = num - prev;
        info("num: {} jmp: {}", .{ num, jmp });
        switch (jmp) {
            1 => jmp_1 += 1,
            3 => jmp_3 += 1,
            else => unreachable,
        }
        prev = num;
    } else blk: {
        break :blk prev + 3;
    };

    print("part1: 1_jumps: {}, 3_jumps: {} => a*b={}\n", .{ jmp_1, jmp_3, jmp_1 * jmp_3 });

    // part 2

    nums = allo.realloc(nums, nums.len + 1) catch unreachable;
    nums[nums.len - 1] = target;

    var p2: usize = 1;
    var ones_seq: usize = 1; // count first 0 too
    prev = 0;

    for (nums) |num| {
        // p2
        const jmp = num - prev;
        switch (jmp) {
            1 => ones_seq += 1,
            3 => {
                info("jmp!", .{});
                p2 *= switch (ones_seq) {
                    1 => @intCast(usize, 1),
                    2 => @intCast(usize, 1),
                    3 => @intCast(usize, 2),
                    4 => @intCast(usize, 4),
                    5 => @intCast(usize, 7),
                    else => unreachable,
                };
                ones_seq = 1;
            },
            else => unreachable,
        }
        info("[{}/{}] num: {}", .{ p2, ones_seq, num });
        prev = num;
    }
    print("part2: {}\n", .{p2});

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
