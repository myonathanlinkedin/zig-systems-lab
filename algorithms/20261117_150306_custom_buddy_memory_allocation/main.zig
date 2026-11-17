const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    // Allocate a static memory pool of exactly 2^MAX_ORDER bytes.
    var memory: [1 << types.MAX_ORDER]u8 = undefined;
    const buffer = memory[0..];

    var allocator = types.BuddyAllocator{
        .buffer = undefined,
        .free_lists = undefined,
    };
    allocator.init(buffer);

    // ---------- Basic allocation tests ----------
    // Allocate 1 byte (should round up to 16 bytes).
    const a1 = try allocator.alloc(1);
    std.debug.assert(a1.len == 1);
    // Write and read back to ensure the slice is usable.
    a1[0] = 0xAA;
    std.debug.assert(a1[0] == 0xAA);

    // Allocate 5000 bytes (requires a 8192‑byte block).
    const a2 = try allocator.alloc(5000);
    std.debug.assert(a2.len == 5000);
    a2[0] = 0x55;
    std.debug.assert(a2[0] == 0x55);

    // Allocate the maximum possible size (just under the whole pool).
    const max_payload = (1 << types.MAX_ORDER) - @sizeOf(types.BlockHeader);
    const a3 = try allocator.alloc(max_payload);
    std.debug.assert(a3.len == max_payload);
    a3[0] = 0xFF;
    std.debug.assert(a3[0] == 0xFF);

    // Free in a different order and re‑allocate to test coalescing.
    allocator.free(a2);
    allocator.free(a1);
    // After freeing a1 and a2, a 16‑byte block and an 8192‑byte block should coalesce
    // up to a 8192‑byte block (since they are not buddies, the allocator will just
    // keep them separate). Allocate a 8000‑byte block to ensure the large block is reused.
    const a4 = try allocator.alloc(8000);
    std.debug.assert(a4.len == 8000);
    a4[0] = 0x77;
    std.debug.assert(a4[0] == 0x77);

    // Free everything.
    allocator.free(a3);
    allocator.free(a4);

    // ---------- Exhaustive allocation/deallocation ----------
    // Allocate many small blocks to fill the pool.
    const small_size = 24; // forces a 32‑byte block (order 5)
    const blocks_needed = (1 << types.MAX_ORDER) / (1 << (types.MIN_ORDER + 5));
    var blocks: [blocks_needed][]u8 = undefined;
    var i: usize = 0;
    while (i < blocks_needed) : (i += 1) {
        blocks[i] = try allocator.alloc(small_size);
        // Fill with a pattern.
        blocks[i][0] = @intCast(u8, i);
    }

    // Verify pattern.
    i = 0;
    while (i < blocks_needed) : (i += 1) {
        std.debug.assert(blocks[i][0] == @intCast(u8, i));
    }

    // Free all blocks.
    i = 0;
    while (i < blocks_needed) : (i += 1) {
        allocator.free(blocks[i]);
    }

    // After full free, we should be able to allocate the whole pool again.
    const whole = try allocator.alloc((1 << types.MAX_ORDER) - @sizeOf(types.BlockHeader));
    std.debug.assert(whole.len == (1 << types.MAX_ORDER) - @sizeOf(types.BlockHeader));
    allocator.free(whole);

    // ---------- Edge cases ----------
    // Zero‑size allocation must error.
    var caught = false;
    allocator.alloc(0) catch |e| {
        caught = true;
        std.debug.assert(e == engine.BuddyError.InvalidSize);
    };
    std.debug.assert(caught);

    // Allocation larger than the pool must error.
    caught = false;
    allocator.alloc((1 << types.MAX_ORDER) + 1) catch |e| {
        caught = true;
        std.debug.assert(e == engine.BuddyError.OutOfMemory);
    };
    std.debug.assert(caught);

    // All tests passed.
    std.debug.print("All buddy allocator tests passed.\n", .{});
}
