const std = @import("std");

pub const RingBuffer = struct {
    const Self = @This();

    pub const Error = error{
        BufferFull,
        BufferEmpty,
    };

    // Compile‑time check: capacity must be a power of two and at least 2.
    comptime {
        if (capacity < 2) @compileError("capacity must be >= 2");
        if ((capacity & (capacity - 1)) != 0) @compileError("capacity must be a power of two");
    }

    // Generic parameters
    pub fn init(comptime T: type, comptime capacity: usize) Self {
        return Self{
            .buffer = undefined,
            .head = std.atomic.AtomicUsize.init(0),
            .tail = std.atomic.AtomicUsize.init(0),
            .mask = capacity - 1,
        };
    }

    // Internal storage
    buffer: [capacity]T,
    head: std.atomic.AtomicUsize,
    tail: std.atomic.AtomicUsize,
    mask: usize,

    /// Returns true if the buffer contains no elements.
    pub fn isEmpty(self: *Self) bool {
        return self.head.load(.Relaxed) == self.tail.load(.Relaxed);
    }

    /// Returns true if the buffer cannot accept another element.
    pub fn isFull(self: *Self) bool {
        const next = (self.head.load(.Relaxed) + 1) & self.mask;
        return next == self.tail.load(.Relaxed);
    }

    /// Number of stored elements (0 ≤ len < capacity).
    pub fn len(self: *Self) usize {
        const h = self.head.load(.Relaxed);
        const t = self.tail.load(.Relaxed);
        return (h + capacity - t) & self.mask;
    }

    /// Pushes an element into the buffer. Returns BufferFull if no space.
    pub fn push(self: *Self, item: T) Error!void {
        const head = self.head.load(.Acquire);
        const tail = self.tail.load(.Relaxed);
        const next = (head + 1) & self.mask;
        if (next == tail) return error.BufferFull;

        self.buffer[head] = item;
        // Release ensures the write to buffer[head] becomes visible before head advances.
        self.head.store(next, .Release);
    }

    /// Pops an element from the buffer. Returns BufferEmpty if empty.
    pub fn pop(self: *Self) Error!T {
        const tail = self.tail.load(.Acquire);
        const head = self.head.load(.Relaxed);
        if (tail == head) return error.BufferEmpty;

        const item = self.buffer[tail];
        const next = (tail + 1) & self.mask;
        // Release ensures the read of buffer[tail] happens before tail advances.
        self.tail.store(next, .Release);
        return item;
    }
};
