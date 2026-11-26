const std = @import("std");
const engine = @import("engine.zig");
const Queue = engine.Queue;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test 1: Basic enqueue/dequeue
    var q1 = try Queue.init(allocator, 5);
    defer q1.deinit();

    q1.enqueue(10);
    q1.enqueue(20);
    q1.enqueue(30);

    std.debug.assert(q1.dequeue() == 10);
    std.debug.assert(q1.dequeue() == 20);
    std.debug.assert(q1.dequeue() == 30);

    // Test 2: Multi-thread producers and consumers
    const num_items = 1000;
    const num_producers = 4;
    const num_consumers = 4;
    var total_produced: usize = 0;
    var total_consumed: usize = 0;

    var q2 = try Queue.init(allocator, 50);
    defer q2.deinit();

    var prod_threads: [num_producers]std.Thread = undefined;
    var cons_threads: [num_consumers]std.Thread = undefined;

    // Producer function
    const Producer = struct {
        q: *Queue,
        start: usize,
        count: usize,
        produced: *std.atomic.Atomic(usize),
    };
    const producer_fn = struct {
        pub fn run(ctx: *anyopaque) void {
            const p = @ptrCast(*Producer, ctx);
            for (p.start .. p.start + p.count) |i| {
                p.q.enqueue(@intCast(i));
                p.produced.fetchAdd(1, .SeqCst);
            }
        }
    };

    // Consumer function
    const Consumer = struct {
        q: *Queue,
        consumed: *std.atomic.Atomic(usize),
    };
    const consumer_fn = struct {
        pub fn run(ctx: *anyopaque) void {
            const c = @ptrCast(*Consumer, ctx);
            while (true) {
                const val = c.q.dequeue();
                _ = val; // value used only for consumption
                c.consumed.fetchAdd(1, .SeqCst);
                if (c.consumed.load(.SeqCst) >= num_items) break;
            }
        }
    };

    var prod_ctxs: [num_producers]Producer = undefined;
    var cons_ctxs: [num_consumers]Consumer = undefined;

    var produced_atomic = std.atomic.Atomic(usize).init(0);
    var consumed_atomic = std.atomic.Atomic(usize).init(0);

    // Start consumers
    for (cons_threads) |*t, idx| {
        cons_ctxs[idx] = Consumer{
            .q = &q2,
            .consumed = &consumed_atomic,
        };
        t.* = try std.Thread.spawn(.{}, consumer_fn.run, &cons_ctxs[idx]);
    }

    // Start producers
    const items_per_producer = num_items / num_producers;
    for (prod_threads) |*t, idx| {
        prod_ctxs[idx] = Producer{
            .q = &q2,
            .start = idx * items_per_producer,
            .count = items_per_producer,
            .produced = &produced_atomic,
        };
        t.* = try std.Thread.spawn(.{}, producer_fn.run, &prod_ctxs[idx]);
    }

    // Wait for producers
    for (prod_threads) |t| {
        t.join();
    }

    // Wait for consumers
    for (cons_threads) |t| {
        t.join();
    }

    std.debug.assert(produced_atomic.load(.SeqCst) == num_items);
    std.debug.assert(consumed_atomic.load(.SeqCst) == num_items);

    // Test 3: Blocking behavior
    var q3 = try Queue.init(allocator, 1);
    defer q3.deinit();

    var block_test_done = std.atomic.Atomic(bool).init(false);

    // Consumer that will block until item is enqueued
    const block_consumer = struct {
        pub fn run(ctx: *anyopaque) void {
            const q = @ptrCast(*Queue, ctx);
            const val = q.dequeue();
            std.debug.assert(val == 42);
            block_test_done.store(true, .SeqCst);
        }
    };

    var consumer_thread = try std.Thread.spawn(.{}, block_consumer.run, &q3);

    // Sleep briefly to ensure consumer is blocked
    std.time.sleep(10 * std.time.ns_per_ms);

    // Producer enqueues item
    q3.enqueue(42);

    // Wait for consumer to finish
    consumer_thread.join();

    std.debug.assert(block_test_done.load(.SeqCst));

    // Test 4: Enqueue blocks when full
    var q4 = try Queue.init(allocator, 2);
    defer q4.deinit();

    var enqueue_blocked = std.atomic.Atomic(bool).init(false);
    var enqueue_done = std.atomic.Atomic(bool).init(false);

    // Fill queue
    q4.enqueue(1);
    q4.enqueue(2);

    // Thread that attempts to enqueue third item and should block
    const block_enqueue = struct {
        pub fn run(ctx: *anyopaque) void {
            const q = @ptrCast(*Queue, ctx);
            // Mark that we are about to block
            enqueue_blocked.store(true, .SeqCst);
            q.enqueue(3);
            enqueue_done.store(true, .SeqCst);
        }
    };

    var enqueue_thread = try std.Thread.spawn(.{}, block_enqueue.run, &q4);

    // Wait a bit to confirm blocking
    std.time.sleep(10 * std.time.ns_per_ms);
    std.debug.assert(enqueue_blocked.load(.SeqCst));
    std.debug.assert(!enqueue_done.load(.SeqCst));

    // Dequeue one item to free space
    const val = q4.dequeue();
    std.debug.assert(val == 1);

    // Wait for enqueue thread to finish
    enqueue_thread.join();
    std.debug.assert(enqueue_done.load(.SeqCst));

    // Final state: queue should contain 2 and 3
    std.debug.assert(q4.dequeue() == 2);
    std.debug.assert(q4.dequeue() == 3);

    // All tests passed
    std.debug.print("All tests passed.\n", .{});
}
