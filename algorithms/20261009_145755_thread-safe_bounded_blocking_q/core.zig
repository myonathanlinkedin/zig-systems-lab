const std = @import("std");
const Mutex = std.Thread.Mutex;
const Cond = std.Thread.Condition;

pub const QueueError = error{ Full, Empty };

pub fn BoundedBlockingQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        buf: []T,
        head: usize,
        tail: usize,
        count: usize,
        mutex: Mutex,
        not_full: Cond,
        not_empty: Cond,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            if (capacity == 0) return error.InvalidCapacity;
            const buf = try allocator.alloc(T, capacity);
            return Self{
                .buf = buf,
                .head = 0,
                .tail = 0,
                .count = 0,
                .mutex = Mutex{},
                .not_full = Cond{},
                .not_empty = Cond{},
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buf);
        }

        pub fn capacity(self: *const Self) usize {
            return self.buf.len;
        }

        pub fn len(self: *const Self) usize {
            return self.count;
        }

        pub fn isFull(self: *const Self) bool {
            return self.count == self.buf.len;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }

        /// Blocking enqueue. O(1). Waits on not_full when full.
        pub fn put(self: *Self, value: T) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.count == self.buf.len) {
                self.not_full.wait(&self.mutex);
            }
            self.buf[self.tail] = value;
            self.tail = (self.tail + 1) % self.buf.len;
            self.count += 1;
            self.not_empty.signal();
        }

        /// Blocking dequeue. O(1). Waits on not_empty when empty.
        pub fn get(self: *Self) !T {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (self.count == 0) {
                self.not_empty.wait(&self.mutex);
            }
            const value = self.buf[self.head];
            self.head = (self.head + 1) % self.buf.len;
            self.count -= 1;
            self.not_full.signal();
            return value;
        }

        /// Non-blocking enqueue. Returns Full if at capacity. O(1).
        pub fn tryPut(self: *Self, value: T) QueueError!void {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.count == self.buf.len) return QueueError.Full;
            self.buf[self.tail] = value;
            self.tail = (self.tail + 1) % self.buf.len;
            self.count += 1;
            self.not_empty.signal();
        }

        /// Non-blocking dequeue. Returns Empty if empty. O(1).
        pub fn tryGet(self: *Self) QueueError!T {
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.count == 0) return QueueError.Empty;
            const value = self.buf[self.head];
            self.head = (self.head + 1) % self.buf.len;
            self.count -= 1;
            self.not_full.signal();
            return value;
        }
    };
}
