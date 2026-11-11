const std = @import("std");
const core = @import("core.zig");

pub const SharedContext = struct {
    counter: usize = 0,
};

pub const CounterTaskState = struct {
    limit: usize,
    current: usize = 0,
    ctx: *SharedContext,
};

fn counterTaskFn(task: *core.Task) bool {
    const state = @ptrCast(*CounterTaskState, task.data.?);
    if (state.current >= state.limit) return true;
    state.ctx.counter += 1;
    state.current += 1;
    return false;
}

fn immediateTaskFn(task: *core.Task) bool {
    _ = task;
    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = gpa.allocator();

    var ctx = SharedContext{};

    var scheduler = core.Scheduler.init(allocator);
    defer scheduler.deinit();

    // ---- Test: no tasks ----
    scheduler.run();
    std.debug.assert(ctx.counter == 0);

    // ---- Test: immediate (zero‑work) task ----
    const immTask = core.Task{
        .id = 1,
        .func = immediateTaskFn,
        .data = null,
    };
    try scheduler.addTask(immTask);
    scheduler.run();
    std.debug.assert(ctx.counter == 0);
    std.debug.assert(scheduler.tasks.len == 0);

    // ---- Test: two cooperative counter tasks ----
    var state1 = CounterTaskState{ .limit = 3, .ctx = &ctx };
    const task1 = core.Task{
        .id = 2,
        .func = counterTaskFn,
        .data = @ptrCast(?*anyopaque, &state1),
    };
    try scheduler.addTask(task1);

    var state2 = CounterTaskState{ .limit = 5, .ctx = &ctx };
    const task2 = core.Task{
        .id = 3,
        .func = counterTaskFn,
        .data = @ptrCast(?*anyopaque, &state2),
    };
    try scheduler.addTask(task2);

    scheduler.run();

    // Expected total increments: 3 + 5 = 8
    std.debug.assert(ctx.counter == 8);
    std.debug.assert(scheduler.tasks.len == 0);
}
