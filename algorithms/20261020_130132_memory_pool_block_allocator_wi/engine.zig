const std = @import("std");
const types = @import("types.zig");

pub const Pool = struct {
    buffer: []u8,
    block_size: usize,
    block_count: usize,
    free_list_head: ?*types.Block = null,

    pub fn init(allocator: *std.mem.Allocator, block_size: usize, block_count: usize) !Pool {
        std.debug.assert(block_size > 0);
        std.debug.assert(block_count > 0);

        const min_size = @sizeOf(types.Block);
        const align = @alignOf(types.Block);
        const aligned_block_size = std.math.alignForward(usize, block_size, align);
        std.debug.assert(aligned_block_size >= min_size);

        const total_size = aligned_block_size * block_count;
        var buf = try allocator.alloc(u8, total_size);

        var pool = Pool{
            .buffer = buf,
            .block_size = aligned_block_size,
            .block_count = block_count,
            .free_list_head = null,
        };

        var offset: usize = 0;
        while (offset < total_size) : (offset += aligned_block_size) {
            const block_ptr = @ptrCast(*types.Block, &buf[offset]);
            block_ptr.next = pool.free_list_head;
            pool.free_list_head = block_ptr;
        }

        return pool;
    }

    pub fn deinit(self: *Pool, allocator: *std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn allocate(self: *Pool) ?*u8 {
        if (self.free_list_head == null) return null;
        const block = self.free_list_head.?;
        self.free_list_head = block.next;
        const ptr = @ptrCast(*u8, block);
        return ptr;
    }

    pub fn deallocate(self: *Pool, ptr: *u8) void {
        const block = @ptrCast(*types.Block, ptr);
        block.next = self.free_list_head;
        self.free_list_head = block;
    }
};
