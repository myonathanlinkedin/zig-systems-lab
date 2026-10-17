const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var grammar = core.Grammar.init(&allocator, 3); // Nonterminals: 0=S,1=A,2=B
    defer grammar.deinit();

    // Productions:
    // S -> A B
    // S -> S S
    // A -> 'a'
    // B -> 'b'
    try grammar.addBinary(0, 1, 2); // S -> A B
    try grammar.addBinary(0, 0, 0); // S -> S S
    try grammar.addTerminal(1, 'a'); // A -> a
    try grammar.addTerminal(2, 'b'); // B -> b

    // Helper to test strings
    fn test(input: []const u8, expected: bool) void {
        const result = grammar.cyk(input);
        std.debug.assert(result == expected);
    }

    // Accepted strings
    test("ab", true);
    test("abab", true);
    test("ababab", true);
    test("abababab", true);

    // Rejected strings
    test("", false);
    test("a", false);
    test("b", false);
    test("aba", false);
    test("abb", false);
    test("aab", false);
    test("ba", false);
    test("ababa", false);

    // Additional edge cases
    test("ab" ** 10, true); // 20 chars, repeated "ab"
    test("ab" ** 10 ++ "a", false); // extra terminal

    // Print confirmation (optional, not required for verification)
    std.debug.print("All CYK tests passed.\n", .{});
}
