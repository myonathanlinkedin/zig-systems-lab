const std = @import("std");
const types = @import("types.zig");
const engine_mod = @import("engine.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = types.TemporalStore.init(&allocator);
    defer store.deinit();

    var eng = engine_mod.Engine.init(&allocator);

    // Populate temporal data for key "foo"
    try eng.set(&store, "foo", "a", 10);
    try eng.set(&store, "foo", "b", 20);
    try eng.set(&store, "foo", "c", 15); // out-of-order insertion

    // Populate another key "bar"
    try eng.set(&store, "bar", "x", 5);
    try eng.set(&store, "bar", "y", 25);

    // Helper for assertions
    const assertValue = fn (key: []const u8, ts: u64, expected: ?[]const u8) void {
        const got = eng.get(&store, key, ts);
        if (expected) |exp| {
            std.debug.assert(got != null);
            std.debug.assert(std.mem.eql(u8, got.?, exp));
        } else {
            std.debug.assert(got == null);
        }
    };

    // Edge cases and normal queries for "foo"
    assertValue("foo", 5, null);
    assertValue("foo", 10, "a");
    assertValue("foo", 14, "a");
    assertValue("foo", 15, "c");
    assertValue("foo", 19, "c");
    assertValue("foo", 20, "b");
    assertValue("foo", 30, "b");

    // Queries for "bar"
    assertValue("bar", 1, null);
    assertValue("bar", 5, "x");
    assertValue("bar", 24, "x");
    assertValue("bar", 25, "y");
    assertValue("bar", 100, "y");

    // Non-existent key
    assertValue("baz", 10, null);
}
