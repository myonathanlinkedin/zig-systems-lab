const std = @import("std");
const types = @import("types.zig");

pub fn kruskal(
    allocator: *std.mem.Allocator,
    n: usize,
    edges: []types.Edge,
) !types.MSTResult {
    // Sort edges by weight (ascending)
    const Edge = types.Edge;
    const cmp = struct {
        pub fn lessThan(context: void, a: Edge, b: Edge) bool {
            _ = context;
            return a.weight < b.weight;
        }
    }.lessThan;

    // std.sort.sort works in-place
    std.sort.sort(Edge, edges, {}, cmp);

    var dsu = try types.DSU.init(allocator, n);
    defer dsu.deinit(allocator);

    var mst_edges = try allocator.alloc(Edge, n - 1);
    var mst_count: usize = 0;
    var total_weight: i64 = 0;

    for (edges) |e| {
        if (mst_count == n - 1) break;
        if (dsu.union(e.u, e.v)) {
            mst_edges[mst_count] = e;
            mst_count += 1;
            total_weight += e.weight;
        }
    }

    if (n > 0 and mst_count != n - 1) {
        // Not enough edges to connect all vertices
        allocator.free(mst_edges);
        return types.KruskalError.DisconnectedGraph;
    }

    // Resize slice to actual count (may be zero)
    const final_edges = mst_edges[0..mst_count];
    return types.MSTResult{
        .total_weight = total_weight,
        .edges = final_edges,
    };
}
