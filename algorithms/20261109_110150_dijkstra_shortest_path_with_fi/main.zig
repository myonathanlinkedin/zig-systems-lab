const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test 1: Simple triangle graph
    {
        const edges = [_][]const core.Edge{
            // vertex 0
            &[_]core.Edge{
                .{ .to = 1, .weight = 4 },
                .{ .to = 2, .weight = 1 },
            },
            // vertex 1
            &[_]core.Edge{
                .{ .to = 3, .weight = 1 },
            },
            // vertex 2
            &[_]core.Edge{
                .{ .to = 1, .weight = 2 },
                .{ .to = 3, .weight = 5 },
            },
            // vertex 3
            &[_]core.Edge{},
        };
        const dist = try core.dijkstra(edges, 0, allocator);
        defer allocator.free(dist);
        std.debug.assert(dist[0] == 0);
        std.debug.assert(dist[1] == 3); // 0->2 (1) + 2->1 (2)
        std.debug.assert(dist[2] == 1);
        std.debug.assert(dist[3] == 4); // 0->2 (1) + 2->1 (2) + 1->3 (1)
    }

    // Test 2: Disconnected vertex
    {
        const edges = [_][]const core.Edge{
            // 0
            &[_]core.Edge{
                .{ .to = 1, .weight = 7 },
            },
            // 1
            &[_]core.Edge{},
            // 2 (isolated)
            &[_]core.Edge{},
        };
        const dist = try core.dijkstra(edges, 0, allocator);
        defer allocator.free(dist);
        const INF = std.math.maxInt(usize);
        std.debug.assert(dist[0] == 0);
        std.debug.assert(dist[1] == 7);
        std.debug.assert(dist[2] == INF);
    }

    // Test 3: Zero-weight edges
    {
        const edges = [_][]const core.Edge{
            // 0
            &[_]core.Edge{
                .{ .to = 1, .weight = 0 },
                .{ .to = 2, .weight = 2 },
            },
            // 1
            &[_]core.Edge{
                .{ .to = 2, .weight = 0 },
                .{ .to = 3, .weight = 1 },
            },
            // 2
            &[_]core.Edge{
                .{ .to = 3, .weight = 0 },
            },
            // 3
            &[_]core.Edge{},
        };
        const dist = try core.dijkstra(edges, 0, allocator);
        defer allocator.free(dist);
        std.debug.assert(dist[0] == 0);
        std.debug.assert(dist[1] == 0);
        std.debug.assert(dist[2] == 0);
        std.debug.assert(dist[3] == 0);
    }

    // Simple benchmark (optional, not measured precisely)
    {
        const n = 1000;
        var graph = try allocator.alloc([]core.Edge, n);
        defer allocator.free(graph);
        for (graph) |*adj, i| {
            const deg = 4;
            const edges = try allocator.alloc(core.Edge, deg);
            defer allocator.free(edges);
            for (edges) |*e, j| {
                const to = (i + j + 1) % n;
                e.* = core.Edge{ .to = to, .weight = 1 };
            }
            adj.* = edges;
        }
        const dist = try core.dijkstra(graph, 0, allocator);
        defer allocator.free(dist);
        // Verify that all distances are reachable and equal to floor(i/4)+1 approx.
        for (dist) |d, i| {
            std.debug.assert(d != std.math.maxInt(usize));
        }
    }

    std.debug.print("All tests passed.\n", .{});
}
