const std = @import("std");
const types = @import("types");
const engine = @import("engine");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize component tables.
    var posTable = types.Table(types.Position).init(&allocator);
    defer posTable.deinit();

    var velTable = types.Table(types.Velocity).init(&allocator);
    defer velTable.deinit();

    // Create entities.
    const e1: types.EntityId = 1;
    const e2: types.EntityId = 2;
    const e3: types.EntityId = 3;

    // Populate components.
    posTable.add(e1, .{ .x = 0.0, .y = 0.0 });
    velTable.add(e1, .{ .dx = 1.0, .dy = 0.0 });

    posTable.add(e2, .{ .x = 5.0, .y = 5.0 });
    // e2 has no velocity component.
}
