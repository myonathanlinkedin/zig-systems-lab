const std = @import("std");
const types = @import("types.zig");

pub const AtomicEngine = struct {
    counter: types.AtomicCounter,
    flag: types.AtomicFlag,
    queue: types.AtomicQueue,

    pub fn init(queue_capacity: usize) AtomicEngine {
        return .{
            .counter = types.AtomicCounter.init(0),
            .flag = types.AtomicFlag.init(),
            .queue = types.AtomicQueue.init(queue_capacity),
        };
    }

    pub fn deinit(self: *AtomicEngine) void {
        self.queue.deinit();
    }

    pub fn increment(self: *AtomicEngine) i64 {
        return self.counter.fetchAdd(1);
    }

    pub fn decrement(self: *AtomicEngine) i64 {
        return self.counter.fetchSub(1);
    }

    pub fn getCounterValue(self: *const AtomicEngine) i64 {
        return self.counter.load();
    }

    pub fn setFlag(self: *AtomicEngine) void {
        self.flag.set();
    }

    pub fn clearFlag(self: *AtomicEngine) void {
        self.flag.clear();
    }

    pub fn isFlagSet(self: *const AtomicEngine) bool {
        return self.flag.isSet();
    }

    pub fn testAndSetFlag(self: *AtomicEngine) bool {
        return self.flag.testAndSet();
    }

    pub fn enqueue(self: *AtomicEngine, item: usize) bool {
        return self.queue.push(item);
    }

    pub fn dequeue(self: *AtomicEngine) ?usize {
        return self.queue.pop();
    }

    pub fn isQueueEmpty(self: *const AtomicEngine) bool {
        return self.queue.isEmpty();
    }

    pub fn isQueueFull(self: *const AtomicEngine) bool {
        return self.queue.isFull();
    }

    pub fn simulateConcurrentIncrements(self: *AtomicEngine, iterations: i64) i64 {
        var total: i64 = 0;
        for (0..iterations) |_| {
            total += self.increment();
        }
        return total;
    }

    pub fn simulateQueueOperations(self: *AtomicEngine, num_items: usize) !void {
        for (0..num_items) |i| {
            if (!self.enqueue(i)) {
                return error.QueueFull;
            }
        }

        for (0..num_items) |i| {
            const item = self.dequeue() orelse return error.QueueEmpty;
            if (item != i) {
                return error.ItemMismatch;
            }
        }
    }
};
