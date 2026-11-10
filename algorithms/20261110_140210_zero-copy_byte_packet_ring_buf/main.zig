const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test 1: Basic enqueue/dequeue
    var rb1 = try core.RingBuffer.init(allocator, 32);
    defer rb1.deinit(allocator);
    const pkt1 = [_]u8{ 1, 2, 3, 4, 5 };
    try rb1.enqueue(&pkt1);
    const out1 = rb1.dequeue() orelse unreachable;
    std.debug.assert(out1.len == pkt1.len);
    for (out1, pkt1) |a, b| std.debug.assert(a == b);

    // Test 2: Wrap-around behavior
    var rb2 = try core.RingBuffer.init(allocator, 16);
    defer rb2.deinit(allocator);
    const pktA = [_]u8{ 10, 20, 30, 40 };
    const pktB = [_]u8{ 50, 60, 70, 80 };
    const pktC = [_]u8{ 90, 100, 110, 120 };
    try rb2.enqueue(&pktA);
    try rb2.enqueue(&pktB);
    try rb2.enqueue(&pktC); // should wrap head to 0
    const outA = rb2.dequeue() orelse unreachable;
    std.debug.assert(outA.len == pktA.len);
    for (outA, pktA) |a, b| std.debug.assert(a == b);
    const outB = rb2.dequeue() orelse unreachable;
    std.debug.assert(outB.len == pktB.len);
    for (outB, pktB) |a, b| std.debug.assert(a == b);
    const outC = rb2.dequeue() orelse unreachable;
    std.debug.assert(outC.len == pktC.len);
    for (outC, pktC) |a, b| std.debug.assert(a == b);
    std.debug.assert(rb2.is_empty(rb2));

    // Test 3: Full buffer detection
    var rb3 = try core.RingBuffer.init(allocator, 10);
    defer rb3.deinit(allocator);
    const pktX = [_]u8{ 1, 2, 3, 4 };
    try rb3.enqueue(&pktX);
    try rb3.enqueue(&pktX);
    try rb3.enqueue(&pktX); // should fit exactly
    try std.testing.expectError(core.RingBuffer.Error.BufferFull, rb3.enqueue(&pktX));

    // Test 4: Dispatch callback
    var rb4 = try core.RingBuffer.init(allocator, 32);
    defer rb4.deinit(allocator);
    const pktD = [_]u8{ 5, 6, 7 };
    const pktE = [_]u8{ 8, 9 };
    try rb4.enqueue(&pktD);
    try rb4.enqueue(&pktE);
    var collected = std.ArrayList([]const u8).init(allocator);
    defer collected.deinit();
    rb4.dispatch(struct {
        fn callback(data: []const u8) void {
            collected.append(data) catch unreachable;
        }
    }.callback);
    std.debug.assert(collected.items.len == 2);
    std.debug.assert(std.mem.eql(u8, collected.items[0], &pktD));
    std.debug.assert(std.mem.eql(u8, collected.items[1], &pktE));

    // All tests passed
    std.debug.print("All tests passed.\n", .{});
}
