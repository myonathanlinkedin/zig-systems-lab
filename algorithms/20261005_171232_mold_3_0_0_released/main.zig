const std = @import("std");
const core = @import("core.zig");
const Allocator = std.heap.page_allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test: insert and get
    var map = try core.HashMap(u32, []const u8, Allocator).init(allocator, 16);
    defer map.deinit();

    try map.put(42, "Answer");
    try map.put(7, "Lucky");
    try map.put(13, "Unlucky");

    std.debug.assert(std.mem.eql(u8, map.get(42).?, "Answer"));
    std.debug.assert(std.mem.eql(u8, map.get(7).?, "Lucky"));
    std.debug.assert(std.mem.eql(u8, map.get(13).?, "Unlucky"));
    std.debug.assert(map.get(99) == null);

    // Test: remove
    std.debug.assert(map.remove(7));
    std.debug.assert(map.get(7) == null);
    std.debug.assert(!map.remove(7));

    // Test: resize
    const N = 1000;
    for (0..N) |i| {
        try map.put(@intCast(u32, i), "val");
    }
    std.debug.assert(map.count == N + 2); // 2 remaining from earlier
    for (0..N) |i| {
        std.debug.assert(map.get(@intCast(u32, i)).? == "val");
    }

    // Benchmark: bulk insert
    const bench_map = try core.HashMap(u32, u32, Allocator).init(allocator, 1 << 20);
    defer bench_map.deinit();

    const start = std.time.nanoTimestamp();
    for (0..(1 << 20)) |i| {
        try bench_map.put(@intCast(u32, i), @intCast(u32, i * 2));
    }
    const elapsed = std.time.nanoTimestamp() - start;
    std.debug.print("Inserted 1,048,576 entries in {d} ns\n", .{elapsed});

    // Verify benchmark data
    std.debug.assert(bench_map.get(123456).? == 123456 * 2);
    std.debug.assert(bench_map.get(999999).? == 999999 * 2);
}
