const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const fmt = std.fmt;

pub fn readInputLines(allo: *std.mem.Allocator, inp_fn: []const u8) !std.mem.TokenIterator {
    const separator: [1]u8 = .{'\n'};

    const file = try std.fs.cwd().readFileAlloc(allo, inp_fn, 10 * 1024 * 1024);
    var lines = std.mem.tokenize(file, &separator);

    return lines;
}
