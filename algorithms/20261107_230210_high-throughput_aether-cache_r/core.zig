const std = @import("std");

pub const RingBuffer = struct {
    const Self = @This();

    // Errors returned by the buffer operations
    pub const Error = error{
        BufferFull,
        BufferEmpty,
    };

    // Compile‑time parameters
    pub const T = anytype;
    pub const capacity: usize = 0; // placeholder, replaced by comptime param

    // Internal storage
    buf: []T,
    mask: usize,
    // head points to the next element to read, tail points to the next slot to write
    head: std.atomic.AtomicUsize,
    tail: std.atomic.AtomicUsize,

    // -------------------------------------------------------------------------
    // Constructor – generic over element type and power‑of‑two capacity
    // -------------------------------------------------------------------------
    pub fn init(comptime Elem: type, comptime cap: usize) Self {
        // Capacity must be a power of two and at least 2
        comptime {
            if (cap < 2 or (cap & (cap - 1)) != 0) {
                @compileError("RingBuffer capacity must be a power of two and >= 2");
            }
        }
        const allocator = std.heap.page_allocator;
        const buffer = allocator.alloc(Elem, cap) catch unreachable;
        return Self{
            .buf = buffer,
            .mask = cap - 1,
            .head = std.atomic.AtomicUsize.init(0),
            .tail = std.atomic.AtomicUsize.init(0),
        };
    }

    // -------------------------------------------------------------------------
    // Deinitializer – releases the underlying buffer
    // -------------------------------------------------------------------------
    pub fn deinit(self: *Self) void {
        const allocator = std.heap.page_allocator;
        allocator.free(self.buf);
        self.buf = &[_]T{};
    }

    // -------------------------------------------------------------------------
    // Returns the total capacity of the ring buffer
    // -------------------------------------------------------------------------
    pub fn capacity(self: *const Self) usize {
        return self.mask + 1;
    }

    // -------------------------------------------------------------------------
    // Returns the current number of stored elements
    // -------------------------------------------------------------------------
    pub fn len(self: *const Self) usize {
        const head = self.head.load(.SeqCst);
        const tail = self.tail.load(.SeqCst);
        return tail - head;
    }

    // -------------------------------------------------------------------------
    // Checks whether the buffer is empty
    // -------------------------------------------------------------------------
    pub fn isEmpty(self: *const Self) bool {
        return self.len() == 0;
    }

    // -------------------------------------------------------------------------
    // Checks whether the buffer is full
    // -------------------------------------------------------------------------
    pub fn isFull(self: *const Self) bool {
        return self.len() == self.capacity();
    }

    // -------------------------------------------------------------------------
    // Pushes an element into the buffer; returns BufferFull if no space
    // -------------------------------------------------------------------------
    pub fn push(self: *Self, item: T) Error!void {
        const tail = self.tail.load(.SeqCst);
        const head = self.head.load(.SeqCst);
        if ((tail + 1) & self.mask == head & self.mask) {
            return Error.BufferFull;
        }
        self.buf[tail & self.mask] = item;
        // Ensure the write to the buffer happens before publishing the new tail
        @fence(.SeqCst);
        self.tail.store(tail + 1, .SeqCst);
    }

    // -------------------------------------------------------------------------
    // Pops an element from the buffer; returns BufferEmpty if none
    // -------------------------------------------------------------------------
    pub fn pop(self: *Self) Error!T {
        const head = self.head.load(.SeqCst);
        const tail = self.tail.load(.SeqCst);
        if (head == tail) {
            return Error.BufferEmpty;
        }
        const item = self.buf[head & self.mask];
        // Ensure the read completes before moving the head forward
        @fence(.SeqCst);
        self.head.store(head + 1, .SeqCst);
        return item;
    }

    // -------------------------------------------------------------------------
    // Peek at the next element without removing it; returns BufferEmpty if none
    // -------------------------------------------------------------------------
    pub fn peek(self: *const Self) Error!T {
        const head = self.head.load(.SeqCst);
        const tail = self.tail.load(.SeqCst);
        if (head == tail) {
            return Error.BufferEmpty;
        }
        return self.buf[head & self.mask];
    }
};
