const std = @import("std");
const types = @import("types.zig");
const HeapError = types.HeapError;
const MinHeap = types.MinHeap;

pub fn initHeap(comptime T: type, allocator: *std.mem.Allocator, initial_capacity: usize) !MinHeap(T) {
    var cap = if (initial_capacity == 0) 4 else initial_capacity;
    const buf = try allocator.alloc(T, cap);
    return MinHeap(T){
        .data = buf,
        .len = 0,
        .capacity = cap,
        .allocator = allocator,
    };
}

pub fn deinitHeap(comptime T: type, heap: *MinHeap(T)) void {
    heap.allocator.free(heap.data);
    heap.* = undefined;
}

// Internal helper: swap two elements.
fn swap(comptime T: type, a: *T, b: *T) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

// Internal: ensure capacity for at least one more element.
fn ensureCapacity(comptime T: type, heap: *MinHeap(T)) !void {
    if (heap.len < heap.capacity) return;
    const new_cap = heap.capacity * 2;
    const new_buf = try heap.allocator.realloc(heap.data, new_cap);
    heap.data = new_buf;
    heap.capacity = new_cap;
}

// Public: insert a new element into the heap.
pub fn push(comptime T: type, heap: *MinHeap(T), value: T) !void {
    try ensureCapacity(T, heap);
    heap.data[heap.len] = value;
    heap.len += 1;
    siftUp(T, heap, heap.len - 1);
}

// Internal: move element at index up to restore heap property.
fn siftUp(comptime T: type, heap: *MinHeap(T), idx: usize) void {
    var i = idx;
    while (i > 0) {
        const parent = (i - 1) / 2;
        if (heap.data[i] < heap.data[parent]) {
            swap(T, &heap.data[i], &heap.data[parent]);
            i = parent;
        } else break;
    }
}

// Public: peek at the minimum element without removing it.
pub fn peek(comptime T: type, heap: *MinHeap(T)) !T {
    if (heap.len == 0) return HeapError.EmptyHeap;
    return heap.data[0];
}

// Public: remove and return the minimum element.
pub fn pop(comptime T: type, heap: *MinHeap(T)) !T {
    if (heap.len == 0) return HeapError.EmptyHeap;
    const min = heap.data[0];
    heap.len -= 1;
    if (heap.len > 0) {
        heap.data[0] = heap.data[heap.len];
        siftDown(T, heap, 0);
    }
    return min;
}

// Internal: move element at index down to restore heap property.
fn siftDown(comptime T: type, heap: *MinHeap(T), idx: usize) void {
    var i = idx;
    while (true) {
        const left = 2 * i + 1;
        const right = left + 1;
        var smallest = i;

        if (left < heap.len and heap.data[left] < heap.data[smallest]) {
            smallest = left;
        }
        if (right < heap.len and heap.data[right] < heap.data[smallest]) {
            smallest = right;
        }
        if (smallest != i) {
            swap(T, &heap.data[i], &heap.data[smallest]);
            i = smallest;
        } else break;
    }
}

// Public: return current size of the heap.
pub fn size(comptime T: type, heap: *MinHeap(T)) usize {
    return heap.len;
}
