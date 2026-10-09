const std = @import("std");

pub const Sample = struct {
    start: u64,
    end: u64,
    stack: []const u32, // function identifiers, deepest call last
};

pub const Aggregated = struct {
    func_id: u32,
    inclusive: u64,
    exclusive: u64,
};

pub const Profiler = struct {
    allocator: *std.mem.Allocator,
    samples: std.ArrayList(Sample),

    pub fn init(allocator: *std.mem.Allocator) Profiler {
        return Profiler{
            .allocator = allocator,
            .samples = std.ArrayList(Sample).init(allocator.*),
        };
    }

    pub fn deinit(self: *Profiler) void {
        // free duplicated stacks
        for (self.samples.items) |s| {
            self.allocator.free(s.stack);
        }
        self.samples.deinit();
    }

    /// Record the beginning of a sample.
    /// `stack` is copied; the caller may reuse its memory after the call.
    pub fn startSample(self: *Profiler, timestamp: u64, stack: []const u32) !void {
        const dup = try self.allocator.dupe(u32, stack);
        try self.samples.append(Sample{
            .start = timestamp,
            .end = 0,
            .stack = dup,
        });
    }

    /// Record the end of the most‑recent sample.
    pub fn endSample(self: *Profiler, timestamp: u64) void {
        if (self.samples.items.len == 0) return;
        const idx = self.samples.items.len - 1;
        self.samples.items[idx].end = timestamp;
    }

    /// Aggregate inclusive and exclusive times per function identifier.
    /// Returns a heap‑allocated slice; the caller owns the memory.
    pub fn aggregate(self: *Profiler, allocator: *std.mem.Allocator) ![]Aggregated {
        var map = std.AutoHashMap(u32, struct { inclusive: u64, exclusive: u64 }).init(allocator.*);
        defer map.deinit();

        for (self.samples.items) |s| {
            const duration = s.end - s.start;
            if (s.stack.len == 0) continue;

            // Inclusive time for every frame in the stack.
            for (s.stack) |fid| {
                const entry = try map.getOrPut(fid);
                if (!entry.found_existing) entry.value_ptr.* = .{ .inclusive = 0, .exclusive = 0 };
                entry.value_ptr.inclusive += duration;
            }

            // Exclusive time for the leaf (deepest) frame.
            const leaf = s.stack[s.stack.len - 1];
            const leafEntry = try map.getOrPut(leaf);
            if (!leafEntry.found_existing) leafEntry.value_ptr.* = .{ .inclusive = 0, .exclusive = 0 };
            leafEntry.value_ptr.exclusive += duration;
        }

        // Convert hashmap to a dense array.
        const result = try allocator.alloc(Aggregated, map.count());
        var i: usize = 0;
        var it = map.iterator();
        while (it.next()) |kv| {
            result[i] = Aggregated{
                .func_id = kv.key,
                .inclusive = kv.value.inclusive,
                .exclusive = kv.value.exclusive,
            };
            i += 1;
        }
        return result;
    }
};
