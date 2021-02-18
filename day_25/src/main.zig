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

const Step = enum {
    e, se, sw, w, nw, ne
};

fn mod_exp(b: usize, n: usize, m: usize) usize {
    var result: usize = 1;
    var i: usize = 1;
    while (i <= n) : (i += 1) {
        result = b * result % m;
    }
    return result;
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    // setup
    //

    var pubkey_1 = try fmt.parseUnsigned(usize, (lines.next() orelse unreachable), 10);
    var pubkey_2 = try fmt.parseUnsigned(usize, (lines.next() orelse unreachable), 10);
    info("pub1: {} pub2: {}", .{ pubkey_1, pubkey_2 });

    const subject_nr: usize = 7;
    const modulus: usize = 20201227;
    var value: usize = 1;

    var exp_1: usize = 0;
    var i: usize = 1;
    while (true) : (i += 1) {
        value = value * subject_nr % modulus;
        if (value == pubkey_1) {
            exp_1 = i;
            break;
        }
    }

    const key = mod_exp(pubkey_2, exp_1, modulus);
    print("p1: {}\n", .{key});

    // end
    //
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
