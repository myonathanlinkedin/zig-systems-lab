const std = @import("std");

pub const RingBuffer = struct {
    buffer: []u8,
    capacity: usize,
    head: usize, // write position
    tail: usize, // read position

    pub const Error = error{
        BufferFull,
    };

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !RingBuffer {
        // capacity must be at least 8 to store length + data and distinguish full/empty
        if (capacity < 8) return error.BufferFull;
        const buf = try allocator.alloc(u8, capacity);
        return RingBuffer{
            .buffer = buf,
            .capacity = capacity,
            .head = 0,
            .tail = 0,
        };
    }

    pub fn deinit(self: *RingBuffer, allocator: *std.mem.Allocator) void {
        allocator.free(self.buffer);
        self.buffer = &[_]u8{};
        self.capacity = 0;
        self.head = 0;
        self.tail = 0;
    }

    fn used(self: *const RingBuffer) usize {
        if (self.head >= self.tail) {
            return self.head - self.tail;
        } else {
            return self.capacity - (self.tail - self.head);
        }
    }

    fn freeSpace(self: *const RingBuffer) usize {
        // keep one byte empty to differentiate full vs empty
        return self.capacity - self.used() - 1;
    }

    pub fn isEmpty(self: *const RingBuffer) bool {
        return self.head == self.tail;
    }

    pub fn push(self: *RingBuffer, data: []const u8) !void {
        const needed = 4 + data.len; // 4 bytes for length prefix
        if (self.freeSpace() < needed) return Error.BufferFull;

        const endSpace = self.capacity - self.head;
        var writePos = self.head;

        // Ensure packet is stored contiguously; wrap if it doesn't fit at the end
        if (endSpace < needed) {
            // leave the remaining tail bytes unused and wrap to start
            writePos = 0;
            self.head = 0;
        }

        // write length (little endian)
        std.mem.writeIntLittle(u32, self.buffer[writePos..][0..4], @intCast(u32, data.len));
        // copy payload
        std.mem.copy(u8, self.buffer[writePos + 4 .. writePos + 4 + data.len], data);

        // advance head
        self.head = (writePos + needed) % self.capacity;
    }

    pub fn pop(self: *RingBuffer) ?[]u8 {
        if (self.isEmpty()) return null;

        // read length (little endian)
        const len = std.mem.readIntLittle(u32, self.buffer[self.tail..][0..4]);
        const start = (self.tail + 4) % self.capacity;

        // Since push guarantees contiguity, the data must be within buffer bounds
        const slice = self.buffer[start .. start + len];

        // advance tail
        self.tail = (self.tail + 4 + len) % self.capacity;
        return slice;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var ring = try RingBuffer.init(allocator, 256);
    defer ring.deinit(allocator);

    // Simple push/pop test
    const msg1 = "hello";
    const msg2 = "world!";
    const msg3 = "zig";

    try ring.push(msg1);
    try ring.push(msg2);
    try ring.push(msg3);

    const out1 = ring.pop() orelse return error.Unexpected;
    std.debug.assert(std.mem.eql(u8, out1, msg1));

    const out2 = ring.pop() orelse return error.Unexpected;
    std.debug.assert(std.mem.eql(u8, out2, msg2));

    const out3 = ring.pop() orelse return error.Unexpected;
    std.debug.assert(std.mem.eql(u8, out3, msg3));

    std.debug.assert(ring.isEmpty());

    // Fill buffer to cause wrap-around
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const payload = try std.fmt.allocPrint(allocator, "msg_{d}", .{i});
        defer allocator.free(payload);
        try ring.push(payload);
    }

    // Drain all
    i = 0;
    while (i < 50) : (i += 1) {
        const expected = try std.fmt.allocPrint(allocator, "msg_{d}", .{i});
        defer allocator.free(expected);
        const got = ring.pop() orelse return error.Unexpected;
        std.debug.assert(std.mem.eql(u8, got, expected));
    }

    std.debug.assert(ring.isEmpty());
}
