const std = @import("std");
const types = @import("types.zig");

/// Push *value* into the ring buffer.
pub fn push(comptime T: type, rb: *types.RingBuffer(T), value: T) bool {
    const mask = rb.mask;
    // Load current head with acquire semantics.
    const head = rb.head.load(.Acquire);
    const tail = rb.tail.load(.Acquire);
    const next_head = (head + 1) & mask;

    // Full condition.
    if (next_head == tail) {
        return false;
    }

    // Write the value into the slot.
    rb.buffer[head] = value;

    // Publish the new head with release semantics.
    rb.head.store(next_head, .Release);
    return true;
}

/// Pop a value from the ring buffer into *out*.
/// Returns true on success, false if the buffer is empty.
pub fn pop(comptime T: type, rb: *types.RingBuffer(T), out: *T) bool {
    const mask = rb.mask;
    const head = rb.head.load(.Acquire);
    const tail = rb.tail.load(.Acquire);

    // Empty condition.
    if (tail == head) {
        return false;
    }

    // Read the value before moving the tail.
    out.* = rb.buffer[tail];

    const next_tail = (tail + 1) & mask;
    // Publish the new tail with release semantics.
    rb.tail.store(next_tail, .Release);
    return true;
}

/// Returns true if the buffer is empty.
pub fn isEmpty(comptime T: type, rb: *types.RingBuffer(T)) bool {
    return rb.head.load(.Acquire) == rb.tail.load(.Acquire);
}

/// Returns true if the buffer is full.
pub fn isFull(comptime T: type, rb: *types.RingBuffer(T)) bool {
    const mask = rb.mask;
    const head = rb.head.load(.Acquire);
    const tail = rb.tail.load(.Acquire);
    return ((head + 1) & mask) == tail;
}
