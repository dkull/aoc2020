const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() anyerror!void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const input_lines = try utils.read_input_lines(allo, "./input1");
    defer allo.free(input_lines);

    var past_nums = try allo.alloc(usize, input_lines.len);
    defer allo.free(past_nums);

    info("== got {} input lines ==", .{input_lines.len});

    // business logic
    var i: u32 = 0;
    for (input_lines) |line| {
        defer allo.free(line);
        const num = try fmt.parseUnsigned(usize, line, 10);
        //info("line {} -> {}", .{ line, num });
        var j: u32 = 0;
        past_nums[i] = num;
        while (j <= i) : (j += 1) {
            const a = num;
            const b = past_nums[j];
            const sum1 = a + b;
            if (sum1 == 2020) {
                info("nums: {} + {} = 2020 | part1 answer: {}", .{ a, b, a * b });
            }
            var k: u32 = 0;
            while (k <= j) : (k += 1) {
                const c = past_nums[k];
                const sum2 = a + b + c;
                if (sum2 == 2020) {
                    info("nums: {} + {} + {} = 2020 | part2 answer: {}", .{ a, b, c, a * b * c });
                }
            }
        }
        i += 1;
    }
    info("done!", .{});
}
