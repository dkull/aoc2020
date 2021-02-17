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

const HANDS = 2;

const Game = struct {
    hands: [2]ArrayList(u8),

    pub fn init(allo: *std.mem.Allocator) Game {
        return .{
            .hands = .{
                ArrayList(u8).init(allo),
                ArrayList(u8).init(allo),
            },
        };
    }

    pub fn deinit(self: *Game) void {
        for (self.hands) |hand| {
            hand.deinit();
        }
    }

    pub fn load_card(self: *Game, hand_idx: usize, card: u8) void {
        self.hands[hand_idx].append(card) catch unreachable;
    }

    pub fn play_round(self: *Game) bool {
        for (self.hands) |hand| {
            if (hand.items.len == 0) return false;
        }

        // could order the hands in reverse for a bit more optimal solution
        const a_card = self.hands[0].orderedRemove(0);
        const b_card = self.hands[1].orderedRemove(0);

        if (a_card > b_card) {
            self.hands[0].append(a_card) catch unreachable;
            self.hands[0].append(b_card) catch unreachable;
        } else {
            self.hands[1].append(b_card) catch unreachable;
            self.hands[1].append(a_card) catch unreachable;
        }
        return true;
    }

    pub fn get_highest_score(self: *Game) usize {
        var high_score: usize = 0;
        for (self.hands) |hand| {
            var hand_score: usize = 0;
            for (hand.items) |card, i| {
                hand_score += card * (hand.items.len - i);
            }
            if (hand_score > high_score) {
                high_score = hand_score;
            }
        }
        return high_score;
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

    var p1: usize = 0;
    var p2: usize = 0;

    // setup done

    // setup p1
    var game = Game.init(allo);
    defer game.deinit();

    var hand_idx: isize = -1;
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        if (std.mem.indexOf(u8, line, "Player") != null) {
            hand_idx += 1;
            continue;
        }
        const card_value = try fmt.parseUnsigned(u8, line, 10);
        game.load_card(@intCast(usize, hand_idx), card_value);
    }

    // calc p1
    while (game.play_round()) {}
    p1 = game.get_highest_score();
    info("p1: {}", .{p1});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
