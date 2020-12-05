const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const PassportField = struct {
    is_set: bool = false,
    is_ok: bool = false,
};

const Passport = struct {
    byr: PassportField = PassportField{},
    iyr: PassportField = PassportField{},
    eyr: PassportField = PassportField{},
    hgt: PassportField = PassportField{},
    hcl: PassportField = PassportField{},
    ecl: PassportField = PassportField{},
    pid: PassportField = PassportField{},
    cid: PassportField = PassportField{},

    pub fn empty() Passport {
        return Passport{};
    }

    pub fn parse_from_line(self: *Passport, allo: *std.mem.Allocator, line: []const u8) !void {
        const token_separator: [1]u8 = .{' '};
        const prop_separator: [1]u8 = .{':'};
        var tokens = std.mem.split(line, &token_separator);

        while (tokens.next()) |token| {
            var pair = std.mem.split(token, &prop_separator);
            const key = pair.next() orelse unreachable;
            const val = pair.next() orelse unreachable;
            try self.parse_prop(allo, key, val);
        }
    }

    pub fn parse_prop(self: *Passport, allo: *std.mem.Allocator, key: []const u8, val: []const u8) !void {
        info("parsing prop {} {}", .{ key, val });

        if (std.mem.eql(u8, key, "byr")) {
            self.byr.is_set = true;
            const num = fmt.parseUnsigned(usize, val, 10) catch {
                return;
            };
            self.byr.is_ok = (1920 <= num) and (num <= 2002);
            return;
        }

        if (std.mem.eql(u8, key, "iyr")) {
            self.iyr.is_set = true;
            const num = fmt.parseUnsigned(usize, val, 10) catch {
                return;
            };
            self.iyr.is_ok = (2010 <= num) and (num <= 2020);
            return;
        }

        if (std.mem.eql(u8, key, "eyr")) {
            self.eyr.is_set = true;
            const num = fmt.parseUnsigned(usize, val, 10) catch {
                return;
            };
            self.eyr.is_ok = (2020 <= num) and (num <= 2030);
            return;
        }

        if (std.mem.eql(u8, key, "hgt")) {
            self.hgt.is_set = true;
            if (std.mem.endsWith(u8, val, "cm")) {
                const idx = std.mem.indexOf(u8, val, "cm") orelse {
                    return;
                };
                const num = fmt.parseUnsigned(usize, val[0..idx], 10) catch {
                    return;
                };
                self.hgt.is_ok = (150 <= num) and (num <= 193);
                return;
            }
            if (std.mem.endsWith(u8, val, "in")) {
                const idx = std.mem.indexOf(u8, val, "in") orelse {
                    return;
                };
                const num = fmt.parseUnsigned(usize, val[0..idx], 10) catch {
                    return;
                };
                self.hgt.is_ok = (59 <= num) and (num <= 76);
                return;
            }
        }

        if (std.mem.eql(u8, key, "hcl")) {
            self.hcl.is_set = true;
            if (!std.mem.startsWith(u8, val, "#")) {
                return;
            }
            if (val.len != 7) {
                return;
            }
            const num = fmt.parseUnsigned(usize, val[1..7], 16) catch {
                return;
            };
            self.hcl.is_ok = true;
        }

        if (std.mem.eql(u8, key, "ecl")) {
            self.ecl.is_set = true;
            self.ecl.is_ok = std.mem.eql(u8, val, "amb") or
                std.mem.eql(u8, val, "blu") or
                std.mem.eql(u8, val, "brn") or
                std.mem.eql(u8, val, "gry") or
                std.mem.eql(u8, val, "grn") or
                std.mem.eql(u8, val, "hzl") or
                std.mem.eql(u8, val, "oth");
        }

        if (std.mem.eql(u8, key, "pid")) {
            self.pid.is_set = true;
            if (val.len != 9) {
                return;
            }
            _ = fmt.parseUnsigned(usize, val[0..9], 10) catch {
                return;
            };
            self.pid.is_ok = true;
        }

        if (std.mem.eql(u8, key, "cid")) {
            self.cid.is_set = true;
        }
    }

    pub fn p1_ok(self: Passport) bool {
        return self.byr.is_set and
            self.iyr.is_set and
            self.eyr.is_set and
            self.hgt.is_set and
            self.hcl.is_set and
            self.ecl.is_set and
            self.pid.is_set;
    }

    pub fn p2_ok(self: Passport) bool {
        return self.byr.is_ok and
            self.iyr.is_ok and
            self.eyr.is_ok and
            self.hgt.is_ok and
            self.hcl.is_ok and
            self.ecl.is_ok and
            self.pid.is_ok;
    }
};

pub fn main() !void {
    // allocator
    defer _ = gpa.deinit();
    var allo = &gpa.allocator;

    const lines: [][]const u8 = try utils.read_input_lines(allo, "./input1");
    defer allo.free(lines);

    print("== got {} input lines ==\n", .{lines.len});

    // part1
    //
    var p1_cnt: usize = 0;
    var p2_cnt: usize = 0;

    var pp: Passport = Passport.empty();
    var i: usize = 0;
    for (lines) |line| {
        defer allo.free(line);
        i += 1;

        info("--- line {}/{} {}", .{ i, lines.len, line });

        if (line.len == 0) {
            if (pp.p1_ok()) {
                p1_cnt += 1;
            }

            if (pp.p2_ok()) {
                p2_cnt += 1;
            }

            pp = Passport.empty();
            continue;
        }

        pp.parse_from_line(allo, line) catch |err| {
            info("line had err: {}", .{err});
            break;
        };
    }
    print("valid p1 passports: {}\n", .{p1_cnt});
    print("valid p2 passports: {}\n", .{p2_cnt});
}
