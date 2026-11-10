const std = @import("std");

pub const RingBuffer = struct {
    buffer: []u8,
    capacity: usize,
    head: usize,
    tail: usize,

    pub const Error = error{ BufferFull, PacketTooLarge };

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !RingBuffer {
        var buf = try allocator.alloc(u8, capacity);
        return RingBuffer{
            .buffer = buf,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
        };
    }

    pub fn deinit(self: *RingBuffer, allocator: *std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn space_available(self: *const RingBuffer) usize {
        if (self.head >= self.tail) {
            return self.capacity - (self.head - self.tail) - 1;
        } else {
            return self.tail - self.head - 1;
        }
    }

    pub fn is_empty(self: *const RingBuffer) bool {
        return self.head == self.tail;
    }

    pub fn is_full(self: *const RingBuffer) bool {
        return self.space_available(self) == 0;
    }

    pub fn enqueue(self: *RingBuffer, data: []const u8) !void {
        const len = data.len;
        if (len > std.math.maxInt(u16)) {
            return error.PacketTooLarge;
        }
        const total = 2 + len; // 2 bytes for length
        if (total > self.space_available(self)) {
            return error.BufferFull;
        }

        // Wrap head if packet would cross end
        if (self.head + total > self.capacity) {
            self.head = 0;
        }

        // Write length
        const len_bytes = std.mem.toBytes(u16, @intCast(u16, len));
        std.mem.copy(u8, self.buffer[self.head .. self.head + 2], len_bytes[0..2]);
        self.head = (self.head + 2) % self.capacity;

        // Write data
        std.mem.copy(u8, self.buffer[self.head .. self.head + len], data);
        self.head = (self.head + len) % self.capacity;
    }

    pub fn dequeue(self: *RingBuffer) ?[]const u8 {
        if (self.is_empty(self)) return null;

        // Read length
        const len_bytes = self.buffer[self.tail .. self.tail + 2];
        const len = std.mem.readInt(u16, len_bytes, .little);
        self.tail = (self.tail + 2) % self.capacity;

        // Read data slice
        const data = self.buffer[self.tail .. self.tail + len];
        self.tail = (self.tail + len) % self.capacity;
        return data;
    }

    pub fn dispatch(self: *RingBuffer, process: fn([]const u8) void) void {
        var pos = self.tail;
        while (pos != self.head) {
            // Read length
            const len_bytes = self.buffer[pos .. pos + 2];
            const len = std.mem.readInt(u16, len_bytes, .little);
            pos = (pos + 2) % self.capacity;

            // Read data slice
            const data = self.buffer[pos .. pos + len];
            pos = (pos + len) % self.capacity;

            process(data);
        }
    }
};
