const std = @import("std");
const RingBuffer = @import("core.zig").RingBuffer;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const capacity = 16;
    var rb = try RingBuffer(u32).init(allocator, capacity);
    defer rb.deinit(allocator);

    // Single-threaded tests
    std.debug.assert(rb.push(42));
    std.debug.assert(rb.push(43));
    std.debug.assert(rb.pop().? == 42);
    std.debug.assert(rb.pop().? == 43);
    std.debug.assert(rb.pop() == null);

    // Fill buffer
    for (0..capacity) |i| {
        std.debug.assert(rb.push(@intCast(u32, i)));
    }
    std.debug.assert(!rb.push(999)); // should be full

    // Empty buffer
    for (0..capacity) |i| {
        const val = rb.pop().?;
        std.debug.assert(val == @intCast(u32, i));
    }
    std.debug.assert(rb.pop() == null);

    // Multi-threaded test
    const num_threads = 4;
    const items_per_thread = 1000;
    const total_items = num_threads * items_per_thread;

    var prod_done = std.atomic.Atomic(u32).init(0);
    var cons_done = std.atomic.Atomic(u32).init(0);
    var sum = std.atomic.Atomic(u64).init(0);

    // Producer function
    const Producer = struct {
        fn run(arg: ?*anyopaque) void {
            const rb_ptr = @ptrCast(*RingBuffer(u32), @alignCast(@alignOf(RingBuffer(u32)), arg.?));
            var i: u32 = 0;
            while (i < items_per_thread) : (i += 1) {
                while (!rb_ptr.push(i)) {}
            }
            prod_done.fetchAdd(1, .SeqCst);
        }
    };

    // Consumer function
    const Consumer = struct {
        fn run(arg: ?*anyopaque) void {
            const rb_ptr = @ptrCast(*RingBuffer(u32), @alignCast(@alignOf(RingBuffer(u32)), arg.?));
            var local_sum: u64 = 0;
            while (true) {
                if (cons_done.load(.SeqCst) == num_threads and rb_ptr.pop() == null) {
                    break;
                }
                if (rb_ptr.pop()) |v| {
                    local_sum += v;
                }
            }
            sum.fetchAdd(local_sum, .SeqCst);
            cons_done.fetchAdd(1, .SeqCst);
        }
    };

    var threads: [num_threads]std.Thread = undefined;
    // Start producers
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, Producer.run, &rb);
    }
    // Start consumers
    for (0..num_threads) |i| {
        threads[i + num_threads] = try std.Thread.spawn(.{}, Consumer.run, &rb);
    }

    // Wait for all threads
    for (threads) |t| {
        t.join();
    }

    // Verify all items processed
    const expected_sum = @intCast(u64, (items_per_thread * (items_per_thread - 1)) / 2) * @intCast(u64, num_threads);
    std.debug.assert(sum.load(.SeqCst) == expected_sum);
}
