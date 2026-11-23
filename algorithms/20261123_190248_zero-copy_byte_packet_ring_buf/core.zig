const std = @import("std");

pub const RingBuffer = struct {
    slots: []?[]const u8,
    capacity: usize,
    head: usize,
    tail: usize,
    count: usize,

    pub const Error = error{ Full };

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !RingBuffer {
        var slots = try allocator.alloc(?[]const u8, capacity);
        for (slots) |*slot| slot.* = null;
        return RingBuffer{
            .slots = slots,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
            .count = 0,
        };
    }

    pub fn deinit(self: *RingBuffer, allocator: *std.mem.Allocator) void {
        allocator.free(self.slots);
    }

    pub fn enqueue(self: *RingBuffer, packet: []const u8) !void {
        if (self.count == self.capacity) return Error.Full;
        self.slots[self.tail] = packet;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;
    }

    pub fn dequeue(self: *RingBuffer) ?[]const u8 {
        if (self.count == 0) return null;
        const pkt = self.slots[self.head].?;
        self.slots[self.head] = null;
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;
        return pkt;
    }
};
