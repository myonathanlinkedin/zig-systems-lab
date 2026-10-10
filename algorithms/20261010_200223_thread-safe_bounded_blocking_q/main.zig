const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const Item = usize;
    const capacity = 8;
    var queue = try core.BoundedBlockingQueue.init(Item, allocator, capacity);
    defer queue.deinit();

    const total_items = 10_000;
    const producer_count = 4;
    const consumer_count = 4;
    const items_per_producer = total_items / producer_count;

    // Atomic counters for verification
    var produced = std.atomic.AtomicUsize.init(0);
    var consumed = std.atomic.AtomicUsize.init(0);

    // Simple bitmap to ensure each value appears exactly once
    var seen = try allocator.alloc(bool, total_items);
    defer allocator.free(seen);
    for (seen) |*b| b.* = false;

    // Spawn producers
    var producers: [producer_count]std.Thread = undefined;
    for (producers) |*thr, idx| {
        const start = idx * items_per_producer;
        thr.* = try std.Thread.spawn(.{}, struct {
            fn run(start: usize, count: usize, q: *core.BoundedBlockingQueue) void {
                var i: usize = 0;
                while (i < count) : (i += 1) {
                    q.enqueue(start + i);
                }
            }
        }.run, .{ start, items_per_producer, &queue });
    }

    // Spawn consumers
    var consumers: [consumer_count]std.Thread = undefined;
    for (consumers) |*thr| {
        thr.* = try std.Thread.spawn(.{}, struct {
            fn run(q: *core.BoundedBlockingQueue, seen: []bool, prod: *std.atomic.AtomicUsize, cons: *std.atomic.AtomicUsize) void {
                while (true) {
                    const val = q.dequeue();
                    // Record the value
                    std.debug.assert(!seen[val]); // each value must be unique
                    seen[val] = true;
                    cons.fetchAdd(1, .Monotonic);
                    // Exit condition
                    if (cons.load(.Monotonic) >= prod.load(.Monotonic)) {
                        // All produced items have been consumed
                        break;
                    }
                }
            }
        }.run, .{ &queue, seen, &produced, &consumed });
    }

    // Wait for producers to finish
    for (producers) |thr| {
        thr.wait();
        // Update produced counter
        produced.fetchAdd(items_per_producer, .Monotonic);
    }

    // Wait for consumers to finish
    for (consumers) |thr| {
        thr.wait();
    }

    // Final assertions
    std.debug.assert(produced.load(.Monotonic) == total_items);
    std.debug.assert(consumed.load(.Monotonic) == total_items);
    // Verify every index was seen
    for (seen) |b| std.debug.assert(b);
}
