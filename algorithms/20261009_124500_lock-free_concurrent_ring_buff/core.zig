const std = @import("std");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []T,
        mask: usize,
        head: std.atomic.AtomicUsize,
        tail: std.atomic.AtomicUsize,

        pub const Error = error{ NotPowerOfTwo };

        /// Initialize a ring buffer with *capacity* slots.
        /// *capacity* must be a power of two.
        pub fn init(allocator: *std.mem.Allocator, capacity: usize) !Self {
            if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
                return Error.NotPowerOfTwo;
            }
            var buf = try allocator.alloc(T, capacity);
            return Self{
                .buffer = buf,
                .mask = capacity - 1,
                .head = std.atomic.AtomicUsize.init(0),
                .tail = std.atomic.AtomicUsize.init(0),
            };
        }

        /// Release the underlying storage.
        pub fn deinit(self: *Self, allocator: *std.mem.Allocator) void {
            allocator.free(self.buffer);
        }

        /// Attempt to enqueue *value*.
        /// Returns `true` on success, `false` if the buffer is full.
        pub fn push(self: *Self, value: T) bool {
            var tail = self.tail.load(.Relaxed);
            var head = self.head.load(.Acquire);
            if ((tail + 1) & self.mask == head) {
                return false; // full
            }
            self.buffer[tail & self.mask] = value;
            // Ensure the write to the buffer happens before publishing the new tail.
            self.tail.store(tail + 1, .Release);
            return true;
        }

        /// Attempt to dequeue an element.
        /// Returns `null` if the buffer is empty.
        pub fn pop(self: *Self) ?T {
            var head = self.head.load(.Relaxed);
            var tail = self.tail.load(.Acquire);
            if (head == tail) {
                return null; // empty
            }
            const value = self.buffer[head & self.mask];
            // Ensure the read of the element happens before advancing the head.
            self.head.store(head + 1, .Release);
            return value;
        }
    };
}
