const std = @import("std");
const types = @import("types.zig");

// Re‑export the allocator type and its errors for convenience.
pub const BuddyAllocator = types.BuddyAllocator;
pub const BuddyError = types.BuddyAllocator.error;

// Helper: round up to the next power of two (used only for tests).
pub fn nextPowerOfTwo(x: usize) usize {
    var v = x;
    v -= 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    if (@sizeOf(usize) == 8) v |= v >> 32;
    v += 1;
    return v;
}
