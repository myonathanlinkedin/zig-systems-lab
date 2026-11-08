const std = @import("std");

// Utility to check power of two at compile time
fn isPowerOfTwo(comptime n: usize) bool {
    return n != 0 and (n & (n - 1)) == 0;
}

// Generic single‑producer single‑consumer lock‑free ring buffer
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    comptime {
        // Capacity must be a power of two for mask‑based indexing
        if (!isPowerOfTwo(capacity)) {
            @compileError("RingBuffer capacity must be a power of two");
        }
    }

    const Mask = capacity - 1;

    return struct {
        // Underlying storage; aligned for any type
        buffer: [capacity]T align(@alignOf(T)) = undefined,

        // Head (write) and tail (read) indices – atomic for lock‑free SPSC
        head: std.atomic.AtomicUsize = .{ .value = 0 },
        tail: std.atomic.AtomicUsize = .{ .value = 0 },

        // Initialize the buffer (zero‑initialize elements if possible)
        pub fn init() RingBuffer {
            var self: RingBuffer = .{};
            // Zero‑initialize if T is a zero‑able type
            if (@typeInfo(T) != .Void) {
                for (self.buffer) |*slot| {
                    slot.* = undefined;
                }
            }
            return self;
        }

        // Number of elements currently stored
        pub fn len(self: *RingBuffer) usize {
            const h = self.head.load(.Acquire);
            const t = self.tail.load(.Acquire);
            return h -% t;
        }

        // Maximum capacity (always the compile‑time constant)
        pub const max_capacity = capacity;

        // True if buffer is empty
        pub fn isEmpty(self: *RingBuffer) bool {
            return self.len() == 0;
        }

        // True if buffer is full (len == capacity)
        pub fn isFull(self: *RingBuffer) bool {
            return self.len() == capacity;
        }

        // Push a value; returns true on success, false if full
        pub fn push(self: *RingBuffer, value: T) bool {
            const h = self.head.load(.Relaxed);
            const t = self.tail.load(.Acquire);
            if ((h -% t) == capacity) {
                // Full
                return false;
            }
            const idx = h & Mask;
            self.buffer[idx] = value;
            // Ensure the write to buffer happens before publishing the new head
            std.atomic.fence(.Release);
            self.head.store(h +% 1, .Release);
            return true;
        }

        // Pop a value; returns true on success, false if empty
        pub fn pop(self: *RingBuffer, out: *T) bool {
            const t = self.tail.load(.Relaxed);
            const h = self.head.load(.Acquire);
            if ((h -% t) == 0) {
                // Empty
                return false;
            }
            const idx = t & Mask;
            out.* = self.buffer[idx];
            // Ensure the read of buffer happens before advancing tail
            std.atomic.fence(.Release);
            self.tail.store(t +% 1, .Release);
            return true;
        }

        // Peek at the next element without removing; returns true on success
        pub fn peek(self: *RingBuffer, out: *T) bool {
            const t = self.tail.load(.Acquire);
            const h = self.head.load(.Acquire);
            if ((h -% t) == 0) {
                return false;
            }
            const idx = t & Mask;
            out.* = self.buffer[idx];
            return true;
        }
    };
}
