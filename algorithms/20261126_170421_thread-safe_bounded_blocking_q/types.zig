const std = @import("std");

pub fn BoundedBlockingQueue(comptime T: type) type {
    return struct {
        capacity: usize,
        buffer: []T,
        head: usize,
        tail: usize,
        count: usize,
        mutex: std.sync.Mutex,
        not_empty: std.sync.Cond,
        not_full: std.sync.Cond,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !BoundedBlockingQueue {
            std.debug.assert(capacity > 0);
            var buf = try allocator.alloc(T, capacity);
            return BoundedBlockingQueue{
                .capacity = capacity,
                .buffer = buf,
                .head = 0,
                .tail = 0,
                .count = 0,
                .mutex = std.sync.Mutex{},
                .not_empty = std.sync.Cond{},
                .not_full = std.sync.Cond{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *BoundedBlockingQueue) void {
            self.allocator.free(self.buffer);
        }

        pub fn enqueue(self: *BoundedBlockingQueue, item: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == self.capacity) {
                self.not_full.wait(&self.mutex);
            }

            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % self.capacity;
            self.count += 1;

            self.not_empty.signal();
        }

        pub fn dequeue(self: *BoundedBlockingQueue) T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == 0) {
                self.not_empty.wait(&self.mutex);
            }

            const item = self.buffer[self.head];
            self.head = (self.head + 1) % self.capacity;
            self.count -= 1;

            self.not_full.signal();
            return item;
        }
    };
}
