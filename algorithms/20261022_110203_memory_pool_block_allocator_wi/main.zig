const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    // Create a buffer large enough for 20 blocks of 32 bytes each.
    var buffer: [1024]u8 = undefined;
    const block_size: usize = 32;
    const num_blocks: usize = 20;

    var pool = core.MemoryPool.init(&buffer, block_size, num_blocks);

    // Allocate all blocks.
    var allocated: [num_blocks]?*u8 = undefined;
    for (allocated) |*slot| {
        slot.* = pool.allocate();
        std.debug.assert(slot.* != null);
    }
    std.debug.assert(pool.used() == num_blocks);
    std.debug.assert(pool.total() == num_blocks);

    // Attempt to allocate one more block; should fail.
    const extra = pool.allocate();
    std.debug.assert(extra == null);

    // Deallocate one block.
    pool.deallocate(allocated[0].?);
    std.debug.assert(pool.used() == num_blocks - 1);

    // Allocate again; should succeed.
    const again = pool.allocate();
    std.debug.assert(again != null);
    std.debug.assert(pool.used() == num_blocks);

    // Verify that all allocated pointers are distinct.
    var seen = std.AutoHashMap(*u8, void).init(std.heap.page_allocator);
    defer seen.deinit();
    for (allocated) |ptr| {
        if (ptr) |p| {
            const res = seen.put(p, {});
            std.debug.assert(res == .ok);
        }
    }

    // Deallocate all blocks.
    for (allocated) |ptr| {
        if (ptr) |p| pool.deallocate(p);
    }
    std.debug.assert(pool.used() == 0);

    // Allocate all blocks again to ensure the pool is reusable.
    for (allocated) |*slot| {
        slot.* = pool.allocate();
        std.debug.assert(slot.* != null);
    }
    std.debug.assert(pool.used() == num_blocks);

    // Clean up: deallocate all again.
    for (allocated) |ptr| {
        if (ptr) |p| pool.deallocate(p);
    }
    std.debug.assert(pool.used() == 0);
}
