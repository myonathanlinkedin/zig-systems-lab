const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    try runTests();
}

fn runTests() !void {
    const allocator = std.heap.page_allocator;

    // Helper to compare two slices
    fn assertSlicesEqual(comptime T: type, a: []const T, b: []const T) void {
        std.debug.assert(a.len == b.len);
        var i: usize = 0;
        while (i < a.len) : (i += 1) {
            std.debug.assert(a[i] == b[i]);
        }
    }

    // Build a small multimodal graph
    var g = try core.Graph.init(&allocator, 5);
    defer g.deinit();

    // edges: 0-1 (Walk 5), 0-2 (Bike 2), 1-3 (Car 1), 2-3 (Walk 4), 3-4 (Train 3), 1-4 (Bus 10)
    try g.addEdge(0, 1, 5.0, .Walk);
    try g.addEdge(0, 2, 2.0, .Bike);
    try g.addEdge(1, 3, 1.0, .Car);
    try g.addEdge(2, 3, 4.0, .Walk);
    try g.addEdge(3, 4, 3.0, .Train);
    try g.addEdge(1, 4, 10.0, .Bus);

    // Test 1: all modes allowed, shortest path 0->2->3->4 (2+4+3 = 9)
    const allModes = &[_]core.Mode{ .Walk, .Bike, .Car, .Train, .Bus };
    const path1 = try g.shortestPath(0, 4, allModes) orelse {
        std.debug.assert(false);
        unreachable;
    };
    defer allocator.free(path1);
    assertSlicesEqual(usize, path1, &[_]usize{0, 2, 3, 4});

    // Test 2: disallow Bike, must go 0->1->3->4 (5+1+3 = 9)
    const noBike = &[_]core.Mode{ .Walk, .Car, .Train, .Bus };
    const path2 = try g.shortestPath(0, 4, noBike) orelse {
        std.debug.assert(false);
        unreachable;
    };
    defer allocator.free(path2);
    assertSlicesEqual(usize, path2, &[_]usize{0, 1, 3, 4});

    // Test 3: disallow Walk and Bike, only Car/Train/Bus allowed -> 0 cannot leave, unreachable
    const onlyMotor = &[_]core.Mode{ .Car, .Train, .Bus };
    const maybe = try g.shortestPath(0, 4, onlyMotor);
    std.debug.assert(maybe == null);

    // Test 4: source equals destination
    const pathSelf = try g.shortestPath(2, 2, allModes) orelse {
        std.debug.assert(false);
        unreachable;
    };
    defer allocator.free(pathSelf);
    assertSlicesEqual(usize, pathSelf, &[_]usize{2});

    // Test 5: larger graph sanity (random but deterministic)
    // Build a line graph 0-1-2-...-9 with weight 1, mode Walk
    var g2 = try core.Graph.init(&allocator, 10);
    defer g2.deinit();
    var i: usize = 0;
    while (i < 9) : (i += 1) {
        try g2.addEdge(i, i + 1, 1.0, .Walk);
        try g2.addEdge(i + 1, i, 1.0, .Walk);
    }
    const pathLine = try g2.shortestPath(0, 9, &[_]core.Mode{.Walk}) orelse {
        std.debug.assert(false);
        unreachable;
    };
    defer allocator.free(pathLine);
    std.debug.assert(pathLine.len == 10);
    std.debug.assert(pathLine[0] == 0 and pathLine[9] == 9);
}
