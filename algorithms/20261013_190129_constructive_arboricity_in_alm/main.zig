const std = @import("std");
const core = @import("core.zig");
const Graph = core.Graph;
const Edge = core.Edge;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Helper to build a graph from edge list
    fn buildGraph(edges: []const [2]usize, n: usize) !Graph {
        var g = try Graph.init(allocator, n);
        for (edges) |e| {
            try g.addEdge(e[0], e[1]);
        }
        return g;
    }

    // Test 1: triangle (K3) -> arboricity 2
    {
        const edges = [_][2]usize{
            .{0,1}, .{1,2}, .{2,0},
        };
        var g = try buildGraph(&edges, 3);
        defer g.deinit();

        const a = try g.arboricity(allocator);
        std.debug.assert(a == 2);

        const forests = try g.decomposeIntoForests(allocator);
        defer {
            for (forests) |f| {
                // each forest is a slice; no need to deinit
                // but underlying ArrayLists were allocated; we free them via g.deinit()
                // (they share the same allocator)
                // nothing extra needed.
                _ = f;
            }
            allocator.free(forests);
        }
        std.debug.assert(forests.len == a);
    }

    // Test 2: complete graph K5 -> arboricity ceil(5/2)=3
    {
        const n = 5;
        var edges = std.ArrayList([2]usize).init(allocator);
        defer edges.deinit();
        var i: usize = 0;
        while (i < n) : (i += 1) {
            var j: usize = i + 1;
            while (j < n) : (j += 1) {
                try edges.append([2]usize{ i, j });
            }
        }
        var g = try buildGraph(edges.items, n);
        defer g.deinit();

        const a = try g.arboricity(allocator);
        std.debug.assert(a == 3);
    }

    // Test 3: tree (path) -> arboricity 1
    {
        const n = 6;
        const edges = [_][2]usize{
            .{0,1}, .{1,2}, .{2,3}, .{3,4}, .{4,5},
        };
        var g = try buildGraph(&edges, n);
        defer g.deinit();

        const a = try g.arboricity(allocator);
        std.debug.assert(a == 1);
    }

    // Test 4: random dense graph, verify decomposition uses ≤ a forests
    {
        const n = 50;
        const prob = 0.5;
        var rng = std.rand.DefaultPrng.init(0xdeadbeef);
        var rand = rng.random();

        var edges = std.ArrayList([2]usize).init(allocator);
        defer edges.deinit();

        var i: usize = 0;
        while (i < n) : (i += 1) {
            var j: usize = i + 1;
            while (j < n) : (j += 1) {
                if (rand.float(f64) < prob) {
                    try edges.append([2]usize{ i, j });
                }
            }
        }

        var g = try buildGraph(edges.items, n);
        defer g.deinit();

        const a = try g.arboricity(allocator);
        const forests = try g.decomposeIntoForests(allocator);
        defer {
            allocator.free(forests);
        }
        std.debug.assert(forests.len == a);
        // Verify each forest is acyclic via Union‑Find
        const UF = struct {
            parent: []usize,
            fn init(allocator: *std.mem.Allocator, n: usize) !UF {
                var p = try allocator.alloc(usize, n);
                for (p) |*ptr, idx| ptr.* = idx;
                return UF{ .parent = p };
            }
            fn deinit(self: *UF, allocator: *std.mem.Allocator) void {
                allocator.free(self.parent);
            }
            fn find(self: *UF, x: usize) usize {
                var root = x;
                while (self.parent[root] != root) : (root = self.parent[root]) {}
                var cur = x;
                while (self.parent[cur] != cur) {
                    const nxt = self.parent[cur];
                    self.parent[cur] = root;
                    cur = nxt;
                }
                return root;
            }
            fn union(self: *UF, a: usize, b: usize) void {
                const ra = self.find(a);
                const rb = self.find(b);
                if (ra != rb) self.parent[ra] = rb;
            }
        };
        var uf = try UF.init(allocator, n);
        defer uf.deinit(allocator);
        for (forests) |edgesSlice| {
            // reset UF
            var k: usize = 0;
            while (k < n) : (k += 1) uf.parent[k] = k;
            for (edgesSlice) |e| {
                std.debug.assert(uf.find(e.u) != uf.find(e.v)); // no cycle
                uf.union(e.u, e.v);
            }
        }
    }

    // All tests passed
    std.debug.print("All tests passed.\\n", .{});
}
