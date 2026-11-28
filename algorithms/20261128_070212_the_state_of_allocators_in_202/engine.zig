const std = @import("std");
const types = @import("types.zig");

pub const AllocEngine = struct {
    allocator: types.BumpAllocator,

    /// Create a new engine with a backing buffer of `capacity` bytes.
    pub fn create(capacity: usize) AllocEngine {
        // Allocate the backing buffer on the stack; for larger capacities the caller
        // should provide its own buffer. Here we keep it simple and use a heap allocation
        // via the global allocator, which is part of the standard library and safe.
        const buf = std.heap.page_allocator.alloc(u8, capacity) catch unreachable;
        return AllocEngine{
            .allocator = types.BumpAllocator.init(buf),
        };
    }

    /// Deinitialize the engine, releasing the backing buffer.
    pub fn destroy(self: *AllocEngine) void {
        const buf = self.allocator.buffer;
        std.heap.page_allocator.free(buf);
        self.allocator = undefined;
    }

    /// Allocate a slice of `u8` with the requested `size` and `alignment`.
    pub fn allocU8Slice(
        self: *AllocEngine,
        size: usize,
        alignment: u29,
    ) types.AllocError![]u8 {
        return self.allocator.allocate(u8, size, alignment);
    }

    /// Reset the allocator, making the whole buffer reusable.
    pub fn reset(self: *AllocEngine) void {
        self.allocator.reset();
    }

    /// Query remaining free bytes.
    pub fn remaining(self: *AllocEngine) usize {
        return self.allocator.remaining();
    }
};
