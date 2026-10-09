const std = @import("std");
const types = @import("types");
const engine = @import("engine");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // -----------------------------------------------------------------
    // Test case 1 – simple overlapping intervals.
    // -----------------------------------------------------------------
    const intervals1 = [_]types.Interval{
        .{ .id = 0, .start = 0, .end = 4 },
        .{ .id = 1, .start = 2, .end = 6 },
        .{ .id = 2, .start = 5, .end = 7 },
    };

    const alloc1 = try engine.allocate(&allocator, &intervals1);
    defer allocator.free(alloc1);

    // Sort allocations by variable id for deterministic assertions.
    const cmpId = struct {
        fn lessThan(a: types.Allocation, b: types.Allocation) bool {
            return a.id < b.id;
        }
    }.lessThan;
    std.sort.sort(types.Allocation, alloc1, {}, cmpId);

    // Expected mapping:
    //  id 0 → reg 0
    //  id 1 → reg 1
    //  id 2 → reg 0 (re‑used after id 0 expires)
    std.debug.assert(alloc1[0].reg == 0);
    std.debug.assert(alloc1[1].reg == 1);
    std.debug.assert(alloc1[2].reg == 0);

    // Verify that the allocator indeed used only two registers.
    var maxReg: u32 = 0;
    for (alloc1) |a| {
        if (a.reg > maxReg) maxReg = a.reg;
    }
    std.debug.assert(maxReg == 1); // registers are 0‑based, so max 1 ⇒ 2 registers.

    // -----------------------------------------------------------------
    // Test case 2 – nested intervals and zero‑length interval.
    // -----------------------------------------------------------------
    const intervals2 = [_]types.Interval{
        .{ .id = 0, .start = 0, .end = 10 }, // long live range
        .{ .id = 1, .start = 2, .end = 5 },  // nested inside 0
        .{ .id = 2, .start = 5, .end = 5 },  // zero‑length (single point)
        .{ .id = 3, .start = 6, .end = 9 },  // another nested interval
    };

    const alloc2 = try engine.allocate(&allocator, &intervals2);
    defer allocator.free(alloc2);
    std.sort.sort(types.Allocation, alloc2, {}, cmpId);

    // Expected registers:
    //  id 0 → reg 0
    //  id 1 → reg 1
    //  id 2 → reg 1 (re‑used after id 1 expires at 5)
    //  id 3 → reg 1 (re‑used after id 2 expires)
    std.debug.assert(alloc2[0].reg == 0);
    std.debug.assert(alloc2[1].reg == 1);
    std.debug.assert(alloc2[2].reg == 1);
    std.debug.assert(alloc2[3].reg == 1);

    // Minimal registers needed = 2.
    maxReg = 0;
    for (alloc2) |a| {
        if (a.reg > maxReg) maxReg = a.reg;
    }
    std.debug.assert(maxReg == 1);

    // -----------------------------------------------------------------
    // Test case 3 – completely disjoint intervals (should reuse register 0).
    // -----------------------------------------------------------------
    const intervals3 = [_]types.Interval{
        .{ .id = 0, .start = 0, .end = 1 },
        .{ .id = 1, .start = 2, .end = 3 },
        .{ .id = 2, .start = 4, .end = 5 },
    };

    const alloc3 = try engine.allocate(&allocator, &intervals3);
    defer allocator.free(alloc3);
    std.sort.sort(types.Allocation, alloc3, {}, cmpId);

    // All should receive register 0.
    for (alloc3) |a| {
        std.debug.assert(a.reg == 0);
    }

    // Only one register used.
    maxReg = 0;
    for (alloc3) |a| {
        if (a.reg > maxReg) maxReg = a.reg;
    }
    std.debug.assert(maxReg == 0);

    // -----------------------------------------------------------------
    // If we reach this point, all assertions have passed.
    // -----------------------------------------------------------------
    std.debug.print("All register‑allocation tests passed.\n", .{});
}
