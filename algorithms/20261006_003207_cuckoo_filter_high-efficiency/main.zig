const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Small filter for edge‑case testing.
    var small = try types.CuckooFilter.init(allocator, 4);
    defer small.deinit();

    // Insert up to capacity (4 logical entries ≈ 16 slots).
    const items = [_][]const u8{ "a", "b", "c", "d", "e", "f", "g", "h" };
    var inserted: usize = 0;
    for (items) |it| {
        const ok = try engine.insert(&small, it);
        if (ok) inserted += 1;
    }
    // The filter should reject at least one insertion because it is tiny.
    std.debug.assert(inserted < items.len);

    // Verify that all successfully inserted items are reported present.
    for (items[0..inserted]) |it| {
        std.debug.assert(engine.contains(&small, it));
    }

    // Deletion test.
    const del_item = items[0];
    std.debug.assert(engine.delete(&small, del_item));
    std.debug.assert(!engine.contains(&small, del_item));

    // Larger filter for normal operation.
    var filter = try types.CuckooFilter.init(allocator, 1024);
    defer filter.deinit();

    // Insert a set of distinct keys.
    const key_count = 500;
    var keys = try allocator.alloc([]u8, key_count);
    defer allocator.free(keys);
    for (keys) |*k, i| {
        const txt = try std.fmt.allocPrint(allocator, "key_{d}", .{i});
        k.* = txt;
    }

    // Insert all keys; all should succeed in a reasonably sized filter.
    for (keys) |k| {
        const ok = try engine.insert(&filter, k);
        std.debug.assert(ok);
    }

    // Membership checks.
    for (keys) |k| {
        std.debug.assert(engine.contains(&filter, k));
    }

    // Random deletions.
    for (keys[0..100]) |k| {
        std.debug.assert(engine.delete(&filter, k));
        std.debug.assert(!engine.contains(&filter, k));
    }

    // Ensure remaining keys are still present.
    for (keys[100..]) |k| {
        std.debug.assert(engine.contains(&filter, k));
    }

    // Clean up allocated key strings.
    for (keys) |k| {
        allocator.free(k);
    }

    // Edge case: inserting the same element multiple times should not break the filter.
    const dup = "duplicate";
    std.debug.assert(try engine.insert(&filter, dup));
    std.debug.assert(engine.contains(&filter, dup));
    std.debug.assert(try engine.insert(&filter, dup));
    std.debug.assert(engine.contains(&filter, dup));
    std.debug.assert(engine.delete(&filter, dup));
    std.debug.assert(!engine.contains(&filter, dup));
}
