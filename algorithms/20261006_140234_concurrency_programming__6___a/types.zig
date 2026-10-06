const std = @import("std");

pub const AtomicCounter = struct {
    value: std.atomic.Value(i64),

    pub fn init(value: i64) AtomicCounter {
        return .{ .value = std.atomic.Value(i64).init(value) };
    }

    pub fn load(self: *const AtomicCounter) i64 {
        return self.value.load(std.builtin.AtomicOrdering.relaxed);
    }

    pub fn store(self: *AtomicCounter, val: i64) void {
        self.value.store(val, std.builtin.AtomicOrdering.relaxed);
    }

    pub fn fetchAdd(self: *AtomicCounter, delta: i64) i64 {
        return self.value.fetchAdd(delta, std.builtin.AtomicOrdering.relaxed);
    }

    pub fn fetchSub(self: *AtomicCounter, delta: i64) i64 {
        return self.value.fetchSub(delta, std.builtin.AtomicOrdering.relaxed);
    }

    pub fn compareExchange(self: *AtomicCounter, expected: i64, desired: i64) bool {
        return self.value.compareStrong(expected, desired, std.builtin.AtomicOrdering.relaxed, std.builtin.AtomicOrdering.relaxed);
    }
};

pub const AtomicFlag = struct {
    value: std.atomic.Value(u8),

    pub fn init() AtomicFlag {
        return .{ .value = std.atomic.Value(u8).init(0) };
    }

    pub fn isSet(self: *const AtomicFlag) bool {
        return self.value.load(std.builtin.AtomicOrdering.relaxed) != 0;
    }

    pub fn set(self: *AtomicFlag) void {
        self.value.store(1, std.builtin.AtomicOrdering.release);
    }

    pub fn clear(self: *AtomicFlag) void {
        self.value.store(0, std.builtin.AtomicOrdering.release);
    }

    pub fn testAndSet(self: *AtomicFlag) bool {
        return self.value.compareStrong(0, 1, std.builtin.AtomicOrdering.acquire, std.builtin.AtomicOrdering.relaxed);
    }

    pub fn exchange(self: *AtomicFlag, val: u8) u8 {
        return self.value.exchange(val, std.builtin.AtomicOrdering.relaxed);
    }
};

pub const AtomicQueue = struct {
    head: std.atomic.Value(usize),
    tail: std.atomic.Value(usize),
    capacity: usize,
    buffer: []usize,

    pub fn init(capacity: usize) AtomicQueue {
        return .{
            .head = std.atomic.Value(usize).init(0),
            .tail = std.atomic.Value(usize).init(0),
            .capacity = capacity,
            .buffer = @alloc(usize, capacity),
        };
    }

    pub fn deinit(self: *AtomicQueue) void {
        @free(self.buffer);
    }

    pub fn push(self: *AtomicQueue, item: usize) bool {
        var tail = self.tail.load(std.builtin.AtomicOrdering.relaxed);
        while (true) {
            const next_tail = (tail + 1) % self.capacity;
            if (next_tail == self.head.load(std.builtin.AtomicOrdering.acquire)) {
                return false; // Queue is full
            }
            if (self.tail.compareStrong(tail, next_tail, std.builtin.AtomicOrdering.relaxed, std.builtin.AtomicOrdering.relaxed)) {
                self.buffer[tail] = item;
                self.head.store(tail, std.builtin.AtomicOrdering.release);
                return true;
            }
            tail = self.tail.load(std.builtin.AtomicOrdering.relaxed);
        }
    }

    pub fn pop(self: *AtomicQueue) ?usize {
        var head = self.head.load(std.builtin.AtomicOrdering.relaxed);
        while (true) {
            if (head == self.tail.load(std.builtin.AtomicOrdering.acquire)) {
                return null; // Queue is empty
            }
            const item = self.buffer[head];
            const next_head = (head + 1) % self.capacity;
            if (self.head.compareStrong(head, next_head, std.builtin.AtomicOrdering.relaxed, std.builtin.AtomicOrdering.relaxed)) {
                return item;
            }
            head = self.head.load(std.builtin.AtomicOrdering.relaxed);
        }
    }

    pub fn isEmpty(self: *const AtomicQueue) bool {
        return self.head.load(std.builtin.AtomicOrdering.relaxed) == self.tail.load(std.builtin.AtomicOrdering.relaxed);
    }

    pub fn isFull(self: *const AtomicQueue) bool {
        const next_tail = (self.tail.load(std.builtin.AtomicOrdering.relaxed) + 1) % self.capacity;
        return next_tail == self.head.load(std.builtin.AtomicOrdering.relaxed);
    }
};
