const std = @import("std");
const types = @import("types");

pub const BitMask = types.BitMask;
pub const OracleFn = types.OracleFn;

/// Implements Queyranne's algorithm for symmetric submodular minimization.
/// Returns a non‑empty, non‑full subset mask that minimizes the oracle value.
pub fn symmetricSubmodularMinimize(comptime n: usize, oracle: OracleFn) BitMask {
    // Preconditions
    std.debug.assert(n >= 2);
    std.debug.assert(n <= 64);

    // Initial partition: each element is its own set.
    var sets = std.ArrayList(BitMask).init(std.heap.page_allocator);
    defer sets.deinit();

    for (0..n) |i| {
        sets.append(types.BitSet.singleton(i)) catch unreachable;
    }

    var best_mask: BitMask = 0;
    var best_value: f64 = std.math.inf(f64);

    // Helper to evaluate and possibly update best solution.
    const consider = struct {
        fn call(mask: BitMask) void {
            if (types.BitSet.isEmpty(mask) or types.BitSet.isFull(mask, n)) return;
            const val = oracle(mask);
            if (val < best_value) {
                best_value = val;
                best_mask = mask;
            }
        }
    }.call;

    // Main loop of Queyranne's algorithm.
    while (sets.items.len > 1) : (sets.shrinkAndFree()) {
        // Choose arbitrary start element.
        const start = sets.items[0];
        var S = start;
        var order = std.ArrayList(usize).init(std.heap.page_allocator);
        defer order.deinit();

        // Maintain a list of indices of remaining sets.
        var remaining = std.ArrayList(usize).init(std.heap.page_allocator);
        defer remaining.deinit();
        for (0..sets.items.len) |idx| {
            if (sets.items[idx] != start) remaining.append(idx) catch unreachable;
        }

        // Greedy construction of ordering.
        while (remaining.items.len > 0) {
            var best_idx: usize = undefined;
            var best_gain: f64 = std.math.inf(f64);

            for (remaining.items) |idx| {
                const candidate = S | sets.items[idx];
                const gain = oracle(candidate) - oracle(S);
                if (gain < best_gain) {
                    best_gain = gain;
                    best_idx = idx;
                }
            }

            // Add chosen set to S.
            S |= sets.items[best_idx];
            order.append(best_idx) catch unreachable;

            // Remove chosen index from remaining.
            var i: usize = 0;
            while (i < remaining.items.len) : (i += 1) {
                if (remaining.items[i] == best_idx) {
                    _ = remaining.swapRemove(i);
                    break;
                }
            }
        }

        // The last added set is t, the second last is s.
        const t_idx = order.items[order.items.len - 1];
        const s_idx = if (order.items.len >= 2) order.items[order.items.len - 2] else start_idx: {
            // When only one element was added, s is the start set.
            break :start_idx 0;
        };

        // Consider the cut defined by S (which is the union of all added sets).
        consider(S);

        // Merge s and t into a new set.
        const merged = sets.items[s_idx] | sets.items[t_idx];
        // Remove larger index first to keep indices valid.
        const max_idx = if (s_idx > t_idx) s_idx else t_idx;
        const min_idx = if (s_idx > t_idx) t_idx else s_idx;
        _ = sets.swapRemove(max_idx);
        _ = sets.swapRemove(min_idx);
        sets.append(merged) catch unreachable;
    }

    // Edge case: if algorithm never updated best_mask (e.g., all cuts equal),
    // return any non‑trivial subset (first singleton).
    if (best_mask == 0) {
        best_mask = types.BitSet.singleton(0);
    }

    return best_mask;
}
