const std = @import("std");

pub fn BoundedBlockingQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]std.mem.MaybeUninit(T),
        head: usize = 0,
        tail: usize = 0,
        count: usize = 0,

        mutex: std.Thread.Mutex = .{},
        not_empty: std.Thread.Condition = .{},
        not_full: std.Thread.Condition = .{},

        pub fn init() Self {
            return Self{};
        }

        pub fn push(self: *Self, item: T) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == capacity) {
                self.not_full.wait(&self.mutex);
            }

            self.buffer[self.tail] = std.mem.MaybeUninit.init(item);
            self.tail = (self.tail + 1) % capacity;
            self.count += 1;

            self.not_empty.signal();
        }

        pub fn pop(self: *Self) T {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.count == 0) {
                self.not_empty.wait(&self.mutex);
            }

            const item = self.buffer[self.head].assumeInit();
            self.head = (self.head + 1) % capacity;
            self.count -= 1;

            self.not_full.signal();

            return item;
        }
    };
}
