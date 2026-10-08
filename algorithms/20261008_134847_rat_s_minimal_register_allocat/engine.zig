const std = @import("std");
const types = @import("types");

pub const Allocator = std.mem.Allocator;

/// Linear‑scan register allocator that produces a *minimal* number of
/// physical registers for a given set of live intervals.
///
/// The algorithm works as follows:
///   1. Sort intervals by their start point.
///   2. Walk the sorted list, expiring intervals whose end is before the
///      current start and returning their registers to a free‑list.
///   3. Re‑use a register from the free‑list if possible; otherwise allocate
///      a new register identifier.
///   4. Keep the active set sorted by interval end to make expiration cheap.
///
/// The function returns a slice of `types.Allocation` whose length equals the
/// number of input intervals.  The slice is allocated with the supplied
/// allocator and must be freed by the caller.
///
/// The algorithm runs in `O(n log n)` time (dominated by the initial sort)
/// and uses `O(n)` auxiliary space.
pub fn allocate(
    allocator: *Allocator,
    intervals: []const types.Interval,
) ![]types.Allocation {
    // -----------------------------------------------------------------
    // 1. Make a mutable copy and sort by start.
    // -----------------------------------------------------------------
    var sorted = try allocator.dupe(types.Interval, intervals);
    defer allocator.free(sorted);

    const cmpStart = struct {
        fn lessThan(a: types.Interval, b: types.Interval) bool {
            return a.start < b.start;
        }
    }.lessThan;

    std.sort.sort(types.Interval, sorted, {}, cmpStart);

    // -----------------------------------------------------------------
    // 2. Data structures used during the scan.
    // -----------------------------------------------------------------
    // Active intervals, each paired with its assigned register.
    const ActiveEntry = struct {
        interval: types.Interval,
        reg: u32,
    };
    var active = std.ArrayList(ActiveEntry).init(allocator);
    defer active.deinit();

    // Stack of registers that have been freed and can be re‑used.
    var freeRegs = std.ArrayList(u32).init(allocator);
    defer freeRegs.deinit();

    var nextReg: u32 = 0; // next fresh register identifier.

    // Result buffer – we fill it in the order we encounter intervals.
    var result = try allocator.alloc(types.Allocation, intervals.len);
    var resultIdx: usize = 0;

    // -----------------------------------------------------------------
    // 3. Main linear‑scan loop.
    // -----------------------------------------------------------------
    for (sorted) |intv| {
        // ---- Expire old intervals ------------------------------------
        var i: usize = 0;
        while (i < active.items.len) {
            if (active.items[i].interval.end < intv.start) {
                // Interval has finished; its register becomes free.
                try freeRegs.append(active.items[i].reg);
                // Remove the entry efficiently (swap‑remove).
                _ = active.swapRemove(i);
            } else {
                i += 1;
            }
        }

        // ---- Allocate a register --------------------------------------
        var reg: u32 = undefined;
        if (freeRegs.items.len > 0) {
            reg = freeRegs.pop();
        } else {
            reg = nextReg;
            nextReg += 1;
        }

        // ---- Insert the current interval into the active set ----------
        try active.append(.{ .interval = intv, .reg = reg });

        // Keep `active` sorted by interval end to make future expiration
        // checks cheap.  The list is tiny in practice; a full sort is fine.
        const cmpEnd = struct {
            fn lessThan(a: ActiveEntry, b: ActiveEntry) bool {
                return a.interval.end < b.interval.end;
            }
        }.lessThan;
        std.sort.sort(ActiveEntry, active.items, {}, cmpEnd);

        // ---- Record the allocation ------------------------------------
        result[resultIdx] = .{ .id = intv.id, .reg = reg };
        resultIdx += 1;
    }

    // The caller owns `result`.  The temporary buffers are freed by the
    // `defer`s above.
    return result;
}
