const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = &gpa.allocator;

    // Virtual memory: 4 pages, each 16 bytes. Physical memory: 2 frames.
    var pager = try core.Pager.init(allocator, 4, 16, 2);
    defer pager.deinit();

    // Write distinct markers to each page (offset 0).
    try pager.write(0 * 16 + 0, 0xAA);
    try pager.write(1 * 16 + 0, 0xBB);
    try pager.write(2 * 16 + 0, 0xCC);
    try pager.write(3 * 16 + 0, 0xDD);

    // Read back; paging must have persisted data across evictions.
    const v0 = try pager.read(0 * 16 + 0);
    const v1 = try pager.read(1 * 16 + 0);
    const v2 = try pager.read(2 * 16 + 0);
    const v3 = try pager.read(3 * 16 + 0);
    std.debug.assert(v0 == 0xAA);
    std.debug.assert(v1 == 0xBB);
    std.debug.assert(v2 == 0xCC);
    std.debug.assert(v3 == 0xDD);

    // LRU sanity check.
    // Write a second byte to page 0, then touch pages 1 and 2.
    try pager.write(0 * 16 + 1, 0x11);
    _ = try pager.read(1 * 16 + 0); // makes page 1 most recent.
    _ = try pager.read(2 * 16 + 0); // evicts page 3 (LRU).

    // Write to page 3 again, forcing eviction of the current LRU (page 0).
    try pager.write(3 * 16 + 1, 0x22);

    // Verify that page 0's second byte survived the round‑trip.
    const v0_1 = try pager.read(0 * 16 + 1);
    std.debug.assert(v0_1 == 0x11);
}
