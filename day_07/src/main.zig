const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Node = struct {
    allo: *std.mem.Allocator = undefined,
    is_root: bool = false,
    name: []u8 = undefined,
    parent_contains: usize = undefined,
    children: []*Node = undefined,

    pub fn init(allo: *std.mem.Allocator, name: []u8, is_root: bool, parent_contains: usize) !Node {
        return Node{
            .allo = allo,
            .is_root = is_root,
            .name = try allo.dupe(u8, name),
            .parent_contains = parent_contains,
            .children = try allo.alloc(*Node, 0),
        };
    }

    pub fn append_child(self: *Node, name: []u8, count: usize) !void {
        self.children = try self.allo.realloc(self.children, self.children.len + 1);
        const child = try self.allo.create(Node);
        child.* = try Node.init(self.allo, name, false, count);
        self.children[self.children.len - 1] = child;
    }

    pub fn deinit(self: *Node) void {
        self.allo.free(self.name);
        for (self.children) |child| {
            child.deinit();
            self.allo.destroy(child);
        }
        self.allo.free(self.children);
    }
};

pub fn parseNode(allo: *std.mem.Allocator, line: []const u8) !Node {
    var tokens = std.mem.tokenize(line, " ");

    // read and set parent
    var name = try fmt.allocPrint(allo, "{}_{}", .{
        tokens.next(),
        tokens.next(),
    });
    defer allo.free(name);
    var node = try Node.init(allo, name, true, 0);

    // drop "bags contain"
    _ = tokens.next();
    _ = tokens.next();

    // read contained bags info
    var i: u32 = 0;
    while (true) : (i += 1) {
        const maybe_count = tokens.next() orelse {
            break;
        };
        // check if no children
        const count = fmt.parseUnsigned(usize, maybe_count, 10) catch {
            break;
        };

        // parse child property and color
        var child_name = try fmt.allocPrint(allo, "{}_{}", .{
            tokens.next(),
            tokens.next(),
        });
        defer allo.free(child_name);

        try node.append_child(child_name, count);

        // drop "bag,/."
        _ = tokens.next() orelse {
            break;
        };
    }

    return node;
}

pub fn containsChild(map: std.StringHashMap(Node), name: []const u8, needle: []const u8) bool {
    if (std.mem.eql(u8, name, needle)) {
        return true;
    }
    const node = map.get(name) orelse {
        return false;
    };
    for (node.children) |child| {
        if (containsChild(map, child.name, needle)) {
            return true;
        }
    }
    return false;
}

pub fn countP1(map: std.StringHashMap(Node), needle: []const u8) !u32 {
    var iter = map.iterator();
    var res: u32 = 0;
    // count all toplevels that can contain shiny_gold
    while (iter.next()) |kv| {
        if (!kv.value.is_root or std.mem.eql(u8, needle, kv.key)) {
            continue;
        }
        if (containsChild(map, kv.key, needle)) {
            res += 1;
        }
    }

    return res;
}

pub fn countP2(map: std.StringHashMap(Node), needle: []const u8) anyerror!usize {
    const root = map.get(needle) orelse {
        return error.WHAT;
    };
    var tot: usize = 0;
    for (root.children) |child| {
        const val = try countP2(map, child.name);
        tot += val * child.parent_contains + child.parent_contains;
    }
    return tot;
}

pub fn main() !void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const lines: [][]const u8 = try utils.readInputLines(allo, "./input1");
    defer allo.free(lines);

    print("== got {} input lines ==\n", .{lines.len});

    var nodes = std.StringHashMap(Node).init(allo);
    defer nodes.deinit();

    for (lines) |line| {
        defer allo.free(line);
        info("parsing line: [{}]", .{line});
        const root_node = try parseNode(allo, line);
        try nodes.put(root_node.name, root_node);
    }

    // solutions
    //

    const needle = "shiny_gold";

    const p1 = try countP1(nodes, needle[0..]);
    print("p1: {}\n", .{p1});

    const p2 = try countP2(nodes, needle[0..]);
    print("p2: {}\n", .{p2});

    var iter = nodes.iterator();
    while (iter.next()) |kv| {
        defer kv.value.deinit();
    }
}
