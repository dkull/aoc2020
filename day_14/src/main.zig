const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn parseMask(line: []const u8, allow: u8) usize {
    var res: usize = 0;
    const one: usize = 1;
    // i could parse this with std.fmt but that would mean allocations for replace
    for (line) |tok, i| {
        res <<= 1;
        if (tok != allow) {
            continue;
        }
        res |= one;
    }
    return res;
}

const Memory = struct {
    allo: *std.mem.Allocator,
    mem: std.AutoHashMap(usize, usize),
    ones_mask: usize,
    zeros_mask: usize,
    float_mask: usize,
    p2_mode: bool,

    pub fn init(allo: *std.mem.Allocator, p2_mode: bool) Memory {
        return Memory{
            .allo = allo,
            .mem = std.AutoHashMap(usize, usize).init(allo),
            .ones_mask = 0x00,
            .zeros_mask = 0x00,
            .float_mask = 0x00,
            .p2_mode = p2_mode,
        };
    }

    pub fn deinit(self: *Memory) void {
        self.mem.deinit();
    }

    pub fn doLine(self: *Memory, line: []const u8) void {
        const is_mask = std.mem.indexOf(u8, line, "mask");
        if (is_mask) |_val| {
            self.doMaskLine(line);
        } else {
            self.doMemLine(line);
        }
    }

    fn doMaskLine(self: *Memory, line: []const u8) void {
        var tokens = std.mem.tokenize(line, "mask =");
        const mask = tokens.next() orelse unreachable;

        self.zeros_mask = parseMask(mask, '0');
        self.ones_mask = parseMask(mask, '1');
        self.float_mask = parseMask(mask, 'X');
    }

    fn doMemLine(self: *Memory, line: []const u8) void {
        var tokens = std.mem.tokenize(line, "mem[] =");
        const addr = fmt.parseInt(usize, tokens.next() orelse unreachable, 10) catch unreachable;
        const val = fmt.parseInt(usize, tokens.next() orelse unreachable, 10) catch unreachable;

        if (!self.p2_mode) {
            self.doP1Mem(addr, val);
        } else {
            self.doP2Mem(addr, val);
        }
    }

    fn doP1Mem(self: *Memory, addr: usize, val: usize) void {
        const ones_masked = val | self.ones_mask;
        const zeros_masked = ones_masked & ~self.zeros_mask;
        _ = self.mem.put(addr, zeros_masked) catch unreachable;
    }

    fn doP2Mem(self: *Memory, addr: usize, val: usize) void {
        const float_bits_cnt = @intCast(u6, @popCount(usize, self.float_mask));
        const one: usize = 1;
        const upper: usize = one << float_bits_cnt;

        var i: usize = 0;
        while (i < upper) : (i += 1) {
            var addr_tweaked: usize = addr;
            addr_tweaked |= self.ones_mask;

            var mod_mask = self.float_mask;

            var long: usize = 0;
            var short: usize = 0;
            while (true) : (long += 1) {
                const shifted_mask = mod_mask >> @intCast(u6, long);
                if (shifted_mask == 0) {
                    // all mask bits set
                    break;
                }
                if (shifted_mask & 0x01 == 1) {
                    const bit = i >> @intCast(u6, short) & 0x01;
                    const bit_mask = one << @intCast(u6, long);
                    if (bit == 0) {
                        addr_tweaked &= ~(one << @intCast(u6, long));
                    } else {
                        addr_tweaked |= bit_mask;
                    }
                    short += 1;
                }
            }
            self.mem.put(addr_tweaked, val) catch unreachable;
        }
    }

    fn sumAll(self: *Memory) usize {
        var sum: usize = 0;
        var iter = self.mem.iterator();
        while (iter.next()) |kv| {
            sum += kv.value;
        }
        return sum;
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

    var p1_mem = Memory.init(allo, false);
    defer p1_mem.deinit();
    var p2_mem = Memory.init(allo, true);
    defer p2_mem.deinit();

    while (lines.next()) |line| {
        p1_mem.doLine(line);
        p2_mem.doLine(line);
    }

    // 14722016054794
    print("p1: {}\n", .{p1_mem.sumAll()});
    print("p2: {}\n", .{p2_mem.sumAll()});

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
