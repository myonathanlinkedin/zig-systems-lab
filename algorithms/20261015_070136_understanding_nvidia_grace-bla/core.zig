const std = @import("std");

pub const Placement = enum {
    CPU,
    GPU,
    ANY,
};

const Pool = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buf: []u8) Pool {
        return Pool{
            .buffer = buf,
            .offset = 0,
        };
    }

    pub fn alloc(self: *Pool, size: usize, align: u29) ?[]u8 {
        const aligned = std.math.alignForward(self.offset, align);
        if (aligned + size > self.buffer.len) return null;
        const slice = self.buffer[aligned .. aligned + size];
        self.offset = aligned + size;
        return slice;
    }

    pub fn reset(self: *Pool) void {
        self.offset = 0;
    }
};

const Allocation = struct {
    ptr: []u8,
    size: usize,
    placement: Placement,
};

pub const UnifiedMemoryManager = struct {
    cpu_pool: Pool,
    gpu_pool: Pool,
    allocations: std.ArrayList(Allocation),

    pub fn init(cpu_buf: []u8, gpu_buf: []u8, allocator: *std.mem.Allocator) UnifiedMemoryManager {
        return UnifiedMemoryManager{
            .cpu_pool = Pool.init(cpu_buf),
            .gpu_pool = Pool.init(gpu_buf),
            .allocations = std.ArrayList(Allocation).init(allocator),
        };
    }

    fn findAllocation(self: *UnifiedMemoryManager, ptr: []u8) ?usize {
        for (self.allocations.items, 0..) |alloc, i| {
            if (alloc.ptr.ptr == ptr.ptr) return i;
        }
        return null;
    }

    pub fn allocate(
        self: *UnifiedMemoryManager,
        size: usize,
        align: u29,
        placement: Placement,
    ) ![]u8 {
        var target = placement;
        if (placement == .ANY) {
            // Prefer CPU, fallback to GPU
            target = .CPU;
        }

        const tryAlloc = (pool: *Pool) ?[]u8 => pool.alloc(size, align);
        var slice: ?[]u8 = null;

        if (target == .CPU) {
            slice = tryAlloc(&self.cpu_pool);
            if (slice == null) {
                // fallback to GPU if ANY was requested
                if (placement == .ANY) slice = tryAlloc(&self.gpu_pool);
            }
        } else if (target == .GPU) {
            slice = tryAlloc(&self.gpu_pool);
        }

        if (slice) |s| {
            try self.allocations.append(Allocation{
                .ptr = s,
                .size = size,
                .placement = if (target == .CPU) .CPU else .GPU,
            });
            return s;
        } else {
            return error.OutOfMemory;
        }
    }

    pub fn deallocate(self: *UnifiedMemoryManager, ptr: []u8) void {
        const idx = self.findAllocation(ptr) orelse return;
        // Simple strategy: keep allocation metadata but ignore freed space.
        // Remove from list to avoid future migrations.
        _ = self.allocations.swapRemove(idx);
    }

    pub fn migrate(self: *UnifiedMemoryManager, ptr: []u8, target: Placement) ![]u8 {
        const idx = self.findAllocation(ptr) orelse return error.InvalidPointer;
        const alloc = self.allocations.items[idx];
        if (alloc.placement == target) return alloc.ptr; // already there

        // Allocate new block in target pool
        const newSlice = try self.allocate(alloc.size, @alignOf(u8), target);
        // Copy data
        std.mem.copy(u8, newSlice, alloc.ptr);
        // Deallocate old block
        self.deallocate(alloc.ptr);
        // Update metadata (allocation already added by allocate)
        // Find the newly added allocation and set correct placement
        const newIdx = self.findAllocation(newSlice) orelse unreachable;
        self.allocations.items[newIdx].placement = target;
        return newSlice;
    }

    pub fn queryPlacement(self: *UnifiedMemoryManager, ptr: []u8) ?Placement {
        const idx = self.findAllocation(ptr) orelse return null;
        return self.allocations.items[idx].placement;
    }
};
