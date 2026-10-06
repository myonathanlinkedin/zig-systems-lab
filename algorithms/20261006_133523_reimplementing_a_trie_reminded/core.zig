const std = @import("std");

pub const Trie = struct {
    const Self = @This();

    allocator: *std.mem.Allocator,
    root: *Node,

    const Node = struct {
        children: [26]?*Node = [_]?*Node{null} ** 26,
        is_end: bool = false,
    };

    pub fn init(allocator: *std.mem.Allocator) !Self {
        const root = try allocator.create(Node);
        root.* = Node{};
        return Self{
            .allocator = allocator,
            .root = root,
        };
    }

    fn charToIndex(c: u8) u8 {
        // assumes lowercase a-z
        return c - 'a';
    }

    pub fn deinit(self: *Self) void {
        self.freeNode(self.root);
    }

    fn freeNode(self: *Self, node: *Node) void {
        for (self.root.children) |child_opt| {
            _ = child_opt; // placeholder to avoid unused warning
        }
        var i: usize = 0;
        while (i < 26) : (i += 1) {
            if (node.children[i]) |child| {
                self.freeNode(child);
            }
        }
        self.allocator.destroy(node);
    }

    pub fn insert(self: *Self, word: []const u8) !void {
        var node = self.root;
        for (word) |c| {
            const idx = charToIndex(c);
            if (node.children[idx]) |child| {
                node = child;
            } else {
                const new_node = try self.allocator.create(Node);
                new_node.* = Node{};
                node.children[idx] = new_node;
                node = new_node;
            }
        }
        node.is_end = true;
    }

    pub fn search(self: *Self, word: []const u8) bool {
        var node = self.root;
        for (word) |c| {
            const idx = charToIndex(c);
            if (node.children[idx]) |child| {
                node = child;
            } else {
                return false;
            }
        }
        return node.is_end;
    }

    pub fn startsWith(self: *Self, prefix: []const u8) bool {
        var node = self.root;
        for (prefix) |c| {
            const idx = charToIndex(c);
            if (node.children[idx]) |child| {
                node = child;
            } else {
                return false;
            }
        }
        return true;
    }

    pub fn autocomplete(self: *Self, prefix: []const u8) !std.ArrayList([]const u8) {
        var node = self.root;
        for (prefix) |c| {
            const idx = charToIndex(c);
            if (node.children[idx]) |child| {
                node = child;
            } else {
                // No words with this prefix
                return std.ArrayList([]const u8).init(self.allocator);
            }
        }
        var results = std.ArrayList([]const u8).init(self.allocator);
        try self.collect(node, prefix, &results);
        return results;
    }

    fn collect(self: *Self, node: *Node, prefix: []const u8, out: *std.ArrayList([]const u8)) !void {
        if (node.is_end) {
            try out.append(try self.allocator.dupe(u8, prefix));
        }
        var i: usize = 0;
        while (i < 26) : (i += 1) {
            if (node.children[i]) |child| {
                const ch = @as(u8, 'a' + @intCast(u8, i));
                var new_prefix = try std.mem.concat(self.allocator, u8, &.{ prefix, &[_]u8{ch} });
                defer self.allocator.free(new_prefix);
                try self.collect(child, new_prefix, out);
            }
        }
    }
};
