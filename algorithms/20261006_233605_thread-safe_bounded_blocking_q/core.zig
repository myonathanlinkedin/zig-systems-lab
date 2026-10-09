const std = @import("std");
const Mutex = std.Thread.Mutex;
const Cond = std.Thread.Condition;

pub const BoundedBlockingQueue = struct {
    const Self = @This();

    capacity: usize,
    buffer: []usize,
    head: usize,
    tail: usize,
    count: usize,
    mutex: Mutex,
    not_empty: Cond,
    not_full: Cond,

    pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
        if (capacity == 0) return error.InvalidCapacity;
        const buffer = try allocator.alloc(usize, capacity);
        return Self{
            .capacity = capacity,
            .buffer = buffer,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = Mutex{},
            .not_empty = Cond{},
            .not_full = Cond{},
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn push(self: *Self, value: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count == self.capacity) {
            self.not_full.wait(&self.mutex);
        }

        self.buffer[self.tail] = value;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;

        self.not_empty.signal();
    }

    pub fn pop(self: *Self) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count == 0) {
            self.not_empty.wait(&self.mutex);
        }

        const value = self.buffer[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;

        self.not_full.signal();
        return value;
    }

    pub fn try_push(self: *Self, value: usize) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == self.capacity) return false;

        self.buffer[self.tail] = value;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;

        self.not_empty.signal();
        return true;
    }

    pub fn try_pop(self: *Self) ?usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == 0) return null;

        const value = self.buffer[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;

        self.not_full.signal();
        return value;
    }

    pub fn len(self: *Self) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.count;
    }

    pub fn is_empty(self: *Self) bool {
        return self.len() == 0;
    }

    pub fn is_full(self: *Self) bool {
        return self.len() == self.capacity;
    }
};
