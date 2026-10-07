const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // --------------------------------------------------------------------
    // Basic functionality tests
    // --------------------------------------------------------------------
    var chain = core.ContextualChain.init(allocator);
    defer chain.deinit();

    const secret = "supersecret";

    // Empty chain should verify trivially.
    std.debug.assert(chain.verify(secret) == true);

    // Add two legitimate entries.
    try chain.addEntry("deviceA", secret);
    std.debug.assert(chain.verify(secret) == true);

    try chain.addEntry("deviceB", secret);
    std.debug.assert(chain.verify(secret) == true);

    // Wrong secret must break verification.
    std.debug.assert(chain.verify("wrong") == false);

    // --------------------------------------------------------------------
    // Tampering detection test
    // --------------------------------------------------------------------
    var tampered = core.ContextualChain.init(allocator);
    defer tampered.deinit();

    try tampered.addEntry("deviceA", secret);
    try tampered.addEntry("deviceB", secret);

    // Corrupt the second entry's context (simulating an attack).
    tampered.entries.items[1].context = "tampered";

    std.debug.assert(tampered.verify(secret) == false);

    // --------------------------------------------------------------------
    // lastHash correctness test
    // --------------------------------------------------------------------
    const maybe_hash = chain.lastHash();
    std.debug.assert(maybe_hash != null);

    // Re‑compute expected last hash using the public helper.
    var prev_hash: [32]u8 = [_]u8{0} ** 32;
    const first_hash = core.ContextualChain.computeHash(&prev_hash, "deviceA", secret);
    const second_hash = core.ContextualChain.computeHash(&first_hash, "deviceB", secret);
    std.debug.assert(std.mem.eql(u8, &second_hash, &maybe_hash.?));

    // --------------------------------------------------------------------
    // All tests passed
    // --------------------------------------------------------------------
    std.debug.print("All ContextualChain tests passed.\n", .{});
    return;
}
