const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    test_basic();
    test_wrapAround();
    test_fullEmptyTransitions();
    std.debug.print("All Chronos‑Buffer tests passed.\n", .{});
}

// -----------------------------------------------------------------------------
// Test: basic push/pop sequence.
fn test_basic() void {
    var rb = core.RingBuffer.init(u32, 8);
    std.debug.assert(rb.isEmpty());
    std.debug.assert(!rb.isFull());

    // Push three values.
    try rb.push(10);
    try rb.push(20);
    try rb.push(30);
    std.debug.assert(!rb.isEmpty());
    std.debug.assert(!rb.isFull());
    std.debug.assert(rb.len() == 3);

    // Pop them in order.
    const a = try rb.pop();
    const b = try rb.pop();
    const c = try rb.pop();
    std.debug.assert(a == 10);
    std.debug.assert(b == 20);
    std.debug.assert(c == 30);
    std.debug.assert(rb.isEmpty());
}

// -----------------------------------------------------------------------------
// Test: wrap‑around behavior after head/tail cross the buffer boundary.
fn test_wrapAround() void {
    var rb = core.RingBuffer.init(u8, 4); // capacity 4, usable slots = 3

    // Fill to capacity‑1.
    try rb.push(1);
    try rb.push(2);
    try rb.push(3);
    std.debug.assert(rb.isFull());

    // Pop two items, creating space at the beginning.
    const x = try rb.pop();
    const y = try rb.pop();
    std.debug.assert(x == 1);
    std.debug.assert(y == 2);
    std.debug.assert(!rb.isFull());
    std.debug.assert(rb.len() == 1);

    // Push two more items; they should wrap to the low indices.
    try rb.push(4);
    try rb.push(5);
    std.debug.assert(rb.isFull());

    // Drain all items and verify order.
    const order = [_]u8{ 3, 4, 5 };
    for (order) |expected| {
        const got = try rb.pop();
        std.debug.assert(got == expected);
    }
    std.debug.assert(rb.isEmpty());
}

// -----------------------------------------------------------------------------
// Test: transitions between empty and full states, ensuring errors are raised.
fn test_fullEmptyTransitions() void {
    var rb = core.RingBuffer.init(i64, 2); // usable slots = 1

    // Initially empty.
    std.debug.assert(rb.isEmpty());
    const empty_err = rb.pop() catch |e| e;
    std.debug.assert(empty_err == core.RingBuffer.Error.BufferEmpty);

    // Push one element – now full.
    try rb.push(-42);
    std.debug.assert(rb.isFull());

    const full_err = rb.push(99) catch |e| e;
    std.debug.assert(full_err == core.RingBuffer.Error.BufferFull);

    // Pop the element – back to empty.
    const val = try rb.pop();
    std.debug.assert(val == -42);
    std.debug.assert(rb.isEmpty());
}

// Helper to silence "unused result" warnings for try statements in void functions.
fn try(comptime T: type, result: T) void {
    _ = result;
}
