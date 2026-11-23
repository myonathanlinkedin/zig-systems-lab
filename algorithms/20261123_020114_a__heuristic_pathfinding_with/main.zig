const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Helper to compare two paths (ignoring order)
    fn containsPoint(path: []types.Point, p: types.Point) bool {
        for (path) |pt| {
            if (pt.x == p.x and pt.y == p.y) return true;
        }
        return false;
    }

    // Test 1: Simple clear grid 5x5
    {
        var grid = try types.Grid.init(&allocator, 5, 5, 1);
        defer grid.deinit();

        const start = types.Point{ .x = 0, .y = 0 };
        const goal = types.Point{ .x = 4, .y = 4 };
        const path = try engine.findPath(&allocator, grid, start, goal);
        defer allocator.free(path);

        std.debug.assert(path != null);
        const p = path.?;
        std.debug.assert(p.len > 0);
        std.debug.assert(p[0].x == start.x and p[0].y == start.y);
        std.debug.assert(p[p.len - 1].x == goal.x and p[p.len - 1].y == goal.y);
    }

    // Test 2: Dynamic obstacle cost (high cost cell should be avoided)
    {
        var grid = try types.Grid.init(&allocator, 5, 5, 1);
        defer grid.deinit();

        // Place a high-cost obstacle at (2,2)
        grid.setCost(2, 2, 10);

        const start = types.Point{ .x = 0, .y = 0 };
        const goal = types.Point{ .x = 4, .y = 4 };
        const path = try engine.findPath(&allocator, grid, start, goal);
        defer allocator.free(path);

        std.debug.assert(path != null);
        const p = path.?;
        std.debug.assert(!containsPoint(p, types.Point{ .x = 2, .y = 2 }));
    }

    // Test 3: Start equals goal
    {
        var grid = try types.Grid.init(&allocator, 3, 3, 1);
        defer grid.deinit();

        const start = types.Point{ .x = 1, .y = 1 };
        const goal = start;
        const path = try engine.findPath(&allocator, grid, start, goal);
        defer allocator.free(path);

        std.debug.assert(path != null);
        const p = path.?;
        std.debug.assert(p.len == 1);
        std.debug.assert(p[0].x == start.x and p[0].y == start.y);
    }

    // Test 4: Unreachable goal due to blocked row
    {
        var grid = try types.Grid.init(&allocator, 3, 3, 1);
        defer grid.deinit();

        // Block middle row completely
        for (x: usize = 0; x < grid.width; x += 1) {
            grid.setCost(x, 1, engine.INF_COST);
        }

        const start = types.Point{ .x = 0, .y = 0 };
        const goal = types.Point{ .x = 0, .y = 2 };
        const path = try engine.findPath(&allocator, grid, start, goal);
        // Should be null because no passage
        std.debug.assert(path == null);
    }
}
