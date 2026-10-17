const std = @import("std");

pub const CuckooFilter = struct {
    const BucketSize = 4;
    const MaxKicks = 500;
    const FingerprintMask: u8 = 0xFF; // 8-bit fingerprint, zero is reserved

    buckets: []Bucket,
    num_buckets: usize,
    rng: std.rand.DefaultRandom,

    const Bucket = struct {
        slots: [BucketSize]u8 = [_]u8{0} ** BucketSize,
        fn insert(self: *Bucket, fp: u8) bool {
            for (self.slots) |*slot| {
                if (slot.* == 0) {
                    slot.* = fp;
                    return true;
                }
            }
            return false;
        }
        fn contains(self: *const Bucket, fp: u8) bool {
            for (self.slots) |slot| {
                if (slot == fp) return true;
            }
            return false;
        }
        fn delete(self: *Bucket, fp: u8) bool {
            for (self.slots) |*slot| {
                if (slot.* == fp) {
                    slot.* = 0;
                    return true;
                }
            }
            return false;
        }
        fn randomSlotIndex(self: *Bucket, rng: *std.rand.DefaultRandom) usize {
            return rng.random().intRangeLessThan(usize, BucketSize);
        }
        fn swapRandom(self: *Bucket, fp: u8, rng: *std.rand.DefaultRandom) u8 {
            const idx = self.randomSlotIndex(rng);
            const evicted = self.slots[idx];
            self.slots[idx] = fp;
            return evicted;
        }
    };

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !CuckooFilter {
        // capacity is number of items; we allocate enough buckets (capacity / BucketSize * 2) for load factor ~0.5
        const num_buckets = std.math.ceilPowerOfTwo(usize, capacity / BucketSize * 2) catch capacity;
        const buckets = try allocator.alloc(Bucket, num_buckets);
        // zero-initialize
        for (buckets) |*b| {
            b.* = Bucket{};
        }
        var rng = std.rand.DefaultRandom.init(0);
        return CuckooFilter{
            .buckets = buckets,
            .num_buckets = num_buckets,
            .rng = rng,
        };
    }

    pub fn deinit(self: *CuckooFilter, allocator: *std.mem.Allocator) void {
        allocator.free(self.buckets);
    }

    fn hash(key: []const u8) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(key);
        return hasher.final();
    }

    fn fingerprint(hash_val: u64) u8 {
        var fp = @intCast(u8, hash_val & FingerprintMask);
        // fingerprint must be non-zero
        if (fp == 0) fp = 1;
        return fp;
    }

    fn index1(hash_val: u64, num_buckets: usize) usize {
        return @intCast(usize, hash_val % @intCast(u64, num_buckets));
    }

    fn index2(fp: u8, i1: usize, num_buckets: usize) usize {
        // simple secondary index: i1 xor hash(fp)
        const fp_hash = std.hash.Wyhash.hash(&.{fp});
        const i2 = i1 ^ @intCast(usize, fp_hash % @intCast(u64, num_buckets));
        return i2 % num_buckets;
    }

    pub fn insert(self: *CuckooFilter, key: []const u8) !bool {
        const h = hash(key);
        const fp = fingerprint(h);
        const i1 = index1(h, self.num_buckets);
        const i2 = index2(fp, i1, self.num_buckets);

        if (self.buckets[i1].insert(fp) or self.buckets[i2].insert(fp)) {
            return true;
        }

        var cur_fp = fp;
        var cur_idx = if (self.rng.random().bool()) i1 else i2;
        var kick = 0;
        while (kick < MaxKicks) : (kick += 1) {
            cur_fp = self.buckets[cur_idx].swapRandom(cur_fp, &self.rng);
            const alt_idx = index2(cur_fp, cur_idx, self.num_buckets);
            if (self.buckets[alt_idx].insert(cur_fp)) {
                return true;
            }
            cur_idx = alt_idx;
        }
        return false; // filter is full
    }

    pub fn lookup(self: *const CuckooFilter, key: []const u8) bool {
        const h = hash(key);
        const fp = fingerprint(h);
        const i1 = index1(h, self.num_buckets);
        const i2 = index2(fp, i1, self.num_buckets);
        return self.buckets[i1].contains(fp) or self.buckets[i2].contains(fp);
    }

    pub fn delete(self: *CuckooFilter, key: []const u8) bool {
        const h = hash(key);
        const fp = fingerprint(h);
        const i1 = index1(h, self.num_buckets);
        const i2 = index2(fp, i1, self.num_buckets);
        if (self.buckets[i1].delete(fp)) return true;
        if (self.buckets[i2].delete(fp)) return true;
        return false;
    }
};
