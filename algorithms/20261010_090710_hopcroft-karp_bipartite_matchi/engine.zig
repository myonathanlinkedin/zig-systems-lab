const std = @import("std");
const types = @import("types.zig");

pub fn hopcroftKarp(g: types.Graph, allocator: *std.mem.Allocator) !usize {
    const NIL = std.math.maxInt(usize);

    var pairU = try allocator.alloc(usize, g.left);
    defer allocator.free(pairU);
    var pairV = try allocator.alloc(usize, g.right);
    defer allocator.free(pairV);
    var dist = try allocator.alloc(usize, g.left);
    defer allocator.free(dist);

    // initialise matchings to NIL (unmatched)
    for (pairU) |*p| p.* = NIL;
    for (pairV) |*p| p.* = NIL;

    var matching: usize = 0;

    while (bfs(g, pairU, pairV, dist, NIL)) {
        for (0..g.left) |u| {
            if (pairU[u] == NIL) {
                if (dfs(g, u, pairU, pairV, dist, NIL)) {
                    matching += 1;
                }
            }
        }
    }
    return matching;
}

// Breadth‑first search builds distance layers.
// Returns true iff there exists at least one free right‑side vertex reachable from a free left‑side vertex.
fn bfs(g: types.Graph, pairU: []usize, pairV: []usize, dist: []usize, NIL: usize) bool {
    var queue = std.ArrayList(usize).init(std.heap.page_allocator);
    defer queue.deinit();

    const INF = std.math.maxInt(usize);

    for (0..g.left) |u| {
        if (pairU[u] == NIL) {
            dist[u] = 0;
            _ = queue.append(u) catch unreachable;
        } else {
            dist[u] = INF;
        }
    }

    var found = false;
    var i: usize = 0;
    while (i < queue.items.len) : (i += 1) {
        const u = queue.items[i];
        for (g.adj[u]) |v| {
            const pu = pairV[v];
            if (pu == NIL) {
                // an unmatched right vertex is reachable → augmenting path exists
                found = true;
            } else if (dist[pu] == INF) {
                dist[pu] = dist[u] + 1;
                _ = queue.append(pu) catch unreachable;
            }
        }
    }
    return found;
}

// Depth‑first search attempts to find an augmenting path from left vertex u.
// Returns true iff such a path is found and updates pairU / pairV accordingly.
fn dfs(g: types.Graph, u: usize, pairU: []usize, pairV: []usize, dist: []usize, NIL: usize) bool {
    const INF = std.math.maxInt(usize);
    for (g.adj[u]) |v| {
        const pu = pairV[v];
        if (pu == NIL or (dist[pu] == dist[u] + 1 and dfs(g, pu, pairU, pairV, dist, NIL))) {
            pairU[u] = v;
            pairV[v] = u;
            return true;
        }
    }
    // mark u as dead‑end for this phase
    dist[u] = INF;
    return false;
}
