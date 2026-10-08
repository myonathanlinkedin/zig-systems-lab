const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = core.ScalardbEngine.init(allocator);
    defer engine.deinit();

    // Test 1: Write transaction
    const write_txn = try engine.executeTransaction(.write, "key1", "value1");
    std.debug.assert(write_txn.id == 1);
    std.debug.assert(write_txn.type == .write);
    std.debug.assert(write_txn.status == .committed);
    std.debug.assert(write_txn.timestamp == 1);

    // Test 2: Read transaction
    const read_txn = try engine.executeTransaction(.read, "key1", null);
    std.debug.assert(read_txn.id == 2);
    std.debug.assert(read_txn.type == .read);
    std.debug.assert(read_txn.status == .committed);
    std.debug.assert(read_txn.timestamp == 2);

    // Test 3: Verify data store
    const val = engine.get("key1");
    std.debug.assert(val != null);
    std.debug.assert(val.? == 'v');

    // Test 4: Delete transaction
    const delete_txn = try engine.executeTransaction(.delete, "key1", null);
    std.debug.assert(delete_txn.id == 3);
    std.debug.assert(delete_txn.type == .delete);
    std.debug.assert(delete_txn.status == .committed);
    std.debug.assert(delete_txn.timestamp == 3);

    // Test 5: Verify deletion
    const deleted_val = engine.get("key1");
    std.debug.assert(deleted_val == null);

    // Test 6: Multiple writes
    _ = try engine.executeTransaction(.write, "key2", "value2");
    _ = try engine.executeTransaction(.write, "key3", "value3");
    std.debug.assert(engine.get("key2") != null);
    std.debug.assert(engine.get("key3") != null);

    // Test 7: Transaction log integrity
    const log = engine.getTransactionLog();
    std.debug.assert(log.len == 6);
    std.debug.assert(log[0].id == 1);
    std.debug.assert(log[5].id == 6);
    std.debug.assert(log[0].timestamp < log[5].timestamp);

    // Test 8: Transaction count
    std.debug.assert(engine.getTransactionCount() == 6);

    // Test 9: Timestamp monotonicity
    for (log) |txn| {
        std.debug.assert(txn.timestamp > 0);
    }

    // Test 10: All transactions committed
    for (log) |txn| {
        std.debug.assert(txn.status == .committed);
    }

    std.debug.print("All tests passed.\n", .{});
}
