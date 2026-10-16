const std = @import("std");

pub const Config = struct {
    /// Number of entries per bucket. Typical values: 4.
    pub const bucket_size: usize = 4;
    /// Number of bits for fingerprint. Using 8 bits (1 byte) for simplicity.
    pub const fingerprint_bits: usize = 8;
    /// Maximum number of evictions (kicks) before giving up on insertion.
    pub const max_kicks: usize = 500;
};

pub const Fingerprint = u8; // 8‑bit fingerprint

pub const BucketEntry = [Config.bucket_size]Fingerprint;

/// Core cuckoo filter data structure. All algorithmic logic lives in `engine.zig`.
pub const CuckooFilter = struct {
    buckets: []BucketEntry,
    bucket_mask: usize,
    allocator: *std.mem.Allocator,
    prng: std.rand.DefaultPrng,

    /// Initialise a filter with at least `capacity` logical entries.
    /// Returns an error if allocation fails.
    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !CuckooFilter {
        // Compute number of buckets as next power‑of‑two.
        const buckets_needed = (capacity + Config.bucket_size - 1) / Config.bucket_size;
        const bucket_count = std.math.ceilPowerOfTwo(usize, buckets_needed);
        const mask = bucket_count - 1;

        var buckets = try allocator.alloc(BucketEntry, bucket_count);
        // Zero‑initialise (0 is reserved as “empty” fingerprint).
        std.mem.set(Fingerprint, @ptrCast([*]Fingerprint, &buckets[0]), 0, bucket_count * Config.bucket_size);

        var prng = std.rand.DefaultPrng.init(0xdeadbeef);
        return CuckooFilter{
            .buckets = buckets,
            .bucket_mask = mask,
            .allocator = allocator,
            .prng = prng,
        };
    }

    /// Release allocated memory.
    pub fn deinit(self: *CuckooFilter) void {
        self.allocator.free(self.buckets);
        self.* = undefined;
    }
};
