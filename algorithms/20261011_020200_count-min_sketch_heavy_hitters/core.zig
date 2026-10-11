const std = @import("std");

pub const CountMinSketch = struct {
    width: usize,
    depth: usize,
    table: []u64,
    seeds: []u64,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, depth: usize, width: usize) !CountMinSketch {
        // allocate table (depth * width) zero‑initialized
        const table = try allocator.alloc(u64, depth * width);
        for (table) |*cell| cell.* = 0;

        // allocate deterministic seeds, one per row
        var rng = std.rand.DefaultPrng.init(0xDEADBEEF);
        const seeds = try allocator.alloc(u64, depth);
        var i: usize = 0;
        while (i < depth) : (i += 1) {
            seeds[i] = rng.random().int(u64);
        }

        return CountMinSketch{
            .width = width,
            .depth = depth,
            .table = table,
            .seeds = seeds,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CountMinSketch) void {
        self.allocator.free(self.table);
        self.allocator.free(self.seeds);
    }

    // hash a byte slice for a given row using Wyhash with per‑row seed
    fn hash(self: *const CountMinSketch, row: usize, data: []const u8) usize {
        const h = std.hash.Wyhash.hash(data, self.seeds[row]);
        return @intCast(usize, h % @intCast(u64, self.width));
    }

    // increment the counter for `data` by `count`
    pub fn add(self: *CountMinSketch, data: []const u8, count: u64) void {
        var r: usize = 0;
        while (r < self.depth) : (r += 1) {
            const col = self.hash(r, data);
            const idx = r * self.width + col;
            self.table[idx] +%= count; // saturating add (wrap‑around safe for u64)
        }
    }

    // return the estimated frequency of `data`
    pub fn estimate(self: *const CountMinSketch, data: []const u8) u64 {
        var min: u64 = std.math.maxInt(u64);
        var r: usize = 0;
        while (r < self.depth) : (r += 1) {
            const col = self.hash(r, data);
            const idx = r * self.width + col;
            const val = self.table[idx];
            if (val < min) min = val;
        }
        return min;
    }
};
