const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;
const ArrayList = std.ArrayList;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

// Edit input1 to calc p1, by defualt this calculates p2
//

const RuleDetails = union(enum) {
    or_rules: [][]usize,
    char: u8,
};

const Rule = struct {
    allo: *std.mem.Allocator,
    id: usize,
    details: RuleDetails,

    pub fn init(allo: *std.mem.Allocator, line: []const u8) Rule {
        var line_iter = std.mem.tokenize(line, ":");
        var rule_id = std.fmt.parseInt(usize, line_iter.next() orelse unreachable, 10) catch unreachable;
        var rules = std.mem.trim(u8, line_iter.next() orelse unreachable, " ");

        if (std.mem.indexOf(u8, line, "\"")) |_| {
            return Rule{
                .allo = allo,
                .id = rule_id,
                .details = RuleDetails{
                    .char = rules[1],
                },
            };
        } else {
            var or_rules = allo.alloc([]usize, 0) catch unreachable;
            var parts = std.mem.split(line, " ");

            var genned = false;
            while (parts.next()) |sub_rule_id| {
                if (sub_rule_id[0] == '|' or !genned) {
                    var inner_rules = allo.alloc(usize, 0) catch unreachable;
                    or_rules = allo.realloc(or_rules, or_rules.len + 1) catch unreachable;
                    or_rules[or_rules.len - 1] = inner_rules;
                    genned = true;
                    if (genned) {
                        continue;
                    }
                }
                var ruleset = or_rules[or_rules.len - 1];

                ruleset = allo.realloc(ruleset, ruleset.len + 1) catch unreachable;
                ruleset[ruleset.len - 1] = std.fmt.parseInt(usize, sub_rule_id, 10) catch unreachable;

                or_rules[or_rules.len - 1] = ruleset;
            }
            return Rule{
                .allo = allo,
                .id = rule_id,
                .details = RuleDetails{
                    .or_rules = or_rules,
                },
            };
        }
    }

    pub fn deinit(self: *Rule, allo: *std.mem.Allocator) void {
        _ = switch (self.details) {
            RuleDetails.or_rules => |rules| {
                for (rules) |rule| {
                    allo.free(rule);
                }
                allo.free(rules);
            },
            else => void,
        };
    }

    pub fn matches(self: Rule, and_rules: []usize, all_rules: []?Rule, line: []const u8) bool {
        // only happens in p2 - actually this was the only addition to get p2 to work
        if (line.len == 0) {
            return false;
        }

        switch (self.details) {
            .char => |chr| {
                // bad char
                if (line[0] != chr) return false;
                if (and_rules.len > 0) {
                    const and_rule = all_rules[and_rules[0]] orelse unreachable;
                    const res = and_rule.matches(and_rules[1..], all_rules, line[1..]);
                    return res;
                } else {
                    return line.len == 1;
                }
            },
            .or_rules => |or_rules| {
                // one of the rule sets must match
                for (or_rules) |rule_set, i| {
                    const first_rule_id = rule_set[0];
                    const first_rule = all_rules[first_rule_id] orelse unreachable;

                    const concatted = self.allo.alloc(usize, rule_set[1..].len + and_rules.len) catch unreachable;
                    defer self.allo.free(concatted);
                    std.mem.copy(usize, concatted, rule_set[1..]);
                    std.mem.copy(usize, concatted[rule_set[1..].len..], and_rules);

                    const match = first_rule.matches(concatted, all_rules, line);

                    if (match) {
                        return true;
                    }
                }
            },
        }
        return false;
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

    var sum_p2: isize = 0;

    var rules: []?Rule = allo.alloc(?Rule, 0) catch unreachable;
    defer {
        for (rules) |*maybe_rule| {
            if (maybe_rule.*) |*rule| {
                rule.deinit(allo);
            }
        }
        allo.free(rules);
    }

    while (lines.next()) |line| {
        info("line: {} ", .{line});
        if (std.mem.indexOf(u8, line, ":") != null) {
            const rule = Rule.init(allo, line);
            if (rules.len < rule.id + 1) {
                rules = allo.realloc(rules, rule.id + 1) catch unreachable;
            }
            rules[rule.id] = rule;
        } else {
            // match
            const main_rule = rules[0] orelse unreachable;
            if (main_rule.matches(&[0]usize{}, rules, line)) {
                sum_p2 += 1;
            }
        }
    }

    print("p2: {}\n", .{sum_p2});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
