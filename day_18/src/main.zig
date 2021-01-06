const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Op = enum {
    sum,
    mul,
    pub fn apply(self: Op, a: isize, b: isize) isize {
        return switch (self) {
            .sum => a + b,
            .mul => a * b,
        };
    }
};

const Token = union(enum) {
    num: isize, op: Op, lpar, rpar
};

const ExprRes = struct {
    val: isize,
    ptr: usize,
};

fn findMatchingParens(tokens: []Token) usize {
    var depth: isize = 0;
    for (tokens) |token, i| {
        switch (token) {
            .lpar => depth += 1,
            .rpar => depth -= 1,
            else => continue,
        }
        if (depth == -1) {
            return i;
        }
    }
    unreachable;
}

fn parseTokens(allo: *std.mem.Allocator, line: []const u8) []Token {
    var output = allo.alloc(Token, 0) catch unreachable;
    for (line) |char| {
        const token = switch (char) {
            ' ' => continue,
            '(' => .lpar,
            ')' => .rpar,
            '+' => Token{ .op = .sum },
            '*' => Token{ .op = .mul },
            // assume all numbers are single digits (as in examples and input)
            else => blk: {
                var chr_as_str: [1]u8 = .{char};
                break :blk Token{ .num = std.fmt.parseInt(isize, &chr_as_str, 10) catch unreachable };
            },
        };
        output = allo.realloc(output, output.len + 1) catch unreachable;
        output[output.len - 1] = token;
    }
    return output;
}

fn calcExpressionP1(tokens: []Token, roll_val: isize, cur_op: ?Op) isize {
    if (tokens.len == 0) return roll_val;
    info("tok: {} val: {} curop: {}", .{ tokens[0], roll_val, cur_op });
    return switch (tokens[0]) {
        .lpar => blk: {
            var val = calcExpressionP1(tokens[1..], 0, null);
            if (cur_op) |cur_op_val| {
                val = cur_op_val.apply(roll_val, val);
            }
            const closing = findMatchingParens(tokens[1..]);
            break :blk calcExpressionP1(tokens[closing + 1 + 1 ..], val, null);
        },
        .rpar => return roll_val,
        .op => |op_op| calcExpressionP1(tokens[1..], roll_val, op_op),
        .num => |cur_val| if (cur_op) |cur_op_val|
            calcExpressionP1(tokens[1..], cur_op_val.apply(roll_val, cur_val), null)
        else
            calcExpressionP1(tokens[1..], cur_val, null),
    };
}

fn calcExpressionP2(tokens: []Token, roll_val: isize, cur_op: ?Op) isize {
    if (tokens.len == 0) return roll_val;
    info("tok: {} val: {} curop: {}", .{ tokens[0], roll_val, cur_op });
    return switch (tokens[0]) {
        .lpar => blk: {
            var val = calcExpressionP2(tokens[1..], 0, null);
            if (cur_op) |cur_op_val| {
                val = cur_op_val.apply(roll_val, val);
            }
            const closing = findMatchingParens(tokens[1..]);
            break :blk calcExpressionP2(tokens[closing + 1 + 1 ..], val, null);
        },
        .rpar => return roll_val,
        .op => |op_op| switch (op_op) {
            // NOTE: only change in P2 is this switch
            .sum => calcExpressionP2(tokens[1..], roll_val, op_op),
            .mul => op_op.apply(roll_val, calcExpressionP2(tokens[1..], 0, null)),
        },
        .num => |cur_val| if (cur_op) |cur_op_val|
            calcExpressionP2(tokens[1..], cur_op_val.apply(roll_val, cur_val), null)
        else
            calcExpressionP2(tokens[1..], cur_val, null),
    };
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var sum_p1: isize = 0;
    var sum_p2: isize = 0;

    while (lines.next()) |line| {
        info("doing expression: {}", .{line});
        var tokens = parseTokens(allo, line);
        defer allo.free(tokens);

        const res_p1 = calcExpressionP1(tokens, 0, .sum);
        info("res p1: {}", .{res_p1});
        sum_p1 += res_p1;

        const res_p2 = calcExpressionP2(tokens, 0, .sum);
        info("res p2: {}", .{res_p2});
        sum_p2 += res_p2;
    }

    print("p1: {}\n", .{sum_p1});
    print("p2: {}\n", .{sum_p2});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
