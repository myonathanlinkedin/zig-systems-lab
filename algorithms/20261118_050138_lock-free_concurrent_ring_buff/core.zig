const std = @import("std");

pub fn RingBuffer(comptime T: type) type {
    return struct {
        const Slot = struct {
            value: T,
            seq: std.atomic.Atomic(u64),
        };

        capacity: usize,
        mask: usize,
        buffer: []Slot,
        head: std.atomic.Atomic(u64),
        tail: std.atomic.Atomic(u64),

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !RingBuffer {
            if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
                return error.InvalidCapacity;
            }
            const buf = try allocator.alloc(Slot, capacity);
            for (buf) |*s, i| {
                s.* = Slot{
                    .value = undefined,
                    .seq = std.atomic.Atomic(u64).init(@intCast(u64, i)),
                };
            }
            return RingBuffer{
                .capacity = capacity,
                .mask = capacity - 1,
                .buffer = buf,
                .head = std.atomic.Atomic(u64).init(0),
                .tail = std.atomic.Atomic(u64).init(0),
            };
        }

        pub fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
            allocator.free(self.buffer);
        }

        pub fn push(self: *RingBuffer, item: T) bool {
            var tail: u64 = self.tail.load(.SeqCst);
            while (true) {
                const idx = @intCast(usize, tail & @intCast(u64, self.mask));
                const slot = &self.buffer[idx];
                const seq = slot.seq.load(.SeqCst);
                const dif = @intCast(i64, seq) - @intCast(i64, tail);
                if (dif == 0) {
                    if (self.tail.compareExchangeStrong(tail, tail + 1, .SeqCst, .SeqCst)) {
                        slot.value = item;
                        slot.seq.store(tail + 1, .SeqCst);
                        return true;
                    }
                    tail = self.tail.load(.SeqCst);
                } else if (dif < 0) {
                    return false; // full
                } else {
                    tail = self.tail.load(.SeqCst);
                }
            }
        }

        pub fn pop(self: *RingBuffer) ?T {
            var head: u64 = self.head.load(.SeqCst);
            while (true) {
                const idx = @intCast(usize, head & @intCast(u64, self.mask));
                const slot = &self.buffer[idx];
                const seq = slot.seq.load(.SeqCst);
                const dif = @intCast(i64, seq) - @intCast(i64, head + 1);
                if (dif == 0) {
                    if (self.head.compareExchangeStrong(head, head + 1, .SeqCst, .SeqCst)) {
                        const val = slot.value;
                        slot.seq.store(head + @intCast(u64, self.capacity), .SeqCst);
                        return val;
                    }
                    head = self.head.load(.SeqCst);
                } else if (dif < 0) {
                    return null; // empty
                } else {
                    head = self.head.load(.SeqCst);
                }
            }
        }
    };
}
