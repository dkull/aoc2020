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

const P2Type = struct { allergen: []u8, ingredient: []u8 };
const P2Ctx = struct { allo: *std.mem.Allocator };

fn lt_fn(ctx: P2Ctx, a: P2Type, b: P2Type) bool {
    const a_val = std.cstr.addNullByte(ctx.allo, a.allergen) catch unreachable;
    const b_val = std.cstr.addNullByte(ctx.allo, b.allergen) catch unreachable;
    const result = std.cstr.cmp(a_val, b_val) == -1;
    ctx.allo.free(a_val);
    ctx.allo.free(b_val);
    return result;
}

const Entry = struct {
    allocator: *std.mem.Allocator,
    ingredients: ArrayList([]u8),
    allergens: ArrayList([]u8),

    pub fn from_line(allo: *std.mem.Allocator, line: []const u8) Entry {
        var ingredients = ArrayList([]u8).init(allo);
        var allergens = ArrayList([]u8).init(allo);

        const token_sep: [1]u8 = .{' '};
        var token_iter = std.mem.split(line, &token_sep);

        // parse ingredients
        while (token_iter.next()) |token| {
            if (std.mem.startsWith(u8, token, "(")) break; // allergen time
            const ingredient = allo.dupe(u8, token) catch unreachable;
            ingredients.append(ingredient) catch unreachable;
        }

        // parse allergens
        while (token_iter.next()) |token| {
            const clean_token = token[0 .. token.len - 1];
            const allergen = allo.dupe(u8, clean_token) catch unreachable;
            allergens.append(allergen) catch unreachable;
        }

        return .{
            .allocator = allo,
            .ingredients = ingredients,
            .allergens = allergens,
        };
    }

    pub fn contains_ingredient(self: *const Entry, target_ingredient: []const u8) i32 {
        for (self.ingredients.items) |ingredient, i| {
            if (std.ascii.eqlIgnoreCase(ingredient, target_ingredient)) return @intCast(i32, i);
        }
        return -1;
    }

    pub fn contains_allergen(self: *const Entry, target_allergen: []const u8) i32 {
        for (self.allergens.items) |allergen, i| {
            if (std.ascii.eqlIgnoreCase(allergen, target_allergen)) return @intCast(i32, i);
        }
        return -1;
    }

    pub fn remove_ingredient(self: *Entry, ingr: []const u8) void {
        const index = self.contains_ingredient(ingr);
        if (index < 0) return;
        const item = self.ingredients.swapRemove(@intCast(usize, index));
        self.allocator.free(item);
    }

    pub fn remove_allergen(self: *Entry, aller: []const u8) void {
        const index = self.contains_allergen(aller);
        if (index < 0) return;
        const item = self.allergens.swapRemove(@intCast(usize, index));
        self.allocator.free(item);
    }

    pub fn print(self: *const Entry) void {
        print("<", .{});
        for (self.ingredients.items) |item| {
            print("{} ", .{item});
        }
        print(" -- ", .{});
        for (self.allergens.items) |item| {
            print("{} ", .{item});
        }
        print(">\n", .{});
    }

    pub fn deinit(self: *Entry) void {
        for (self.ingredients.items) |ingredient| self.allocator.free(ingredient);
        self.ingredients.deinit();

        for (self.allergens.items) |allergen| self.allocator.free(allergen);
        self.allergens.deinit();
    }
};

pub fn get_unique_allergens(entries: []Entry, output: *ArrayList([]u8)) void {
    // populate arraylist with all unique allergens
    for (entries) |entry| {
        for (entry.allergens.items) |allergen| {
            var exists = false;
            for (output.items) |existing_allergen| {
                const match = std.ascii.eqlIgnoreCase(existing_allergen, allergen);
                if (match) {
                    exists = true;
                    break;
                }
            }
            if (!exists) output.append(allergen) catch unreachable;
        }
    }
}

pub fn main() !void {
    const begin = @divTrunc(std.time.nanoTimestamp(), 1000);

    // setup
    //

    var p1: usize = 1;

    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    var lines: std.mem.TokenIterator = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines.buffer);

    var entries = try allo.alloc(Entry, 0);
    defer {
        for (entries) |*entry| entry.deinit();
        allo.free(entries);
    }

    while (lines.next()) |line| {
        const entry = Entry.from_line(allo, line);
        entries = try allo.realloc(entries, entries.len + 1);
        entries[entries.len - 1] = entry;
    }
    info("entries: {}", .{entries.len});

    // p1
    //

    info("== solving p1 ==", .{});

    var pairs = ArrayList(P2Type).init(allo); // for p2
    defer pairs.deinit();

    var unique_allergens = ArrayList([]u8).init(allo);
    defer unique_allergens.deinit();
    get_unique_allergens(entries, &unique_allergens);

    while (true) {
        for (unique_allergens.items) |target_allergen, ua_i| {
            info(">> matching unique allergen: {} in {} entries", .{ target_allergen, entries.len });
            //for (entries) |entry| {
            //    entry.print();
            //}

            var candidate_ingredients = std.BufSet.init(allo);
            defer candidate_ingredients.deinit();

            var inited = false;
            for (entries) |entry, i| {
                if (!(entry.contains_allergen(target_allergen) >= 0)) {
                    continue;
                }

                if (!inited) {
                    inited = true;
                    for (entry.ingredients.items) |ingredient| {
                        candidate_ingredients.put(ingredient) catch unreachable;
                    }
                } else {
                    var existing_ingr = candidate_ingredients.iterator();
                    // remove old ingredients that are not in this entry
                    while (existing_ingr.next()) |ingr| {
                        if (!(entry.contains_ingredient(ingr.key) >= 0)) {
                            candidate_ingredients.delete(ingr.key);
                        }
                    }
                }
            }

            // should only be one candidate left
            if (candidate_ingredients.count() == 1) {
                const ingredient = candidate_ingredients.iterator().next() orelse unreachable;
                info("!!! allergen {} is in {}", .{ target_allergen, ingredient.key });

                // for p2
                const _ingredient = try allo.dupe(u8, ingredient.key);
                const _allergen = try allo.dupe(u8, target_allergen);
                try pairs.append(P2Type{ .allergen = _allergen, .ingredient = _ingredient });
                // end for p2

                // remove this ingredient and allergen from all entries
                for (entries) |*entry| {
                    entry.remove_ingredient(ingredient.key);
                    entry.remove_allergen(target_allergen);
                }
                _ = unique_allergens.swapRemove(ua_i);

                break;
            }
        }

        if (unique_allergens.items.len == 0) {
            break;
        }
    }

    var p1_result: usize = 0;
    for (entries) |entry| {
        p1_result += entry.ingredients.items.len;
    }
    info("p1: {}", .{p1_result});

    // p2
    //

    std.sort.sort(P2Type, pairs.items, P2Ctx{ .allo = allo }, lt_fn);
    print("p2: ", .{});
    for (pairs.items) |item| {
        print("{},", .{item.ingredient});
        allo.free(item.ingredient);
        allo.free(item.allergen);
    }
    print("\n", .{});

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
