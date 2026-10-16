const std = @import("std");

pub const BoundedQueue = struct {
    const Self = @This();

    buffer: []T,
    capacity: usize,
    head: usize,
    tail: usize,
    count: usize,
    mutex: std.sync.Mutex,
    notEmpty: std.sync.Condition,
    notFull: std.sync.Condition,
    allocator: *std.mem.Allocator,

    pub fn init(comptime T: type, allocator: *std.mem.Allocator, capacity: usize) !BoundedQueue(T) {
        if (capacity == 0) return error.InvalidCapacity;
        const buf = try allocator.alloc(T, capacity);
        return BoundedQueue(T){
            .buffer = buf,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = .{},
            .notEmpty = .{},
            .notFull = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn push(self: *Self, item: T) void {
        self.mutex.lock();
        while (self.count == self.capacity) {
            self.notFull.wait(&self.mutex);
        }
        self.buffer[self.tail] = item;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;
        self.notEmpty.signal();
        self.mutex.unlock();
    }

    pub fn pop(self: *Self) T {
        self.mutex.lock();
        while (self.count == 0) {
            self.notEmpty.wait(&self.mutex);
        }
        const item = self.buffer[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;
        self.notFull.signal();
        self.mutex.unlock();
        return item;
    }
};
