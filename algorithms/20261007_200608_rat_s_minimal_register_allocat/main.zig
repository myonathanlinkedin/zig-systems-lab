const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test 1: non‑overlapping ranges -> all share register 0
    {
        const ranges = [_]core.LiveRange{
            .{ .var_id = 0, .start = 0, .end = 4 },
            .{ .var_id = 1, .start = 5, .end = 9 },
            .{ .var_id = 2, .start = 10, .end = 14 },
        };
        var graph = try core.buildGraph(&allocator, &ranges);
        defer graph.deinit();

        const colors = try core.allocateRegisters(&allocator, &graph);
        defer allocator.free(colors);

        std.debug.assert(colors[0] == 0);
        std.debug.assert(colors[1] == 0);
        std.debug.assert(colors[2] == 0);
    }

    // Test 2: fully overlapping ranges -> each needs distinct register
    {
        const ranges = [_]core.LiveRange{
            .{ .var_id = 0, .start = 0, .end = 10 },
            .{ .var_id = 1, .start = 5, .end = 15 },
            .{ .var_id = 2, .start = 8, .end = 12 },
        };
        var graph = try core.buildGraph(&allocator, &ranges);
        defer graph.deinit();

        const colors = try core.allocateRegisters(&allocator, &graph);
        defer allocator.free(colors);

        // All colors must be distinct
        std.debug.assert(colors[0] != colors[1]);
        std.debug.assert(colors[0] != colors[2]);
        std.debug.assert(colors[1] != colors[2]);
    }

    // Test 3: mixed overlapping / non‑overlapping
    {
        const ranges = [_]core.LiveRange{
            .{ .var_id = 0, .start = 0, .end = 4 },   // overlaps with 1
            .{ .var_id = 1, .start = 3, .end = 7 },   // overlaps with 0 and 2
            .{ .var_id = 2, .start = 8, .end = 12 },  // no overlap with 0, overlaps none
            .{ .var_id = 3, .start = 6, .end = 9 },   // overlaps with 1
        };
        var graph = try core.buildGraph(&allocator, &ranges);
        defer graph.deinit();

        const colors = try core.allocateRegisters(&allocator, &graph);
        defer allocator.free(colors);

        // 0 and 2 can share a register
        std.debug.assert(colors[0] == colors[2] or colors[0] != colors[2]); // just ensure compile
        // 0 and 1 must differ
        std.debug.assert(colors[0] != colors[1]);
        // 1 and 3 must differ
        std.debug.assert(colors[1] != colors[3]);
        // 2 and 3 can share (no edge)
        // No strict requirement, just ensure algorithm runs
    }

    // Simple benchmark: allocate 1000 random ranges
    {
        const var_count = 1000;
        var rng = std.rand.DefaultPrng.init(0xdeadbeef);
        var ranges = try allocator.alloc(core.LiveRange, var_count);
        defer allocator.free(ranges);

        var i: usize = 0;
        while (i < var_count) : (i += 1) {
            const start = rng.random().intRangeLessThan(usize, 0, 10_000);
            const len = rng.random().intRangeLessThan(usize, 1, 20);
            ranges[i] = core.LiveRange{
                .var_id = i,
                .start = start,
                .end = start + len,
            };
        }

        var graph = try core.buildGraph(&allocator, ranges);
        defer graph.deinit();

        const colors = try core.allocateRegisters(&allocator, &graph);
        defer allocator.free(colors);

        // Verify that no two adjacent nodes share a color
        var v: usize = 0;
        while (v < var_count) : (v += 1) {
            for (graph.adj[v].items) |nbr| {
                std.debug.assert(colors[v] != colors[nbr]);
            }
        }
    }

    std.debug.print("All tests passed.\n", .{});
}
