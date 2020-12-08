const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const fmt = std.fmt;

pub fn readInputLines(allo: *std.mem.Allocator, inp_fn: []const u8) ![][]const u8 {
    const separator: [1]u8 = .{'\n'};

    const f = try fs.cwd().openFile(inp_fn, fs.File.OpenFlags{
        .read = true,
    });
    defer f.close();

    var byte_buffer = try allo.alloc(u8, 2048 * 1024);
    defer allo.free(byte_buffer);

    const nr_bytes = try f.readAll(byte_buffer);
    var lines = std.mem.tokenize(byte_buffer[0..nr_bytes], &separator);

    var out_lines: [][]const u8 = try allo.alloc([]const u8, 1024 * 1024);
    defer allo.free(out_lines);

    var i: u32 = 0;
    while (lines.next()) |line| {
        var fresh_line = try allo.alloc(u8, line.len);
        std.mem.copy(u8, fresh_line, line);
        out_lines[i] = fresh_line;
        i += 1;
    }
    var out_lines_real: [][]const u8 = try allo.alloc([]const u8, i);
    std.mem.copy([]const u8, out_lines_real, out_lines[0..i]);

    return out_lines_real[0..i];
}
