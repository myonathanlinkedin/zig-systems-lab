const std = @import("std");

pub const Edge = struct {
    u: usize,
    v: usize,
};

pub const Graph = struct {
    n: usize,
    // adjacency list: each vertex has an ArrayList of neighbor indices
    adj: []std.ArrayList(usize),

    pub fn init(allocator: *std.mem.Allocator, n: usize) !Graph {
        var adj = try allocator.alloc(std.ArrayList(usize), n);
        var i: usize = 0;
        while (i < n) : (i += 1) {
            adj[i] = std.ArrayList(usize).init(allocator);
        }
        return Graph{ .n = n, .adj = adj };
    }

    pub fn deinit(self: *Graph) void {
        var i: usize = 0;
        while (i < self.n) : (i += 1) {
            self.adj[i].deinit();
        }
        self.adj[0].allocator.free(self.adj);
    }

    pub fn addEdge(self: *Graph, u: usize, v: usize) !void {
        std.debug.assert(u < self.n and v < self.n);
        try self.adj[u].append(v);
        try self.adj[v].append(u);
    }

    // Compute degeneracy ordering and degeneracy value.
    // Returns (ordering, degeneracy). Ordering is removal order (first removed first).
    pub fn degeneracy(self: *Graph, allocator: *std.mem.Allocator) !struct {
        ordering: std.ArrayList(usize),
        degeneracy: usize,
    } {
        const maxDeg = self.n; // degree cannot exceed n-1
        var buckets = try allocator.alloc(std.ArrayList(usize), maxDeg + 1);
        defer allocator.free(buckets);
        var i: usize = 0;
        while (i <= maxDeg) : (i += 1) {
            buckets[i] = std.ArrayList(usize).init(allocator);
        }

        var degree = try allocator.alloc(usize, self.n);
        defer allocator.free(degree);
        var removed = try allocator.alloc(bool, self.n);
        defer allocator.free(removed);
        for (i = 0; i < self.n; i += 1) {
            degree[i] = self.adj[i].len;
            removed[i] = false;
            try buckets[degree[i]].append(i);
        }

        var ordering = std.ArrayList(usize).init(allocator);
        var currentMin: usize = 0;
        var maxSeenDeg: usize = 0;

        var remaining = self.n;
        while (remaining > 0) : (remaining -= 1) {
            // find non‑empty bucket
            while (currentMin <= maxDeg and buckets[currentMin].len == 0) : (currentMin += 1) {}
            std.debug.assert(currentMin <= maxDeg);
            const v = buckets[currentMin].pop();
            removed[v] = true;
            try ordering.append(v);
            if (currentMin > maxSeenDeg) maxSeenDeg = currentMin;

            // decrease degree of neighbors still present
            for (self.adj[v].items) |nbr| {
                if (removed[nbr]) continue;
                const oldDeg = degree[nbr];
                const newDeg = oldDeg - 1;
                degree[nbr] = newDeg;
                // move nbr from old bucket to new bucket
                // remove from old bucket: linear search (acceptable for dense graphs)
                var idx: usize = 0;
                while (idx < buckets[oldDeg].len) : (idx += 1) {
                    if (buckets[oldDeg].items[idx] == nbr) {
                        // swap‑remove
                        buckets[oldDeg].items[idx] = buckets[oldDeg].pop();
                        break;
                    }
                }
                try buckets[newDeg].append(nbr);
                if (newDeg < currentMin) currentMin = newDeg;
            }
        }

        // reverse ordering to obtain degeneracy ordering (optional)
        // we keep removal order as is; degeneracy value is maxSeenDeg.
        return .{ .ordering = ordering, .degeneracy = maxSeenDeg };
    }

    // Exact arboricity via degeneracy: a = ceil((d+1)/2) = (d+2)/2 integer division.
    pub fn arboricity(self: *Graph, allocator: *std.mem.Allocator) !usize {
        const res = try self.degeneracy(allocator);
        const d = res.degeneracy;
        return (d + 2) / 2;
    }

    // Constructive decomposition into at most a forests.
    // Returns an array of forests, each forest is an ArrayList(Edge).
    pub fn decomposeIntoForests(self: *Graph, allocator: *std.mem.Allocator) ![][]Edge {
        const a = try self.arboricity(allocator);
        // allocate forest edge containers
        var forests = try allocator.alloc(std.ArrayList(Edge), a);
        defer {
            // caller will deinit forests; we only free the slice here
        }
        var i: usize = 0;
        while (i < a) : (i += 1) {
            forests[i] = std.ArrayList(Edge).init(allocator);
        }

        // Union‑Find per forest
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
                // path compression
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

        var ufList = try allocator.alloc(UF, a);
        defer {
            for (ufList) |*uf| uf.deinit(allocator);
            allocator.free(ufList);
        }
        for (ufList) |*uf| {
            uf.* = try UF.init(allocator, self.n);
        }

        // iterate over each undirected edge once (u < v)
        for (self.adj) |neighbors, u| {
            for (neighbors.items) |v| {
                if (v <= u) continue;
                const e = Edge{ .u = u, .v = v };
                var placed = false;
                var fIdx: usize = 0;
                while (fIdx < a) : (fIdx += 1) {
                    const uf = &ufList[fIdx];
                    if (uf.find(e.u) != uf.find(e.v)) {
                        try forests[fIdx].append(e);
                        uf.union(e.u, e.v);
                        placed = true;
                        break;
                    }
                }
                // In theory, placement always succeeds because a >= arboricity.
                std.debug.assert(placed);
            }
        }

        // Convert to slice of slices for return
        var result = try allocator.alloc([]Edge, a);
        for (i = 0; i < a; i += 1) {
            result[i] = forests[i].items;
        }
        // Caller must deinit each forest's ArrayList and free result slice.
        return result;
    }
};
