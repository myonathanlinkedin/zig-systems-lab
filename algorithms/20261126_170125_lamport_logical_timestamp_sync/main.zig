const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Initialize engine.
    var eng = try engine.Engine.init(allocator);
    defer eng.deinit();

    // Register two processes.
    try eng.register(1, null);
    try eng.register(2, null);

    // Initial comparison: both timestamps are 0.
    const ord0 = try eng.compareClocks(1, 2);
    std.debug.assert(ord0 == .eq);

    // Process 1 sends an event to Process 2.
    const ev1 = try eng.sendEvent(1, 2);
    std.debug.assert(ev1.sender == 1);
    std.debug.assert(ev1.receiver == 2);
    std.debug.assert(ev1.timestamp == 1);

    // After the send, Process 1's clock should be 1, Process 2's clock should be 2.
    const ord1 = try eng.compareClocks(1, 2);
    std.debug.assert(ord1 == .lt); // 1 < 2

    // Process 2 sends back to Process 1.
    const ev2 = try eng.sendEvent(2, 1);
    std.debug.assert(ev2.timestamp == 3); // Process 2 ticked from 2 -> 3

    // Now Process 1 should have timestamp 4.
    const ord2 = try eng.compareClocks(1, 2);
    std.debug.assert(ord2 == .gt); // 4 > 3

    // Simulate out‑of‑order receipt: Process 1 receives a stale timestamp 2.
    try eng.receiveExternal(1, 2);
    // Clock must advance to max(4,2)+1 = 5.
    const finalClock1 = (try eng.compareClocks(1, 1)).?; // trivial, just to fetch
    const clkPtr = try eng.getClock(1);
    std.debug.assert(clkPtr.time == 5);

    // Edge case: large timestamps near u64 overflow.
    // Manually set Process 2 clock to max-1 and tick.
    const maxMinusOne = std.math.maxInt(types.LamportTimestamp) - 1;
    const clk2 = try eng.getClock(2);
    clk2.time = maxMinusOne;
    const ts = clk2.tick(); // should wrap to max (since +% is wrapping)
    std.debug.assert(ts == std.math.maxInt(types.LamportTimestamp));

    // Next tick would wrap to 0 (wrapping arithmetic). Verify deterministic behavior.
    const ts2 = clk2.tick();
    std.debug.assert(ts2 == 0);

    // All assertions passed.
    std.debug.print("All Lamport engine tests passed.\n", .{});
}

// Helper to expose internal getClock for test verification.
// Not part of public API; used only in main for assertions.
fn getClock(eng: *engine.Engine, pid: u32) !*types.LamportClock {
    return eng.getClock(pid);
}
