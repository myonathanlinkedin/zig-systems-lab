const std = @import("std");
const types = @import("types.zig");
const engine_mod = @import("engine.zig");

pub fn main() !void {
    const allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer allocator.deinit();

    // --------------------------------------------------------------------
    // Unit Test 1: Basic push/pop order preservation.
    // --------------------------------------------------------------------
    var ring = try types.RingBuffer.init(&allocator.allocator, 4);
    defer ring.deinit(&allocator.allocator);

    const pkt1 = "hello";
    const pkt2 = "world";
    const pkt3 = "zig";

    std.debug.assert(ring.isEmpty());
    try ring.push(pkt1);
    try ring.push(pkt2);
    try ring.push(pkt3);
    std.debug.assert(!ring.isEmpty());
    std.debug.assert(!ring.isFull());

    // Pop in FIFO order.
    var popped = try ring.pop();
    std.debug.assert(popped == pkt1);
    popped = try ring.pop();
    std.debug.assert(popped == pkt2);
    popped = try ring.pop();
    std.debug.assert(popped == pkt3);
    std.debug.assert(ring.isEmpty());

    // --------------------------------------------------------------------
    // Unit Test 2: Full buffer detection and wrap‑around behaviour.
    // --------------------------------------------------------------------
    // Fill the buffer completely.
    try ring.push(pkt1);
    try ring.push(pkt2);
    try ring.push(pkt3);
    const pkt4 = "buffer";
    try ring.push(pkt4);
    std.debug.assert(ring.isFull());

    // Attempt to push into a full buffer – should error.
    const push_err = ring.push("extra") catch |e| e;
    std.debug.assert(push_err == types.RingError.Full);

    // Pop two elements to create space.
    _ = try ring.pop(); // pkt1
    _ = try ring.pop(); // pkt2
    std.debug.assert(!ring.isFull());
    std.debug.assert(ring.count == 2);

    // Push two more to test wrap‑around.
    const pkt5 = "wrap1";
    const pkt6 = "wrap2";
    try ring.push(pkt5);
    try ring.push(pkt6);
    std.debug.assert(ring.isFull());

    // Verify order after wrap‑around.
    popped = try ring.pop(); // pkt3
    std.debug.assert(popped == pkt3);
    popped = try ring.pop(); // pkt4
    std.debug.assert(popped == pkt4);
    popped = try ring.pop(); // pkt5
    std.debug.assert(popped == pkt5);
    popped = try ring.pop(); // pkt6
    std.debug.assert(popped == pkt6);
    std.debug.assert(ring.isEmpty());

    // --------------------------------------------------------------------
    // Unit Test 3: Engine façade correctness.
    // --------------------------------------------------------------------
    var eng_ring = try types.RingBuffer.init(&allocator.allocator, 2);
    defer eng_ring.deinit(&allocator.allocator);
    var eng = engine_mod.Engine.init(&eng_ring);

    // Enqueue two packets – should succeed.
    std.debug.assert(eng.enqueue("first"));
    std.debug.assert(eng.enqueue("second"));
    // Buffer now full; further enqueue must fail.
    std.debug.assert(!eng.enqueue("third"));

    // Dequeue and verify.
    var pkt = eng.dequeue();
    std.debug.assert(pkt != null and pkt.? == "first");
    pkt = eng.dequeue();
    std.debug.assert(pkt != null and pkt.? == "second");
    std.debug.assert(eng.dequeue() == null);

    // Re‑enqueue and use processAll.
    std.debug.assert(eng.enqueue("alpha"));
    std.debug.assert(eng.enqueue("beta"));
    var processed_count: usize = 0;
    const handler = fn (p: []const u8) void {
        // Simple handler that counts packets.
        processed_count += 1;
        // Verify that the handler receives the exact data.
        if (processed_count == 1) std.debug.assert(p == "alpha");
        if (processed_count == 2) std.debug.assert(p == "beta");
    };
    const any_processed = eng.processAll(handler);
    std.debug.assert(any_processed);
    std.debug.assert(processed_count == 2);
    std.debug.assert(!eng.dequeue());

    // --------------------------------------------------------------------
    // Unit Test 4: Dispatch via RingBuffer directly.
    // --------------------------------------------------------------------
    var disp_ring = try types.RingBuffer.init(&allocator.allocator, 3);
    defer disp_ring.deinit(&allocator.allocator);
    try disp_ring.push("A");
    try disp_ring.push("B");
    try disp_ring.push("C");

    var dispatch_counter: usize = 0;
    const dispatch_handler = fn (p: []const u8) void {
        dispatch_counter += 1;
        // Ensure order A, B, C.
        if (dispatch_counter == 1) std.debug.assert(p == "A");
        if (dispatch_counter == 2) std.debug.assert(p == "B");
        if (dispatch_counter == 3) std.debug.assert(p == "C");
    };
    try disp_ring.dispatch(dispatch_handler);
    std.debug.assert(dispatch_counter == 3);
    std.debug.assert(disp_ring.isEmpty());

    // All assertions passed – program exits cleanly.
    return;
}
