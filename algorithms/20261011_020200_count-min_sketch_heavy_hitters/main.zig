const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Parameters chosen to keep error bound reasonable for the test size
    const depth = 4;
    const width = 1024;
    var cms = try core.CountMinSketch.init(allocator, depth, width);
    defer cms.deinit();

    // Exact frequencies stored in a hash map for verification
    var exact = std.AutoHashMap([]const u8, u64).init(allocator);
    defer exact.deinit();

    // Helper to add an item both to the sketch and the exact map
    fn record(item: []const u8, cnt: u64) !void {
        cms.add(item, cnt);
        const entry = try exact.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* +%= cnt;
        } else {
            entry.value_ptr.* = cnt;
        }
    }

    // Create a synthetic stream with known frequencies
    const items = [_][]const u8{
        "apple", "banana", "cherry", "date", "elderberry",
        "fig", "grape", "honeydew", "kiwi", "lemon",
    };
    // Frequencies: increasing powers of two
    var i: usize = 0;
    while (i < items.len) : (i += 1) {
        const freq = 1 << @intCast(u64, i); // 1,2,4,...,512
        try record(items[i], freq);
    }

    // Compute total count for error bound
    var total: u64 = 0;
    var it = exact.iterator();
    while (it.next()) |kv| total +%= kv.value;

    const epsilon = (total / @intCast(u64, width)) + 1;

    // Verify each estimate respects Count‑Min guarantees
    it = exact.iterator();
    while (it.next()) |kv| {
        const est = cms.estimate(kv.key);
        std.debug.assert(est >= kv.value); // never underestimate
        std.debug.assert(est <= kv.value +% epsilon); // bounded overestimate
    }

    // Heavy‑hitter detection test
    const threshold: u64 = 200; // items with true count >= 200 should be reported
    var reported = std.ArrayList([]const u8).init(allocator);
    defer reported.deinit();

    it = exact.iterator();
    while (it.next()) |kv| {
        if (cms.estimate(kv.key) >= threshold) {
            try reported.append(kv.key);
        }
    }

    // Expected heavy hitters (true count >= threshold)
    var expected = std.ArrayList([]const u8).init(allocator);
    defer expected.deinit();
    it = exact.iterator();
    while (it.next()) |kv| {
        if (kv.value >= threshold) {
            try expected.append(kv.key);
        }
    }

    // Sort both slices for order‑independent comparison
    const cmp = struct {
        fn lessThan(a: []const u8, b: []const u8) bool {
            return std.mem.compare(u8, a, b) == .lt;
        }
    }.lessThan;

    std.sort.sort([]const u8, reported.items, {}, cmp);
    std.sort.sort([]const u8, expected.items, {}, cmp);

    std.debug.assert(reported.items.len == expected.items.len);
    var idx: usize = 0;
    while (idx < reported.items.len) : (idx += 1) {
        std.debug.assert(std.mem.eql(u8, reported.items[idx], expected.items[idx]));
    }

    // All assertions passed
    std.debug.print("All Count‑Min Sketch tests passed.\n", .{});
}
