const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    // Capacity must be a power of two to enable efficient masking.
    if ((capacity & (capacity - 1)) != 0) {
        @compileError("capacity must be a power of two");
    }

    return struct {
        const Self = @This();

        buffer: [capacity]T,
        head: std.atomic.AtomicUsize,
        tail: std.atomic.AtomicUsize,

        pub fn init() Self {
            return Self{
                .buffer = @as([capacity]T, undefined),
                .head = std.atomic.AtomicUsize.init(0),
                .tail = std.atomic.AtomicUsize.init(0),
            };
        }

        fn mask() usize {
            return capacity - 1;
        }

        pub fn isFull(self: *Self) bool {
            const head = self.head.load(.Relaxed);
            const tail = self.tail.load(.Acquire);
            return ((head + 1) & mask()) == (tail & mask());
        }

        pub fn isEmpty(self: *Self) bool {
            const head = self.head.load(.Acquire);
            const tail = self.tail.load(.Relaxed);
            return (head & mask()) == (tail & mask());
        }

        pub fn push(self: *Self, value: T) bool {
            const head = self.head.load(.Relaxed);
            const next = (head + 1) & mask();
            const tail = self.tail.load(.Acquire);
            if (next == (tail & mask())) {
                return false; // buffer full
            }
            self.buffer[head & mask()] = value;
            self.head.store(next, .Release);
            return true;
        }

        pub fn pop(self: *Self) ?T {
            const tail = self.tail.load(.Relaxed);
            const head = self.head.load(.Acquire);
            if ((tail & mask()) == (head & mask())) {
                return null; // buffer empty
            }
            const value = self.buffer[tail & mask()];
            const next = (tail + 1) & mask();
            self.tail.store(next, .Release);
            return value;
        }

        pub fn len(self: *Self) usize {
            const head = self.head.load(.Relaxed);
            const tail = self.tail.load(.Relaxed);
            return (head + capacity - tail) % capacity;
        }
    };
}
