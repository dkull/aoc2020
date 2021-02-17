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

const Node = struct {
    allo: *std.mem.Allocator,
    value: usize,
    next: *Node,

    pub fn populate(self: *Node, allo: *std.mem.Allocator, value: usize) void {
        self.allo = allo;
        self.value = value;
        self.next = allo.create(Node) catch unreachable;
    }
};

fn print_ring(node: *Node) void {
    var next = node;
    while (true) {
        print("{}", .{next.value});
        next = next.next;
        if (next.value == node.value) break;
    }
    print("\n", .{});
}

fn slice_contains(node: *Node, value: usize, cnt: usize) bool {
    var next = node;
    var i: usize = 0;
    while (i < cnt) : (i += 1) {
        if (next.value == value) return true;
        next = next.next;
        if (next.value == node.value) return false;
    }
    return false;
}

fn cut_right(node: *Node, cnt: usize) *Node {
    if (cnt == 0) {
        return node;
    } else {
        const new_next = cut_right(node.next, cnt - 1);
        const cut_slice = node.next;
        node.next = new_next;
        return cut_slice;
    }
}

fn right_nth(node: *Node, nth: usize) *Node {
    var next = node;
    var i: usize = 0;
    while (true) : (i += 1) {
        if (i == nth) return next;
        next = next.next;
    }
}

fn splice_right(node: *Node, new: *Node, cnt: usize) void {
    // store continuation to ring
    const old_next = node.next;
    // insert new slice
    node.next = new;
    // slice last node
    var slice_end = right_nth(new, cnt - 1);
    slice_end.next = old_next;
}

fn map_nodes(node: *Node, output: []*Node) void {
    var next = node;
    while (true) {
        info("> {}", .{next.value});
        output[next.value] = next;
        next = next.next;
        if (next.value == node.value) break;
    }
}

fn destroy_ring(allo: *std.mem.Allocator, node: *Node) void {
    var next = node;
    var i: usize = 0;
    while (true) : (i += 1) {
        const prev = next;
        next = next.next;
        defer allo.destroy(prev);
        if (next.value == node.value) break;
    }
}

fn run_game(allo: *std.mem.Allocator, node: *Node, rounds: usize, largest_value: usize) *Node {
    // helper for finding nodes quickly
    var node_map: []*Node = allo.alloc(*Node, largest_value + 1) catch unreachable;
    map_nodes(node, node_map);

    var first_node = node;
    var i: usize = 0;
    while (i < rounds) : (i += 1) {
        // cut a slice and patch the remaining nodes
        const cur_val = first_node.value;
        const cut = first_node.next;
        const new_next = right_nth(first_node, 1 + 3);
        first_node.next = new_next;

        // find target value
        var target: usize = if (cur_val == 1) largest_value else cur_val - 1;
        while (slice_contains(cut, target, 3)) {
            target = if (target == 1) largest_value else target - 1;
        }
        // our target is behind us! so lets use a map
        var target_node = node_map[target];
        if (target_node.value != target) unreachable;

        // splice cut into ring
        splice_right(target_node, cut, 3);
        // choose a new "first" node
        first_node = first_node.next;
    }
    const one_node = node_map[1];

    allo.free(node_map);
    return one_node;
}

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
    var largest_value: usize = 0;

    var first_node_p1: *Node = try allo.create(Node);
    var last_node_p1: *Node = first_node_p1;

    var first_node_p2: *Node = try allo.create(Node);
    var last_node_p2: *Node = first_node_p2;

    const line = lines.next() orelse unreachable;
    for (line) |char, i| {
        // create new node from input
        const char_val = try fmt.parseUnsigned(usize, &[_]u8{char}, 10);
        if (char_val > largest_value) largest_value = char_val;

        last_node_p1.populate(allo, char_val);
        last_node_p2.populate(allo, char_val);

        // do not move to next node on last char
        if (i < line.len - 1) {
            last_node_p1 = last_node_p1.next;
            last_node_p2 = last_node_p2.next;
        }
    }
    // finally link first and last nodes
    allo.destroy(last_node_p1.next);
    // link first and last
    last_node_p1.next = first_node_p1;
    last_node_p2 = last_node_p2.next;
    // NOTE: p2 we do not link first and last yet

    // p1
    const first_game = run_game(allo, first_node_p1, 100, largest_value);
    print("p1 order (drop the 1): ", .{});
    print_ring(first_game);

    // p2
    var i = largest_value + 1;
    while (i <= 1000000) : (i += 1) {
        last_node_p2.populate(allo, i);
        if (i < 1000000) {
            last_node_p2 = last_node_p2.next;
        }
    }
    allo.destroy(last_node_p2.next);
    last_node_p2.next = first_node_p2;

    const second_game = run_game(allo, first_node_p2, 10000000, 1000000);
    p2 = second_game.next.value * second_game.next.next.value;
    print("p2: {}\n", .{p2});

    // destroy memory

    destroy_ring(allo, first_node_p1);
    info("freeing p2 nodes... this takes a long while", .{});
    destroy_ring(allo, last_node_p2);

    // end
    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
