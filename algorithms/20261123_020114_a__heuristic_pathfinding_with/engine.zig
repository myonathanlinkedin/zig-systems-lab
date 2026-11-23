const std = @import("std");
const types = @import("types.zig");

pub const INF_COST: u32 = std.math.maxInt(u32);

fn heuristic(a: types.Point, b: types.Point) u32 {
    const dx = std.math.absDiff(a.x, b.x);
    const dy = std.math.absDiff(a.y, b.y);
    return @intCast(u32, dx + dy);
}

fn lessThan(_: void, a: OpenNode, b: OpenNode) bool {
    if (a.fScore != b.fScore) return a.fScore < b.fScore;
    if (a.pos.x != b.pos.x) return a.pos.x < b.pos.x;
    return a.pos.y < b.pos.y;
}

const OpenNode = struct {
    fScore: u32,
    pos: types.Point,
};

pub fn findPath(
    allocator: *std.mem.Allocator,
    grid: types.Grid,
    start: types.Point,
    goal: types.Point,
) !?[]types.Point {
    // Trivial case
    if (start.x == goal.x and start.y == goal.y) {
        var single = try allocator.alloc(types.Point, 1);
        single[0] = start;
        return single;
    }

    const size = grid.width * grid.height;
    var gScore = try allocator.alloc(u32, size);
    defer allocator.free(gScore);
    var cameFrom = try allocator.alloc(?types.Point, size);
    defer allocator.free(cameFrom);

    for (gScore) |*s| s.* = INF_COST;
    for (cameFrom) |*c| c.* = null;

    const startIdx = grid.index(start.x, start.y);
    gScore[startIdx] = 0;

    var openSet = std.PriorityQueue(OpenNode).init(allocator, {}, lessThan);
    defer openSet.deinit();

    try openSet.add(OpenNode{
        .fScore = heuristic(start, goal),
        .pos = start,
    });

    const dirs = [_][2]usize{
        .{ 1, 0 },
        .{ -1, 0 },
        .{ 0, 1 },
        .{ 0, -1 },
    };

    while (!openSet.isEmpty()) {
        const currentNode = openSet.remove();
        const cur = currentNode.pos;

        if (cur.x == goal.x and cur.y == goal.y) {
            // Reconstruct path
            var revPath = std.ArrayList(types.Point).init(allocator);
            defer revPath.deinit();

            var step = goal;
            while (true) {
                try revPath.append(step);
                if (step.x == start.x and step.y == start.y) break;
                const idx = grid.index(step.x, step.y);
                const maybePrev = cameFrom[idx];
                if (maybePrev) |prev| {
                    step = prev;
                } else {
                    break; // Should not happen
                }
            }

            const len = revPath.items.len;
            var result = try allocator.alloc(types.Point, len);
            for (revPath.items) |p, i| {
                result[len - 1 - i] = p;
            }
            return result;
        }

        const curIdx = grid.index(cur.x, cur.y);
        const curG = gScore[curIdx];

        for (dirs) |d| {
            const nx = cur.x + d[0];
            const ny = cur.y + d[1];
            if (!grid.inBounds(nx, ny)) continue;

            const cost = grid.getCost(nx, ny);
            if (cost == INF_COST) continue; // blocked cell

            const tentativeG = curG + cost;
            const neighborIdx = grid.index(nx, ny);
            if (tentativeG < gScore[neighborIdx]) {
                cameFrom[neighborIdx] = cur;
                gScore[neighborIdx] = tentativeG;
                const fScore = tentativeG + heuristic(types.Point{ .x = nx, .y = ny }, goal);
                try openSet.add(OpenNode{
                    .fScore = fScore,
                    .pos = types.Point{ .x = nx, .y = ny },
                });
            }
        }
    }

    // No path found
    return null;
}
