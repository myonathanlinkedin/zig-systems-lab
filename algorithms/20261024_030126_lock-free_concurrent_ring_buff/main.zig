const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // Create a ring buffer for u32 with capacity 8 (must be power of two).
    const RingU32 = types.RingBuffer(u32);
    var rb = try RingU32.init(8, &allocator);
    defer rb.deinit();

    // Helper to push and assert success.
    fn mustPush(value: u32) void {
        const ok = engine.push(u32, &rb, value);
        std.debug.assert(ok);
    }

    // Helper to pop and assert expected value.
    fn mustPop(expected: u32) void {
        var out: u32 = undefined;
        const ok = engine.pop(u32, &rb, &out);
        std.debug.assert(ok);
        std.debug.assert(out == expected);
    }

    // Initially empty.
    std.debug.assert(engine.isEmpty(u32, &rb));
    std.debug.assert(!engine.isFull(u32, &rb));

    // Fill the buffer completely.
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        mustPush(i);
    }

    // Buffer should now be full.
    std.debug.assert(engine.isFull(u32, &rb));
    std.debug.assert(!engine.isEmpty(u32, &rb));

    // Attempt to push into a full buffer must fail.
    const pushFail = engine.push(u32, &rb, 999);
    std.debug.assert(!pushFail);

    // Pop three elements to create space and test wrap‑around.
    mustPop(0);
    mustPop(1);
    mustPop(2);

    std.debug.assert(!engine.isFull(u32, &rb));
    std.debug.assert(!engine.isEmpty(u32, &rb));

    // Push again to wrap around the internal indices.
    mustPush(100);
    mustPush(101);
    mustPush(102);

    // At this point the buffer should be full again.
    std.debug.assert(engine.isFull(u32, &rb));

    // Drain the buffer completely and verify order.
    const expected = [_]u32{ 3, 4, 5, 6, 7, 100, 101, 102 };
    for (expected) |val| {
        mustPop(val);
    }

    // Buffer must be empty now.
    std.debug.assert(engine.isEmpty(u32, &rb));
    std.debug.assert(!engine.isFull(u32, &rb));

    // Clean shutdown of allocator.
    const deinit_ok = !gpa.deinit();
    std.debug.assert(deinit_ok);
}
