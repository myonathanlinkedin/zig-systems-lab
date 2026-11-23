const std = @import("std");

pub const HyperLogLog = struct {
    p: u8, // precision
    m: usize, // number of registers = 1 << p
    registers: []u8, // each register stores rank (max 64)
    allocator: std.mem.Allocator,

    pub fn init(p: u8) !HyperLogLog {
        if (p < 4 or p > 16) return error.InvalidPrecision;
        const m = @as(usize, 1) << p;
        const allocator = std.heap.page_allocator;
        const regs = try allocator.alloc(u8, m);
        std.mem.set(u8, regs, 0);
        return HyperLogLog{
            .p = p,
            .m = m,
            .registers = regs,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HyperLogLog) void {
        self.allocator.free(self.registers);
    }

    // Add an element given as a byte slice
    pub fn add(self: *HyperLogLog, item: []const u8) void {
        const hash = std.hash.Wyhash.hash(0, item);
        const idx = @as(usize, hash >> (64 - self.p));
        const w = hash << self.p; // remaining bits
        // count leading zeros in w, add 1. Clamp to (64 - p) + 1
        const rank = @clz(w) + 1;
        const cur = self.registers[idx];
        if (rank > cur) {
            self.registers[idx] = @intCast(u8, rank);
        }
    }

    // Estimate cardinality
    pub fn count(self: *HyperLogLog) f64 {
        const m_f = @intToFloat(f64, self.m);
        var sum: f64 = 0.0;
        var zeros: usize = 0;
        for (self.registers) |reg| {
            sum += @intToFloat(f64, 1) / @intToFloat(f64, 1) << @intCast(u6, reg);
            if (reg == 0) zeros += 1;
        }
        const alpha = switch (self.m) {
            16 => 0.673,
            32 => 0.697,
            64 => 0.709,
            else => 0.7213 / (1.0 + 1.079 / m_f),
        };
        var estimate = alpha * m_f * m_f / sum;

        // Small range correction (Linear Counting)
        if (estimate <= 5.0 / 2.0 * m_f) {
            if (zeros != 0) {
                estimate = m_f * @log(@intToFloat(f64, self.m) / @intToFloat(f64, zeros));
            }
        } else {
            // Large range correction
            const two64 = @intToFloat(f64, @as(u128, 1) << 64);
            if (estimate > (1.0 / 30.0) * two64) {
                estimate = -two64 * @log(1.0 - estimate / two64);
            }
        }
        return estimate;
    }
};
