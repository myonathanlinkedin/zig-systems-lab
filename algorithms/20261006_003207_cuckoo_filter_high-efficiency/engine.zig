const std = @import("std");
const types = @import("types.zig");

pub usingnamespace types;

/// Compute an 8‑bit fingerprint from the item hash. Zero is remapped to 1.
fn fingerprintFromHash(hash: u64) Fingerprint {
    var fp: Fingerprint = @intCast(Fingerprint, hash & 0xFF);
    // Zero fingerprint is used as a sentinel for empty slots.
    if (fp == 0) fp = 1;
    return fp;
}

/// Primary bucket index from the full hash.
fn index1(hash: u64, mask: usize) usize {
    return @intCast(usize, hash & @intCast(u64, mask));
}

/// Secondary bucket index derived from the primary index and fingerprint.
fn index2(i1: usize, fp: Fingerprint, mask: usize) usize {
    const fp_hash = std.hash.Wyhash.hash(&fp);
    return i1 ^ @intCast(usize, fp_hash & @intCast(u64, mask));
}

/// Attempt to place `fp` into `bucket`. Returns true on success.
fn tryInsertIntoBucket(bucket: *BucketEntry, fp: Fingerprint) bool {
    for (bucket) |*slot| {
        if (slot.* == 0) {
            slot.* = fp;
            return true;
        }
    }
    return false;
}

/// Search for `fp` in `bucket`. Returns true if found and clears the slot.
fn tryDeleteFromBucket(bucket: *BucketEntry, fp: Fingerprint) bool {
    for (bucket) |*slot| {
        if (slot.* == fp) {
            slot.* = 0;
            return true;
        }
    }
    return false;
}

/// Check whether `fp` exists in `bucket`.
fn bucketContains(bucket: *const BucketEntry, fp: Fingerprint) bool {
    for (bucket) |slot| {
        if (slot == fp) return true;
    }
    return false;
}

/// Public API: insert an item. Returns true on success, false if the filter is full.
pub fn insert(self: *CuckooFilter, item: []const u8) !bool {
    const hash = std.hash.Wyhash.hash(item);
    const fp = fingerprintFromHash(hash);
    const i1 = index1(hash, self.bucket_mask);
    const i2 = index2(i1, fp, self.bucket_mask);

    // Fast path: try both buckets directly.
    if (tryInsertIntoBucket(&self.buckets[i1], fp)) return true;
    if (tryInsertIntoBucket(&self.buckets[i2], fp)) return true;

    // Eviction loop.
    var cur_idx = if (self.prng.random().bool()) i1 else i2;
    var cur_fp = fp;

    var kick: usize = 0;
    while (kick < Config.max_kicks) : (kick += 1) {
        // Random slot within the bucket.
        const slot = self.prng.random().intRangeLessThan(usize, Config.bucket_size);
        // Swap fingerprint with the occupant.
        const evicted = self.buckets[cur_idx][slot];
        self.buckets[cur_idx][slot] = cur_fp;
        cur_fp = evicted;

        // Compute alternate location for the evicted fingerprint.
        cur_idx = index2(cur_idx, cur_fp, self.bucket_mask);

        if (tryInsertIntoBucket(&self.buckets[cur_idx], cur_fp)) {
            return true;
        }
    }
    // Insertion failed after max_kicks.
    return false;
}

/// Public API: test membership of an item.
pub fn contains(self: *CuckooFilter, item: []const u8) bool {
    const hash = std.hash.Wyhash.hash(item);
    const fp = fingerprintFromHash(hash);
    const i1 = index1(hash, self.bucket_mask);
    const i2 = index2(i1, fp, self.bucket_mask);

    return bucketContains(&self.buckets[i1], fp) or bucketContains(&self.buckets[i2], fp);
}

/// Public API: delete an item. Returns true if the item was present.
pub fn delete(self: *CuckooFilter, item: []const u8) bool {
    const hash = std.hash.Wyhash.hash(item);
    const fp = fingerprintFromHash(hash);
    const i1 = index1(hash, self.bucket_mask);
    const i2 = index2(i1, fp, self.bucket_mask);

    if (tryDeleteFromBucket(&self.buckets[i1], fp)) return true;
    if (tryDeleteFromBucket(&self.buckets[i2], fp)) return true;
    return false;
}
