const std = @import("std");
const Pool = @import("engine.zig").Pool;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    const block_size: usize = 32;
    const block_count: usize = 10;

    var pool = try Pool.init(allocator, block_size, block_count);
    defer pool.deinit(allocator);

    var allocated = std.ArrayList(*u8).init(allocator);
    defer allocated.deinit();

    // Allocate all blocks
    var i: usize = 0;
    while (i < block_count) : (i += 1) {
        const ptr = pool.allocate();
        std.debug.assert(ptr != null);
        try allocated.append(ptr.?);
    }

    // Next allocation should be null
    std.debug.assert(pool.allocate() == null);

    // Deallocate one block
    const freed = allocated.pop();
    pool.deallocate(freed);

    // Allocate again, should get same pointer
    const ptr2 = pool.allocate();
    std.debug.assert(ptr2 != null);
    std.debug.assert(ptr2.? == freed);

    // Allocate remaining blocks
    while (allocated.items.len < block_count) {
        const p = pool.allocate();
        std.debug.assert(p != null);
        try allocated.append(p.?);
    }

    // All blocks allocated again
    std.debug.assert(pool.allocate() == null);

    // Clean up
    for (allocated.items) |p| {
        pool.deallocate(p);
    }

    // After deallocating all, allocate again
    var count: usize = 0;
    while (true) {
        const p = pool.allocate();
        if (p == null) break;
        count += 1;
    }
    std.debug.assert(count == block_count);
}
