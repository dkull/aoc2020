const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const History = struct {
    allo: *std.mem.Allocator,
    prev: usize,
    hist: []?[3]usize,
    idx: usize,

    pub fn init(allo: *std.mem.Allocator) History {
        return History{
            .allo = allo,
            .prev = 0,
            .hist = allo.alloc(?[3]usize, 1000) catch unreachable,
            .idx = 0,
        };
    }

    pub fn ensureCapacity(self: *History, num: usize) void {
        while (num >= self.hist.len) {
            self.hist = self.allo.realloc(self.hist, self.hist.len * 2) catch unreachable;
        }
    }

    pub fn seenNew(self: *History, num: usize) void {
        self.ensureCapacity(num);

        self.idx += 1;
        if (self.hist[num]) |*existing| {
            existing[0] += 1;
            existing[1] = existing[2];
            existing[2] = self.idx;
        } else {
            self.hist[num] = .{
                0, self.idx, self.idx,
            };
        }
        self.prev = num;
    }

    pub fn genNext(self: *History) usize {
        const prev_data = self.hist[self.prev] orelse unreachable;
        const prev_cnt = prev_data[0];
        const prev_last_old = prev_data[1];
        const prev_last_new = prev_data[2];

        const prev_unique = prev_cnt == 0;

        const new_num = if (prev_unique) 0 else prev_last_new - prev_last_old;

        self.seenNew(new_num);

        return new_num;
    }

    pub fn deinit(self: *History) void {
        self.allo.free(self.hist);
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

    const line = lines.next() orelse unreachable;

    var tokens = std.mem.tokenize(line, ",");

    var hist = History.init(allo);
    defer hist.deinit();

    // prime the game from input
    while (tokens.next()) |token| {
        const val = std.fmt.parseInt(usize, token, 10) catch unreachable;
        hist.seenNew(val);
    }

    while (hist.idx < 30000000) {
        const res = hist.genNext();
        if (hist.idx == 2020) {
            print("p1: {}\n", .{res});
        }
        if (hist.idx == 30000000) {
            print("p2: {}\n", .{res});
        }
    }

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
