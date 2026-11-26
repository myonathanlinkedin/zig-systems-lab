const std = @import("std");
const types = @import("types.zig");

pub const Queue = types.BoundedBlockingQueue(i32);
