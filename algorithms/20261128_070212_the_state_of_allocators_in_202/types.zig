const std = @import("std");

pub const AllocError = error{
    OutOfMemory,
};

pub const BumpAllocator = struct {
    buffer: []u8,
    offset: usize = 0,

    /// Initialise a bump allocator with the provided backing buffer.
    pub fn init(buf: []u8) BumpAllocator {
        return BumpAllocator{
            .buffer = buf,
            .offset = 0,
        };
    }

    /// Allocate `count` objects of type `T` with the given `alignment`.
    /// Returns a slice of `T` on success, otherwise an `AllocError.OutOfMemory`.
    pub fn allocate(
        self: *BumpAllocator,
        comptime T: type,
        count: usize,
        alignment: u29,
    ) AllocError![]T {
        const size = @sizeOf(T) * count;
        const aligned_offset = std.mem.alignForward(self.offset, alignment);
        if (aligned_offset + size > self.buffer.len) {
            return AllocError.OutOfMemory;
        }
        const ptr = self.buffer.ptr + aligned_offset;
        self.offset = aligned_offset + size;
        // Cast the raw pointer to a typed slice.
        const typed_ptr = @ptrCast([*]T, ptr);
        return typed_ptr[0..count];
    }

    /// Reset the allocator, discarding all previously allocated memory.
    /// This operation is O(1) and does not invoke any destructors.
    pub fn reset(self: *BumpAllocator) void {
        self.offset = 0;
    }

    /// Return the number of bytes still available for allocation.
    pub fn remaining(self: *BumpAllocator) usize {
        return self.buffer.len - self.offset;
    }
};
