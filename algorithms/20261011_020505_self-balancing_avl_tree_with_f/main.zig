const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    var tree = core.AVLTree.init(allocator);
    defer tree.deinit();

    // Insert keys that trigger all rotation cases
    const keys = [_]i32{ 30, 20, 40, 10, 25, 35, 50, 5, 15, 27 };
    for (keys) |k| {
        try tree.insert(k, k * 10);
    }

    // Verify balance factor constraints
    fn checkBalance(node: ?*core.Node) void {
        if (node) |n| {
            const bf = core.balanceFactor(n);
            std.debug.assert(bf >= -1 and bf <= 1);
            checkBalance(n.left);
            checkBalance(n.right);
        }
    }
    checkBalance(tree.root);

    // Verify in-order traversal yields sorted keys
    var out: [keys.len]i32 = undefined;
    const count = tree.inorder(&out);
    std.debug.assert(count == keys.len);
    for (out[0..count - 1]) |v, i| {
        std.debug.assert(v < out[i + 1]);
    }

    // Test find
    const node = tree.find(27);
    std.debug.assert(node != null and node.?.value == 270);

    // Delete a node with two children
    try tree.delete(20);
    std.debug.assert(tree.find(20) == null);
    // Re-check balance after deletion
    checkBalance(tree.root);

    // Delete leaf node
    try tree.delete(5);
    std.debug.assert(tree.find(5) == null);
    checkBalance(tree.root);

    // Delete node with one child
    try tree.delete(40);
    std.debug.assert(tree.find(40) == null);
    checkBalance(tree.root);

    // Final in-order check
    var final_out: [keys.len - 3]i32 = undefined; // three deletions
    const final_cnt = tree.inorder(&final_out);
    std.debug.assert(final_cnt == keys.len - 3);
    for (final_out[0..final_cnt - 1]) |v, i| {
        std.debug.assert(v < final_out[i + 1]);
    }

    // Ensure tree is still functional after multiple ops
    try tree.insert(22, 220);
    std.debug.assert(tree.find(22) != null);
    checkBalance(tree.root);
}
