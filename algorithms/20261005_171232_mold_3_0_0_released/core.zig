const std = @import("std");

pub fn HashMap(comptime K: type, comptime V: type, comptime Allocator: type) type {
    return struct {
        const Entry = struct {
            key: K,
            value: V,
            used: bool = false,
        };

        allocator: Allocator,
        entries: []Entry,
        capacity: usize,
        count: usize,

        pub fn init(allocator: Allocator, init_capacity: usize) !HashMap {
            const cap = std.math.max(init_capacity, 8);
            const buf = try allocator.alloc(Entry, cap);
            return HashMap{
                .allocator = allocator,
                .entries = buf,
                .capacity = cap,
                .count = 0,
            };
        }

        pub fn deinit(self: *HashMap) void {
            self.allocator.free(self.entries);
            self.entries = &.{};
            self.capacity = 0;
            self.count = 0;
        }

        fn hash(self: *HashMap, key: K) usize {
            const h = std.hash.hash(K, &key);
            return h;
        }

        fn probe(self: *HashMap, idx: usize) usize {
            return (idx + 1) % self.capacity;
        }

        fn findIndex(self: *HashMap, key: K) ?usize {
            var idx = self.hash(key) % self.capacity;
            while (self.entries[idx].used) {
                if (std.meta.eql(self.entries[idx].key, key)) return idx;
                idx = self.probe(idx);
            }
            return null;
        }

        pub fn put(self: *HashMap, key: K, value: V) !void {
            if (self.count * 10 >= self.capacity * 7) {
                try self.resize(self.capacity * 2);
            }
            var idx = self.hash(key) % self.capacity;
            while (self.entries[idx].used) {
                if (std.meta.eql(self.entries[idx].key, key)) {
                    self.entries[idx].value = value;
                    return;
                }
                idx = self.probe(idx);
            }
            self.entries[idx] = Entry{ .key = key, .value = value, .used = true };
            self.count += 1;
        }

        pub fn get(self: *HashMap, key: K) ?V {
            const idx = self.findIndex(key) orelse return null;
            return self.entries[idx].value;
        }

        pub fn remove(self: *HashMap, key: K) bool {
            const idx_opt = self.findIndex(key);
            if (idx_opt == null) return false;
            const idx = idx_opt.?;
            self.entries[idx].used = false;
            self.count -= 1;
            // Rehash following cluster
            var next = self.probe(idx);
            while (self.entries[next].used) {
                const rehash_key = self.entries[next].key;
                const rehash_val = self.entries[next].value;
                self.entries[next].used = false;
                self.count -= 1;
                self.put(rehash_key, rehash_val) catch {};
                next = self.probe(next);
            }
            return true;
        }

        fn resize(self: *HashMap, new_cap: usize) !void {
            const old_entries = self.entries;
            const old_cap = self.capacity;
            const new_entries = try self.allocator.alloc(Entry, new_cap);
            self.entries = new_entries;
            self.capacity = new_cap;
            self.count = 0;
            for (old_entries) |e| {
                if (e.used) {
                    try self.put(e.key, e.value);
                }
            }
            self.allocator.free(old_entries);
        }
    };
}
