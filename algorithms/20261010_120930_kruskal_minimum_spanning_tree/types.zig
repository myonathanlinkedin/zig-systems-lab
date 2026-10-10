const std = @import("std");

pub const Edge = struct {
    u: usize,
    v: usize,
    weight: i64,
};

pub const DSU = struct {
    parent: []usize,
    rank: []usize,

    pub fn init(allocator: *std.mem.Allocator, n: usize) !DSU {
        var parent = try allocator.alloc(usize, n);
        var rank = try allocator.alloc(usize, n);
        for (parent) |*p, i| p.* = i;
        for (rank) |*r| r.* = 0;
        return DSU{
            .parent = parent,
            .rank = rank,
        };
    }

    pub fn deinit(self: *DSU, allocator: *std.mem.Allocator) void {
        allocator.free(self.parent);
        allocator.free(self.rank);
    }

    pub fn find(self: *DSU, x: usize) usize {
        if (self.parent[x] != x) {
            self.parent[x] = self.find(self.parent[x]);
        }
        return self.parent[x];
    }

    pub fn union(self: *DSU, x: usize, y: usize) bool {
        const xr = self.find(x);
        const yr = self.find(y);
        if (xr == yr) return false;

        if (self.rank[xr] < self.rank[yr]) {
            self.parent[xr] = yr;
        } else if (self.rank[xr] > self.rank[yr]) {
            self.parent[yr] = xr;
        } else {
            self.parent[yr] = xr;
            self.rank[xr] += 1;
        }
        return true;
    }
};

pub const MSTResult = struct {
    total_weight: i64,
    edges: []Edge,
};

pub const KruskalError = error{
    DisconnectedGraph,
};
