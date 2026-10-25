const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    var engine = core.LSMEngine.init(allocator);
    defer engine.deinit();

    // Insert a range of keys
    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        try engine.put(i, i * 10);
    }

    // Verify reads before flush
    std.debug.assert(engine.get(0) == 0);
    std.debug.assert(engine.get(999) == 9990);
    std.debug.assert(engine.get(1000) == null);

    // Flush MemTable to SSTable
    try engine.flush();

    // MemTable should be empty now
    std.debug.assert(engine.mem.size() == 0);
    // Reads should still succeed via SSTable
    std.debug.assert(engine.get(500) == 5000);

    // Overwrite some keys
    try engine.put(500, 5555);
    try engine.put(1500, 15000); // new key beyond previous range
    std.debug.assert(engine.get(500) == 5555);
    std.debug.assert(engine.get(1500) == 15000);

    // Flush again, creating second SSTable
    try engine.flush();

    // Compact all SSTables into one
    try engine.compact();

    // After compaction, only one SSTable should exist
    std.debug.assert(engine.sstables.items.len == 1);

    // Verify that latest values win
    std.debug.assert(engine.get(500) == 5555);
    std.debug.assert(engine.get(1500) == 15000);
    std.debug.assert(engine.get(0) == 0);
    std.debug.assert(engine.get(999) == 9990);

    // Edge case: non‑existent key
    std.debug.assert(engine.get(2000) == null);

    // Clean up is handled by defer statements
    return;
}
