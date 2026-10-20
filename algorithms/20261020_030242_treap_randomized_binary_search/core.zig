const std = @import("std");

pub const Treap = struct {
    const Node = struct {
        key: u32,
        priority: u32,
        left: ?*Node = null,
        right: ?*Node = null,
    };

    root: ?*Node = null,
    size: usize = 0,
    rng: std.Random,

    pub fn init(seed: u64) Treap {
        return .{ .rng = std.Random.Prng.init(seed) };
    }

    pub fn deinit(self: *Treap) void {
        self._deinit(self.root);
        self.root = null;
        self.size = 0;
    }

    fn _deinit(self: *Treap, node: ?*Node) void {
        if (node == null) return;
        self._deinit(node.?.left);
        self._deinit(node.?.right);
        self.rng.allocator.free(node);
    }

    pub fn insert(self: *Treap, key: u32) !void {
        const node = try self.rng.allocator.create(Node);
        node.* = .{ .key = key, .priority = self.rng.random().int(u32) };
        self.root = self._insert(self.root, node);
        self.size += 1;
    }

    fn _insert(self: *Treap, root: ?*Node, node: *Node) ?*Node {
        if (root == null) return node;
        const r = root.?;
        if (node.priority > r.priority) {
            const left, right = self._split(r, node.key);
            node.left = left;
            node.right = right;
            return node;
        }
        if (node.key < r.key) {
            r.left = self._insert(r.left, node);
        } else {
            r.right = self._insert(r.right, node);
        }
        return r;
    }

    fn _split(self: *Treap, root: ?*Node, key: u32) struct { ?*Node, ?*Node } {
        if (root == null) return .{ null, null };
        const r = root.?;
        if (r.key <= key) {
            const res = self._split(r.right, key);
            r.right = res[0];
            return .{ r, res[1] };
        } else {
            const res = self._split(r.left, key);
            r.left = res[1];
            return .{ res[0], r };
        }
    }

    pub fn remove(self: *Treap, key: u32) bool {
        const found = self._remove(self.root, key);
        if (found) self.size -= 1;
        return found;
    }

    fn _remove(self: *Treap, root: ?*Node, key: u32) bool {
        if (root == null) return false;
        const r = root.?;
        if (key < r.key) {
            const found = self._remove(r.left, key);
            if (found) r.left = self._merge(r.left, r.right);
            return found;
        } else if (key > r.key) {
            const found = self._remove(r.right, key);
            if (found) r.right = self._merge(r.left, r.right);
            return found;
        } else {
            const merged = self._merge(r.left, r.right);
            self.rng.allocator.free(r);
            return true;
        }
    }

    fn _merge(self: *Treap, a: ?*Node, b: ?*Node) ?*Node {
        if (a == null) return b;
        if (b == null) return a;
        const ra = a.?;
        const rb = b.?;
        if (ra.priority > rb.priority) {
            ra.right = self._merge(ra.right, b);
            return ra;
        } else {
            rb.left = self._merge(a, rb.left);
            return rb;
        }
    }

    pub fn contains(self: *const Treap, key: u32) bool {
        var cur = self.root;
        while (cur != null) {
            const n = cur.?;
            if (key == n.key) return true;
            cur = if (key < n.key) n.left else n.right;
        }
        return false;
    }

    pub fn min(self: *const Treap) ?u32 {
        var cur = self.root;
        while (cur != null and cur.?.left != null) cur = cur.?.left;
        return if (cur != null) cur.?.key else null;
    }

    pub fn max(self: *const Treap) ?u32 {
        var cur = self.root;
        while (cur != null and cur.?.right != null) cur = cur.?.right;
        return if (cur != null) cur.?.key else null;
    }

    pub fn height(self: *const Treap) usize {
        return self._height(self.root);
    }

    fn _height(self: *const Treap, node: ?*Node) usize {
        if (node == null) return 0;
        const n = node.?;
        const lh = self._height(n.left);
        const rh = self._height(n.right);
        return 1 + @max(lh, rh);
    }

    pub fn inorder(self: *const Treap, out: []u32) usize {
        var count: usize = 0;
        count = self._inorder(self.root, out, count);
        return count;
    }

    fn _inorder(self: *const Treap, node: ?*Node, out: []u32, count: usize) usize {
        if (node == null) return count;
        const n = node.?;
        count = self._inorder(n.left, out, count);
        if (count < out.len) out[count] = n.key;
        count += 1;
        count = self._inorder(n.right, out, count);
        return count;
    }
};
