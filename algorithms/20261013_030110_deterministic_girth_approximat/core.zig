const std = @import("std");

pub const EdgeInfo = struct {
    u: usize,
    v: usize,
    weight: f64,
};

pub const AdjEdge = struct {
    to: usize,
    weight: f64,
    idx: usize, // index into edge list
};

pub const Graph = struct {
    allocator: *std.mem.Allocator,
    n: usize,
    adj: []std.ArrayList(AdjEdge), // adjacency list per vertex
    edges: std.ArrayList(EdgeInfo),

    pub fn init(allocator: *std.mem.Allocator, n: usize) !Graph {
        var adj = try allocator.alloc(std.ArrayList(AdjEdge), n);
        var i: usize = 0;
        while (i < n) : (i += 1) {
            adj[i] = std.ArrayList(AdjEdge).init(allocator);
        }
        return Graph{
            .allocator = allocator,
            .n = n,
            .adj = adj,
            .edges = std.ArrayList(EdgeInfo).init(allocator),
        };
    }

    pub fn deinit(self: *Graph) void {
        var i: usize = 0;
        while (i < self.n) : (i += 1) {
            self.adj[i].deinit();
        }
        self.allocator.free(self.adj);
        self.edges.deinit();
    }

    pub fn addEdge(self: *Graph, u: usize, v: usize, weight: f64) !void {
        const idx = self.edges.items.len;
        try self.edges.append(EdgeInfo{ .u = u, .v = v, .weight = weight });
        try self.adj[u].append(AdjEdge{ .to = v, .weight = weight, .idx = idx });
        try self.adj[v].append(AdjEdge{ .to = u, .weight = weight, .idx = idx });
    }

    // Dijkstra from src to dst ignoring edge with index excludeIdx.
    // Returns distance or null if unreachable.
    fn dijkstra(self: *Graph, src: usize, dst: usize, excludeIdx: usize) ?f64 {
        const INF = std.math.inf(f64);
        var dist = try self.allocator.alloc(f64, self.n);
        defer self.allocator.free(dist);
        for (dist) |*d| d.* = INF;
        dist[src] = 0.0;

        const Node = struct {
            node: usize,
            dist: f64,
        };
        const less = struct {
            fn lessThan(a: Node, b: Node) bool {
                return a.dist < b.dist;
            }
        };
        var pq = std.PriorityQueue(Node, less.lessThan).init(self.allocator);
        defer pq.deinit();

        _ = pq.push(Node{ .node = src, .dist = 0.0 }) catch unreachable;

        while (!pq.empty()) {
            const cur = pq.pop() catch unreachable;
            if (cur.dist > dist[cur.node]) continue; // stale entry
            if (cur.node == dst) return cur.dist;
            const list = self.adj[cur.node];
            for (list.items) |e| {
                if (e.idx == excludeIdx) continue; // skip excluded edge
                const ndist = cur.dist + e.weight;
                if (ndist < dist[e.to]) {
                    dist[e.to] = ndist;
                    _ = pq.push(Node{ .node = e.to, .dist = ndist }) catch unreachable;
                }
            }
        }
        return null;
    }

    // Deterministic girth approximation (exact for weighted undirected graphs).
    // Returns null if graph is acyclic.
    pub fn girth(self: *Graph) ?f64 {
        var best: ?f64 = null;
        const edgeCount = self.edges.items.len;
        var i: usize = 0;
        while (i < edgeCount) : (i += 1) {
            const e = self.edges.items[i];
            // shortest path between e.u and e.v without using edge i
            const d = self.dijkstra(e.u, e.v, i);
            if (d) |dist| {
                const cycleLen = dist + e.weight;
                if (best) |b| {
                    if (cycleLen < b) best = cycleLen;
                } else {
                    best = cycleLen;
                }
            }
        }
        return best;
    }
};
