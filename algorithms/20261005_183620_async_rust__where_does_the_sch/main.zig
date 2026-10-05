const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var scheduler = core.Scheduler.init();

    // Counter structure to test scheduler
    const Counter = struct {
        value: usize,
        limit: usize,
        scheduler: *core.Scheduler,
    };

    // Task function that increments counter and reschedules itself
    fn counterTask(ctx: *anyopaque) void {
        var counter = @ptrCast(*Counter, ctx);
        counter.value += 1;
        std.debug.print("Counter: {}\n", .{counter.value});
        if (counter.value < counter.limit) {
            counter.scheduler.spawn(counterTask, ctx);
        }
    }

    // Initialize counter and spawn first task
    var counter = Counter{
        .value = 0,
        .limit = 10,
        .scheduler = &scheduler,
    };
    scheduler.spawn(counterTask, &counter);

    // Run scheduler
    scheduler.run();

    // Assert final counter value
    std.debug.assert(counter.value == counter.limit);

    // Benchmark: run scheduler with many tasks
    const bench_tasks = 1000;
    var bench_counter = Counter{
        .value = 0,
        .limit = bench_tasks,
        .scheduler = &scheduler,
    };
    scheduler.spawn(counterTask, &bench_counter);

    const start = std.time.nanoTimestamp();
    scheduler.run();
    const elapsed = std.time.nanoTimestamp() - start;
    std.debug.print("Benchmark: {} tasks in {} ns\n", .{ bench_tasks, elapsed });

    // Unit test: ensure scheduler empties queue
    std.debug.assert(scheduler.queue.count() == 0);
}
