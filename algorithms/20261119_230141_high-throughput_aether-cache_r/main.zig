const std = @import("std");
const core = @import("core.zig");

// Simple sanity‑check harness using `std.debug.assert`.
pub fn main() !void {
    // Instantiate a ring buffer for i32 with capacity 8 (power of two).
    var rb = core.RingBuffer(i32, 8).init();

    // --------------------------------------------------------------------
    // Fill the buffer to capacity.
    // --------------------------------------------------------------------
    var i: i32 = 0;
    while (i < 8) : (i += 1) {
        std.debug.assert(rb.push(i));
    }
    // Buffer must now be full; further pushes should fail.
    std.debug.assert(!rb.push(99));
    std.debug.assert(rb.isFull());
    std.debug.assert(rb.len() == 8);

    // --------------------------------------------------------------------
    // Drain the buffer and verify order.
    // --------------------------------------------------------------------
    i = 0;
    while (i < 8) : (i += 1) {
        const v = rb.pop() orelse unreachable;
        std.debug.assert(v == i);
    }
    std.debug.assert(rb.isEmpty());
    std.debug.assert(rb.pop() == null);

    // --------------------------------------------------------------------
    // Wrap‑around behaviour: push, pop, then push again.
    // --------------------------------------------------------------------
    var j: i32 = 0;
    while (j < 4) : (j += 1) {
        std.debug.assert(rb.push(j + 100));
    }
    std.debug.assert(rb.len() == 4);

    // Pop two items.
    var k: i32 = 0;
    while (k < 2) : (k += 1) {
        const v = rb.pop() orelse unreachable;
        std.debug.assert(v == 100 + k);
    }

    // Push six more items; this forces the internal indices to wrap.
    var m: i32 = 0;
    while (m < 6) : (m += 1) {
        std.debug.assert(rb.push(m + 200));
    }
    std.debug.assert(rb.isFull());

    // Expected remaining sequence after the above operations.
    const expected: []i32 = &[_]i32{ 102, 103, 200, 201, 202, 203, 204, 205 };
    for (expected) |exp| {
        const v = rb.pop() orelse unreachable;
        std.debug.assert(v == exp);
    }
    std.debug.assert(rb.isEmpty());

    // --------------------------------------------------------------------
    // Light benchmark: push and pop 1_000_000 items, measuring elapsed time.
    // --------------------------------------------------------------------
    const iterations = 1_000_000;
    var start = std.time.milliTimestamp();
    var n: usize = 0;
    while (n < iterations) : (n += 1) {
        // Buffer is empty at the start of each loop iteration.
        std.debug.assert(rb.push(@intCast(i32, n)));
        const v = rb.pop() orelse unreachable;
        std.debug.assert(v == @intCast(i32, n));
    }
    var elapsed = std.time.milliTimestamp() - start;
    // Simple sanity: elapsed must be non‑negative.
    std.debug.assert(elapsed >= 0);
}
