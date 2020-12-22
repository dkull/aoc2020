const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn parseBusId(data: []const u8) ?usize {
    if (std.mem.eql(u8, data, "x")) {
        return null;
    }
    const bus_id = fmt.parseInt(usize, data, 10) catch unreachable;
    return bus_id;
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    const first_line = lines.next() orelse unreachable;
    const second_line = lines.next() orelse unreachable;

    var p1_low = fmt.parseInt(usize, first_line, 10) catch unreachable;
    const sched: []const u8 = second_line;

    // p1
    //

    var i = p1_low;
    const res: usize = outer: while (true) : (i += 1) {
        var iter = std.mem.tokenize(sched, ",");
        while (iter.next()) |token| {
            const bus_id = parseBusId(token) orelse continue;
            if (i % bus_id == 0) {
                const res = bus_id * (i - p1_low);
                break :outer res;
            }
        }
    } else unreachable;

    print("p1: {}\n", .{res});

    // p2
    //

    var idx: usize = 0;
    var product: usize = 1;
    var interval: usize = 0;
    var iter = std.mem.tokenize(sched, ",");
    var prev_product: usize = 0;
    while (iter.next()) |next| : (idx += 1) {
        const bus_id = parseBusId(next) orelse continue;

        info(">> bus: {} @ {} / product: {} inter {} ", .{ bus_id, idx, product, interval });

        if (product == 1) {
            product = bus_id;
            interval = bus_id;
            continue;
        }

        var from: usize = 0;
        while (true) {
            if ((product + idx) % bus_id == 0) {
                if (from == 0) {
                    prev_product = product;
                    from = product;
                } else {
                    interval = product - from;
                    break;
                }
            }
            product += interval;
        }
    }

    print("p2: {}\n", .{prev_product});

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
