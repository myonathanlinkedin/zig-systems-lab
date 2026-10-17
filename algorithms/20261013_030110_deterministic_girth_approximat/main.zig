const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Test 1: Triangle graph (3-cycle)
    {
        var g = try core.Graph.init(allocator, 3);
        defer g.deinit();

        try g.addEdge(0, 1, 1.0);
        try g.addEdge(1, 2, 1.0);
        try g.addEdge(2, 0, 1.0);

        const girth = g.girth();
        std.debug.assert(girth != null);
        std.debug.assert(girth.? == 3.0);
    }

    // Test 2: Square with diagonal (shortest cycle is triangle)
    {
        var g = try core.Graph.init(allocator, 4);
        defer g.deinit();

        try g.addEdge(0, 1, 1.0);
        try g.addEdge(1, 2, 1.0);
        try g.addEdge(2, 3, 1.0);
        try g.addEdge(3, 0, 1.0);
        try g.addEdge(0, 2, 0.5); // diagonal, creates triangle 0-1-2-0 with length 2.5

        const girth = g.girth();
        std.debug.assert(girth != null);
        // Expected: 0-1 (1) + 1-2 (1) + 0-2 (0.5) = 2.5
        std.debug.assert(std.math.approxEqAbs(f64, girth.?, 2.5, 1e-9));
    }

    // Test 3: Tree (no cycles)
    {
        var g = try core.Graph.init(allocator, 5);
        defer g.deinit();

        try g.addEdge(0, 1, 2.0);
        try g.addEdge(1, 2, 3.0);
        try g.addEdge(2, 3, 4.0);
        try g.addEdge(3, 4, 5.0);

        const girth = g.girth();
        std.debug.assert(girth == null);
    }

    // Test 4: Weighted graph where shortest cycle is not the smallest number of edges
    {
        var g = try core.Graph.init(allocator, 5);
        defer g.deinit();

        try g.addEdge(0, 1, 1.0);
        try g.addEdge(1, 2, 1.0);
        try g.addEdge(2, 0, 5.0); // heavy triangle
        try g.addEdge(2, 3, 1.0);
        try g.addEdge(3, 4, 1.0);
        try g.addEdge(4, 0, 1.0); // creates 0-2-3-4-0 cycle length 5.0

        const girth = g.girth();
        std.debug.assert(girth != null);
        // The lighter cycle is 0-1-2-3-4-0 with total weight 1+1+1+1+1 = 5
        // The heavy triangle is 1+1+5 = 7, so girth should be 5
        std.debug.assert(std.math.approxEqAbs(f64, girth.?, 5.0, 1e-9));
    }

    // All assertions passed
    std.debug.print("All tests passed.\n", .{});
}
