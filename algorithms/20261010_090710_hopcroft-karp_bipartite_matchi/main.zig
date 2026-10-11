const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;

    // ---------- Test 1: empty graph ----------
    {
        const g = types.Graph{
            .left = 0,
            .right = 0,
            .adj = &[_][]usize{},
        };
        const res = try engine.hopcroftKarp(g, &allocator);
        std.debug.assert(res == 0);
    }

    // ---------- Test 2: single edge ----------
    {
        var adj0 = [_]usize{0};
        var adj1 = [_]usize{};
        const adj = [_][]usize{ &adj0, &adj1 };
        const g = types.Graph{
            .left = 2,
            .right = 2,
            .adj = &adj,
        };
        const res = try engine.hopcroftKarp(g, &allocator);
        std.debug.assert(res == 1);
    }

    // ---------- Test 3: complete 3×3 ----------
    {
        var a0 = [_]usize{0, 1, 2};
        var a1 = [_]usize{0, 1, 2};
        var a2 = [_]usize{0, 1, 2};
        const adj = [_][]usize{ &a0, &a1, &a2 };
        const g = types.Graph{
            .left = 3,
            .right = 3,
            .adj = &adj,
        };
        const res = try engine.hopcroftKarp(g, &allocator);
        std.debug.assert(res == 3);
    }

    // ---------- Test 4: asymmetric example ----------
    {
        // left vertices: 0,1,2 ; right vertices: 0,1
        var l0 = [_]usize{0};
        var l1 = [_]usize{0, 1};
        var l2 = [_]usize{1};
        const adj = [_][]usize{ &l0, &l1, &l2 };
        const g = types.Graph{
            .left = 3,
            .right = 2,
            .adj = &adj,
        };
        const res = try engine.hopcroftKarp(g, &allocator);
        std.debug.assert(res == 2);
    }

    // ---------- Test 5: larger graph with perfect matching ----------
    {
        var l0 = [_]usize{1, 3};
        var l1 = [_]usize{0, 2};
        var l2 = [_]usize{1, 3};
        var l3 = [_]usize{2};
        const adj = [_][]usize{ &l0, &l1, &l2, &l3 };
        const g = types.Graph{
            .left = 4,
            .right = 4,
            .adj = &adj,
        };
        const res = try engine.hopcroftKarp(g, &allocator);
        std.debug.assert(res == 4);
    }

    // All assertions passed
    std.debug.print("All Hopcroft‑Karp tests passed.\n", .{});
}
