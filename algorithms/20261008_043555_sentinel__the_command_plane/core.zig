const std = @import("std");

pub const Command = fn (ctx: *anyopaque) void;

/// Node in the singly‑linked list of commands.
/// The sentinel node is a regular node whose `next` points to itself.
pub const CommandNode = struct {
    command: ?Command,
    ctx: ?*anyopaque,
    next: ?*CommandNode,

    /// Initialize a sentinel node. Its `next` points to itself.
    pub fn sentinel(allocator: *std.mem.Allocator) !*CommandNode {
        const node = try allocator.create(CommandNode);
        node.* = CommandNode{
            .command = null,
            .ctx = null,
            .next = node, // points to itself
        };
        return node;
    }

    /// Allocate a normal node.
    pub fn allocate(
        allocator: *std.mem.Allocator,
        command: Command,
        ctx: *anyopaque,
    ) !*CommandNode {
        const node = try allocator.create(CommandNode);
        node.* = CommandNode{
            .command = command,
            .ctx = ctx,
            .next = null,
        };
        return node;
    }

    /// Deallocate a node.
    pub fn destroy(self: *CommandNode, allocator: *std.mem.Allocator) void {
        allocator.destroy(self);
    }
};

/// CommandPlane holds a list of commands with a sentinel node for O(1) insertion.
pub const CommandPlane = struct {
    allocator: *std.mem.Allocator,
    sentinel: *CommandNode,
    len: usize,

    /// Initialise a new CommandPlane.
    pub fn init(allocator: *std.mem.Allocator) !CommandPlane {
        const sent = try CommandNode.sentinel(allocator);
        return CommandPlane{
            .allocator = allocator,
            .sentinel = sent,
            .len = 0,
        };
    }

    /// Deinitialise the plane, freeing all nodes.
    pub fn deinit(self: *CommandPlane) void {
        var cur = self.sentinel.next;
        while (cur) |node| {
            if (node == self.sentinel) break;
            const next = node.next;
            node.destroy(self.allocator);
            cur = next;
        }
        // finally destroy sentinel
        self.sentinel.destroy(self.allocator);
    }

    /// Append a command to the end of the list.
    pub fn add(self: *CommandPlane, command: Command, ctx: *anyopaque) !void {
        const new_node = try CommandNode.allocate(self.allocator, command, ctx);
        // Find tail (node whose next is sentinel)
        var tail = self.sentinel;
        while (tail.next) |next| {
            if (next == self.sentinel) break;
            tail = next;
        }
        // Insert before sentinel
        new_node.next = self.sentinel;
        tail.next = new_node;
        self.len += 1;
    }

    /// Execute all commands in insertion order.
    pub fn executeAll(self: *CommandPlane) void {
        var cur = self.sentinel.next;
        while (cur) |node| {
            if (node == self.sentinel) break;
            // Unwrap safely; sentinel nodes never have a command.
            if (node.command) |cmd| {
                cmd(node.ctx.?);
            }
            cur = node.next;
        }
    }

    /// Return number of stored commands.
    pub fn count(self: *CommandPlane) usize {
        return self.len;
    }
};
