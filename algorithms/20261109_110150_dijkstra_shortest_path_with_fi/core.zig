const std = @import("std");

pub const Edge = struct {
    to: usize,
    weight: usize,
};

/// Fibonacci Heap node. Stores a key (distance) and a value (vertex id).
const Node = struct {
    key: usize,
    value: usize,
    degree: usize = 0,
    mark: bool = false,
    parent: ?*Node = null,
    child: ?*Node = null,
    left: *Node,
    right: *Node,

    pub fn init(key: usize, value: usize, allocator: *std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{
            .key = key,
            .value = value,
            .left = node,
            .right = node,
        };
        return node;
    },

    fn insertIntoRootList(self: *Node, root: ?*Node) ?*Node {
        if (root) |r| {
            // splice self into the circular list of root
            self.left = r.left;
            self.right = r;
            r.left.right = self;
            r.left = self;
            return if (self.key < r.key) self else r;
        } else {
            // first node in the heap
            self.left = self;
            self.right = self;
            return self;
        }
    },

    fn removeFromList(self: *Node) void {
        self.left.right = self.right;
        self.right.left = self.left;
        self.left = self;
        self.right = self;
    },

    fn addChild(parent: *Node, child: *Node) void {
        child.parent = parent;
        child.mark = false;
        if (parent.child) |c| {
            // insert child into sibling list of existing children
            child.left = c.left;
            child.right = c;
            c.left.right = child;
            c.left = child;
        } else {
            parent.child = child;
            child.left = child;
            child.right = child;
        }
        parent.degree += 1;
    },
};

pub const FibHeap = struct {
    min: ?*Node = null,
    n: usize = 0,
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) FibHeap {
        return FibHeap{
            .allocator = allocator,
        };
    }

    pub fn isEmpty(self: *FibHeap) bool {
        return self.min == null;
    }

    pub fn insert(self: *FibHeap, key: usize, value: usize) !*Node {
        const node = try Node.init(key, value, self.allocator);
        self.min = node.insertIntoRootList(self.min);
        self.n += 1;
        return node;
    }

    pub fn extractMin(self: *FibHeap) !*Node {
        const z = self.min orelse return error.EmptyHeap;
        // move children of z to root list
        if (z.child) |c| {
            var x = c;
            const start = c;
            while (true) {
                const next = x.right;
                // detach x from child list
                x.parent = null;
                // add x to root list
                x.left.right = x.right;
                x.right.left = x.left;
                // insert x into root list
                x.left = self.min.?.left;
                x.right = self.min;
                self.min.?.left.right = x;
                self.min.?.left = x;
                if (x.key < self.min.?.key) {
                    self.min = x;
                }
                if (next == start) break;
                x = next;
            }
        }
        // remove z from root list
        if (z.right == z) {
            self.min = null;
        } else {
            z.removeFromList();
            self.min = z.right;
            try self.consolidate();
        }
        self.n -= 1;
        return z;
    }

    fn consolidate(self: *FibHeap) !void {
        const maxDegree = @intCast(usize, @log2(self.n)) + 2;
        var A = try self.allocator.alloc(?*Node, maxDegree);
        defer self.allocator.free(A);
        for (A) |*slot| slot.* = null;

        // collect root list nodes into an array to avoid infinite loops while modifying list
        var roots = std.ArrayList(*Node).init(self.allocator);
        defer roots.deinit();
        if (self.min) |m| {
            var x = m;
            const start = m;
            while (true) {
                try roots.append(x);
                x = x.right;
                if (x == start) break;
            }
        }

        for (roots.items) |w| {
            var x = w;
            var d = x.degree;
            while (A[d]) |y| {
                if (x.key > y.key) {
                    const tmp = x;
                    x = y;
                    y = tmp;
                }
                // link y under x
                y.removeFromList();
                Node.addChild(x, y);
                A[d] = null;
                d += 1;
            }
            A[d] = x;
        }

        self.min = null;
        for (A) |maybeNode| {
            if (maybeNode) |node| {
                node.left = node;
                node.right = node;
                self.min = node.insertIntoRootList(self.min);
            }
        }
    }

    pub fn decreaseKey(self: *FibHeap, node: *Node, newKey: usize) void {
        std.debug.assert(newKey <= node.key);
        node.key = newKey;
        if (node.parent) |p| {
            if (node.key < p.key) {
                self.cut(node, p);
                self.cascadingCut(p);
            }
        }
        if (self.min) |m| {
            if (node.key < m.key) {
                self.min = node;
            }
        }
    }

    fn cut(self: *FibHeap, x: *Node, y: *Node) void {
        // remove x from child list of y
        if (y.child) |c| {
            if (c == x) {
                if (x.right != x) {
                    y.child = x.right;
                } else {
                    y.child = null;
                }
            }
        }
        x.removeFromList();
        y.degree -= 1;
        // add x to root list
        x.parent = null;
        x.mark = false;
        self.min = x.insertIntoRootList(self.min);
    }

    fn cascadingCut(self: *FibHeap, y: *Node) void {
        if (y.parent) |z| {
            if (!y.mark) {
                y.mark = true;
            } else {
                self.cut(y, z);
                self.cascadingCut(z);
            }
        }
    }
};

pub fn dijkstra(
    graph: [][]const Edge,
    src: usize,
    allocator: *std.mem.Allocator,
) ![]usize {
    const n = graph.len;
    const INF = std.math.maxInt(usize);
    const dist = try allocator.alloc(usize, n);
    defer {} // caller may free later
    for (dist) |*d| d.* = INF;
    dist[src] = 0;

    var heap = FibHeap.init(allocator);
    var nodePtr = try allocator.alloc(?*Node, n);
    for (nodePtr) |*p| p.* = null;

    const srcNode = try heap.insert(0, src);
    nodePtr[src] = srcNode;

    while (!heap.isEmpty()) {
        const minNode = try heap.extractMin();
        const u = minNode.value;
        const du = minNode.key;
        // relax edges
        for (graph[u]) |e| {
            const v = e.to;
            const alt = du + e.weight;
            if (alt < dist[v]) {
                dist[v] = alt;
                if (nodePtr[v]) |existing| {
                    heap.decreaseKey(existing, alt);
                } else {
                    const newNode = try heap.insert(alt, v);
                    nodePtr[v] = newNode;
                }
            }
        }
    }

    // clean up heap nodes (they are allocated from the same allocator)
    // Caller is responsible for freeing `dist` and `nodePtr` if needed.
    return dist;
}
