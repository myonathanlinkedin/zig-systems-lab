const std = @import("std");
const core = @import("core");

// Alias for convenience.
const Heap = core.Heap;

// Simple comparator for a min‑heap of integers.
fn intLeMin(a: i32, b: i32) bool {
    return a <= b;
}

// Comparator for a max‑heap of integers.
fn intLeMax(a: i32, b: i32) bool {
    return a >= b;
}

// Run a suite of deterministic unit tests using `std.debug.assert`.
fn runTests() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = &gpa.allocator;

    // ---------- Test 1: Empty heap ----------
    {
        var h = Heap(i32).init(allocator, intLeMin);
        defer h.deinit();

        std.debug.assert(h.isEmpty());
        std.debug.assert(h.peek() == null);
        std.debug.assert(h.pop() == null);
    }

    // ---------- Test 2: Min‑heap ordering ----------
    {
        var h = Heap(i32).init(allocator, intLeMin);
        defer h.deinit();

        const values = [_]i32{ 5, 3, 8, 1, 9, 2 };
        for (values) |v| {
            try h.push(v);
        }
        std.debug.assert(!h.isEmpty());
        std.debug.assert(h.peek().? == 1);

        var sorted: []i32 = try allocator.alloc(i32, values.len);
        defer allocator.free(sorted);
        var idx: usize = 0;
        while (!h.isEmpty()) : (idx += 1) {
            const popped = h.pop().?;
            sorted[idx] = popped;
        }
        // The popped sequence must be sorted ascending.
        const expected = [_]i32{ 1, 2, 3, 5, 8, 9 };
        for (expected) |exp, i| {
            std.debug.assert(sorted[i] == exp);
        }
    }

    // ---------- Test 3: Max‑heap ordering ----------
    {
        var h = Heap(i32).init(allocator, intLeMax);
        defer h.deinit();

        const values = [_]i32{ 7, 4, 6, 10, 3 };
        for (values) |v| {
            try h.push(v);
        }
        std.debug.assert(h.peek().? == 10);

        var popped: []i32 = try allocator.alloc(i32, values.len);
        defer allocator.free(popped);
        var i: usize = 0;
        while (!h.isEmpty()) : (i += 1) {
            popped[i] = h.pop().?;
        }
        const expected = [_]i32{ 10, 7, 6, 4, 3 };
        for (expected) |exp, idx| {
            std.debug.assert(popped[idx] == exp);
        }
    }

    // ---------- Test 4: Stress insert‑pop interleaving ----------
    {
        var h = Heap(i32).init(allocator, intLeMin);
        defer h.deinit();

        // Insert a few, pop some, insert more.
        try h.push(20);
        try h.push(15);
        std.debug.assert(h.pop().? == 15);
        try h.push(5);
        try h.push(30);
        std.debug.assert(h.peek().? == 5);
        std.debug.assert(h.pop().? == 5);
        std.debug.assert(h.pop().? == 20);
        std.debug.assert(h.pop().? == 30);
        std.debug.assert(h.isEmpty());
    }
}

// Entry point required by the specification.
pub fn main() !void {
    try runTests();
}

// End of file.
