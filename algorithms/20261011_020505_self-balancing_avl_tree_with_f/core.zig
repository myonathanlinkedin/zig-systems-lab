const std = @import("std");

pub const Node = struct {
    key: i32,
    value: i32,
    height: i32,
    left: ?*Node = null,
    right: ?*Node = null,
};

fn nodeHeight(n: ?*Node) i32 {
    return if (n) |node| node.height else 0;
}

fn max(a: i32, b: i32) i32 {
    return if (a > b) a else b;
}

fn updateHeight(n: *Node) void {
    n.height = 1 + max(nodeHeight(n.left), nodeHeight(n.right));
}

fn balanceFactor(n: *Node) i32 {
    return nodeHeight(n.left) - nodeHeight(n.right);
}

fn rotateRight(y: *Node) *Node {
    const x = y.left.?;
    const T2 = x.right;

    // Perform rotation
    x.right = y;
    y.left = T2;

    // Update heights
    updateHeight(y);
    updateHeight(x);
    return x;
}

fn rotateLeft(x: *Node) *Node {
    const y = x.right.?;
    const T2 = y.left;

    // Perform rotation
    y.left = x;
    x.right = T2;

    // Update heights
    updateHeight(x);
    updateHeight(y);
    return y;
}

fn rebalance(node: *Node) *Node {
    updateHeight(node);
    const bf = balanceFactor(node);

    // Left heavy
    if (bf > 1) {
        // Left-Right case
        if (balanceFactor(node.left.?) < 0) {
            node.left = rotateLeft(node.left.?);
        }
        return rotateRight(node);
    }
    // Right heavy
    if (bf < -1) {
        // Right-Left case
        if (balanceFactor(node.right.?) > 0) {
            node.right = rotateRight(node.right.?);
        }
        return rotateLeft(node);
    }
    return node;
}

fn insertRec(allocator: *std.mem.Allocator, root: ?*Node, key: i32, value: i32) !?*Node {
    if (root) |node| {
        if (key < node.key) {
            node.left = try insertRec(allocator, node.left, key, value);
        } else if (key > node.key) {
            node.right = try insertRec(allocator, node.right, key, value);
        } else {
            // Update existing key
            node.value = value;
            return root;
        }
        return rebalance(node);
    } else {
        const new_node = try allocator.create(Node);
        new_node.* = Node{
            .key = key,
            .value = value,
            .height = 1,
        };
        return new_node;
    }
}

fn minValueNode(node: *Node) *Node {
    var current = node;
    while (current.left) |l| {
        current = l;
    }
    return current;
}

fn deleteRec(allocator: *std.mem.Allocator, root: ?*Node, key: i32) !?*Node {
    if (root) |node| {
        if (key < node.key) {
            node.left = try deleteRec(allocator, node.left, key);
        } else if (key > node.key) {
            node.right = try deleteRec(allocator, node.right, key);
        } else {
            // Node with only one child or no child
            if (node.left == null) {
                const temp = node.right;
                allocator.destroy(node);
                return temp;
            } else if (node.right == null) {
                const temp = node.left;
                allocator.destroy(node);
                return temp;
            } else {
                // Node with two children: get inorder successor
                const succ = minValueNode(node.right.?);
                node.key = succ.key;
                node.value = succ.value;
                node.right = try deleteRec(allocator, node.right, succ.key);
            }
        }
        return rebalance(node);
    } else {
        return null; // Key not found
    }
}

fn findRec(root: ?*Node, key: i32) ?*Node {
    var cur = root;
    while (cur) |node| {
        if (key == node.key) return node;
        cur = if (key < node.key) node.left else node.right;
    }
    return null;
}

pub const AVLTree = struct {
    root: ?*Node = null,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) AVLTree {
        return AVLTree{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *AVLTree) void {
        fn freeRec(allocator: *std.mem.Allocator, node: ?*Node) void {
            if (node) |n| {
                freeRec(allocator, n.left);
                freeRec(allocator, n.right);
                allocator.destroy(n);
            }
        }
        freeRec(self.allocator, self.root);
        self.root = null;
    }

    pub fn insert(self: *AVLTree, key: i32, value: i32) !void {
        self.root = try insertRec(self.allocator, self.root, key, value);
    }

    pub fn delete(self: *AVLTree, key: i32) !void {
        self.root = try deleteRec(self.allocator, self.root, key);
    }

    pub fn find(self: *AVLTree, key: i32) ?*Node {
        return findRec(self.root, key);
    }

    // Helper for testing: in-order traversal into a slice
    pub fn inorder(self: *AVLTree, out: []i32) usize {
        var idx: usize = 0;
        fn walk(node: ?*Node, out: []i32, idx: *usize) void {
            if (node) |n| {
                walk(n.left, out, idx);
                if (idx.* < out.len) {
                    out[idx.*] = n.key;
                }
                idx.* += 1;
                walk(n.right, out, idx);
            }
        }
        walk(self.root, out, &idx);
        return idx;
    }
};
