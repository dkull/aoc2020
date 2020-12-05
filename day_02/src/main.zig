const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Error = error{ NoDashInRule, NoSpaceInRule, NoColonInRule };

const Validator = struct {
    cnt_min: usize,
    cnt_max: usize,
    char: u8,
    pub fn init(rule_line: []const u8) anyerror!Validator {
        const min_until = std.mem.indexOf(u8, rule_line, "-") orelse return Error.NoDashInRule;
        const max_until = std.mem.indexOf(u8, rule_line, " ") orelse return Error.NoSpaceInRule;
        return Validator{
            .cnt_min = try fmt.parseUnsigned(usize, rule_line[0..min_until], 10),
            .cnt_max = try fmt.parseUnsigned(usize, rule_line[min_until + 1 .. max_until], 10),
            .char = rule_line[max_until + 1],
        };
    }

    pub fn valid_part1(self: Validator, password: []const u8) bool {
        var cnt: usize = 0;
        for (password) |pw_char| {
            if (pw_char == self.char) {
                cnt += 1;
            }
        }
        return cnt >= self.cnt_min and cnt <= self.cnt_max;
    }

    pub fn valid_part2(self: Validator, password: []const u8) bool {
        var cnt: usize = 0;
        var fst_contains: u32 = if (password[self.cnt_min] == self.char) 1 else 0;
        var scn_contains: u32 = if (password[self.cnt_max] == self.char) 1 else 0;
        return (fst_contains ^ scn_contains) == 1;
    }
};

pub fn main() anyerror!void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const input_lines = try utils.read_input_lines(allo, "./input1");
    defer allo.free(input_lines);

    print("== got {} input lines ==\n", .{input_lines.len});

    // business logic
    var i: usize = 0;
    var p1_valid_cnt: usize = 0;
    var p2_valid_cnt: usize = 0;
    for (input_lines) |line| {
        defer allo.free(line);

        const separator_at = std.mem.indexOf(u8, line, ":") orelse return Error.NoColonInRule;
        const rule_part = line[0..separator_at];
        const pw_part = line[separator_at + 1 ..];

        const validator = try Validator.init(rule_part);
        if (validator.valid_part1(pw_part)) {
            p1_valid_cnt += 1;
        }
        if (validator.valid_part2(pw_part)) {
            p2_valid_cnt += 1;
        }
    }
    print("p1 valid: {} p2 valid: {}\n", .{ p1_valid_cnt, p2_valid_cnt });
    print("done!\n", .{});
}
