const std = @import("std");

pub const Point = struct {
    x: usize,
    y: usize,
};

pub const Grid = struct {
    width: usize,
    height: usize,
    costs: []u32,
    allocator: *std.mem.Allocator,

    pub fn init(
        allocator: *std.mem.Allocator,
        width: usize,
        height: usize,
        default_cost: u32,
    ) !Grid {
        const size = width * height;
        var costs = try allocator.alloc(u32, size);
        for (costs) |*c| c.* = default_cost;
        return Grid{
            .width = width,
            .height = height,
            .costs = costs,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Grid) void {
        self.allocator.free(self.costs);
    }

    pub fn index(self: Grid, x: usize, y: usize) usize {
        return y * self.width + x;
    }

    pub fn getCost(self: Grid, x: usize, y: usize) u32 {
        return self.costs[self.index(x, y)];
    }

    pub fn setCost(self: *Grid, x: usize, y: usize, cost: u32) void {
        self.costs[self.index(x, y)] = cost;
    }

    pub fn inBounds(self: Grid, x: usize, y: usize) bool {
        return x < self.width and y < self.height;
    }
};
