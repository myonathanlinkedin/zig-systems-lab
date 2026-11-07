const std = @import("std");
const BoundedBlockingQueue = @import("core.zig").BoundedBlockingQueue;

pub fn main() !void {
    // Basic single-thread test
    var q = BoundedBlockingQueue(i32, 5).init();
    q.push(1);
    q.push(2);
    q.push(3);
    const a = q.pop();
    const b = q.pop();
    const c = q.pop();
    std.debug.assert(a == 1);
    std.debug.assert(b == 2);
    std.debug.assert(c == 3);

    // Test blocking behavior with threads
    const num_threads = 4;
    const items_per_thread = 1000;
    const total_items = num_threads * items_per_thread;

    var queue = BoundedBlockingQueue(i32, 10).init();

    // Producer threads
    var producers: [num_threads]std.Thread = undefined;
    for (producers) |*p, idx| {
        p.* = try std.Thread.spawn(.{}, producer, .{ &queue, idx, items_per_thread });
    }

    // Consumer threads
    var consumers: [num_threads]std.Thread = undefined;
    var results = std.ArrayList(i32).init(std.heap.page_allocator);
    defer results.deinit();

    for (consumers) |*c, idx| {
        c.* = try std.Thread.spawn(.{}, consumer, .{ &queue, idx, items_per_thread, &results });
    }

    // Wait for all threads
    for (producers) |p| p.join();
    for (consumers) |c| c.join();

    // Verify all items consumed
    std.debug.assert(results.items.len == total_items);

    // Verify sum of all items
    var sum: i32 = 0;
    for (results.items) |v| sum += v;
    const expected_sum: i32 = @intCast(i32, (items_per_thread * (items_per_thread - 1) / 2) * num_threads);
    std.debug.assert(sum == expected_sum);
}

fn producer(queue: *BoundedBlockingQueue(i32, 10), id: usize, count: usize) void {
    for i in 0..count {
        queue.push(@intCast(i32, i));
    }
}

fn consumer(queue: *BoundedBlockingQueue(i32, 10), id: usize, count: usize, results: *std.ArrayList(i32)) void {
    for i in 0..count {
        const val = queue.pop();
        results.append(val) catch unreachable;
    }
}
