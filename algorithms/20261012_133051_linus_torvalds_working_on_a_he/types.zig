const std = @import("std");

pub const HeapError = error{
    EmptyHeap,
    OutOfMemory,
};

pub fn MinHeap(comptime T: type) type {
    return struct {
        // Underlying storage for heap elements.
        data: []T,
        // Current number of elements in the heap.
        len: usize,
        // Maximum capacity of the allocated buffer.
        capacity: usize,
        // Allocator used for dynamic memory management.
        allocator: *std.mem.Allocator,
    };
}
