const std = @import("std");

pub fn Deque(comptime T: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        buffer: []T,
        head: usize,
        tail: usize,
        len: usize,

        pub fn init(allocator: *std.mem.Allocator, initial_capacity: usize) !@This() {
            const cap = if (initial_capacity == 0) 1 else initial_capacity;
            var buf = try allocator.alloc(T, cap);
            return @This(){
                .allocator = allocator,
                .buffer = buf,
                .head = 0,
                .tail = 0,
                .len = 0,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.allocator.free(self.buffer);
        }

        fn capacity(self: @This()) usize {
            return self.buffer.len;
        }

        pub fn len(self: @This()) usize {
            return self.len;
        }

        pub fn isEmpty(self: @This()) bool {
            return self.len == 0;
        }

        fn grow(self: *@This()) !void {
            const old_cap = self.capacity();
            const new_cap = old_cap * 2;
            var new_buf = try self.allocator.alloc(T, new_cap);
            for (0..self.len) |i| {
                const src = (self.head + i) % old_cap;
                new_buf[i] = self.buffer[src];
            }
            self.allocator.free(self.buffer);
            self.buffer = new_buf;
            self.head = 0;
            self.tail = self.len;
        }

        pub fn pushBack(self: *@This(), value: T) !void {
            if (self.len == self.capacity()) {
                try self.grow();
            }
            self.buffer[self.tail] = value;
            self.tail = (self.tail + 1) % self.capacity();
            self.len += 1;
        }

        pub fn pushFront(self: *@This(), value: T) !void {
            if (self.len == self.capacity()) {
                try self.grow();
            }
            self.head = (self.head + self.capacity() - 1) % self.capacity();
            self.buffer[self.head] = value;
            self.len += 1;
        }

        pub fn popBack(self: *@This()) !T {
            std.debug.assert(self.len > 0);
            self.tail = (self.tail + self.capacity() - 1) % self.capacity();
            const val = self.buffer[self.tail];
            self.len -= 1;
            return val;
        }

        pub fn popFront(self: *@This()) !T {
            std.debug.assert(self.len > 0);
            const val = self.buffer[self.head];
            self.head = (self.head + 1) % self.capacity();
            self.len -= 1;
            return val;
        }

        pub fn peekFront(self: @This()) ?T {
            if (self.len == 0) return null;
            return self.buffer[self.head];
        }

        pub fn peekBack(self: @This()) ?T {
            if (self.len == 0) return null;
            const idx = (self.tail + self.capacity() - 1) % self.capacity();
            return self.buffer[idx];
        }

        pub const Iterator = struct {
            deque: *const @This(),
            index: usize,
            remaining: usize,

            pub fn next(self: *@This()) ?T {
                if (self.remaining == 0) return null;
                const cap = self.deque.capacity();
                const idx = (self.deque.head + self.index) % cap;
                const val = self.deque.buffer[idx];
                self.index += 1;
                self.remaining -= 1;
                return val;
            }
        };

        pub fn iterator(self: *const @This()) Iterator {
            return Iterator{
                .deque = self,
                .index = 0,
                .remaining = self.len,
            };
        }
    };
}
