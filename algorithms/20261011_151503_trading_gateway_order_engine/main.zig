const std = @import("std");
const RingBuffer = @import("core.zig").RingBuffer;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    // Test with integers
    var rb = try RingBuffer(i32).init(allocator, 3);
    defer rb.deinit();

    std.debug.assert(rb.is_empty());
    std.debug.assert(!rb.is_full());
    std.debug.assert(rb.len() == 0);
    std.debug.assert(rb.cap() == 3);

    // Push elements
    std.debug.assert(rb.push(10));
    std.debug.assert(rb.push(20));
    std.debug.assert(rb.push(30));
    std.debug.assert(!rb.push(40)); // should be full

    std.debug.assert(rb.is_full());
    std.debug.assert(rb.len() == 3);

    // Pop elements
    var val = rb.pop();
    std.debug.assert(val != null);
    std.debug.assert(val.? == 10);
    std.debug.assert(rb.len() == 2);

    val = rb.pop();
    std.debug.assert(val.? == 20);
    val = rb.pop();
    std.debug.assert(val.? == 30);
    std.debug.assert(rb.is_empty());

    // Test wrap-around
    std.debug.assert(rb.push(1));
    std.debug.assert(rb.push(2));
    std.debug.assert(rb.push(3));
    std.debug.assert(rb.is_full());
    val = rb.pop();
    std.debug.assert(val.? == 1);
    std.debug.assert(rb.push(4));
    std.debug.assert(rb.is_full());
    val = rb.pop();
    std.debug.assert(val.? == 2);
    val = rb.pop();
    std.debug.assert(val.? == 3);
    val = rb.pop();
    std.debug.assert(val.? == 4);
    std.debug.assert(rb.is_empty());

    // Test with struct type
    const Point = struct { x: i32, y: i32 };
    var rb2 = try RingBuffer(Point).init(allocator, 2);
    defer rb2.deinit();

    std.debug.assert(rb2.push(.{ .x = 1, .y = 2 }));
    std.debug.assert(rb2.push(.{ .x = 3, .y = 4 }));
    std.debug.assert(!rb2.push(.{ .x = 5, .y = 6 }));

    var p = rb2.pop();
    std.debug.assert(p != null);
    std.debug.assert(p.?.x == 1);
    std.debug.assert(p.?.y == 2);

    p = rb2.pop();
    std.debug.assert(p.?.x == 3);
    std.debug.assert(p.?.y == 4);
    std.debug.assert(rb2.is_empty());

    std.debug.print("All tests passed.\n", .{});
}
