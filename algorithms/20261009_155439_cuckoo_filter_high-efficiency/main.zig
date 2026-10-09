const std = @import("std");
const CuckooFilter = @import("core.zig").CuckooFilter;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Create filter with capacity for 1000 items
    var filter = try CuckooFilter.init(allocator, 1000);
    defer filter.deinit(allocator);

    // Simple deterministic test set
    const keys = [_][]const u8{
        "apple", "banana", "cherry", "date", "elderberry",
        "fig", "grape", "honeydew", "kiwi", "lemon",
    };

    // Insert all keys
    for (keys) |k| {
        const ok = try filter.insert(k);
        std.debug.assert(ok);
    }

    // Verify presence
    for (keys) |k| {
        std.debug.assert(filter.lookup(k));
    }

    // Verify non‑present key
    std.debug.assert(!filter.lookup("mango"));

    // Delete a subset
    const to_delete = [_][]const u8{ "banana", "date", "kiwi" };
    for (to_delete) |k| {
        const removed = filter.delete(k);
        std.debug.assert(removed);
        std.debug.assert(!filter.lookup(k));
    }

    // Ensure remaining keys still present
    for (keys) |k| {
        const should_exist = !std.mem.eql(u8, k, "banana") and
                             !std.mem.eql(u8, k, "date") and
                             !std.mem.eql(u8, k, "kiwi");
        std.debug.assert(filter.lookup(k) == should_exist);
    }

    // Stress test: insert many random keys and verify false‑positive bound
    const total = 5000;
    var inserted = std.AutoHashMap(u64, void).init(allocator);
    defer inserted.deinit();

    var rng = std.rand.DefaultRandom.init(0);
    var i: usize = 0;
    while (i < total) : (i += 1) {
        const val = rng.random().int(u64);
        const key = std.mem.asBytes(&val);
        // ignore duplicates for map
        if (inserted.put(val, {})) {
            const ok = try filter.insert(key);
            std.debug.assert(ok);
        }
    }

    // Measure false positive rate on unseen keys
    var false_positives: usize = 0;
    var trials: usize = 2000;
    i = 0;
    while (i < trials) : (i += 1) {
        const val = rng.random().int(u64);
        if (inserted.contains(val)) continue; // skip inserted
        const key = std.mem.asBytes(&val);
        if (filter.lookup(key)) false_positives += 1;
    }
    const fp_rate = @intToFloat(f64, false_positives) / @intToFloat(f64, trials);
    // Expect rate well below 5%
    std.debug.assert(fp_rate < 0.05);

    std.debug.print("All tests passed. False‑positive rate: {d:.2%}\n", .{fp_rate});
}
