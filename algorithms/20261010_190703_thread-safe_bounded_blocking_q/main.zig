const std = @import("std");
const BoundedQueue = @import("core.zig").BoundedQueue;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // ---------- Test 1: single‑thread push/pop ----------
    {
        var q = try BoundedQueue(i32).init(allocator, 4);
        defer q.deinit();

        q.push(10);
        q.push(20);
        const a = q.pop();
        const b = q.pop();
        std.debug.assert(a == 10);
        std.debug.assert(b == 20);
    }

    // ---------- Test 2: producer‑consumer with two threads ----------
    {
        const N = 1000;
        var q = try BoundedQueue(i32).init(allocator, 8);
        defer q.deinit();

        var out_buf = try allocator.alloc(i32, N);
        defer allocator.free(out_buf);
        var out_idx: usize = 0;
        var out_mutex = std.sync.Mutex{};

        const ProducerCtx = struct {
            queue: *BoundedQueue(i32),
            start: usize,
            end: usize,
        };
        const ConsumerCtx = struct {
            queue: *BoundedQueue(i32),
            out: []i32,
            idx: *usize,
            idx_mutex: *std.sync.Mutex,
        };

        fn producer(arg: ?*anyopaque) void {
            const ctx = @ptrCast(*ProducerCtx, arg);
            var i = ctx.start;
            while (i < ctx.end) : (i += 1) {
                ctx.queue.push(@intCast(i32, i));
            }
        }

        fn consumer(arg: ?*anyopaque) void {
            const ctx = @ptrCast(*ConsumerCtx, arg);
            var i: usize = 0;
            while (i < ctx.out.len) : (i += 1) {
                const v = ctx.queue.pop();
                ctx.idx_mutex.lock();
                ctx.out[*ctx.idx] = v;
                *ctx.idx += 1;
                ctx.idx_mutex.unlock();
            }
        }

        var prod_ctx = ProducerCtx{
            .queue = &q,
            .start = 0,
            .end = N,
        };
        var cons_ctx = ConsumerCtx{
            .queue = &q,
            .out = out_buf,
            .idx = &out_idx,
            .idx_mutex = &out_mutex,
        };

        const prod_thread = try std.Thread.spawn(.{}, producer, &prod_ctx);
        const cons_thread = try std.Thread.spawn(.{}, consumer, &cons_ctx);
        prod_thread.wait();
        cons_thread.wait();

        // Verify FIFO order
        var i: usize = 0;
        while (i < N) : (i += 1) {
            std.debug.assert(out_buf[i] == @intCast(i32, i));
        }
    }

    // ---------- Test 3: blocking behaviour ----------
    {
        var q = try BoundedQueue(i32).init(allocator, 1);
        defer q.deinit();

        const start = std.time.milliTimestamp();

        // Producer will attempt to push two items; the second push must block until consumer pops.
        const ProducerCtx = struct {
            queue: *BoundedQueue(i32),
        };
        fn producer(arg: ?*anyopaque) void {
            const ctx = @ptrCast(*ProducerCtx, arg);
            ctx.queue.push(1); // fills the queue
            ctx.queue.push(2); // should block until a pop occurs
        }

        const ConsumerCtx = struct {
            queue: *BoundedQueue(i32),
        };
        fn consumer(arg: ?*anyopaque) void {
            const ctx = @ptrCast(*ConsumerCtx, arg);
            std.time.sleep(50_000_000); // 50 ms
            const _ = ctx.queue.pop(); // frees space for second push
        }

        var prod_ctx = ProducerCtx{ .queue = &q };
        var cons_ctx = ConsumerCtx{ .queue = &q };

        const prod_thread = try std.Thread.spawn(.{}, producer, &prod_ctx);
        const cons_thread = try std.Thread.spawn(.{}, consumer, &cons_ctx);
        prod_thread.wait();
        cons_thread.wait();

        const elapsed = std.time.milliTimestamp() - start;
        // The elapsed time must be at least the consumer's sleep (≈50 ms)
        std.debug.assert(elapsed >= 45);
    }
}
