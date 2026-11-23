const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    // Test 1: Small cardinality, p=4 (m=16)
    {
        var h = try core.HyperLogLog.init(4);
        defer h.deinit();
        const items = [_][]const u8{ "a", "b", "c", "d", "e" };
        for (items) |it| h.add(it);
        const est = h.count();
        std.debug.assert(est >= 5.0 and est <= 6.0); // within 20%
    }

    // Test 2: Medium cardinality, p=10 (m=1024)
    {
        var h = try core.HyperLogLog.init(10);
        defer h.deinit();
        const n = 5000;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            var buf = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{i});
            defer std.heap.page_allocator.free(buf);
            h.add(buf);
        }
        const est = h.count();
        const rel_err = @abs(est - @intToFloat(f64, n)) / @intToFloat(f64, n);
        std.debug.assert(rel_err < 0.15); // <15% error
    }

    // Test 3: Large cardinality, p=14 (m=16384)
    {
        var h = try core.HyperLogLog.init(14);
        defer h.deinit();
        const n = 200_000;
        var i: usize = 0;
        while (i < n) : (i += 1) {
            var buf = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{i});
            defer std.heap.page_allocator.free(buf);
            h.add(buf);
        }
        const est = h.count();
        const rel_err = @abs(est - @intToFloat(f64, n)) / @intToFloat(f64, n);
        std.debug.assert(rel_err < 0.12); // <12% error
    }

    // All tests passed
    std.debug.print("All HyperLogLog tests passed.\n", .{});
}
