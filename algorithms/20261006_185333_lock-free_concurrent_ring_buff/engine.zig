const std = @import("std");
const RingBuffer = @import("types.zig").RingBuffer;

/// Push a value into the ring buffer.
pub fn push(comptime T: type, comptime capacity: usize, rb: *RingBuffer(T, capacity), value: T) bool {
    const mask = rb.mask;
    while (true) {
        const tail = rb.tail.load(.SeqCst);
        const head = rb.head.load(.SeqCst);
        const next = (tail + 1) & mask;

        // Buffer full?
        if (next == head) {
            return false;
        }

        // Try to claim the slot.
        if (rb.tail.compareExchange(tail, next, .SeqCst, .SeqCst)) |_| {
            // Store after successful claim.
            rb.buffer[tail] = value;
            return true;
        }
        // CAS failed – retry.
    }
}

/// Pop a value from the ring buffer. Returns null if empty.
pub fn pop(comptime T: type, comptime capacity: usize, rb: *RingBuffer(T, capacity)) ?T {
    const mask = rb.mask;
    while (true) {
        const head = rb.head.load(.SeqCst);
        const tail = rb.tail.load(.SeqCst);

        // Buffer empty?
        if (head == tail) {
            return null;
        }

        const value = rb.buffer[head];
        const next = (head + 1) & mask;

        // Try to advance the head.
        if (rb.head.compareExchange(head, next, .SeqCst, .SeqCst)) |_| {
            return value;
        }
        // CAS failed – retry.
    }
}
