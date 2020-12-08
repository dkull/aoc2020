const std = @import("std");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;
    var map = std.AutoHashMap([]u8, usize).init(allo);

    const a = "abcd";
    try map.put(a[0..], 123);
}
