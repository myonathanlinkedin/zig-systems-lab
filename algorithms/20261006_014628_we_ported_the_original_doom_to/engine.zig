const std = @import("std");
const types = @import("types");

pub fn query(
    comptime T: type,
    table: *types.Table(T),
    predicate: fn(*const T) bool,
    allocator: *std.mem.Allocator,
) !std.ArrayList(T) {
    var result = std.ArrayList(T).init(allocator);
    for (table.items()) |*comp| {
        if (predicate(comp)) {
            try result.append(comp.*);
        }
    }
    return result;
}

pub fn updatePositions(
    posTable: *types.Table(types.Position),
    velTable: *types.Table(types.Velocity),
    dt: f32,
) void {
    // Iterate over positions; if a matching velocity exists, update the position.
    for (posTable.entityIds()) |entity, i| {
        if (velTable.get(entity)) |vel| {
            var pos = &posTable.comps.items[i];
            pos.x += vel.dx * dt;
            pos.y += vel.dy * dt;
        }
    }
}
