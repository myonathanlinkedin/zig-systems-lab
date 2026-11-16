const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;
    defer _ = gpa.deinit();

    // Test 1: basic hit/miss tracking
    var pager = try core.Pager.init(allocator, 3);
    defer pager.deinit(allocator);

    const seq = [_]core.PageId{ 1, 2, 3, 1, 4, 2, 5 };
    var hits: usize = 0;
    var misses: usize = 0;
    for (seq) |p| {
        if (pager.access(p)) hits += 1 else misses += 1;
    }
    std.debug.assert(hits == 2);   // hits on second 1 and second 2
    std.debug.assert(misses == 5);
    std.debug.assert(pager.loadedCount() == 3);

    // Test 2: LRU eviction correctness
    var pager2 = try core.Pager.init(allocator, 2);
    defer pager2.deinit(allocator);

    std.debug.assert(!pager2.access(10)); // miss, load 10
    std.debug.assert(!pager2.access(20)); // miss, load 20
    std.debug.assert(pager2.access(10));  // hit, 10 becomes most recent
    std.debug.assert(!pager2.access(30)); // miss, evicts 20 (LRU)
    std.debug.assert(!pager2.access(20)); // miss, 20 was evicted
    std.debug.assert(pager2.access(10));  // hit
    std.debug.assert(pager2.access(30));  // hit

    std.debug.print("All tests passed\n", .{});
}
