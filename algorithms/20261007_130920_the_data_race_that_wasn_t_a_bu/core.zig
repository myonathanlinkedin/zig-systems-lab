const std = @import("std");

pub const RaceDetector = struct {
    pub const AccessType = enum { read, write };
    pub const RaceStatus = enum { no_race, race_detected, false_positive };

    // In-memory state tracking for the "bug" scenario (unsynchronized access)
    // and the "non-bug" scenario (synchronized access via logical locks).
    // Since we cannot use real threads or OS primitives per constraints, we simulate
    // concurrent execution via interleaved access logs and logical consistency checks.

    // Represents a single memory access event in a simulated timeline
    pub const AccessEvent = struct {
        thread_id: u32,
        address: u64,
        access_type: AccessType,
        timestamp: u64,
        // For synchronization simulation:
        lock_held: bool,
        lock_id: u32,
    };

    // Tracks the last known state of a memory location per thread
    pub const MemoryState = struct {
        last_write_thread: u32,
        last_write_timestamp: u64,
        value: u64,
        is_dirty: bool,
    };

    // The detector maintains a log of accesses and a map of memory states
    access_log: std.ArrayList(AccessEvent),
    memory_states: std.HashMap(u64, MemoryState),
    // Simulated lock table: lock_id -> set of thread_ids currently holding it
    lock_holders: std.HashMap(u32, std.ArrayList(u32)),

    pub fn init(allocator: std.mem.Allocator) RaceDetector {
        return .{
            .access_log = .init(allocator),
            .memory_states = .init(allocator),
            .lock_holders = .init(allocator),
        };
    }

    pub fn deinit(self: *RaceDetector) void {
        self.access_log.deinit();
        self.memory_states.deinit();
        for (self.lock_holders.values()) |* list| {
            list.deinit();
        }
        self.lock_holders.deinit();
    }

    /// Records an access event. In a real system, this would be called from
    /// instrumentation hooks. Here, we simulate by appending to the log.
    pub fn recordAccess(self: *RaceDetector, event: AccessEvent) !void {
        try self.access_log.append(event);
    }

    /// Simulates acquiring a lock. Returns true if the lock was successfully acquired.
    /// In this simulation, a lock can only be held by one thread at a time.
    pub fn acquireLock(self: *RaceDetector, thread_id: u32, lock_id: u32) !bool {
        const holders = try self.lock_holders.getOrPut(lock_id);
        if (holders.value_ptr.items.len > 0) {
            // Lock is already held by another thread
            return false;
        }
        try holders.value_ptr.append(thread_id);
        return true;
    }

    /// Simulates releasing a lock.
    pub fn releaseLock(self: *RaceDetector, thread_id: u32, lock_id: u32) !void {
        const holders = self.lock_holders.get(lock_id) orelse return;
        for (holders.items, 0..) |holder, i| {
            if (holder == thread_id) {
                _ = holders.orderedRemove(i);
                break;
            }
        }
    }

    /// Analyzes the access log to detect data races.
    /// A data race exists if:
    /// 1. Two accesses to the same memory address occur from different threads
    /// 2. At least one access is a write
    /// 3. The accesses are not ordered by a common lock (i.e., no lock is held by both threads
    ///    during their respective accesses that would serialize them)
    ///
    /// Returns the race status for the entire log.
    pub fn detectRace(self: *RaceDetector) !RaceStatus {
        if (self.access_log.items.len < 2) {
            return .no_race;
        }

        // Group accesses by memory address
        const accesses_by_addr = try self.groupByAddress();

        for (accesses_by_addr.keys()) |addr| {
            const accesses = accesses_by_addr.get(addr).?;
            const status = try self.checkAddressForRace(addr, accesses);
            if (status == .race_detected) {
                return .race_detected;
            }
        }

        return .no_race;
    }

    /// Checks a specific address's accesses for a race condition.
    fn checkAddressForRace(self: *RaceDetector, addr: u64, accesses: []const AccessEvent) !RaceStatus {
        // Sort accesses by timestamp to establish program order
        const sorted = try self.sortByTimestamp(accesses);

        // Check all pairs of accesses from different threads
        for (sorted, 0..) |a, i| {
            for (sorted[i + 1 ..]) |b| {
                // Only consider accesses from different threads
                if (a.thread_id == b.thread_id) continue;

                // A race requires at least one write
                if (a.access_type != .write and b.access_type != .write) continue;

                // Check if the accesses are serialized by a common lock
                const serialized = self.areSerializedByLock(a, b);
                if (serialized) {
                    // This pair is protected, but we continue checking other pairs
                    // to see if any unprotected race exists
                    continue;
                }

                // Found an unprotected race
                return .race_detected;
            }
        }

        return .no_race;
    }

    /// Determines if two accesses are serialized by a common lock.
    /// In this simulation, two accesses are serialized if:
    /// - Both accesses hold the same lock_id
    /// - The lock was held exclusively (only one thread held it at a time)
    fn areSerializedByLock(self: *RaceDetector, a: AccessEvent, b: AccessEvent) bool {
        // If either access doesn't hold a lock, they are not serialized
        if (!a.lock_held or !b.lock_held) return false;

        // If they hold different locks, they are not serialized by a common lock
        if (a.lock_id != b.lock_id) return false;

        // In a proper lock implementation, if both hold the same lock,
        // they must have been serialized (one acquired after the other released).
        // For this simulation, we assume that if both hold the same lock_id,
        // the lock mechanism correctly serialized them.
        return true;
    }

    /// Groups access events by memory address.
    fn groupByAddress(self: *RaceDetector) !std.HashMap(u64, std.ArrayList(AccessEvent)) {
        const map = std.HashMap(u64, std.ArrayList(AccessEvent)).init(self.access_log.allocator);
        for (self.access_log.items) |event| {
            const list = try map.getOrPut(event.address);
            try list.value_ptr.append(event);
        }
        return map;
    }

    /// Sorts accesses by timestamp.
    fn sortByTimestamp(self: *RaceDetector, accesses: []const AccessEvent) ![]const AccessEvent {
        const sorted = try self.access_log.allocator.dupe(AccessEvent, accesses);
        std.mem.sort(AccessEvent, sorted, {}, struct {
            fn lessThan(_: void, a: AccessEvent, b: AccessEvent) bool {
                return a.timestamp < b.timestamp;
            }
        }.lessThan);
        return sorted;
    }

    /// Simulates the "bug" scenario: unsynchronized concurrent writes.
    /// This should detect a race.
    pub fn simulateBugScenario(self: *RaceDetector) !RaceStatus {
        // Thread 1 writes to address 0x1000
        try self.recordAccess(.{
            .thread_id = 1,
            .address = 0x1000,
            .access_type = .write,
            .timestamp = 1,
            .lock_held = false,
            .lock_id = 0,
        });

        // Thread 2 writes to the same address 0x1000
        try self.recordAccess(.{
            .thread_id = 2,
            .address = 0x1000,
            .access_type = .write,
            .timestamp = 2,
            .lock_held = false,
            .lock_id = 0,
        });

        return self.detectRace();
    }

    /// Simulates the "non-bug" scenario: synchronized access via locks.
    /// This should NOT detect a race.
    pub fn simulateNonBugScenario(self: *RaceDetector) !RaceStatus {
        // Thread 1 acquires lock 1 and writes to address 0x2000
        try self.acquireLock(1, 1);
        try self.recordAccess(.{
            .thread_id = 1,
            .address = 0x2000,
            .access_type = .write,
            .timestamp = 1,
            .lock_held = true,
            .lock_id = 1,
        });
        try self.releaseLock(1, 1);

        // Thread 2 acquires lock 1 and writes to the same address 0x2000
        try self.acquireLock(2, 1);
        try self.recordAccess(.{
            .thread_id = 2,
            .address = 0x2000,
            .access_type = .write,
            .timestamp = 2,
            .lock_held = true,
            .lock_id = 1,
        });
        try self.releaseLock(2, 1);

        return self.detectRace();
    }

    /// Simulates a false positive scenario: accesses that appear concurrent
    /// but are actually ordered by program dependencies (not locks).
    /// In this simplified model, we treat this as no race if no lock is involved
    /// but the accesses are from the same logical sequence.
    pub fn simulateFalsePositiveScenario(self: *RaceDetector) !RaceStatus {
        // Thread 1 reads address 0x3000
        try self.recordAccess(.{
            .thread_id = 1,
            .address = 0x3000,
            .access_type = .read,
            .timestamp = 1,
            .lock_held = false,
            .lock_id = 0,
        });

        // Thread 1 writes to the same address (same thread, so no race)
        try self.recordAccess(.{
            .thread_id = 1,
            .address = 0x3000,
            .access_type = .write,
            .timestamp = 2,
            .lock_held = false,
            .lock_id = 0,
        });

        return self.detectRace();
    }
};
