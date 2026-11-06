const std = @import("std");

pub const ModelContext = struct {
    allocator: *std.mem.Allocator,
    parent: ?*ModelContext,
    map: std.StringHashMap([]const u8),

    pub fn init(allocator: *std.mem.Allocator, parent: ?*ModelContext) !*ModelContext {
        const self = try allocator.create(ModelContext);
        self.* = ModelContext{
            .allocator = allocator,
            .parent = parent,
            .map = std.StringHashMap([]const u8).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *ModelContext) void {
        // Free all stored keys and values
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
        self.allocator.destroy(self);
    }

    pub fn set(self: *ModelContext, key: []const u8, value: []const u8) !void {
        // Duplicate key/value so the context owns them
        const keyCopy = try self.allocator.dupe(u8, key);
        const valCopy = try self.allocator.dupe(u8, value);

        // If key existed, free the old value (key memory is reclaimed by map)
        if (self.map.get(keyCopy)) |old| {
            self.allocator.free(old);
        }

        // Insert new pair
        try self.map.put(keyCopy, valCopy);
    }

    pub fn get(self: *ModelContext, key: []const u8) ?[]const u8 {
        var cur: ?*ModelContext = self;
        while (cur) |c| {
            if (c.map.get(key)) |v| return v;
            cur = c.parent;
        }
        return null;
    }

    pub fn child(self: *ModelContext) !*ModelContext {
        return ModelContext.init(self.allocator, self);
    }
};
