const std = @import("std");

pub const Entry = struct {
    timestamp: u64,
    value: []const u8,
};

pub const TemporalStore = struct {
    map: std.StringHashMap(*std.ArrayList(Entry)),

    pub fn init(allocator: *std.mem.Allocator) TemporalStore {
        return TemporalStore{
            .map = std.StringHashMap(*std.ArrayList(Entry)).init(allocator),
        };
    }

    pub fn deinit(self: *TemporalStore) void {
        var it = self.map.iterator();
        while (it.next()) |kv| {
            const list_ptr = kv.value;
            // free each duplicated value string
            for (list_ptr.items) |entry| {
                self.map.allocator.free(entry.value);
            }
            list_ptr.deinit();
            self.map.allocator.free(list_ptr);
        }
        self.map.deinit();
    }
};
