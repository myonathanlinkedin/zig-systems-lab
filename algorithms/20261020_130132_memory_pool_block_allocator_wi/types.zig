const std = @import("std");

pub const Block = struct {
    next: ?*Block = null,
};
