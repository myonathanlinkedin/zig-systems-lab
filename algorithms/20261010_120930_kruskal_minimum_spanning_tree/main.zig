const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    // Test 1: Empty graph (n = 0)
    {
        const n: usize = 0;
        const edges: []types.Edge = &[_]types.Edge{};
        const result = try engine.kruskal(allocator, n, edges);
        std.debug.assert(result.total_weight == 0);
        std.debug.assert(result.edges.len == 0);
    }

    // Test 2: Single vertex, no edges
    {
        const n: usize = 1;
        const edges: []types.Edge = &[_]types.Edge{};
        const result = try engine.kruskal(allocator, n, edges);
        std.debug.assert(result.total_weight == 0);
        std.debug.assert(result.edges.len == 0);
    }

    // Test 3: Simple triangle graph
    // Vertices: 0,1,2
    // Edges: (0-1, weight 1), (1-2, weight 2), (0-2, weight 3)
    {
        const n: usize = 3;
        var edge_buf = [_]types.Edge{
            .{ .u = 0, .v = 1, .weight = 1 },
            .{ .u = 1, .v = 2, .weight = 2 },
            .{ .u = 0, .v = 2, .weight = 3 },
        };
        const result = try engine.kruskal(allocator, n, edge_buf[0..]);
        std.debug.assert(result.total_weight == 3); // 1 + 2
        std.debug.assert(result.edges.len == 2);
        // Verify that the selected edges are the two smallest and form a tree
        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();
        for (result.edges) |e| {
            std.debug.assert(e.weight == 1 or e.weight == 2);
            // Ensure no duplicate vertices in the edge set beyond tree property
            // (just a sanity check)
            _ = seen.put(e.u, {}) catch {};
            _ = seen.put(e.v, {}) catch {};
        }
    }

    // Test 4: Disconnected graph (should raise error)
    {
        const n: usize = 3;
        var edge_buf = [_]types.Edge{
            .{ .u = 0, .v = 1, .weight = 5 },
            // Vertex 2 is isolated
        };
        const result = engine.kruskal(allocator, n, edge_buf[0..]);
        std.debug.assert(result catch |e| {
            // Expect DisconnectedGraph error
            return e == types.KruskalError.DisconnectedGraph;
        } == true);
    }

    // Test 5: Larger graph
    {
        const n: usize = 5;
        var edge_buf = [_]types.Edge{
            .{ .u = 0, .v = 1, .weight = 10 },
            .{ .u = 0, .v = 2, .weight = 6 },
            .{ .u = 0, .v = 3, .weight = 5 },
            .{ .u = 1, .v = 3, .weight = 15 },
            .{ .u = 2, .v = 3, .weight = 4 },
            .{ .u = 1, .v = 2, .weight = 25 },
        };
        const result = try engine.kruskal(allocator, n, edge_buf[0..]);
        // Expected MST edges: (2-3,4), (0-3,5), (0-2,6), (0-1,10) total = 25
        std.debug.assert(result.total_weight == 25);
        std.debug.assert(result.edges.len == 4);
    }

    // Clean up allocator
    const leak_check = gpa.deinit();
    std.debug.assert(leak_check == .ok);
}
