const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    try testSingleThread();
    try testConcurrent();
}

// ---------------------------------------------------------------------
// Single‑threaded sanity test
// ---------------------------------------------------------------------
fn testSingleThread() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    var rb = try core.RingBuffer(u32).init(allocator, 8);
    defer rb.deinit(allocator);

    // Fill the buffer (capacity‑1 usable slots)
    for (0..7) |i| {
        std.debug.assert(rb.push(@intCast(u32, i)));
    }
    // Buffer should now be full
    std.debug.assert(!rb.push(99));

    // Drain and verify order
    for (0..7) |i| {
        const v = rb.pop() orelse unreachable;
        std.debug.assert(v == @intCast(u32, i));
    }
    // Empty now
    std.debug.assert(rb.pop() == null);
}

// ---------------------------------------------------------------------
// Multi‑threaded SPSC test
// ---------------------------------------------------------------------
fn testConcurrent() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    const capacity = 1024;
    var rb = try core.RingBuffer(u64).init(allocator, capacity);
    defer rb.deinit(allocator);

    const total = 100_000;
    var produced = std.atomic.AtomicUsize.init(0);
    var consumed = std.atomic.AtomicUsize.init(0);

    const prod = try std.Thread.spawn(.{}, producerFn, .{ &rb, total, &produced });
    const cons = try std.Thread.spawn(.{}, consumerFn, .{ &rb, total, &consumed });

    prod.wait();
    cons.wait();

    std.debug.assert(produced.load(.Relaxed) == total);
    std.debug.assert(consumed.load(.Relaxed) == total);
}

// Producer: spin‑push until all items are enqueued.
fn producerFn(args: anytype) void {
    const rb: *core.RingBuffer(u64) = args[0];
    const total: usize = args[1];
    const produced: *std.atomic.AtomicUsize = args[2];

    var i: usize = 0;
    while (i < total) : (i += 1) {
        while (!rb.push(@intCast(u64, i))) {}
        _ = produced.fetchAdd(1, .Relaxed);
    }
}

// Consumer: spin‑pop until all items are dequeued.
fn consumerFn(args: anytype) void {
    const rb: *core.RingBuffer(u64) = args[0];
    const total: usize = args[1];
    const consumed: *std.atomic.AtomicUsize = args[2];

    var count: usize = 0;
    while (count < total) {
        const v = rb.pop();
        if (v) |val| {
            _ = consumed.fetchAdd(1, .Relaxed);
            count += 1;
        } else {
            // busy‑wait; in a real system a pause instruction could be used.
        }
    }
}
