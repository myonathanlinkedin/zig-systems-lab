const std = @import("std");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []T,
        mask: usize,
        head: std.atomic.AtomicUsize,
        tail: std.atomic.AtomicUsize,
        allocator: *std.mem.Allocator,

        pub const Error = error{
            NotPowerOfTwo,
        };

        /// Initialise a ring buffer with a *capacity* that must be a power of two.
        pub fn init(capacity: usize, allocator: *std.mem.Allocator) !Self {
            if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
                return Error.NotPowerOfTwo;
            }
            const buf = try allocator.alloc(T, capacity);
            return Self{
                .buffer = buf,
                .mask = capacity - 1,
                .head = std.atomic.AtomicUsize.init(0),
                .tail = std.atomic.AtomicUsize.init(0),
                .allocator = allocator,
            };
        }

        /// Release the underlying storage.
        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buffer);
        }
    };
}
