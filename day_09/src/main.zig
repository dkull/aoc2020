const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const SEEBACK: usize = 25;

fn isSum(num: usize, parts: []usize) bool {
    for (parts) |part1, i| {
        for (parts) |part2| {
            if (part1 == part2) {
                continue;
            }
            if (part1 + part2 == num) {
                return true;
            }
        }
    }
    return false;
}

const RollingSumFinder = struct {
    allo: *std.mem.Allocator = undefined,
    target: usize = undefined,
    rolling_sum: usize = 0,
    hist: []usize = undefined,

    pub fn init(allo: *std.mem.Allocator, target: usize) RollingSumFinder {
        return RollingSumFinder{
            .allo = allo,
            .target = target,
            .hist = allo.alloc(usize, 0) catch unreachable,
        };
    }

    pub fn deinit(self: *RollingSumFinder) void {
        self.allo.free(self.hist);
    }

    pub fn appendNum(self: *RollingSumFinder, num: usize) bool {
        if (self.hist.len <= self.hist.len) {
            self.hist = self.allo.realloc(self.hist, self.hist.len + 1) catch unreachable;
        }

        self.rolling_sum += num;
        self.hist[self.hist.len - 1] = num;

        if (self.rolling_sum > self.target) {
            while (self.rolling_sum > self.target) {
                self.rolling_sum -= self.hist[0];
                const new_hist = self.allo.dupe(usize, self.hist[1..self.hist.len]) catch unreachable;
                self.allo.free(self.hist);
                self.hist = new_hist;
            }
        }

        if (self.rolling_sum == self.target) {
            return true;
        }
        return false;
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

    var nums = allo.alloc(usize, 0) catch unreachable;
    defer allo.free(nums);

    while (lines.next()) |line| {
        nums = allo.realloc(nums, nums.len + 1) catch unreachable;
        nums[nums.len - 1] = fmt.parseUnsigned(usize, line, 10) catch unreachable;
    }

    // business logic
    //

    // p1
    //

    var hist: [SEEBACK]usize = [_]usize{0} ** SEEBACK;
    var p1_target: ?usize = null;
    // find our invalid number
    const target = for (nums) |num, i| {
        if (i >= SEEBACK and !isSum(num, &hist)) {
            break num;
        }
        hist[i % SEEBACK] = num;
    } else {
        info("p1 not found :(", .{});
        return error.P1_NOT_FOUND;
    };
    info("p1: {}", .{p1_target});

    // p2
    //

    var roller = RollingSumFinder.init(allo, target);
    defer roller.deinit();

    for (nums) |num| {
        const p2_done = roller.appendNum(num);
        if (p2_done) {
            const min = std.mem.min(usize, roller.hist);
            const max = std.mem.max(usize, roller.hist);
            info("p2 done! {}", .{min + max});
            break;
        }
    }

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
