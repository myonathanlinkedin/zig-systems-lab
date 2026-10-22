const std = @import("std");

/// Internal block header used for the free list.
/// The header is stored at the beginning of each block.
const Block = struct {
    next: ?*Block,
};

/// A simple memory pool allocator that manages a fixed-size buffer
/// divided into equal-sized blocks. Each block contains a hidden
/// header used to maintain a free list. Allocation returns a pointer
/// to the usable payload area of a block, hiding the header from the
/// caller.
pub const MemoryPool = struct {
    buffer: []u8,
    block_size: usize,
    free_list: ?*Block,
    total_blocks: usize,
    used_blocks: usize,

    /// Create a new memory pool.
    ///
    /// * `buf` – The buffer that will back the pool. It must be large
    ///   enough to hold `num_blocks` blocks of size `block_size`.
    /// * `block_size` – The requested size of each block. The actual
    ///   size will be rounded up to the alignment of `Block` and
    ///   to at least `@sizeOf(Block)`.
    /// * `num_blocks` – Number of blocks to preallocate.
    ///
    /// Returns a `MemoryPool` instance. The caller must keep the
    /// underlying buffer alive for the lifetime of the pool.
    pub fn init(buf: []u8, block_size: usize, num_blocks: usize) MemoryPool {
        // Ensure block size is at least the size of the header.
        var actual_block_size = @max(block_size, @sizeOf(Block));
        // Align block size to the alignment of Block.
        actual_block_size = std.mem.alignForward(actual_block_size, @alignOf(Block));

        const total_size = actual_block_size * num_blocks;
        std.debug.assert(buf.len >= total_size);

        var pool: MemoryPool = .{
            .buffer = buf[0..total_size],
            .block_size = actual_block_size,
            .free_list = null,
            .total_blocks = num_blocks,
            .used_blocks = 0,
        };

        // Link all blocks into the free list.
        var offset: usize = 0;
        var prev: ?*Block = null;
        while (offset < total_size) : (offset += actual_block_size) {
            const block_ptr = @ptrCast(*Block, pool.buffer.ptr + offset);
            block_ptr.next = prev;
            prev = block_ptr;
        }
        pool.free_list = prev;
        return pool;
    }

    /// Allocate a block from the pool.
    ///
    /// Returns a pointer to the usable payload area of the block,
    /// or `null` if no blocks are available.
    pub fn allocate(self: *MemoryPool) ?*u8 {
        if (self.free_list == null) return null;
        const block = self.free_list.?;
        self.free_list = block.next;
        self.used_blocks += 1;
        // Return pointer to payload area (after the header).
        const payload_ptr = @ptrCast(*u8, block) + @sizeOf(Block);
        return payload_ptr;
    }

    /// Deallocate a previously allocated block.
    ///
    /// The pointer must have been returned by a prior call to
    /// `allocate`. The function is unsafe because it does not
    /// perform any runtime checks on the pointer.
    pub fn deallocate(self: *MemoryPool, ptr: *u8) void {
        // Compute the address of the block header.
        const block_ptr = @ptrCast(*Block, @intToPtr(?*u8, @ptrToInt(ptr) - @sizeOf(Block)));
        // Push the block back onto the free list.
        block_ptr.next = self.free_list;
        self.free_list = block_ptr;
        self.used_blocks -= 1;
    }

    /// Return the number of blocks currently allocated.
    pub fn used(self: *const MemoryPool) usize {
        return self.used_blocks;
    }

    /// Return the total number of blocks in the pool.
    pub fn total(self: *const MemoryPool) usize {
        return self.total_blocks;
    }
};
