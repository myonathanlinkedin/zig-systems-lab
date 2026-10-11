const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(!leaked);
    }
    const allocator = &gpa.allocator;

    // Create a deque of i32 with small initial capacity to test growth.
    var dq = try core.Deque(i32).init(allocator, 2);
    defer dq.deinit();

    // Initially empty.
    std.debug.assert(dq.isEmpty());
    std.debug.assert(dq.len() == 0);
    std.debug.assert(dq.peekFront() == null);
    std.debug.assert(dq.peekBack() == null);

    // Push back elements.
    try dq.pushBack(10);
    try dq.pushBack(20);
    std.debug.assert(!dq.isEmpty());
    std.debug.assert(dq.len() == 2);
    std.debug.assert(dq.peekFront().? == 10);
    std.debug.assert(dq.peekBack().? == 20);

    // Trigger growth by pushing another element.
    try dq.pushBack(30);
    std.debug.assert(dq.len() == 3);
    std.debug.assert(dq.peekFront().? == 10);
    std.debug.assert(dq.peekBack().? == 30);

    // Push front.
    try dq.pushFront(5);
    std.debug.assert(dq.len() == 4);
    std.debug.assert(dq.peekFront().? == 5);
    std.debug.assert(dq.peekBack().? == 30);

    // Pop front.
    const f1 = try dq.popFront();
    std.debug.assert(f1 == 5);
    std.debug.assert(dq.peekFront().? == 10);
    std.debug.assert(dq.len() == 3);

    // Pop back.
    const b1 = try dq.popBack();
    std.debug.assert(b1 == 30);
    std.debug.assert(dq.peekBack().? == 20);
    std.debug.assert(dq.len() == 2);

    // Exhaust remaining elements.
    const f2 = try dq.popFront();
    const f3 = try dq.popFront();
    std.debug.assert(f2 == 10);
    std.debug.assert(f3 == 20);
    std.debug.assert(dq.isEmpty());

    // Reuse after empty.
    try dq.pushFront(100);
    try dq.pushBack(200);
    std.debug.assert(dq.len() == 2);
    std.debug.assert(dq.peekFront().? == 100);
    std.debug.assert(dq.peekBack().? == 200);

    // Iterator test.
    var it = dq.iterator();
    const vals = [_]i32{ it.next().?, it.next().? };
    std.debug.assert(vals[0] == 100);
    std.debug.assert(vals[1] == 200);
    std.debug.assert(it.next() == null);
}
