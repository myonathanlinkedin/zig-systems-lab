const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define nonterminal indices
    const S: u8 = 0;
    const A: u8 = 1;
    const B: u8 = 2;

    // Build grammar: S -> AB | BA, A -> 'a', B -> 'b'
    const prod_count = 5;
    const prods = try allocator.alloc(core.Production, prod_count);
    defer allocator.free(prods);

    prods[0] = core.Production{ .lhs = S, .rhs = .{ .binary = .{ .left = A, .right = B } } };
    prods[1] = core.Production{ .lhs = S, .rhs = .{ .binary = .{ .left = B, .right = A } } };
    prods[2] = core.Production{ .lhs = A, .rhs = .{ .terminal = 'a' } };
    prods[3] = core.Production{ .lhs = B, .rhs = .{ .terminal = 'b' } };
    prods[4] = core.Production{ .lhs = B, .rhs = .{ .terminal = 'b' } }; // duplicate to test robustness

    const grammar = core.Grammar{ .start = S, .productions = prods };

    // Test cases
    const tests = [_]struct {
        input: []const u8,
        expected: bool,
    }{
        .{ .input = "ab", .expected = true },
        .{ .input = "ba", .expected = true },
        .{ .input = "aa", .expected = false },
        .{ .input = "bb", .expected = false },
        .{ .input = "aba", .expected = false },
        .{ .input = "", .expected = false },
    };

    for (tests) |t| {
        const result = core.cyk(allocator, &grammar, t.input);
        std.debug.assert(result == t.expected);
    }

    // Additional test: longer string not derivable
    const long_input = "abab";
    const long_result = core.cyk(allocator, &grammar, long_input);
    std.debug.assert(long_result == false);

    // Edge case: single character
    const single = "a";
    std.debug.assert(core.cyk(allocator, &grammar, single) == false);

    // All tests passed
    std.debug.print("All CYK tests passed.\n", .{});
}
