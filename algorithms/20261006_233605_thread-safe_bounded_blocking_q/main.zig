const std = @import("std");
const core = @import("core.zig");
const BoundedBlockingQueue = core.BoundedBlockingQueue;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test 1: Basic initialization and capacity
    {
        var queue = try BoundedBlockingQueue.init(allocator, 5);
        defer queue.deinit(allocator);

        std.debug.assert(queue.capacity == 5);
        std.debug.assert(queue.is_empty());
        std.debug.assert(!queue.is_full());
        std.debug.assert(queue.len() == 0);
    }

    // Test 2: Push and pop operations
    {
        var queue = try BoundedBlockingQueue.init(allocator, 3);
        defer queue.deinit(allocator);

        try queue.push(10);
        try queue.push(20);
        try queue.push(30);

        std.debug.assert(queue.len() == 3);
        std.debug.assert(queue.is_full());

        const val1 = try queue.pop();
        const val2 = try queue.pop();
        const val3 = try queue.pop();

        std.debug.assert(val1 == 10);
        std.debug.assert(val2 == 20);
        std.debug.assert(val3 == 30);
        std.debug.assert(queue.is_empty());
    }

    // Test 3: Try push/pop non-blocking operations
    {
        var queue = try BoundedBlockingQueue.init(allocator, 2);
        defer queue.deinit(allocator);

        std.debug.assert(queue.try_push(100));
        std.debug.assert(queue.try_push(200));
        std.debug.assert(!queue.try_push(300)); // Should fail, queue is full

        std.debug.assert(queue.len() == 2);

        const v1 = queue.try_pop();
        const v2 = queue.try_pop();
        const v3 = queue.try_pop();

        std.debug.assert(v1 == 100);
        std.debug.assert(v2 == 200);
        std.debug.assert(v3 == null); // Should be null, queue is empty
    }

    // Test 4: Circular buffer behavior (wrap-around)
    {
        var queue = try BoundedBlockingQueue.init(allocator, 3);
        defer queue.deinit(allocator);

        // Fill and empty multiple times to test wrap-around
        for (0..10) |i| {
            try queue.push(i);
            const val = try queue.pop();
            std.debug.assert(val == i);
        }

        std.debug.assert(queue.is_empty());
    }

    // Test 5: Multi-threaded producer-consumer test
    {
        var queue = try BoundedBlockingQueue.init(allocator, 10);
        defer queue.deinit(allocator);

        const num_producers = 4;
        const num_consumers = 4;
        const items_per_producer = 100;
        const total_items = num_producers * items_per_producer;

        var producer_results: [num_producers]usize = undefined;
        var consumer_results: [num_consumers]usize = undefined;

        const producer_thread = try std.Thread.spawn(.{}, producer_fn, .{ &queue, &producer_results, items_per_producer });
        const consumer_thread = try std.Thread.spawn(.{}, consumer_fn, .{ &queue, &consumer_results, total_items });

        // Spawn multiple producers
        var producer_threads: [num_producers - 1]std.Thread = undefined;
        for (1..num_producers) |i| {
            producer_threads[i - 1] = try std.Thread.spawn(.{}, producer_fn, .{ &queue, &producer_results, items_per_producer });
        }

        // Spawn multiple consumers
        var consumer_threads: [num_consumers - 1]std.Thread = undefined;
        for (1..num_consumers) |i| {
            consumer_threads[i - 1] = try std.Thread.spawn(.{}, consumer_fn, .{ &queue, &consumer_results, total_items });
        }

        // Wait for all threads to complete
        producer_thread.join();
        consumer_thread.join();
        for (producer_threads) |t| t.join();
        for (consumer_threads) |t| t.join();

        // Verify all items were produced and consumed
        var total_produced: usize = 0;
        for (producer_results) |r| total_produced += r;
        var total_consumed: usize = 0;
        for (consumer_results) |r| total_consumed += r;

        std.debug.assert(total_produced == total_items);
        std.debug.assert(total_consumed == total_items);
        std.debug.assert(queue.is_empty());
    }

    // Test 6: Blocking behavior verification
    {
        var queue = try BoundedBlockingQueue.init(allocator, 1);
        defer queue.deinit(allocator);

        // Push one item
        try queue.push(42);

        // Try to push another - should block until we pop
        const push_thread = try std.Thread.spawn(.{}, blocking_push_fn, .{ &queue, 99 });

        // Give the push thread time to block
        std.Thread.sleep(10_000_000); // 10ms

        // Pop the first item, which should unblock the push
        const val = try queue.pop();
        std.debug.assert(val == 42);

        // Wait for push thread to complete
        push_thread.join();

        // Now the queue should have the second item
        const val2 = try queue.pop();
        std.debug.assert(val2 == 99);
    }

    // Test 7: Edge case - capacity of 1
    {
        var queue = try BoundedBlockingQueue.init(allocator, 1);
        defer queue.deinit(allocator);

        try queue.push(1);
        std.debug.assert(queue.is_full());

        const val = try queue.pop();
        std.debug.assert(val == 1);
        std.debug.assert(queue.is_empty());
    }

    // Test 8: Invalid capacity
    {
        const result = BoundedBlockingQueue.init(allocator, 0);
        std.debug.assert(result == error.InvalidCapacity);
    }

    std.debug.print("All tests passed!\n", .{});
}

fn producer_fn(queue: *BoundedBlockingQueue, results: *[]usize, items_per_producer: usize) void {
    // Each producer pushes items_per_producer items
    // We use a simple counter to track how many this producer pushed
    var count: usize = 0;
    for (0..items_per_producer) |i| {
        queue.push(i) catch |err| {
            std.debug.print("Producer error: {}\n", .{err});
            return;
        };
        count += 1;
    }
    // Store the count in the first available slot (simplified for test)
    // In a real scenario, we'd need thread-safe aggregation
    if (results.len > 0) {
        results[0] += count;
    }
}

fn consumer_fn(queue: *BoundedBlockingQueue, results: *[]usize, total_items: usize) void {
    // Each consumer pops until no more items
    var count: usize = 0;
    while (count < total_items) {
        const val = queue.pop() catch |err| {
            std.debug.print("Consumer error: {}\n", .{err});
            return;
        };
        _ = val;
        count += 1;
    }
    if (results.len > 0) {
        results[0] += count;
    }
}

fn blocking_push_fn(queue: *BoundedBlockingQueue, value: usize) void {
    queue.push(value) catch |err| {
        std.debug.print("Blocking push error: {}\n", .{err});
    };
}
