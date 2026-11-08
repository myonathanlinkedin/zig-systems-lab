const std = @import("std");
const types = @import("types");

// A simple cache entry; key is u64, value is generic
pub fn CacheEntry(comptime V: type) type {
    return struct {
        key: u64,
        value: V,
    };
}

// High‑throughput Aether‑Cache built on a RingBuffer.
// When full, new inserts overwrite the oldest entry (circular eviction).
pub fn AetherCache(comptime V: type, comptime capacity: usize) type {
    const Entry = CacheEntry(V);
    const Buffer = types.RingBuffer(Entry, capacity);

    return struct {
        ring: Buffer,

        pub fn init() AetherCache {
            return .{
                .ring = Buffer.init(),
            };
        }

        // Insert a key/value pair. Overwrites oldest entry if buffer is full.
        pub fn insert(self: *AetherCache, key: u64, value: V) void {
            var entry: Entry = .{ .key = key, .value = value };
            // Try normal push; if it fails, force overwrite by discarding oldest.
            if (!self.ring.push(entry)) {
                // Buffer full: pop oldest then push again (guaranteed to succeed)
                var discard: Entry = undefined;
                _ = self.ring.pop(&discard);
                const ok = self.ring.push(entry);
                // The second push must succeed; assert for safety.
                std.debug.assert(ok);
            }
        }

        // Retrieve the most recent value for a given key.
        // Linear scan from newest to oldest (O(n)) – acceptable for small capacities.
        pub fn get(self: *AetherCache, key: u64, out: *V) bool {
            // Snapshot of head/tail to avoid race with concurrent producer.
            const head = self.ring.head.load(.Acquire);
            const tail = self.ring.tail.load(.Acquire);
            var idx = head;
            while (idx != tail) {
                idx = idx -% 1; // move backwards
                const bufIdx = idx & (capacity - 1);
                const entry = self.ring.buffer[bufIdx];
                if (entry.key == key) {
                    out.* = entry.value;
                    return true;
                }
            }
            return false;
        }

        // Expose helpers for testing
        pub fn len(self: *AetherCache) usize {
            return self.ring.len();
        }

        pub fn isFull(self: *AetherCache) bool {
            return self.ring.isFull();
        }

        pub fn isEmpty(self: *AetherCache) bool {
            return self.ring.isEmpty();
        }
    };
}
