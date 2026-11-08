const std = @import("std");
const engine = @import("engine");

// Define a concrete cache of u32 values with capacity 8 (power of two)
const Cache = engine.AetherCache(u32, 8);

pub fn main() !void {
    var cache = Cache.init();

    // Initially empty
    std.debug.assert(cache.isEmpty());
    std.debug.assert(!cache.isFull());
    std.debug.assert(cache.len() == 0);

    // Insert 8 distinct entries
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const key = @intCast(u64, i);
        const value = @intCast(u32, i * 10);
        cache.insert(key, value);
    }

    // After filling, buffer should be full
    std.debug.assert(cache.isFull());
    std.debug.assert(cache.len() == 8);

    // Verify retrieval of each inserted key
    i = 0;
    while (i < 8) : (i += 1) {
        const key = @intCast(u64, i);
        var out: u32 = undefined;
        const found = cache.get(key, &out);
        std.debug.assert(found);
        std.debug.assert(out == @intCast(u32, i * 10));
    }

    // Insert a new entry; this should overwrite the oldest (key 0)
    cache.insert(100, 999);
    std.debug.assert(cache.isFull());
    std.debug.assert(cache.len() == 8);

    // Key 0 should now be absent
    var dummy: u32 = undefined;
    std.debug.assert(!cache.get(0, &dummy));

    // New key should be retrievable
    std.debug.assert(cache.get(100, &dummy));
    std.debug.assert(dummy == 999);

    // Overwrite multiple times to test circular behavior
    var j: usize = 0;
    while (j < 20) : (j += 1) {
        const k = @intCast(u64, 200 + j);
        const v = @intCast(u32, 5000 + j);
        cache.insert(k, v);
    }
    // After many overwrites, length stays at capacity
    std.debug.assert(cache.len() == 8);
    std.debug.assert(cache.isFull());

    // Spot‑check that the most recent key is present
    std.debug.assert(cache.get(219, &dummy));
    std.debug.assert(dummy == 5219);

    // Ensure that a key far older than the last 8 inserts is absent
    std.debug.assert(!cache.get(100, &dummy));

    // All assertions passed – program exits cleanly
    return;
}
