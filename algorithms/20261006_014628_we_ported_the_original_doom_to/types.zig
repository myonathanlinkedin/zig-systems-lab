const std = @import("std");

pub const EntityId = u32;

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Velocity = struct {
    dx: f32,
    dy: f32,
};

pub const Renderable = struct {
    sprite: u32,
};

pub fn Table(comptime T: type) type {
    return struct {
        allocator: *std.mem.Allocator,
        comps: std.ArrayList(T),
        ents: std.ArrayList(EntityId),

        pub fn init(allocator: *std.mem.Allocator) Table(T) {
            return .{
                .allocator = allocator,
                .comps = std.ArrayList(T).init(allocator),
                .ents = std.ArrayList(EntityId).init(allocator),
            };
        }

        pub fn deinit(self: *Table(T)) void {
            self.comps.deinit();
            self.ents.deinit();
        }

        pub fn add(self: *Table(T), entity: EntityId, comp: T) void {
            // No duplicate check for performance; caller must ensure uniqueness.
            self.comps.append(comp) catch unreachable;
            self.ents.append(entity) catch unreachable;
        }

        pub fn get(self: *Table(T), entity: EntityId) ?*T {
            for (self.ents.items, self.comps.items) |e, *c| {
                if (e == entity) return c;
            }
            return null;
        }

        pub fn remove(self: *Table(T), entity: EntityId) void {
            var idx_opt: ?usize = null;
            for (self.ents.items, 0..) |e, i| {
                if (e == entity) {
                    idx_opt = i;
                    break;
                }
            }
            if (idx_opt) |idx| {
                _ = self.ents.swapRemove(idx);
                _ = self.comps.swapRemove(idx);
            }
        }

        pub fn len(self: *Table(T)) usize {
            return self.comps.items.len;
        }

        pub fn items(self: *Table(T)) []T {
            return self.comps.items;
        }

        pub fn entityIds(self: *Table(T)) []EntityId {
            return self.ents.items;
        }
    };
}
