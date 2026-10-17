const std = @import("std");
const RingBuffer = @import("types.zig").RingBuffer;
const push = @import("engine.zig").push;
const pop = @import("engine.zig").pop;

pub fn main() !void {
    // Create a ring buffer for i32 with capacity 8 (must be power of two).
    var rb = RingBuffer(i32, 8).init();

    // Helper aliases for readability.
    const push_i32 = push(i32, 8);
    const pop_i32 = pop(i32, 8);

    // Initially empty.
    std.debug.assert(pop_i32(&rb) == null);

    // Fill the buffer completely.
    var i: i32 = 0;
    while (i < 8) : (i += 1) {
        const ok = push_i32(&rb, i);
        std.debug.assert(ok);
    }

    // Buffer should now be full; next push must fail.
    std.debug.assert(!push_i32(&rb, 999));

    // Pop all elements and verify order.
    i = 0;
    while (i < 8) : (i += 1) {
        const val = pop_i32(&rb);
        std.debug.assert(val != null);
        std.debug.assert(val.? == i);
    }

    // Buffer should be empty again.
    std.debug.assert(pop_i32(&rb) == null);

    // Test wrap‑around behavior.
    // Push 4 items.
    i = 0;
    while (i < 4) : (i += 1) {
        std.debug.assert(push_i32(&rb, i + 100));
    }
    // Pop 2 items.
    i = 0;
    while (i < 2) : (i += 1) {
        const val = pop_i32(&rb);
        std.debug.assert(val != null);
        std.debug.assert(val.? == i + 100);
    }
    // Push another 4 items – this will wrap the internal indices.
    i = 0;
    while (i < 4) : (i += 1) {
        std.debug.assert(push_i32(&rb, i + 200));
    }
    // Pop remaining items (should be 6 total now).
    var expected: []i32 = &[_]i32{
        102, 103, // remaining from first batch
        200, 201, 202, 203, // newly added
    };
    for (expected) |exp| {
        const val = pop_i32(&rb);
        std.debug.assert(val != null);
        std.debug.assert(val.? == exp);
    }

    // Final empty check.
    std.debug.assert(pop_i32(&rb) == null);
}
