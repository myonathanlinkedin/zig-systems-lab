const std = @import("std");

/// A packet is represented as an immutable slice of bytes.
pub const Packet = []const u8;

/// Errors that can be returned by the RingBuffer operations.
pub const RingError = error{
    Full,
    Empty,
};

/// RingBuffer holds a fixed‑size circular queue of packet references.
/// It never copies packet data; it only stores the slice references,
/// achieving zero‑copy semantics.
pub const RingBuffer = struct {
    /// Maximum number of packets the buffer can hold.
    capacity: usize,
    /// Index of the next element to read.
    head: usize,
    /// Index of the next element to write.
    tail: usize,
    /// Current number of stored packets.
    count: usize,
    /// Storage for packet references. Each slot may be null when empty.
    entries: []?Packet,

    /// Initialise a RingBuffer with the given capacity.
    /// The caller must provide an allocator; the function allocates the
    /// internal descriptor array.
    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !RingBuffer {
        // Capacity of zero is illegal – guard against it.
        if (capacity == 0) {
            return error.Empty;
        }
        const entries = try allocator.alloc(?Packet, capacity);
        // Initialise all slots to null.
        for (entries) |*e| e.* = null;
        return RingBuffer{
            .capacity = capacity,
            .head = 0,
            .tail = 0,
            .count = 0,
            .entries = entries,
        };
    }

    /// Deinitialise the RingBuffer, releasing its internal storage.
    pub fn deinit(self: *RingBuffer, allocator: *std.mem.Allocator) void {
        allocator.free(self.entries);
        self.* = undefined;
    }

    /// Returns true if the buffer contains no packets.
    pub fn isEmpty(self: *const RingBuffer) bool {
        return self.count == 0;
    }

    /// Returns true if the buffer cannot accept more packets.
    pub fn isFull(self: *const RingBuffer) bool {
        return self.count == self.capacity;
    }

    /// Push a packet reference onto the ring.
    /// The packet slice must remain valid for the duration it stays in the buffer.
    pub fn push(self: *RingBuffer, pkt: Packet) RingError!void {
        if (self.isFull()) return RingError.Full;
        self.entries[self.tail] = pkt;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;
    }

    /// Pop the oldest packet reference from the ring.
    /// Returns null if the buffer is empty.
    pub fn pop(self: *RingBuffer) RingError!?Packet {
        if (self.isEmpty()) return RingError.Empty;
        const opt_pkt = self.entries[self.head];
        // Safety: we guarantee that a non‑empty slot always contains a packet.
        const pkt = opt_pkt.?;
        self.entries[self.head] = null;
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;
        return pkt;
    }

    /// Dispatch all pending packets to the supplied handler function.
    /// The handler receives a packet slice; it must not retain the slice
    /// beyond the call (the buffer may be mutated afterwards).
    pub fn dispatch(self: *RingBuffer, handler: fn (Packet) void) RingError!void {
        while (!self.isEmpty()) {
            const pkt = try self.pop();
            handler(pkt);
        }
    }
};
