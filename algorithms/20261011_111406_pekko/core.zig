const std = @import("std");

/// A generic binary heap (priority queue) implementation.
/// The heap stores elements of type `T` and orders them according to the
/// user‑provided comparator `le`.  If `le(a, b)` returns `true`, `a` is
/// considered to have higher priority (i.e. comes before `b`).
///
/// The implementation uses `std.ArrayList` for storage, guaranteeing
/// amortised O(log n) insertion and removal, and O(1) peek.
///
/// Example:
/// ```zig
/// const Heap = @import("core").Heap;
/// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
/// const allocator = &gpa.allocator;
/// var minHeap = Heap(i32).init(allocator, struct {
///     fn le(a: i32, b: i32) bool { return a <= b; }
/// }.le);
/// defer minHeap.deinit();
/// try minHeap.push(5);
/// try minHeap.push(2);
/// try minHeap.push(8);
/// std.debug.assert(minHeap.peek().? == 2);
/// std.debug.assert(minHeap.pop().? == 2);
/// ```
pub fn Heap(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        le: fn (a: T, b: T) bool,

        /// Initialise a heap with the given allocator and comparator.
        pub fn init(allocator: *std.mem.Allocator, le: fn (a: T, b: T) bool) Heap(T) {
            return .{
                .items = std.ArrayList(T).init(allocator),
                .le = le,
            };
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Heap(T)) void {
            self.items.deinit();
        }

        /// Number of elements currently stored.
        pub fn len(self: *const Heap(T)) usize {
            return self.items.len;
        }

        /// Returns `true` if the heap contains no elements.
        pub fn isEmpty(self: *const Heap(T)) bool {
            return self.items.len == 0;
        }

        /// Insert a new element into the heap.
        pub fn push(self: *Heap(T), value: T) !void {
            try self.items.append(value);
            self.siftUp(self.items.len - 1);
        }

        /// Return the element with highest priority without removing it.
        /// Returns `null` when the heap is empty.
        pub fn peek(self: *const Heap(T)) ?T {
            if (self.items.len == 0) return null;
            return self.items.items[0];
        }

        /// Remove and return the element with highest priority.
        /// Returns `null` when the heap is empty.
        pub fn pop(self: *Heap(T)) ?T {
            if (self.items.len == 0) return null;
            const root = self.items.items[0];
            const last = self.items.pop();
            if (self.items.len > 0) {
                self.items.items[0] = last;
                self.siftDown(0);
            }
            return root;
        }

        /// Internal: restore heap property moving the element at `idx` upwards.
        fn siftUp(self: *Heap(T), idx: usize) void {
            var i = idx;
            while (i > 0) {
                const parent = (i - 1) / 2;
                if (self.le(self.items.items[i], self.items.items[parent])) {
                    std.mem.swap(T, &self.items.items[i], &self.items.items[parent]);
                    i = parent;
                } else break;
            }
        }

        /// Internal: restore heap property moving the element at `idx` downwards.
        fn siftDown(self: *Heap(T), idx: usize) void {
            var i = idx;
            const n = self.items.len;
            while (true) {
                const left = 2 * i + 1;
                const right = left + 1;
                var smallest = i;

                if (left < n and self.le(self.items.items[left], self.items.items[smallest])) {
                    smallest = left;
                }
                if (right < n and self.le(self.items.items[right], self.items.items[smallest])) {
                    smallest = right;
                }
                if (smallest != i) {
                    std.mem.swap(T, &self.items.items[i], &self.items.items[smallest]);
                    i = smallest;
                } else break;
            }
        }
    };
}
