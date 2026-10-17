const std = @import("std");

pub const MemoryPool = struct {
    const Node = struct {
        next: ?*Node,
    };

    block_size: usize,
    block_count: usize,
    buffer: []u8,
    free_head: ?*Node,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator, block_size: usize, block_count: usize) !MemoryPool {
        // Ensure block size can hold a Node pointer
        const aligned_block = std.math.alignForward(usize, block_size, @alignOf(Node));
        const total_size = aligned_block * block_count;
        const buf = try allocator.alloc(u8, total_size);
        var pool = MemoryPool{
            .block_size = aligned_block,
            .block_count = block_count,
            .buffer = buf,
            .free_head = null,
            .allocator = allocator,
        };
        pool.buildFreeList();
        return pool;
    }

    fn buildFreeList(self: *MemoryPool) void {
        var i: usize = 0;
        var prev: ?*Node = null;
        while (i < self.block_count) : (i += 1) {
            const block_ptr = @ptrCast(*Node, self.buffer.ptr + i * self.block_size);
            block_ptr.* = Node{ .next = prev };
            prev = block_ptr;
        }
        self.free_head = prev;
    }

    pub fn deinit(self: *MemoryPool) void {
        self.allocator.free(self.buffer);
        self.buffer = &[_]u8{};
        self.free_head = null;
    }

    pub fn allocate(self: *MemoryPool) ![]u8 {
        const head = self.free_head orelse return error.OutOfMemory;
        self.free_head = head.next;
        // Return slice to usable memory (skip Node header)
        const ptr = @ptrCast([*]u8, head);
        return ptr[0..self.block_size];
    }

    pub fn deallocate(self: *MemoryPool, block: []u8) void {
        // Ensure block belongs to this pool (debug only)
        std.debug.assert(block.ptr >= self.buffer.ptr);
        std.debug.assert(block.ptr + block.len <= self.buffer.ptr + self.buffer.len);
        const node = @ptrCast(*Node, block.ptr);
        node.* = Node{ .next = self.free_head };
        self.free_head = node;
    }

    pub const error = struct {
        OutOfMemory: error{},
    };
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const blockSize = 32;
    const blockCount = 10;
    var pool = try MemoryPool.init(&allocator, blockSize, blockCount);
    defer pool.deinit();

    var blocks: [blockCount][]u8 = undefined;
    // Allocate all blocks
    var i: usize = 0;
    while (i < blockCount) : (i += 1) {
        blocks[i] = try pool.allocate();
        // Ensure distinct pointers
        var j: usize = 0;
        while (j < i) : (j += 1) {
            std.debug.assert(blocks[i].ptr != blocks[j].ptr);
        }
    }

    // Allocation beyond capacity should fail
    const over = pool.allocate();
    std.debug.assert(over catch |e| e == MemoryPool.error.OutOfMemory);

    // Deallocate all blocks
    i = 0;
    while (i < blockCount) : (i += 1) {
        pool.deallocate(blocks[i]);
    }

    // Reallocate to ensure reuse
    i = 0;
    while (i < blockCount) : (i += 1) {
        const blk = try pool.allocate();
        std.debug.assert(blk.ptr == blocks[i].ptr);
    }

    // Clean up
    // (deinit will free underlying buffer)
}
