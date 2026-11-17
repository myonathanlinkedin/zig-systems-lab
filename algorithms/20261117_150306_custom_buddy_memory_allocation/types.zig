const std = @import("std");

// Minimum order (2^4 = 16 bytes) and maximum order (2^20 = 1 MiB)
pub const MIN_ORDER: usize = 4;
pub const MAX_ORDER: usize = 20;
pub const NUM_ORDERS: usize = MAX_ORDER - MIN_ORDER + 1;

// Header placed at the beginning of every block (allocated or free)
pub const BlockHeader = packed struct {
    order: u8,                                   // actual order of the block (log2 size)
    // Pad to the size of a pointer so that the payload can be pointer‑aligned.
    _pad: [@sizeOf(usize) - 1]u8,
};

// Node used while the block is on a free list
pub const FreeBlock = struct {
    next: ?*FreeBlock,
};

// The core allocator structure
pub const BuddyAllocator = struct {
    buffer: []u8,                                 // managed memory region
    free_lists: [NUM_ORDERS]?*FreeBlock,          // heads of free lists per order

    // Initialize the allocator with a raw buffer.
    pub fn init(self: *BuddyAllocator, buffer: []u8) void {
        // Zero all free‑list heads.
        for (self.free_lists) |*head| head.* = null;

        // The whole buffer starts as a single free block of MAX_ORDER.
        const max_order_index = MAX_ORDER - MIN_ORDER;
        const block_ptr = buffer.ptr;
        // Write header.
        const hdr = @ptrCast(*BlockHeader, block_ptr);
        hdr.* = .{ .order = MAX_ORDER };
        // Initialise free‑list node.
        const node = @ptrCast(*FreeBlock, block_ptr + @sizeOf(BlockHeader));
        node.* = .{ .next = null };
        self.free_lists[max_order_index] = node;
        self.buffer = buffer;
    }

    // Allocate a slice of at least `size` bytes.
    pub fn alloc(self: *BuddyAllocator, size: usize) ![]u8 {
        if (size == 0) return error.InvalidSize;

        // Determine the smallest order that can satisfy the request
        // (including space for the header).
        const needed = size + @sizeOf(BlockHeader);
        var order = MIN_ORDER;
        while ((@as(usize, 1) << order) < needed) : (order += 1) {
            if (order > MAX_ORDER) return error.OutOfMemory;
        }

        const order_index = order - MIN_ORDER;
        // Find a free block of this order or larger.
        var cur_index = order_index;
        while (cur_index < NUM_ORDERS and self.free_lists[cur_index] == null) : (cur_index += 1) {}
        if (cur_index == NUM_ORDERS) return error.OutOfMemory;

        // Remove a block from the found free list.
        var block_node = self.free_lists[cur_index].?;
        self.free_lists[cur_index] = block_node.next;

        // Split down to the desired order.
        while (cur_index > order_index) : (cur_index -= 1) {
            const split_order = MIN_ORDER + cur_index - 1;
            const split_size = @as(usize, 1) << split_order;

            // Compute address of the buddy block.
            const block_addr = @intFromPtr(block_node) - @sizeOf(BlockHeader);
            const buddy_addr = block_addr + split_size;

            // Initialise buddy header.
            const buddy_hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, buddy_addr));
            buddy_hdr.* = .{ .order = split_order };
            // Initialise buddy free‑list node.
            const buddy_node = @ptrCast(*FreeBlock, buddy_hdr + 1);
            buddy_node.* = .{ .next = self.free_lists[cur_index - 1] };
            self.free_lists[cur_index - 1] = buddy_node;

            // Adjust the current block's header for the smaller size.
            const cur_hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, block_addr));
            cur_hdr.* = .{ .order = split_order };
        }

        // At this point `block_node` points to a block of the exact order.
        const final_hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, @intFromPtr(block_node) - @sizeOf(BlockHeader)));
        final_hdr.* = .{ .order = order };
        // Return the usable payload (after the header).
        const payload_ptr = @intToPtr(*u8, @intFromPtr(final_hdr) + @sizeOf(BlockHeader));
        return payload_ptr[0..size];
    }

    // Free a previously allocated slice.
    pub fn free(self: *BuddyAllocator, slice: []u8) void {
        if (slice.len == 0) return; // nothing to do

        // Recover the block header.
        const payload_addr = @intFromPtr(slice.ptr);
        const hdr_addr = payload_addr - @sizeOf(BlockHeader);
        const hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, hdr_addr));
        const order = hdr.order;
        const order_index = @as(usize, order) - MIN_ORDER;
        const block_size = @as(usize, 1) << order;

        var cur_hdr_addr = hdr_addr;
        var cur_order = order;

        // Coalescing loop.
        while (cur_order < MAX_ORDER) : (cur_order += 1) {
            const cur_index = cur_order - MIN_ORDER;
            const buddy_addr = cur_hdr_addr ^ block_size;

            // Search the free list of the current order for the buddy.
            var prev: ?*FreeBlock = null;
            var node = self.free_lists[cur_index];
            var found = false;
            while (node) |n| {
                const n_hdr_addr = @intFromPtr(n) - @sizeOf(BlockHeader);
                if (n_hdr_addr == buddy_addr) {
                    // Buddy is free – remove it from the list.
                    if (prev) |p| {
                        p.next = n.next;
                    } else {
                        self.free_lists[cur_index] = n.next;
                    }
                    found = true;
                    break;
                }
                prev = n;
                node = n.next;
            }
            if (!found) break; // buddy not free, stop merging

            // Merge with buddy: the new block starts at the lower address.
            if (buddy_addr < cur_hdr_addr) cur_hdr_addr = buddy_addr;
            // Update header for the larger block.
            const merged_hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, cur_hdr_addr));
            merged_hdr.* = .{ .order = cur_order + 1 };
            // Continue loop with the larger block.
        }

        // Insert the (possibly merged) block into its free list.
        const final_hdr = @ptrCast(*BlockHeader, @intToPtr(*u8, cur_hdr_addr));
        const final_node = @ptrCast(*FreeBlock, final_hdr + 1);
        const final_index = final_hdr.order - MIN_ORDER;
        final_node.* = .{ .next = self.free_lists[final_index] };
        self.free_lists[final_index] = final_node;
    }

    pub const error = error{
        InvalidSize,
        OutOfMemory,
    };
};
