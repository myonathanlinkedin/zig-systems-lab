const std = @import("std");

pub const LamportTimestamp = u64;

/// Represents a Lamport logical clock.
pub const LamportClock = struct {
    time: LamportTimestamp = 0,

    /// Initialize a clock with a given starting timestamp.
    pub fn init(start: LamportTimestamp) LamportClock {
        return .{ .time = start };
    }

    /// Increment the local clock (a "tick") and return the new timestamp.
    pub fn tick(self: *LamportClock) LamportTimestamp {
        self.time +%= 1;
        return self.time;
    }

    /// Incorporate a remote timestamp according to Lamport's rule:
    ///   C = max(C, remote) + 1
    /// Returns the updated timestamp.
    pub fn update(self: *LamportClock, remote: LamportTimestamp) LamportTimestamp {
        const max = if (self.time > remote) self.time else remote;
        self.time = max +% 1;
        return self.time;
    }

    /// Compare two timestamps.
    pub fn compare(a: LamportTimestamp, b: LamportTimestamp) std.math.Ordering {
        return if (a < b) .lt else if (a > b) .gt else .eq;
    }
};

/// Simple event carrying a Lamport timestamp and an optional payload.
pub const Event = struct {
    sender: u32,
    receiver: u32,
    timestamp: LamportTimestamp,
    // payload omitted for purity; could be generic later.
};
