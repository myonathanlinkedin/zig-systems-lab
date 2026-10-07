const std = @import("std");
const types = @import("types.zig");

pub const Engine = struct {
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) Engine {
        return Engine{ .allocator = allocator };
    }

    pub fn set(
        self: *Engine,
        store: *types.TemporalStore,
        key: []const u8,
        value: []const u8,
        timestamp: u64,
    ) !void {
        var maybe_list = store.map.get(key);
        var list_ptr: *std.ArrayList(types.Entry) = undefined;

        if (maybe_list) |ptr| {
            list_ptr = ptr;
        } else {
            // Duplicate key for ownership inside the map
            const key_owned = try self.allocator.dupe(u8, key);
            var list = try std.ArrayList(types.Entry).init(self.allocator);
            try store.map.put(key_owned, &list);
            list_ptr = &list;
        }

        // Duplicate value string for storage
        const value_owned = try self.allocator.dupe(u8, value);
        const entry = types.Entry{
            .timestamp = timestamp,
            .value = value_owned,
        };

        // Binary insertion to keep timestamps sorted ascending
        var lo: usize = 0;
        var hi: usize = list_ptr.items.len;
        while (lo < hi) {
            const mid = (lo + hi) / 2;
            if (list_ptr.items[mid].timestamp < timestamp) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        try list_ptr.insert(lo, entry);
    }

    pub fn get(
        self: *Engine,
        store: *types.TemporalStore,
        key: []const u8,
        timestamp: u64,
    ) ?[]const u8 {
        const maybe_list = store.map.get(key) orelse return null;
        const list = maybe_list.*;

        // Find greatest timestamp <= query using binary search
        var lo: usize = 0;
        var hi: usize = list.items.len;
        while (lo < hi) {
            const mid = (lo + hi) / 2;
            if (list.items[mid].timestamp <= timestamp) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo == 0) return null;
        return list.items[lo - 1].value;
    }
};
