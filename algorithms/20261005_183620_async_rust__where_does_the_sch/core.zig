const std = @import("std");

pub const Task = struct {
    fn_ptr: fn (*anyopaque) void,
    ctx: *anyopaque,
};

pub const Scheduler = struct {
    queue: std.fifo.LinearFifo(Task, .{ .allocator = std.heap.page_allocator, .capacity = 1024 }),

    pub fn init() Scheduler {
        var self = Scheduler{};
        self.queue.init(std.heap.page_allocator);
        return self;
    }

    pub fn spawn(self: *Scheduler, fn_ptr: fn (*anyopaque) void, ctx: *anyopaque) void {
        const task = Task{ .fn_ptr = fn_ptr, .ctx = ctx };
        self.queue.append(task) catch unreachable;
    }

    pub fn run(self: *Scheduler) void {
        while (self.queue.popOrNull()) |task| {
            task.fn_ptr(task.ctx);
        }
    }
};
