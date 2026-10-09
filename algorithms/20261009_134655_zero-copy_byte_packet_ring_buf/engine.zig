const std = @import("std");
const types = @import("types.zig");

/// The Engine module provides higher‑level operations built on top of the
/// zero‑copy RingBuffer. It demonstrates typical usage patterns such as
/// batch dispatch and safe iteration without copying packet data.
pub const Engine = struct {
    /// Reference to the underlying RingBuffer.
    buffer: *types.RingBuffer,

    /// Create an Engine that operates on the supplied RingBuffer.
    pub fn init(buffer: *types.RingBuffer) Engine {
        return Engine{ .buffer = buffer };
    }

    /// Attempt to enqueue a packet. Returns true on success, false if the
    /// buffer is full.
    pub fn enqueue(self: *Engine, pkt: types.Packet) bool {
        const result = self.buffer.push(pkt);
        return result catch false;
    }

    /// Dequeue a single packet. Returns null if the buffer is empty.
    pub fn dequeue(self: *Engine) ?types.Packet {
        const result = self.buffer.pop();
        return switch (result) {
            error.Empty => null,
            else => result.?, // result is ?Packet
        };
    }

    /// Process all pending packets using the provided handler.
    /// Returns true if at least one packet was processed.
    pub fn processAll(self: *Engine, handler: fn (types.Packet) void) bool {
        var processed = false;
        while (true) {
            const pkt_opt = self.dequeue();
            if (pkt_opt) |pkt| {
                handler(pkt);
                processed = true;
            } else break;
        }
        return processed;
    }
};
