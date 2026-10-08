const std = @import("std");
const types = @import("types");
const engine = @import("engine");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Example: symmetric submodular cut function on a weighted undirected graph.
    // Graph with 4 vertices (0..3) and edge weights:
    // 0-1: 1.0, 0-2: 2.0, 0-3: 3.0, 1-2: 4.0, 1-3: 5.0, 2-3: 6.0
    const N = 4;
    const weights: [N][N]f64 = .{
        .{ 0.0, 1.0, 2.0, 3.0 },
        .{ 1.0, 0.0, 4.0, 5.0 },
        .{ 2.0, 4.0, 0.0, 6.0 },
        .{ 3.0, 5.0, 6.0, 0.0 },
    };

    // Oracle for cut weight: sum of edges crossing the cut.
    const cutOracle = struct {
        fn eval(mask: types.BitMask) f64 {
            var sum: f64 = 0.0;
            var i_iter = types.BitSet.iterator(mask);
            while (i_iter.next()) |i| {
                var j_iter = types.BitSet.iterator(~mask & ((types.BitMask(1) << N) - 1));
                while (j_iter.next()) |j| {
                    sum += weights[i][j];
                }
            }
            return sum;
        }
    }.eval;

    // Run Queyranne's algorithm.
    const minMask = engine.symmetricSubmodularMinimize(N, cutOracle);

    // Expected minimum cut for this graph is the singleton {0} with weight 1+2+3 = 6.
    const expectedMask = types.BitSet.singleton(0);
    std.debug.assert(minMask == expectedMask);

    // Additional edge case test: a graph where two vertices have zero crossing weight.
    // Define a graph of 3 vertices where vertex 0 and 1 are disconnected from 2.
    const M = 3;
    const w2: [M][M]f64 = .{
        .{ 0.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 0.0 },
    };

    const zeroOracle = struct {
        fn eval(mask: types.BitMask) f64 {
            // All edges have weight 0, so any non‑trivial cut has value 0.
            _ = mask;
            return 0.0;
        }
    }.eval;

    const minMask2 = engine.symmetricSubmodularMinimize(M, zeroOracle);
    // Should be a non‑empty, non‑full subset; we accept any such subset.
    std.debug.assert(!types.BitSet.isEmpty(minMask2));
    std.debug.assert(!types.BitSet.isFull(minMask2, M));

    // Print results (optional, not required for tests).
    std.debug.print("Minimum cut mask: {b}\n", .{minMask});
    std.debug.print("Second test mask: {b}\n", .{minMask2});
}
