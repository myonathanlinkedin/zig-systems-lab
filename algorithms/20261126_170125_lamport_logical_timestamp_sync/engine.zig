const std = @import("std");
const types = @import("types.zig");

pub const Engine = struct {
    /// Mapping from process identifier to its Lamport clock.
    clocks: std.AutoHashMap(u32, types.LamportClock),

    /// Create a new engine with an empty process table.
    pub fn init(allocator: *std.mem.Allocator) !Engine {
        return Engine{
            .clocks = try std.AutoHashMap(u32, types.LamportClock).init(allocator, 16),
        };
    }

    /// Deinitialize internal structures.
    pub fn deinit(self: *Engine) void {
        self.clocks.deinit();
    }

    /// Register a new process with an optional initial timestamp (default 0).
    pub fn register(self: *Engine, pid: u32, start: ?types.LamportTimestamp) !void {
        const init_ts = start orelse 0;
        const clock = types.LamportClock.init(init_ts);
        try self.clocks.put(pid, clock);
    }

    /// Retrieve a mutable reference to a process' clock.
    fn getClock(self: *Engine, pid: u32) !*types.LamportClock {
        const opt = self.clocks.getPtr(pid);
        if (opt) |ptr| return ptr;
        return error.ProcessNotFound;
    }

    /// Simulate sending an event from `sender` to `receiver`.
    /// The sender ticks, the event carries that timestamp,
    /// and the receiver updates its clock upon receipt.
    pub fn sendEvent(self: *Engine, sender: u32, receiver: u32) !types.Event {
        const senderClock = try self.getClock(sender);
        const ts = senderClock.tick();

        // Receiver processes the event.
        const receiverClock = try self.getClock(receiver);
        _ = receiverClock.update(ts);

        return types.Event{
            .sender = sender,
            .receiver = receiver,
            .timestamp = ts,
        };
    }

    /// Directly update a process' clock with an external timestamp.
    /// Useful for testing out‑of‑order deliveries.
    pub fn receiveExternal(self: *Engine, pid: u32, remote_ts: types.LamportTimestamp) !void {
        const clock = try self.getClock(pid);
        _ = clock.update(remote_ts);
    }

    /// Compare timestamps of two processes.
    pub fn compareClocks(self: *Engine, a: u32, b: u32) !std.math.Ordering {
        const ca = try self.getClock(a);
        const cb = try self.getClock(b);
        return types.LamportClock.compare(ca.time, cb.time);
    }
};

pub const error = struct {
    ProcessNotFound = error{ProcessNotFound},
};
