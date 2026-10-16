const std = @import("std");
const core = @import("core.zig");
const BoundedBlockingQueue = core.BoundedBlockingQueue;
const QueueError = core.QueueError;

const TestQueue = BoundedBlockingQueue(u32);

fn testBasicFifo() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 4);
    defer q.deinit(allocator);

    try q.tryPut(10);
    try q.tryPut(20);
    try q.tryPut(30);
    std.debug.assert(q.len() == 3);
    std.debug.assert(q.capacity() == 4);
    std.debug.assert(!q.isEmpty());
    std.debug.assert(!q.isFull());

    std.debug.assert(try q.tryGet() == 10);
    std.debug.assert(try q.tryGet() == 20);
    std.debug.assert(try q.tryGet() == 30);
    std.debug.assert(q.isEmpty());
}

fn testTryPutFull() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 2);
    defer q.deinit(allocator);

    try q.tryPut(1);
    try q.tryPut(2);
    std.debug.assert(q.isFull());
    std.debug.assert(q.len() == 2);

    const err = q.tryPut(3) catch |e| e;
    std.debug.assert(err == QueueError.Full);
    std.debug.assert(q.len() == 2);
}

fn testTryGetEmpty() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 3);
    defer q.deinit(allocator);

    std.debug.assert(q.isEmpty());
    const err = q.tryGet() catch |e| e;
    std.debug.assert(err == QueueError.Empty);
}

fn testWraparound() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 3);
    defer q.deinit(allocator);

    // Fill and drain repeatedly to force head/tail wraparound.
    var i: u32 = 0;
    while (i < 30) : (i += 1) {
        try q.tryPut(i);
        const v = try q.tryGet();
        std.debug.assert(v == i);
    }
    std.debug.assert(q.isEmpty());
}

fn testBlockingProducerConsumer() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 2);
    defer q.deinit(allocator);

    const N: u32 = 1000;
    const producer = std.Thread.spawn(.{}, producerFn, .{ &q, N }) catch unreachable;
    const consumer = std.Thread.spawn(.{}, consumerFn, .{ &q, N }) catch unreachable;
    producer.join();
    consumer.join();
    std.debug.assert(q.isEmpty());
}

fn producerFn(q: *TestQueue, n: u32) void {
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        q.put(i) catch unreachable;
    }
}

fn consumerFn(q: *TestQueue, n: u32) void {
    var sum: u64 = 0;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        sum += q.get() catch unreachable;
    }
    // Sum of 0..n-1
    const expected: u64 = @as(u64, n) * (n - 1) / 2;
    std.debug.assert(sum == expected);
}

fn testCapacityOne() !void {
    const allocator = std.testing.allocator;
    var q = try TestQueue.init(allocator, 1);
    defer q.deinit(allocator);

    try q.tryPut(42);
    std.debug.assert(q.isFull());
    std.debug.assert(try q.tryGet() == 42);
    std.debug.assert(q.isEmpty());
}

pub fn main() !void {
    try testBasicFifo();
    try testTryPutFull();
    try testTryGetEmpty();
    try testWraparound();
    try testCapacityOne();
    try testBlockingProducerConsumer();
    std.debug.print("All tests passed.\n", .{});
}
