const std = @import("std");
const core = @import("core.zig");

test "Level initialization" {
    const level = core.Level.init(0, 1024, 10, 0.8);
    std.debug.assert(level.id == 0);
    std.debug.assert(level.state == .Active);
    std.debug.assert(level.size_bytes == 0);
    std.debug.assert(level.capacity_bytes == 1024);
    std.debug.assert(level.fanout == 10);
    std.debug.assert(level.compaction_threshold == 0.8);
}

test "Level isFull detection" {
    var level = core.Level.init(0, 1000, 10, 0.8);
    std.debug.assert(!level.isFull());
    level.addData(799);
    std.debug.assert(!level.isFull());
    level.addData(1);
    std.debug.assert(level.isFull());
}

test "AdaptivePolicy fanout selection" {
    var policy = core.AdaptivePolicy.init(.Hybrid, 10, 4, 0.8, 0.5, 5);
    std.debug.assert(policy.getFanout(0) == 10);
    std.debug.assert(policy.getFanout(1) == 10);
    std.debug.assert(policy.getFanout(2) == 4);
    std.debug.assert(policy.getFanout(3) == 4);
}

test "AdaptivePolicy threshold selection" {
    var policy = core.AdaptivePolicy.init(.Hybrid, 10, 4, 0.8, 0.5, 5);
    std.debug.assert(policy.getThreshold(0) == 0.8);
    std.debug.assert(policy.getThreshold(1) == 0.8);
    std.debug.assert(policy.getThreshold(2) == 0.5);
    std.debug.assert(policy.getThreshold(3) == 0.5);
}

test "LSMTree initialization" {
    var policy = core.AdaptivePolicy.init(.SizeTiered, 10, 10, 0.8, 0.8, 4);
    var tree = core.LSMTree.init(policy, 1024, 4);
    std.debug.assert(tree.num_levels == 4);
    std.debug.assert(tree.total_written == 0);
    std.debug.assert(tree.compactions_triggered == 0);
    std.debug.assert(tree.getSpaceUsage() == 0);
}

test "LSMTree write and compaction" {
    var policy = core.AdaptivePolicy.init(.SizeTiered, 10, 10, 0.8, 0.8, 3);
    var tree = core.LSMTree.init(policy, 100, 3);

    tree.write(80) catch unreachable;
    std.debug.assert(tree.getLevelSize(0) == 80);
    std.debug.assert(tree.compactions_triggered == 0);

    tree.write(20) catch unreachable;
    std.debug.assert(tree.compactions_triggered >= 1);
    std.debug.assert(tree.total_written == 100);
}

test "LSMTree space usage tracking" {
    var policy = core.AdaptivePolicy.init(.Leveled, 4, 4, 0.5, 0.5, 3);
    var tree = core.LSMTree.init(policy, 100, 3);

    tree.write(50) catch unreachable;
    std.debug.assert(tree.getSpaceUsage() == 50);

    tree.write(50) catch unreachable;
    std.debug.assert(tree.getSpaceUsage() <= 100);
}

test "LSMTree compaction ratio" {
    var policy = core.AdaptivePolicy.init(.SizeTiered, 10, 10, 0.8, 0.8, 3);
    var tree = core.LSMTree.init(policy, 100, 3);

    std.debug.assert(tree.getCompactionRatio() == 0.0);

    tree.write(80) catch unreachable;
    tree.write(20) catch unreachable;
    const ratio = tree.getCompactionRatio();
    std.debug.assert(ratio > 0.0);
}

test "Level state transitions" {
    var level = core.Level.init(0, 100, 10, 0.8);
    std.debug.assert(level.state == .Active);
    level.state = .Frozen;
    std.debug.assert(level.state == .Frozen);
    level.state = .Compacting;
    std.debug.assert(level.state == .Compacting);
    level.reset();
    std.debug.assert(level.state == .Active);
    std.debug.assert(level.size_bytes == 0);
}

test "AdaptivePolicy capacity computation" {
    var policy = core.AdaptivePolicy.init(.SizeTiered, 10, 10, 0.8, 0.8, 4);
    const cap0 = policy.computeCapacity(0, 100);
    const cap1 = policy.computeCapacity(1, 100);
    std.debug.assert(cap0 == 100);
    std.debug.assert(cap1 > cap0);
}

pub fn main() !void {
    const gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var policy = core.AdaptivePolicy.init(.Hybrid, 10, 4, 0.8, 0.5, 5);
    var tree = core.LSMTree.init(policy, 1024, 5);

    var i: u64 = 0;
    while (i < 1000) : (i += 1) {
        tree.write(10) catch unreachable;
    }

    std.debug.assert(tree.total_written == 10000);
    std.debug.assert(tree.compactions_triggered > 0);
    std.debug.assert(tree.getSpaceUsage() <= 10000);

    std.debug.print("LSM-Tree Adaptive Architecture: PASSED\n", .{});
    std.debug.print("Total Written: {d} bytes\n", .{tree.total_written});
    std.debug.print("Compactions Triggered: {d}\n", .{tree.compactions_triggered});
    std.debug.print("Final Space Usage: {d} bytes\n", .{tree.getSpaceUsage()});
    std.debug.print("Compaction Ratio: {d:.4}\n", .{tree.getCompactionRatio()});
}
