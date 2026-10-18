const std = @import("std");

pub const Mode = enum(u8) {
    Walk,
    Bike,
    Car,
    Train,
    Bus,
};

pub const Edge = struct {
    target: usize,
    weight: f64,
    mode: Mode,
};

pub const Graph = struct {
    allocator: *std.mem.Allocator,
    adjacency: []std.ArrayList(Edge),

    pub fn init(allocator: *std.mem.Allocator, node_count: usize) !Graph {
        var list = try allocator.alloc(std.ArrayList(Edge), node_count);
        var i: usize = 0;
        while (i < node_count) : (i += 1) {
            list[i] = std.ArrayList(Edge).init(allocator);
        }
        return Graph{
            .allocator = allocator,
            .adjacency = list,
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.adjacency) |*list| {
            list.deinit();
        }
        self.allocator.free(self.adjacency);
    }

    pub fn addEdge(self: *Graph, src: usize, dst: usize, weight: f64, mode: Mode) !void {
        try self.adjacency[src].append(Edge{
            .target = dst,
            .weight = weight,
            .mode = mode,
        });
    }

    // Dijkstra returning optional path (null if unreachable)
    pub fn shortestPath(self: *Graph, src: usize, dst: usize, allowed: []const Mode) !?[]usize {
        const n = self.adjacency.len;
        const INF = std.math.inf(f64);
        var dist = try self.allocator.alloc(f64, n);
        var prev = try self.allocator.alloc(usize, n);
        defer {
            self.allocator.free(dist);
            self.allocator.free(prev);
        }
        for (dist) |*d| d.* = INF;
        for (prev) |*p| p.* = std.math.maxInt(usize);
        dist[src] = 0.0;

        // mode mask for O(1) checks
        var mask: u8 = 0;
        for (allowed) |m| mask |= @as(u8, 1) << @intFromEnum(m);

        const Item = struct {
            node: usize,
            dist: f64,
        };
        const less = struct {
            fn less(a: *const Item, b: *const Item) bool {
                return a.dist < b.dist;
            }
        };
        var pq = std.PriorityQueue(Item, void, less.less).init(self.allocator);
        defer pq.deinit();
        try pq.push(Item{ .node = src, .dist = 0.0 });

        while (!pq.empty()) {
            const cur = pq.pop() catch unreachable;
            if (cur.dist > dist[cur.node]) continue; // stale entry
            if (cur.node == dst) break;
            for (self.adjacency[cur.node].items) |e| {
                const mode_bit = @as(u8, 1) << @intFromEnum(e.mode);
                if ((mask & mode_bit) == 0) continue; // mode not allowed
                const ndist = cur.dist + e.weight;
                if (ndist < dist[e.target]) {
                    dist[e.target] = ndist;
                    prev[e.target] = cur.node;
                    try pq.push(Item{ .node = e.target, .dist = ndist });
                }
            }
        }

        if (dist[dst] == INF) return null;

        // reconstruct path
        var path = std.ArrayList(usize).init(self.allocator);
        defer path.deinit();
        var v = dst;
        while (v != src) {
            try path.append(v);
            const p = prev[v];
            if (p == std.math.maxInt(usize)) break; // should not happen
            v = p;
        }
        try path.append(src);
        // reverse
        var i: usize = 0;
        var j: usize = path.items.len - 1;
        while (i < j) : (i += 1, j -= 1) {
            const tmp = path.items[i];
            path.items[i] = path.items[j];
            path.items[j] = tmp;
        }
        // copy to heap array for return
        const result = try self.allocator.alloc(usize, path.items.len);
        std.mem.copy(usize, result, path.items);
        return result;
    }
};
