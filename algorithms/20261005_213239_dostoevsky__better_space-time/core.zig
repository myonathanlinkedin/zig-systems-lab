const std = @import("std");

pub const Level = struct {
    pub const State = enum {
        Active,
        Frozen,
        Compacting,
    };

    id: u8,
    state: State,
    size_bytes: u64,
    capacity_bytes: u64,
    fanout: u32,
    compaction_threshold: f64,

    pub fn init(id: u8, capacity_bytes: u64, fanout: u32, threshold: f64) Level {
        return .{
            .id = id,
            .state = .Active,
            .size_bytes = 0,
            .capacity_bytes = capacity_bytes,
            .fanout = fanout,
            .compaction_threshold = threshold,
        };
    }

    pub fn isFull(self: *const Level) bool {
        return self.size_bytes >= @as(f64, self.capacity_bytes) * self.compaction_threshold;
    }

    pub fn addData(self: *Level, bytes: u64) void {
        self.size_bytes += bytes;
    }

    pub fn reset(self: *Level) void {
        self.size_bytes = 0;
        self.state = .Active;
    }
};

pub const AdaptivePolicy = struct {
    pub const Strategy = enum {
        SizeTiered,
        Leveled,
        Hybrid,
    };

    strategy: Strategy,
    base_fanout: u32,
    level_fanout: u32,
    base_threshold: f64,
    level_threshold: f64,
    max_levels: u8,

    pub fn init(strategy: Strategy, base_fanout: u32, level_fanout: u32, base_threshold: f64, level_threshold: f64, max_levels: u8) AdaptivePolicy {
        return .{
            .strategy = strategy,
            .base_fanout = base_fanout,
            .level_fanout = level_fanout,
            .base_threshold = base_threshold,
            .level_threshold = level_threshold,
            .max_levels = max_levels,
        };
    }

    pub fn getFanout(self: *const AdaptivePolicy, level: u8) u32 {
        return switch (self.strategy) {
            .SizeTiered => self.base_fanout,
            .Leveled => self.level_fanout,
            .Hybrid => if (level < 2) self.base_fanout else self.level_fanout,
        };
    }

    pub fn getThreshold(self: *const AdaptivePolicy, level: u8) f64 {
        return switch (self.strategy) {
            .SizeTiered => self.base_threshold,
            .Leveled => self.level_threshold,
            .Hybrid => if (level < 2) self.base_threshold else self.level_threshold,
        };
    }

    pub fn computeCapacity(self: *const AdaptivePolicy, level: u8, base_capacity: u64) u64 {
        const fanout = self.getFanout(level);
        const multiplier = std.math.pow(u64, fanout, level) catch base_capacity;
        return base_capacity * multiplier;
    }
};

pub const LSMTree = struct {
    levels: [16]Level,
    num_levels: u8,
    policy: AdaptivePolicy,
    base_capacity: u64,
    total_written: u64,
    compactions_triggered: u64,

    pub fn init(policy: AdaptivePolicy, base_capacity: u64, num_levels: u8) LSMTree {
        var tree = LSMTree{
            .levels = undefined,
            .num_levels = num_levels,
            .policy = policy,
            .base_capacity = base_capacity,
            .total_written = 0,
            .compactions_triggered = 0,
        };

        for (0..num_levels) |i| {
            const level_idx = @as(u8, i);
            const capacity = policy.computeCapacity(level_idx, base_capacity);
            const fanout = policy.getFanout(level_idx);
            const threshold = policy.getThreshold(level_idx);
            tree.levels[i] = Level.init(level_idx, capacity, fanout, threshold);
        }

        return tree;
    }

    pub fn write(self: *LSMTree, bytes: u64) !void {
        self.total_written += bytes;
        self.levels[0].addData(bytes);

        var current_level: u8 = 0;
        while (current_level < self.num_levels) : (current_level += 1) {
            const level = &self.levels[current_level];
            if (!level.isFull()) break;

            level.state = .Compacting;
            self.compactions_triggered += 1;

            if (current_level + 1 < self.num_levels) {
                const next_level = &self.levels[current_level + 1];
                const data_to_move = level.size_bytes;
                level.reset();
                next_level.addData(data_to_move);
            } else {
                level.reset();
            }
        }
    }

    pub fn getSpaceUsage(self: *const LSMTree) u64 {
        var total: u64 = 0;
        for (0..self.num_levels) |i| {
            total += self.levels[i].size_bytes;
        }
        return total;
    }

    pub fn getCompactionRatio(self: *const LSMTree) f64 {
        if (self.total_written == 0) return 0.0;
        return @as(f64, self.compactions_triggered) / @as(f64, self.total_written);
    }

    pub fn getLevelState(self: *const LSMTree, level: u8) Level.State {
        return self.levels[level].state;
    }

    pub fn getLevelSize(self: *const LSMTree, level: u8) u64 {
        return self.levels[level].size_bytes;
    }
};
