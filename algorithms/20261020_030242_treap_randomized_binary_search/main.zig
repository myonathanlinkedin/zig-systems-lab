const std = @import("std");
const core = @import("core.zig");
const Treap = core.Treap;

pub fn main() !void {
    testInsertAndContains();
    testRemove();
    testMinMax();
    testInorderSorted();
    testDuplicates();
    testEmpty();
    testHeight();
    testLargeInsertion();
    std.debug.print("All tests passed.\n", .{});
}

fn testInsertAndContains() void {
    var t = Treap.init(42);
    defer t.deinit();
    for (.{ 5, 3, 8, 1, 4, 7, 9, 2, 6 }) |k| t.insert(k) catch unreachable;
    std.debug.assert(t.size == 9);
    for (.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }) |k| std.debug.assert(t.contains(k));
    std.debug.assert(!t.contains(0));
    std.debug.assert(!t.contains(10));
}

fn testRemove() void {
    var t = Treap.init(123);
    defer t.deinit();
    for (.{ 10, 20, 30, 40, 50 }) |k| t.insert(k) catch unreachable;
    std.debug.assert(t.remove(30));
    std.debug.assert(!t.contains(30));
    std.debug.assert(t.size == 4);
    std.debug.assert(!t.remove(99));
    std.debug.assert(t.size == 4);
    std.debug.assert(t.remove(10));
    std.debug.assert(t.remove(50));
    std.debug.assert(t.size == 2);
    std.debug.assert(t.contains(20));
    std.debug.assert(t.contains(40));
}

fn testMinMax() void {
    var t = Treap.init(7);
    defer t.deinit();
    for (.{ 42, 17, 83, 5, 99, 23 }) |k| t.insert(k) catch unreachable;
    std.debug.assert(t.min() == 5);
    std.debug.assert(t.max() == 99);
    t.remove(5);
    std.debug.assert(t.min() == 17);
    t.remove(99);
    std.debug.assert(t.max() == 83);
}

fn testInorderSorted() void {
    var t = Treap.init(99);
    defer t.deinit();
    const keys = [_]u32{ 50, 30, 70, 20, 40, 60, 80, 10, 25, 35, 45, 55, 65, 75, 85 };
    for (keys) |k| t.insert(k) catch unreachable;
    var buf: [16]u32 = undefined;
    const n = t.inorder(&buf);
    std.debug.assert(n == 15);
    for (0..n - 1) |i| std.debug.assert(buf[i] < buf[i + 1]);
}

fn testDuplicates() void {
    var t = Treap.init(55);
    defer t.deinit();
    t.insert(5) catch unreachable;
    t.insert(5) catch unreachable;
    std.debug.assert(t.size == 2);
    std.debug.assert(t.contains(5));
    std.debug.assert(t.remove(5));
    std.debug.assert(t.size == 1);
    std.debug.assert(t.contains(5));
    std.debug.assert(t.remove(5));
    std.debug.assert(t.size == 0);
    std.debug.assert(!t.contains(5));
}

fn testEmpty() void {
    var t = Treap.init(1);
    defer t.deinit();
    std.debug.assert(t.size == 0);
    std.debug.assert(t.min() == null);
    std.debug.assert(t.max() == null);
    std.debug.assert(!t.contains(0));
    std.debug.assert(!t.remove(0));
    std.debug.assert(t.height() == 0);
}

fn testHeight() void {
    var t = Treap.init(314);
    defer t.deinit();
    for (0..100) |i| t.insert(@as(u32, i)) catch unreachable;
    const h = t.height();
    std.debug.assert(h >= 1);
    std.debug.assert(h <= 50);
}

fn testLargeInsertion() void {
    var t = Treap.init(271828);
    defer t.deinit();
    const n: u32 = 1000;
    for (0..n) |i| t.insert(@as(u32, i)) catch unreachable;
    std.debug.assert(t.size == n);
    for (0..n) |i| std.debug.assert(t.contains(@as(u32, i)));
    std.debug.assert(t.min() == 0);
    std.debug.assert(t.max() == n - 1);
    const h = t.height();
    std.debug.assert(h <= 60);
    for (0..n) |i| {
        if (i % 2 == 0) {
            std.debug.assert(t.remove(@as(u32, i)));
        }
    }
    std.debug.assert(t.size == n / 2);
    for (0..n) |i| {
        if (i % 2 == 1) std.debug.assert(t.contains(@as(u32, i)));
    }
}
