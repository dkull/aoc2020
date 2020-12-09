const std = @import("std");
const fs = std.fs;
const io = std.io;
const info = std.log.info;
const print = std.debug.print;
const fmt = std.fmt;

const utils = @import("utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn flipInstruction(inst: *Instruction) void {
    switch (inst.typ) {
        InstType.JMP => {
            inst.typ = InstType.NOP;
        },
        InstType.NOP => {
            inst.typ = InstType.JMP;
        },
        else => unreachable,
    }
}

const InstType = enum {
    ACC, JMP, NOP
};

const Instruction = struct {
    typ: InstType,
    val: isize,
    visited: bool = false,

    pub fn initFromLine(line: []const u8) Instruction {
        var tokens = std.mem.tokenize(line, " ");
        const typ_str = tokens.next() orelse unreachable;
        const val_str = tokens.next() orelse unreachable;

        var typ: InstType = switch (typ_str[0]) {
            'a' => InstType.ACC,
            'j' => InstType.JMP,
            'n' => InstType.NOP,
            else => unreachable,
        };

        return Instruction{
            .typ = typ,
            .val = fmt.parseInt(isize, val_str, 10) catch unreachable,
        };
    }
};

const Program = struct {
    allo: *std.mem.Allocator = undefined,
    mem: []Instruction = undefined,
    ptr: isize = 0,
    cnt: isize = 0,

    pub fn init(allo: *std.mem.Allocator) Program {
        return Program{
            .allo = allo,
            .mem = allo.alloc(Instruction, 0) catch unreachable,
        };
    }

    pub fn deinit(self: Program) void {
        self.allo.free(self.mem);
    }

    pub fn appendInstruction(self: *Program, inst: Instruction) void {
        const cur_len = self.mem.len;
        self.mem = self.allo.realloc(self.mem, cur_len + 1) catch unreachable;
        self.mem[cur_len] = inst;
    }

    pub fn run(self: *Program) !void {
        self.reset();
        while (true) {
            const ptr = @intCast(usize, self.ptr);

            if (ptr >= self.mem.len) {
                // p2 case
                return error.END;
            }

            var inst = self.mem[ptr];
            if (inst.visited) {
                // p1 case
                return error.VISITED;
            }

            self.mem[ptr].visited = true;
            switch (inst.typ) {
                InstType.ACC => {
                    self.cnt += inst.val;
                    self.ptr += 1;
                },
                InstType.NOP => {
                    self.ptr += 1;
                },
                InstType.JMP => {
                    self.ptr += inst.val;
                },
            }
        }
    }

    fn reset(self: *Program) void {
        self.ptr = 0;
        self.cnt = 0;
        for (self.mem) |*inst| {
            inst.visited = false;
        }
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

    // business logic
    //

    var program = Program.init(allo);
    defer program.deinit();

    while (lines.next()) |line| {
        const inst = Instruction.initFromLine(line);
        program.appendInstruction(inst);
    }

    // do p1
    //

    program.run() catch |e| {
        print("p1 [{}]: {}\n", .{ e, program.cnt });
    };

    // do p2
    //

    var candidate = allo.alloc(usize, program.mem.len) catch unreachable;
    defer allo.free(candidate);
    var cnt: usize = 0;

    for (program.mem) |*inst, i| {
        // we only want to flip visited instructions
        if (!inst.visited) {
            continue;
        }

        // skip if flipping instr would move us to visited instruction
        switch (inst.typ) {
            InstType.ACC => {
                continue;
            },
            InstType.NOP => {
                const offset = @intCast(usize, @intCast(isize, i) + inst.val);
                const jump_candidate = program.mem[offset];
                if (jump_candidate.visited) {
                    continue;
                }
            },
            InstType.JMP => {
                const step_candidate = program.mem[i + 1];
                if (step_candidate.visited) {
                    continue;
                }
            },
        }

        candidate[cnt] = i;
        cnt += 1;
    }

    for (candidate[0..cnt]) |w| {
        // flip a good candidate and see where we end up
        var inst = &program.mem[w];
        flipInstruction(inst);

        program.run() catch |e| {
            if (e != error.VISITED) {
                print("p2 [{}]: {}\n", .{ e, program.cnt });
                break;
            }
        };

        flipInstruction(inst);
    }

    const delta = @divTrunc(std.time.nanoTimestamp(), 1000) - begin;
    print("all done in {} microseconds\n", .{delta});
}
