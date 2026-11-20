const std = @import("std");
const types = @import("types.zig");

pub fn AetherCache(comptime T: type, comptime capacity: usize) type {
    const RB = types.RingBuffer(T, capacity);
    return struct {
        const Self = @This();

        rb: RB,

        pub fn init() Self {
            return Self{ .rb = RB.init() };
        }

        pub fn add(self: *Self, value: T) bool {
            return self.rb.push(value);
        }

        pub fn consume(self: *Self) ?T {
            return self.rb.pop();
        }

        pub fn isFull(self: *Self) bool {
            return self.rb.isFull();
        }

        pub fn isEmpty(self: *Self) bool {
            return self.rb.isEmpty();
        }

        pub fn len(self: *Self) usize {
            return self.rb.len();
        }
    };
}
