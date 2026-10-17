const std = @import("std");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        buffer: []T,
        head: usize,
        tail: usize,
        count: usize,
        capacity: usize,

        pub fn init(allocator: *std.mem.Allocator, capacity: usize) !RingBuffer(T) {
            var buf = try allocator.alloc(T, capacity);
            return RingBuffer(T){
                .allocator = allocator,
                .buffer = buf,
                .head = 0,
                .tail = 0,
                .count = 0,
                .capacity = capacity,
            };
        }

        pub fn deinit(self: *RingBuffer(T)) void {
            self.allocator.free(self.buffer);
        }

        pub fn push(self: *RingBuffer(T), item: T) bool {
            if (self.is_full()) return false;
            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % self.capacity;
            self.count += 1;
            return true;
        }

        pub fn pop(self: *RingBuffer(T)) ?T {
            if (self.is_empty()) return null;
            const item = self.buffer[self.head];
            self.head = (self.head + 1) % self.capacity;
            self.count -= 1;
            return item;
        }

        pub fn is_empty(self: *const RingBuffer(T)) bool {
            return self.count == 0;
        }

        pub fn is_full(self: *const RingBuffer(T)) bool {
            return self.count == self.capacity;
        }

        pub fn len(self: *const RingBuffer(T)) usize {
            return self.count;
        }

        pub fn cap(self: *const RingBuffer(T)) usize {
            return self.capacity;
        }
    };
}
