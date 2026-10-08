const std = @import("std");

pub const BitMask = u64;

/// Utility functions for BitMask representing subsets of up to 64 elements.
pub const BitSet = struct {
    /// Returns a mask with a single bit set at `index`.
    pub fn singleton(index: usize) BitMask {
        return BitMask(1) << @intCast(u6, index);
    }

    /// Returns the number of set bits in `mask`.
    pub fn popcount(mask: BitMask) usize {
        return @popCount(mask);
    }

    /// Returns true if `mask` is empty.
    pub fn isEmpty(mask: BitMask) bool {
        return mask == 0;
    }

    /// Returns true if `mask` contains all `n` elements (i.e., lower `n` bits set).
    pub fn isFull(mask: BitMask, n: usize) bool {
        const full = (BitMask(1) << @intCast(u6, n)) - 1;
        return mask == full;
    }

    /// Returns an iterator over the indices of set bits in `mask`.
    pub fn iterator(mask: BitMask) Iterator {
        return Iterator{ .remaining = mask };
    }

    pub const Iterator = struct {
        remaining: BitMask,

        pub fn next(self: *Iterator) ?usize {
            if (self.remaining == 0) return null;
            const tz = @ctz(self.remaining);
            self.remaining &= self.remaining - 1;
            return @intCast(usize, tz);
        }
    };
};

/// Oracle type: given a subset mask, returns its submodular value.
pub const OracleFn = fn (mask: BitMask) f64;
