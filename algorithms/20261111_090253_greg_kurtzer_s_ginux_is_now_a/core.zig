const std = @import("std");

pub const TaskFn = fn (*Task) bool;

pub const Task = struct {
    id: usize,
    func: TaskFn,
    data: ?*anyopaque,
};

pub const Scheduler = struct {
    tasks: std.ArrayList(Task),

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return Scheduler{
            .tasks = std.ArrayList(Task).init(allocator),
        };
    }

    pub fn deinit(self: *Scheduler) void {
        self.tasks.deinit();
    }

    pub fn addTask(self: *Scheduler, task: Task) !void {
        try self.tasks.append(task);
    }

    pub fn run(self: *Scheduler) void {
        var i: usize = 0;
        while (self.tasks.len > 0) {
            const task = &self.tasks.items[i];
            const finished = task.func(task);
            if (finished) {
                // Remove current task by swapping with the last element.
                self.tasks.swapRemove(i);
                if (self.tasks.len == 0) break;
                // i stays the same because a new task is now at position i.
            } else {
                i = (i + 1) % self.tasks.len;
            }
        }
    }
};
