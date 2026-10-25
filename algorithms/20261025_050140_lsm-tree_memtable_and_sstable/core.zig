const std = @import("std");

pub const Entry = struct {
    key: u64,
    value: u64,
};

fn binarySearch(arr: []const Entry, key: u64) !struct { idx: usize, found: bool } {
    var lo: usize = 0;
    var hi: usize = arr.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const midKey = arr[mid].key;
        if (midKey == key) return .{ .idx = mid, .found = true };
        if (midKey < key) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return .{ .idx = lo, .found = false };
}

// ---------------------------------------------------------------------
// MemTable: mutable sorted array of entries
// ---------------------------------------------------------------------
pub const MemTable = struct {
    allocator: *std.mem.Allocator,
    entries: std.ArrayList(Entry),

    pub fn init(allocator: *std.mem.Allocator) MemTable {
        return MemTable{
            .allocator = allocator,
            .entries = std.ArrayList(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *MemTable) void {
        self.entries.deinit();
    }

    pub fn size(self: *MemTable) usize {
        return self.entries.items.len;
    }

    pub fn clear(self: *MemTable) void {
        self.entries.clearRetainingCapacity();
    }

    pub fn put(self: *MemTable, key: u64, value: u64) !void {
        const arr = self.entries.items;
        const res = try binarySearch(arr, key);
        if (res.found) {
            self.entries.items[res.idx].value = value;
        } else {
            try self.entries.insert(res.idx, Entry{ .key = key, .value = value });
        }
    }

    pub fn get(self: *MemTable, key: u64) ?u64 {
        const arr = self.entries.items;
        const res = binarySearch(arr, key) catch return null;
        if (res.found) return arr[res.idx].value;
        return null;
    }

    // Returns a copy of the sorted entries (used for flushing)
    pub fn cloneEntries(self: *MemTable) ![]Entry {
        const len = self.entries.items.len;
        const slice = try self.allocator.alloc(Entry, len);
        std.mem.copy(Entry, slice, self.entries.items);
        return slice;
    }
};

// ---------------------------------------------------------------------
// SSTable: immutable sorted array of entries
// ---------------------------------------------------------------------
pub const SSTable = struct {
    allocator: *std.mem.Allocator,
    entries: []const Entry,

    pub fn new(allocator: *std.mem.Allocator, entries: []Entry) !*SSTable {
        const self = try allocator.create(SSTable);
        self.* = SSTable{
            .allocator = allocator,
            .entries = entries,
        };
        return self;
    }

    pub fn deinit(self: *SSTable) void {
        self.allocator.free(@constCast(self.entries));
        self.allocator.destroy(self);
    }

    pub fn get(self: *SSTable, key: u64) ?u64 {
        const res = binarySearch(self.entries, key) catch return null;
        if (res.found) return self.entries[res.idx].value;
        return null;
    }
};

// ---------------------------------------------------------------------
// LSMEngine: manages MemTable and a list of SSTables
// ---------------------------------------------------------------------
pub const LSMEngine = struct {
    allocator: *std.mem.Allocator,
    mem: MemTable,
    sstables: std.ArrayList(*SSTable),

    pub fn init(allocator: *std.mem.Allocator) LSMEngine {
        return LSMEngine{
            .allocator = allocator,
            .mem = MemTable.init(allocator),
            .sstables = std.ArrayList(*SSTable).init(allocator),
        };
    }

    pub fn deinit(self: *LSMEngine) void {
        self.mem.deinit();
        for (self.sstables.items) |sst| {
            sst.deinit();
        }
        self.sstables.deinit();
    }

    pub fn put(self: *LSMEngine, key: u64, value: u64) !void {
        try self.mem.put(key, value);
    }

    pub fn get(self: *LSMEngine, key: u64) ?u64 {
        // Check MemTable first (most recent)
        if (self.mem.get(key)) |v| return v;
        // Search SSTables from newest to oldest
        var i: isize = @intCast(self.sstables.items.len) - 1;
        while (i >= 0) : (i -= 1) {
            if (self.sstables.items[@intCast(i)].get(key)) |v| return v;
        }
        return null;
    }

    pub fn flush(self: *LSMEngine) !void {
        if (self.mem.size() == 0) return;
        const entries = try self.mem.cloneEntries();
        const sst = try SSTable.new(self.allocator, entries);
        try self.sstables.append(sst);
        self.mem.clear();
    }

    pub fn compact(self: *LSMEngine) !void {
        if (self.sstables.items.len <= 1) return;
        // Merge all SSTables, newer overrides older on duplicate keys
        var map = std.AutoHashMap(u64, u64).init(self.allocator);
        defer map.deinit();

        // Insert from newest to oldest
        var i: isize = @intCast(self.sstables.items.len) - 1;
        while (i >= 0) : (i -= 1) {
            const sst = self.sstables.items[@intCast(i)];
            for (sst.entries) |e| {
                // Insert only if key not already present (newer already stored)
                _ = map.put(e.key, e.value) catch {};
            }
        }

        // Extract sorted keys
        const total = map.count();
        var keys = try self.allocator.alloc(u64, total);
        defer self.allocator.free(keys);
        var idx: usize = 0;
        var it = map.keyIterator();
        while (it.next()) |k| {
            keys[idx] = k.*;
            idx += 1;
        }
        std.sort.sort(u64, keys, {}, (a, b) => std.math.compare(a, b));

        // Build final entries array
        const finalEntries = try self.allocator.alloc(Entry, total);
        for (keys) |k, j| {
            const v = map.get(k).?;
            finalEntries[j] = Entry{ .key = k, .value = v };
        }

        // Create new SSTable
        const newSST = try SSTable.new(self.allocator, finalEntries);
        // Deinit old SSTables
        for (self.sstables.items) |old| old.deinit();
        self.sstables.clearRetainingCapacity();
        try self.sstables.append(newSST);
    }
};
