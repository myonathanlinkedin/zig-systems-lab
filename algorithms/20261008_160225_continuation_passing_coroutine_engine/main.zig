const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // ---------- Test 1: Basic aggregation ----------
    {
        var profiler = core.Profiler.init(allocator);
        defer profiler.deinit();

        // Sample 1: time 0..10, stack [1,2,3]
        try profiler.startSample(0, &[_]u32{1, 2, 3});
        profiler.endSample(10);

        // Sample 2: time 10..20, stack [1,2]
        try profiler.startSample(10, &[_]u32{1, 2});
        profiler.endSample(20);

        const agg = try profiler.aggregate(allocator);
        defer allocator.free(agg);

        // Helper to find entry by func_id
        fn find(agg: []core.Aggregated, id: u32) ?core.Aggregated {
            for (agg) |e| if (e.func_id == id) return e;
            return null;
        }

        const e1 = find(agg, 1) orelse unreachable;
        const e2 = find(agg, 2) orelse unreachable;
        const e3 = find(agg, 3) orelse unreachable;

        std.debug.assert(e1.inclusive == 20);
        std.debug.assert(e1.exclusive == 0);
        std.debug.assert(e2.inclusive == 20);
        std.debug.assert(e2.exclusive == 10);
        std.debug.assert(e3.inclusive == 10);
        std.debug.assert(e3.exclusive == 10);
    }

    // ---------- Test 2: Overlapping timestamps ----------
    {
        var profiler = core.Profiler.init(allocator);
        defer profiler.deinit();

        // Sample A: 0..5, stack [4]
        try profiler.startSample(0, &[_]u32{4});
        profiler.endSample(5);

        // Sample B: 3..8, stack [4,5]
        try profiler.startSample(3, &[_]u32{4, 5});
        profiler.endSample(8);

        const agg = try profiler.aggregate(allocator);
        defer allocator.free(agg);

        fn find(agg: []core.Aggregated, id: u32) ?core.Aggregated {
            for (agg) |e| if (e.func_id == id) return e;
            return null;
        }

        const e4 = find(agg, 4) orelse unreachable;
        const e5 = find(agg, 5) orelse unreachable;

        // Duration A = 5, Duration B = 5
        // Inclusive for 4 = 5 + 5 = 10
        // Exclusive for 4 = 5 (from A) + 0 (from B, leaf is 5) = 5
        // Inclusive for 5 = 5, Exclusive for 5 = 5
        std.debug.assert(e4.inclusive == 10);
        std.debug.assert(e4.exclusive == 5);
        std.debug.assert(e5.inclusive == 5);
        std.debug.assert(e5.exclusive == 5);
    }

    // ---------- Test 3: Empty stack handling ----------
    {
        var profiler = core.Profiler.init(allocator);
        defer profiler.deinit();

        // Sample with empty stack should be ignored.
        try profiler.startSample(0, &[_]u32{});
        profiler.endSample(10);

        const agg = try profiler.aggregate(allocator);
        defer allocator.free(agg);
        std.debug.assert(agg.len == 0);
    }

    // All tests passed.
    std.debug.print("All profiler unit tests passed.\n", .{});
    return;
}
