const std = @import("std");

pub const LiveRange = struct {
    var_id: usize,
    start: usize,
    end: usize,
};

pub const InterferenceGraph = struct {
    /// adjacency list: for each variable id, a list of neighbor ids
    adj: []std.ArrayList(usize),

    pub fn init(allocator: *std.mem.Allocator, var_count: usize) !InterferenceGraph {
        var adj = try allocator.alloc(std.ArrayList(usize), var_count);
        var i: usize = 0;
        while (i < var_count) : (i += 1) {
            adj[i] = std.ArrayList(usize).init(allocator);
        }
        return InterferenceGraph{ .adj = adj };
    }

    pub fn deinit(self: *InterferenceGraph) void {
        for (self.adj) |*list| {
            list.deinit();
        }
        self.adj[0].allocator.free(self.adj);
    }

    pub fn addEdge(self: *InterferenceGraph, a: usize, b: usize) !void {
        // undirected edge, avoid duplicates
        if (!self.hasEdge(a, b)) {
            try self.adj[a].append(b);
            try self.adj[b].append(a);
        }
    }

    fn hasEdge(self: *InterferenceGraph, a: usize, b: usize) bool {
        for (self.adj[a].items) |nbr| {
            if (nbr == b) return true;
        }
        return false;
    }
};

/// Build an interference graph from a slice of live ranges.
/// Assumes variable ids are dense from 0..N-1.
pub fn buildGraph(allocator: *std.mem.Allocator, ranges: []const LiveRange) !InterferenceGraph {
    // Determine number of variables
    var max_id: usize = 0;
    for (ranges) |r| {
        if (r.var_id > max_id) max_id = r.var_id;
    }
    const var_count = max_id + 1;
    var graph = try InterferenceGraph.init(allocator, var_count);

    // O(n^2) edge detection
    for (ranges) |ra, i| {
        for (ranges) |rb, j| {
            if (i >= j) continue;
            if (ra.var_id == rb.var_id) continue;
            // Overlap if intervals intersect (inclusive)
            if (!(ra.end < rb.start or rb.end < ra.start)) {
                try graph.addEdge(ra.var_id, rb.var_id);
            }
        }
    }
    return graph;
}

/// Greedy coloring of the interference graph.
/// Returns a slice where index = var_id and value = register number.
pub fn allocateRegisters(allocator: *std.mem.Allocator, graph: *InterferenceGraph) ![]usize {
    const var_count = graph.adj.len;
    var colors = try allocator.alloc(usize, var_count);
    // Initialize with sentinel
    for (colors) |*c| c.* = std.math.maxInt(usize);

    // Simple ordering: natural order
    for (0..var_count) |v| {
        // Determine used colors among neighbors
        var used = std.AutoHashMap(usize, void).init(allocator);
        defer used.deinit();

        for (graph.adj[v].items) |nbr| {
            const col = colors[nbr];
            if (col != std.math.maxInt(usize)) {
                _ = used.put(col, {});
            }
        }

        // Find smallest non‑used color
        var reg: usize = 0;
        while (used.contains(reg)) : (reg += 1) {}
        colors[v] = reg;
    }
    return colors;
}
