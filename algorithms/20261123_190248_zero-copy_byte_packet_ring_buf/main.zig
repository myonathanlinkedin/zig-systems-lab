const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    // Create a ring buffer with capacity 4
    var rb = try core.RingBuffer.init(allocator, 4);
    defer rb.deinit(allocator);

    const pkt1 = "hello";
    const pkt2 = "world";
    const pkt3 = "zig";
    const pkt4 = "ring";

    // Enqueue four packets
    try rb.enqueue(pkt1);
    try rb.enqueue(pkt2);
    try rb.enqueue(pkt3);
    try rb.enqueue(pkt4);

    // Buffer should be full now; enqueue should return Full error
    const err_full = rb.enqueue("extra") catch |e| e;
    std.debug.assert(err_full == core.RingBuffer.Error.Full);

    // Dequeue in order
    var d1 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d1, pkt1));
    var d2 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d2, pkt2));
    var d3 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d3, pkt3));
    var d4 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d4, pkt4));

    // Buffer empty now
    std.debug.assert(rb.dequeue() == null);

    // Test wrap-around behavior
    try rb.enqueue(pkt1);
    try rb.enqueue(pkt2);
    var d5 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d5, pkt1));
    try rb.enqueue(pkt3);
    try rb.enqueue(pkt4);
    var d6 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d6, pkt2));
    var d7 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d7, pkt3));
    var d8 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d8, pkt4));

    // Zero-copy test: modify original data after enqueue
    var mutable_pkt: [10]u8 = "mutable";
    try rb.enqueue(mutable_pkt[0..7]);
    mutable_pkt[0] = 'M';
    var d9 = rb.dequeue() orelse unreachable;
    std.debug.assert(std.mem.eql(u8, d9, "Mutable".[0..7]));

    std.debug.print("All tests passed.\n", .{});
}
