const std = @import("std");
const AetherCache = @import("engine.zig").AetherCache;

pub fn main() !void {
    var cache = AetherCache(u32, 8).init();

    // Fill to capacity-1 (ring buffer leaves one slot empty to distinguish full/empty)
    var i: u32 = 0;
    while (i < 7) : (i += 1) {
        const ok = cache.add(i);
        std.debug.assert(ok);
    }

    // Next insertion must fail because buffer is logically full
    std.debug.assert(!cache.add(999));

    // Verify state
    std.debug.assert(cache.len() == 7);
    std.debug.assert(!cache.isEmpty());
    std.debug.assert(!cache.isFull()); // still not "full" due to empty slot rule

    // Consume in FIFO order
    i = 0;
    while (i < 7) : (i += 1) {
        const val = cache.consume() orelse unreachable;
        std.debug.assert(val == i);
    }

    // Buffer should now be empty
    std.debug.assert(cache.isEmpty());
    std.debug.assert(cache.consume() == null);

    // Test wrap‑around behavior after emptying
    i = 100;
    while (i < 107) : (i += 1) {
        std.debug.assert(cache.add(i));
    }

    i = 100;
    while (i < 107) : (i += 1) {
        const val = cache.consume() orelse unreachable;
        std.debug.assert(val == i);
    }

    std.debug.print("All tests passed\n", .{});
}
