const std = @import("std");
const engine = @import("engine.zig");

pub fn main() !void {
    // Create an engine with a modest 256‑byte backing store.
    var eng = engine.AllocEngine.create(256);
    defer eng.destroy();

    // -------------------------------------------------------------------------
    // Test 1: Simple allocation and alignment verification.
    // -------------------------------------------------------------------------
    const slice1 = try eng.allocU8Slice(13, 1);
    std.debug.assert(slice1.len == 13);
    // Alignment 1 imposes no restriction; any address is acceptable.
    std.debug.assert(@intFromPtr(slice1.ptr) % 1 == 0);

    // -------------------------------------------------------------------------
    // Test 2: Allocation with power‑of‑two alignment.
    // -------------------------------------------------------------------------
    const slice2 = try eng.allocU8Slice(7, 8);
    std.debug.assert(slice2.len == 7);
    std.debug.assert(@intFromPtr(slice2.ptr) % 8 == 0);

    // Ensure that slice2 does not overlap slice1.
    const end1 = @intFromPtr(slice1.ptr) + slice1.len;
    const start2 = @intFromPtr(slice2.ptr);
    std.debug.assert(start2 >= end1);

    // -------------------------------------------------------------------------
    // Test 3: Exhaustion handling.
    // -------------------------------------------------------------------------
    // Allocate the remainder of the buffer; this should succeed.
    const remaining = eng.remaining();
    const slice3 = try eng.allocU8Slice(remaining, 1);
    std.debug.assert(slice3.len == remaining);

    // Any further allocation must fail with OutOfMemory.
    const fail = eng.allocU8Slice(1, 1);
    std.debug.assert(fail == error.OutOfMemory);

    // -------------------------------------------------------------------------
    // Test 4: Reset restores full capacity.
    // -------------------------------------------------------------------------
    eng.reset();
    std.debug.assert(eng.remaining() == 256);

    // After reset we can allocate again.
    const slice4 = try eng.allocU8Slice(64, 16);
    std.debug.assert(slice4.len == 64);
    std.debug.assert(@intFromPtr(slice4.ptr) % 16 == 0);

    // -------------------------------------------------------------------------
    // Test 5: Edge‑case zero‑size allocation.
    // -------------------------------------------------------------------------
    const zeroSlice = try eng.allocU8Slice(0, 4);
    std.debug.assert(zeroSlice.len == 0);
    // Zero‑size allocations may return any pointer; we only require they are non‑null.
    std.debug.assert(zeroSlice.ptr != null);

    // All assertions passed.
    std.debug.print("All allocator tests passed.\n", .{});
}
