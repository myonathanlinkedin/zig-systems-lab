const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    // Capacity must be a power of two and greater than zero for mask optimization.
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("RingBuffer capacity must be a non‑zero power of two");
        }
    }

    return struct {
        const Self = @This();
        const Mask = capacity - 1;

        // Fixed storage; undefined values are acceptable because the buffer
        // tracks valid elements via head/tail indices.
        buffer: [capacity]T,
        // Head points to the next element to read, tail points to the next slot to write.
        // Using atomics enables lock‑free single‑producer / single‑consumer usage.
        head: std.atomic.AtomicUsize = std.atomic.AtomicUsize.init(0),
        tail: std.atomic.AtomicUsize = std.atomic.AtomicUsize.init(0),

        /// Initialise a new ring buffer. All indices start at zero.
        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = std.atomic.AtomicUsize.init(0),
                .tail = std.atomic.AtomicUsize.init(0),
            };
        }

        /// Attempt to push an item into the buffer.
        /// Returns `true` on success, `false` if the buffer is full.
        pub fn push(self: *Self, item: T) bool {
            const tail = self.tail.load(.Acquire);
            const head = self.head.load(.Relaxed);
            if ((tail - head) == capacity) {
                // Buffer full.
                return false;
            }
            self.buffer[tail & Mask] = item;
            // Release stores ensure the item is visible before the tail advances.
            self.tail.store(tail + 1, .Release);
            return true;
        }

        /// Attempt to pop an item from the buffer.
        /// Returns `null` if the buffer is empty.
        pub fn pop(self: *Self) ?T {
            const head = self.head.load(.Acquire);
            const tail = self.tail.load(.Relaxed);
            if (head == tail) {
                // Buffer empty.
                return null;
            }
            const item = self.buffer[head & Mask];
            self.head.store(head + 1, .Release);
            return item;
        }

        /// Returns `true` if the buffer contains no elements.
        pub fn isEmpty(self: *Self) bool {
            return self.head.load(.Relaxed) == self.tail.load(.Relaxed);
        }

        /// Returns `true` if the buffer holds `capacity` elements.
        pub fn isFull(self: *Self) bool {
            return (self.tail.load(.Relaxed) - self.head.load(.Relaxed)) == capacity;
        }

        /// Current number of stored elements.
        pub fn len(self: *Self) usize {
            return self.tail.load(.Relaxed) - self.head.load(.Relaxed);
        }
    };
}
