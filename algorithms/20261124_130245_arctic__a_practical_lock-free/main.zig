const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const root = core.newTree();

    // deterministic test keys
    const keys = [_]u64{
        0x0102030405060708,
        0xFFFFFFFFFFFFFFFF,
        0x0000000000000000,
        0x1234567890ABCDEF,
        0x0F0E0D0C0B0A0908,
    };
    const values = [_]usize{ 42, 99, 7, 1234, 5555 };

    // Insert
    for (keys) |k, i| {
        core.insert(root, k, values[i]);
    }

    // Retrieve and verify
    for (keys) |k, i| {
        const got = core.get(root, k);
        std.debug.assert(got != null and got.? == values[i]);
    }

    // Missing key
    std.debug.assert(core.get(root, 0x1111111111111111) == null);

    // Delete a key and verify removal
    std.debug.assert(core.delete(root, 0xFFFFFFFFFFFFFFFF) == true);
    std.debug.assert(core.get(root, 0xFFFFFFFFFFFFFFFF) == null);
    // Deleting again should fail
    std.debug.assert(core.delete(root, 0xFFFFFFFFFFFFFFFF) == false);

    // Delete remaining keys
    for (keys) |k| {
        _ = core.delete(root, k);
    }
    // Tree should be empty
    for (keys) |k| {
        std.debug.assert(core.get(root, k) == null);
    }
}
