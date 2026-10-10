const std = @import("std");

pub const BoundedBlockingQueue = struct {
    const Self = @This();

    // Generic type parameter
    pub fn init(comptime T: type, allocator: *std.mem.Allocator, capacity: usize) !Self {
        if (capacity == 0) return error.InvalidCapacity;
        var buf = try allocator.alloc(?T, capacity);
        // Initialise slots to null
        for (buf) |*slot| slot.* = null;
        return Self{
            .buffer = buf,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
            .size = 0,
            .mutex = std.sync.Mutex{},
            .notEmpty = std.sync.Condition{},
            .notFull = std.sync.Condition{},
            .allocator = allocator,
            .T = T,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    pub fn enqueue(self: *Self, item: Self.T) void {
        const lock = self.mutex.acquire();
        defer lock.release();

        while (self.size == self.capacity) {
            // Wait until a slot becomes free
            self.notFull.wait(&self.mutex);
        }

        // Insert item
        self.buffer[self.tail] = item;
        self.tail = (self.tail + 1) % self.capacity;
        self.size += 1;

        // Wake a waiting consumer
        self.notEmpty.signal();
    }

    pub fn dequeue(self: *Self) Self.T {
        const lock = self.mutex.acquire();
        defer lock.release();

        while (self.size == 0) {
            // Wait until an item is available
            self.notEmpty.wait(&self.mutex);
        }

        const opt = self.buffer[self.head];
        const result = opt.?;
        self.buffer[self.head] = null;
        self.head = (self.head + 1) % self.capacity;
        self.size -= 1;

        // Wake a waiting producer
        self.notFull.signal();

        return result;
    }

    // Internal fields – not exposed publicly
    buffer: []?T,
    capacity: usize,
    head: usize,
    tail: usize,
    size: usize,
    mutex: std.sync.Mutex,
    notEmpty: std.sync.Condition,
    notFull: std.sync.Condition,
    allocator: *std.mem.Allocator,
    T: type,

    pub const error = error{
        InvalidCapacity,
    };
};
