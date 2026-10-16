const std = @import("std");
const core = @import("core.zig");

const Queue = core.BoundedBlockingQueue(usize);

fn producerFn(start: usize, count: usize, q: *Queue) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        q.enqueue(start + i);
    }
}

fn consumerFn(count: usize, q: *Queue, seen: []bool, seen_lock: *core.SRWLOCK, consumed: *std.atomic.Value(usize)) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const val = q.dequeue();
        core.AcquireSRWLockExclusive(seen_lock);
        std.debug.assert(!seen[val]);
        seen[val] = true;
        core.ReleaseSRWLockExclusive(seen_lock);
        _ = consumed.fetchAdd(1, .monotonic);
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const capacity = 16;
    var queue = try Queue.init(allocator, capacity);
    defer queue.deinit();

    const total_items: usize = 10_000;
    const producer_count: usize = 4;
    const consumer_count: usize = 4;
    const items_per_producer = total_items / producer_count;
    const items_per_consumer = total_items / consumer_count;

    var consumed = std.atomic.Value(usize).init(0);

    const seen = try allocator.alloc(bool, total_items);
    defer allocator.free(seen);
    for (seen) |*b| b.* = false;

    var seen_lock: core.SRWLOCK = null;
    core.InitializeSRWLock(&seen_lock);

    var producers: [producer_count]std.Thread = undefined;
    for (0..producer_count) |idx| {
        const start = idx * items_per_producer;
        producers[idx] = try std.Thread.spawn(.{}, producerFn, .{ start, items_per_producer, &queue });
    }

    var consumers: [consumer_count]std.Thread = undefined;
    for (0..consumer_count) |idx| {
        consumers[idx] = try std.Thread.spawn(.{}, consumerFn, .{ items_per_consumer, &queue, seen, &seen_lock, &consumed });
    }

    for (0..producer_count) |idx| {
        producers[idx].join();
    }

    for (0..consumer_count) |idx| {
        consumers[idx].join();
    }

    std.debug.assert(consumed.load(.monotonic) == total_items);
    for (seen) |b| std.debug.assert(b);
}
