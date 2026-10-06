const std = @import("std");

pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    // Capacity must be a power of two and greater than zero.
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("capacity must be a power of two and greater than zero");
        }
    }

    return struct {
        const Self = @This();

        // Underlying storage.
        buffer: [capacity]T,
        // Atomic indices.
        head: std.atomic.AtomicUsize,
        tail: std.atomic.AtomicUsize,
        // Mask for fast modulo.
        mask: usize = capacity - 1,

        /// Initialise a new ring buffer. The buffer contents are undefined.
        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = std.atomic.AtomicUsize.init(0),
                .tail = std.atomic.AtomicUsize.init(0),
            };
        }
    };
}
