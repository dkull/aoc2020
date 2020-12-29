const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

const InputState = enum {
    rules, my_ticket, other_tickets
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Rules = struct {
    allo: *std.mem.Allocator,
    rules: [][2][2]usize,

    pub fn init(allo: *std.mem.Allocator) Rules {
        return Rules{
            .allo = allo,
            .rules = allo.alloc([2][2]usize, 0) catch unreachable,
        };
    }

    pub fn count(self: *Rules) usize {
        return self.rules.len;
    }

    pub fn ingest(self: *Rules, line: []const u8) void {
        // mostly ugly text parsing code
        var colon_iter = std.mem.tokenize(line, ":");
        _ = colon_iter.next();

        const rule_part = colon_iter.next() orelse unreachable;
        var rules_iter = std.mem.tokenize(rule_part, " or ");

        const a = rules_iter.next() orelse unreachable;
        const b = rules_iter.next() orelse unreachable;

        var a_iter = std.mem.tokenize(a, "-");
        var b_iter = std.mem.tokenize(b, "-");

        var a_from = std.fmt.parseInt(usize, a_iter.next() orelse unreachable, 10) catch unreachable;
        var a_to = std.fmt.parseInt(usize, a_iter.next() orelse unreachable, 10) catch unreachable;

        var b_from = std.fmt.parseInt(usize, b_iter.next() orelse unreachable, 10) catch unreachable;
        var b_to = std.fmt.parseInt(usize, b_iter.next() orelse unreachable, 10) catch unreachable;

        self.rules = self.allo.realloc(self.rules, self.rules.len + 1) catch unreachable;
        self.rules[self.rules.len - 1] = .{
            .{ a_from, a_to },
            .{ b_from, b_to },
        };
    }

    pub fn isValidRuleValue(self: *Rules, val: usize, rule_idx: usize) bool {
        const rule = self.rules[rule_idx];
        const a = rule[0];
        const b = rule[1];

        const in_a = a[0] <= val and val <= a[1];
        const in_b = b[0] <= val and val <= b[1];

        if (in_a or in_b) {
            return true;
        }
        return false;
    }

    pub fn isValidValue(self: *Rules, val: usize) bool {
        for (self.rules) |_, i| {
            const valid = self.isValidRuleValue(val, i);
            if (valid) {
                return true;
            }
        }
        return false;
    }

    pub fn sumInvalid(self: *Rules, nums: []usize) ?usize {
        var invalid: ?usize = null;
        for (nums) |num| {
            if (!self.isValidValue(num)) {
                if (invalid) |*x| {
                    x.* += @intCast(usize, 0);
                } else {
                    invalid = num;
                }
            }
        }
        return invalid;
    }

    pub fn deinit(self: *Rules) void {
        self.allo.free(self.rules);
    }
};

fn lineToNums(allo: *std.mem.Allocator, line: []const u8) []usize {
    var tokens = std.mem.tokenize(line, ",");
    var output = allo.alloc(usize, 0) catch unreachable;
    while (tokens.next()) |token| {
        output = allo.realloc(output, output.len + 1) catch unreachable;
        output[output.len - 1] = std.fmt.parseInt(usize, token, 10) catch unreachable;
    }
    return output;
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var rules = Rules.init(allo);
    defer rules.deinit();

    var input_state: InputState = .rules;

    var invalid_total: usize = 0;

    var my_ticket: []usize = allo.alloc(usize, 0) catch unreachable;
    defer allo.free(my_ticket);

    var valid_tickets: [][]usize = allo.alloc([]usize, 0) catch unreachable;
    defer allo.free(valid_tickets); // elements need separate freeing

    // p1

    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "your ticket")) {
            input_state = .my_ticket;
            continue;
        }

        if (std.mem.startsWith(u8, line, "nearby tickets")) {
            input_state = .other_tickets;
            continue;
        }

        switch (input_state) {
            .rules => {
                rules.ingest(line);
            },
            .my_ticket => {
                // NOTE: needs_free
                my_ticket = lineToNums(allo, line);
            },
            .other_tickets => {
                // NOTE: needs_free
                const line_nums = lineToNums(allo, line);
                const invalid_val = rules.sumInvalid(line_nums);
                if (invalid_val) |new| {
                    // free invalid ticket
                    allo.free(line_nums);
                    invalid_total += new;
                } else {
                    // don't free valid ticket
                    valid_tickets = allo.realloc(valid_tickets, valid_tickets.len + 1) catch unreachable;
                    valid_tickets[valid_tickets.len - 1] = line_nums;
                }
            },
        }
    }
    print("p1: {}\n", .{invalid_total});

    // p2

    const rules_cnt = rules.count();

    // track possible field matches
    var rule_fields = allo.alloc(std.AutoHashMap(usize, void), rules_cnt) catch unreachable;
    defer allo.free(rule_fields);
    for (rule_fields) |*rf| {
        rf.* = std.AutoHashMap(usize, void).init(allo);
        var i: usize = 0;
        while (i < rules_cnt) : (i += 1) {
            rf.*.put(i, undefined) catch unreachable;
        }
    }

    // remove invalid fields from rules
    for (valid_tickets) |ticket| {
        defer allo.free(ticket);
        for (ticket) |field_val, field_idx| {
            var i: usize = 0;
            while (i < rules_cnt) : (i += 1) {
                const valid_for_rule = rules.isValidRuleValue(field_val, i);
                if (!valid_for_rule) {
                    // remove this field from this rule
                    _ = rule_fields[i].remove(field_idx);
                }
            }
        }
    }

    // reduce constraints
    while (true) {
        var removed = false;
        for (rule_fields) |rule_caps, i| {
            if (rule_caps.count() == 1) {
                var iter = rule_caps.iterator();
                while (iter.next()) |entry| {
                    for (rule_fields) |*rule_caps_2| {
                        if (rule_caps_2.count() > 1) {
                            _ = rule_caps_2.remove(entry.key);
                            removed = true;
                        }
                    }
                }
            }
        }
        if (!removed) {
            break;
        }
    }

    // see which fields are left
    var p2: usize = 1;
    for (rule_fields) |rf, i| {
        // NOTE: our task requires first 5 rules
        if (i > 5) {
            break;
        }
        var iter = rf.iterator();
        while (iter.next()) |vals| {
            const ticket_field = vals.key;
            p2 *= my_ticket[ticket_field];
        }
    }

    print("p2: {}\n", .{p2});

    // free

    for (rule_fields) |*rf| {
        rf.deinit();
    }

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
