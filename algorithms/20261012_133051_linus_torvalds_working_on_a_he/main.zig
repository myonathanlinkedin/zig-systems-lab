const std = @import("std");
const engine = @import("engine.zig");
const types = @import("types.zig");
const MinHeap = types.MinHeap;
const HeapError = types.HeapError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = &gpa.allocator;

    // ---------- Test 1: Basic push/pop order ----------
    var heap = try engine.initHeap(i32, allocator, 0);
    defer engine.deinitHeap(i32, &heap);

    try engine.push(i32, &heap, 5);
    try engine.push(i32, &heap, 3);
    try engine.push(i32, &heap, 8);
    try engine.push(i32, &heap, 1);

    std.debug.assert(engine.size(i32, &heap) == 4);
    std.debug.assert((try engine.peek(i32, &heap)) == 1);

    std.debug.assert((try engine.pop(i32, &heap)) == 1);
    std.debug.assert((try engine.pop(i32, &heap)) == 3);
    std.debug.assert((try engine.pop(i32, &heap)) == 5);
    std.debug.assert((try engine.pop(i32, &heap)) == 8);
    std.debug.assert(engine.size(i32, &heap) == 0);

    // ---------- Test 2: Empty heap error handling ----------
    var emptyHeap = try engine.initHeap(i32, allocator, 2);
    defer engine.deinitHeap(i32, &emptyHeap);
    const popResult = engine.pop(i32, &emptyHeap);
    std.debug.assert(popResult catch |e| e == HeapError.EmptyHeap);
    const peekResult = engine.peek(i32, &emptyHeap);
    std.debug.assert(peekResult catch |e| e == HeapError.EmptyHeap);

    // ---------- Test 3: Large random dataset ----------
    const N = 10_000;
    var largeHeap = try engine.initHeap(u64, allocator, 0);
    defer engine.deinitHeap(u64, &largeHeap);

    var rng = std.rand.DefaultPrng.init(0xdeadbeef);
    var rand = rng.random();

    // Insert N random numbers.
    var i: usize = 0;
    while (i < N) : (i += 1) {
        const val = rand.int(u64);
        try engine.push(u64, &largeHeap, val);
    }
    std.debug.assert(engine.size(u64, &largeHeap) == N);

    // Verify monotonic pop order.
    var prev: u64 = 0;
    var first = true;
    while (engine.size(u64, &largeHeap) > 0) : (i -= 1) {
        const cur = try engine.pop(u64, &largeHeap);
        if (!first) {
            std.debug.assert(prev <= cur);
        } else {
            first = false;
        }
        prev = cur;
    }

    // ---------- Test 4: Duplicate values ----------
    var dupHeap = try engine.initHeap(i32, allocator, 0);
    defer engine.deinitHeap(i32, &dupHeap);
    try engine.push(i32, &dupHeap, 42);
    try engine.push(i32, &dupHeap, 42);
    try engine.push(i32, &dupHeap, 42);
    std.debug.assert(engine.size(i32, &dupHeap) == 3);
    std.debug.assert((try engine.pop(i32, &dupHeap)) == 42);
    std.debug.assert((try engine.pop(i32, &dupHeap)) == 42);
    std.debug.assert((try engine.pop(i32, &dupHeap)) == 42);
    std.debug.assert(engine.size(i32, &dupHeap) == 0);

    // ---------- Test 5: Capacity growth ----------
    var growHeap = try engine.initHeap(i32, allocator, 1);
    defer engine.deinitHeap(i32, &growHeap);
    // Insert more elements than initial capacity to trigger realloc.
    var j: usize = 0;
    while (j < 100) : (j += 1) {
        try engine.push(i32, &growHeap, @intCast(i32, j));
    }
    std.debug.assert(engine.size(i32, &growHeap) == 100);
    // Verify smallest element after growth.
    std.debug.assert((try engine.peek(i32, &growHeap)) == 0);

    // All assertions passed.
    std.debug.print("All heap tests passed.\n", .{});
}
