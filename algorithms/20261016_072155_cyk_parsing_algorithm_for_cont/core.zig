const std = @import("std");

pub const Production = struct {
    lhs: u8,
    rhs: Rhs,
};

pub const Rhs = union(enum) {
    binary: struct { left: u8, right: u8 },
    terminal: u8,
};

pub const Grammar = struct {
    start: u8,
    productions: []Production,
};

pub fn cyk(allocator: std.mem.Allocator, grammar: *const Grammar, input: []const u8) bool {
    const n = input.len;
    if (n == 0) return false;

    const table = try allocator.alloc(u64, n * n);
    defer allocator.free(table);
    @memset(table, 0);

    // Initialize table for length 1 substrings
    for (input, i) |ch, idx| {
        for (grammar.productions) |prod| {
            if (prod.rhs == .terminal and prod.rhs.terminal == ch) {
                table[idx * n + idx] |= @as(u64, 1) << prod.lhs;
            }
        }
    }

    // CYK main loop
    var l: usize = 2;
    while (l <= n) : (l += 1) {
        var i: usize = 0;
        while (i + l <= n) : (i += 1) {
            const j = i + l - 1;
            var k: usize = i;
            while (k < j) : (k += 1) {
                const left = table[i * n + k];
                const right = table[(k + 1) * n + j];
                if (left == 0 or right == 0) continue;
                for (grammar.productions) |prod| {
                    if (prod.rhs == .binary) {
                        const left_bit = @as(u64, 1) << prod.rhs.binary.left;
                        const right_bit = @as(u64, 1) << prod.rhs.binary.right;
                        if ((left & left_bit) != 0 and (right & right_bit) != 0) {
                            table[i * n + j] |= @as(u64, 1) << prod.lhs;
                        }
                    }
                }
            }
        }
    }

    const final_bits = table[0 * n + n - 1];
    return (final_bits & (@as(u64, 1) << grammar.start)) != 0;
}
