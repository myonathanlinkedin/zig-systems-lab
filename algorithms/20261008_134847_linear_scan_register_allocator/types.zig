const std = @import("std");

pub const Interval = struct {
    /// Unique identifier of the variable / virtual register.
    id: u32,
    /// Inclusive start of the live range.
    start: u32,
    /// Inclusive end of the live range. Must satisfy start <= end.
    end: u32,
};

pub const Allocation = struct {
    /// Variable identifier.
    id: u32,
    /// Physical register assigned by the allocator.
    reg: u32,
};
