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

const Game = struct {
    allo: *std.mem.Allocator,
    hands: [2]ArrayList(u8),
    past_hands: ArrayList([]u8),

    pub fn init(allo: *std.mem.Allocator) Game {
        return .{
            .allo = allo,
            .hands = .{
                ArrayList(u8).init(allo),
                ArrayList(u8).init(allo),
            },
            .past_hands = ArrayList([]u8).init(allo),
        };
    }

    pub fn deinit(self: *Game) void {
        for (self.hands) |hand| {
            hand.deinit();
        }
        for (self.past_hands.items) |past_hand| {
            self.allo.free(past_hand);
        }
        self.past_hands.deinit();
    }

    pub fn load_card(self: *Game, hand_idx: usize, card: u8) void {
        self.hands[hand_idx].append(card) catch unreachable;
    }

    pub fn play_normal_round(self: *Game) ?usize {
        // game over if one player has no cards
        const winner_with_cards = self.player_with_all_cards();
        if (winner_with_cards != null) return winner_with_cards;

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

        return null;
    }

    pub fn play_recursive_round(self: *Game) ?usize {
        // game over if one player has no cards
        const winner_with_cards = self.player_with_all_cards();
        if (winner_with_cards != null) return winner_with_cards;

        // game over if duplicate hand - player 1 wins
        if (self.is_duplicate_hand()) return 0;

        // add p1 hand to history
        const dup = self.allo.dupe(u8, self.hands[0].items) catch unreachable;
        self.past_hands.append(dup) catch unreachable;

        // could order the hands in reverse for a bit more optimal solution
        const a_card = self.hands[0].orderedRemove(0);
        const b_card = self.hands[1].orderedRemove(0);

        // check if we need to recurse
        const recurse = a_card <= self.hands[0].items.len and b_card <= self.hands[1].items.len;

        const round_winner: usize = if (recurse) blk: {
            // setup recursive game
            var recursive_game = Game.init(self.allo);
            recursive_game.hands[0].appendSlice(self.hands[0].items[0..a_card]) catch unreachable;
            recursive_game.hands[1].appendSlice(self.hands[1].items[0..b_card]) catch unreachable;
            // play game until winner is determined
            while (true) {
                const winner = recursive_game.play_recursive_round();
                if (winner != null) {
                    recursive_game.deinit();
                    break :blk winner orelse unreachable;
                }
            }
        } else blk: {
            break :blk switch (a_card > b_card) {
                true => @as(usize, 0),
                false => @as(usize, 1),
            };
        };

        // do regular winning conditions
        //if (round_winner == @as(usize, 0)) {
        if (round_winner == @intCast(usize, 0)) {
            self.hands[0].append(a_card) catch unreachable;
            self.hands[0].append(b_card) catch unreachable;
        } else {
            self.hands[1].append(b_card) catch unreachable;
            self.hands[1].append(a_card) catch unreachable;
        }

        return null;
    }

    pub fn player_with_all_cards(self: *Game) ?usize {
        // we could store this value, but i am opting not to
        var total_cards: usize = 0;
        for (self.hands) |hand| {
            total_cards += hand.items.len;
        }
        for (self.hands) |hand, i| {
            if (hand.items.len == total_cards) return i;
        }
        return null;
    }

    pub fn is_duplicate_hand(self: *Game) bool {
        const p1_hand = self.hands[0].items;
        for (self.past_hands.items) |past_hand| {
            if (std.mem.eql(u8, past_hand, p1_hand)) {
                return true;
            }
        }
        return false;
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
    var game_1 = Game.init(allo);
    defer game_1.deinit();

    // setup p2
    var game_2 = Game.init(allo);
    defer game_2.deinit();

    // load cards to both games
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

        game_1.load_card(@intCast(usize, hand_idx), card_value);
        game_2.load_card(@intCast(usize, hand_idx), card_value);
    }

    // play part 1
    while (game_1.play_normal_round() == null) {}
    p1 = game_1.get_highest_score();
    print("p1: {}\n", .{p1});

    // play part 2
    while (game_2.play_recursive_round() == null) {}
    p2 = game_2.get_highest_score();
    print("p2: {}\n", .{p2});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
