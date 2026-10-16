const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    var cpu_mem: [2048]u8 = undefined;
    var gpu_mem: [2048]u8 = undefined;

    var manager = core.UnifiedMemoryManager.init(&cpu_mem, &gpu_mem, allocator);

    // Test 1: Allocate on CPU
    const a_cpu = try manager.allocate(128, 8, .CPU);
    std.debug.assert(a_cpu.len == 128);
    std.debug.assert(manager.queryPlacement(a_cpu) == .CPU);

    // Fill with pattern
    for (a_cpu) |*b, i| b.* = @intCast(u8, i & 0xFF);

    // Test 2: Allocate on GPU
    const a_gpu = try manager.allocate(256, 16, .GPU);
    std.debug.assert(a_gpu.len == 256);
    std.debug.assert(manager.queryPlacement(a_gpu) == .GPU);

    // Test 3: Allocate with ANY (should go to CPU first)
    const a_any = try manager.allocate(64, 4, .ANY);
    std.debug.assert(a_any.len == 64);
    std.debug.assert(manager.queryPlacement(a_any) == .CPU);

    // Test 4: Over‑allocation should error
    const big = manager.allocate(5000, 8, .ANY);
    std.debug.assert(big catch |e| e == error.OutOfMemory);

    // Test 5: Migrate CPU allocation to GPU
    const migrated = try manager.migrate(a_cpu, .GPU);
    std.debug.assert(manager.queryPlacement(migrated) == .GPU);
    // Verify data integrity after migration
    for (migrated) |b, i| {
        std.debug.assert(b == @intCast(u8, i & 0xFF));
    }

    // Test 6: Deallocate GPU allocation and ensure it disappears
    manager.deallocate(a_gpu);
    std.debug.assert(manager.queryPlacement(a_gpu) == null);

    // Test 7: Re‑allocate after deallocation (bump allocator does not reuse, but should still succeed)
    const a2 = try manager.allocate(128, 8, .GPU);
    std.debug.assert(a2.len == 128);
    std.debug.assert(manager.queryPlacement(a2) == .GPU);

    // All assertions passed
    std.debug.print("All UnifiedMemoryManager tests passed.\n", .{});
    return;
}
