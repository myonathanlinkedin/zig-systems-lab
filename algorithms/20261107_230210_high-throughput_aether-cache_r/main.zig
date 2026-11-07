const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    // Simple sanity test with u32
    {
        var rb = core.RingBuffer.init(u32, 8);
        defer rb.deinit();

        // Fill the buffer completely
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            try rb.push(i);
        }
        std.debug.assert(rb.isFull());
        std.debug.assert(!rb.isEmpty());

        // Attempt to push when full – should error
        const push_err = rb.push(999);
        std.debug.assert(push_err == core.RingBuffer.Error.BufferFull);

        // Pop all elements and verify order
        i = 0;
        while (i < 8) : (i += 1) {
            const val = try rb.pop();
            std.debug.assert(val == i);
        }
        std.debug.assert(rb.isEmpty());

        // Pop from empty – should error
        const pop_err = rb.pop();
        std.debug.assert(pop_err == core.RingBuffer.Error.BufferEmpty);
    }

    // Test wrap‑around behavior
    {
        var rb = core.RingBuffer.init(u8, 4);
        defer rb.deinit();

        // Push two, pop one, push three more (causing wrap)
        try rb.push(10);
        try rb.push(20);
        std.debug.assert(rb.len() == 2);
        const v1 = try rb.pop();
        std.debug.assert(v1 == 10);
        try rb.push(30);
        try rb.push(40);
        try rb.push(50); // now tail wrapped
        std.debug.assert(rb.isFull());

        // Drain and check order
        const expected = [_]u8{20, 30, 40, 50};
        for (expected) |exp| {
            const got = try rb.pop();
            std.debug.assert(got == exp);
        }
        std.debug.assert(rb.isEmpty());
    }

    // Generic test with a struct type
    {
        const Point = struct {
            x: f64,
            y: f64,
        };
        var rb = core.RingBuffer.init(Point, 2);
        defer rb.deinit();

        const p1 = Point{ .x = 1.0, .y = 2.0 };
        const p2 = Point{ .x = -3.5, .y = 4.2 };
        try rb.push(p1);
        try rb.push(p2);
        std.debug.assert(rb.isFull());

        const q1 = try rb.pop();
        const q2 = try rb.pop();
        std.debug.assert(q1.x == p1.x and q1.y == p1.y);
        std.debug.assert(q2.x == p2.x and q2.y == p2.y);
    }

    // Verify compile‑time guard: uncommenting the following line must fail to compile
    // var bad = core.RingBuffer.init(u8, 3); // not a power of two

    // All tests passed
    std.debug.print("All RingBuffer tests passed.\n", .{});
    return;
}
