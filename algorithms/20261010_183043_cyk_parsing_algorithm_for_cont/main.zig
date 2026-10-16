const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    // Grammar for the language { aⁿ bⁿ | n ≥ 1 } in Chomsky Normal Form:
    //   S → A B
    //   S → S S
    //   A → a
    //   B → b
    //
    // Non‑terminal indices:
    //   0 : S (start)
    //   1 : A
    //   2 : B
    //
    // Binary productions:
    //   S → A B   (0 → 1 2)
    //   S → S S   (0 → 0 0)
    // Terminal productions are encoded in the terminal_masks array.
    const binary_prods = [_]core.BinaryProd{
        .{ .left = 0, .right1 = 1, .right2 = 2 }, // S → A B
        .{ .left = 0, .right1 = 0, .right2 = 0 }, // S → S S
    };

    var terminal_masks = [_]u64{0} ** 256;
    // A → a
    terminal_masks['a'] = core.bit(1);
    // B → b
    terminal_masks['b'] = core.bit(2);

    const g = core.Grammar{
        .start = 0,
        .terminal_masks = terminal_masks,
        .binary_productions = &binary_prods,
    };

    // Helper to assert parsing result.
    inline fn assertParse(input: []const u8, expected: bool) void {
        const result = core.parse(g, input);
        std.debug.assert(result == expected);
    }

    // Positive test cases.
    assertParse("ab", true);
    assertParse("aabb", true);
    assertParse("aaabbb", true);
    assertParse("aaaabbbb", true);
    assertParse("aaaaaaaaabbbbbbbbbb", true);

    // Negative test cases.
    assertParse("", false);               // empty string
    assertParse("a", false);              // single terminal
    assertParse("b", false);
    assertParse("aab", false);
    assertParse("abb", false);
    assertParse("ba", false);
    assertParse("abab", false);           // interleaved
    assertParse("aaabbbbbb", false);      // mismatched counts

    // Edge case: long correct string (length 1000, 500 a's followed by 500 b's)
    const len = 500;
    var buffer = try std.heap.page_allocator.alloc(u8, len * 2);
    defer std.heap.page_allocator.free(buffer);
    for (buffer[0..len]) |*c| c.* = 'a';
    for (buffer[len..]) |*c| c.* = 'b';
    assertParse(buffer, true);

    // All assertions passed.
    std.debug.print("All CYK tests passed.\n", .{});
}
