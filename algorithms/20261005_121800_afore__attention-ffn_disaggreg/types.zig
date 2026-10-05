const std = @import("std");

pub const Tensor = struct {
    data: []f32,
    shape: [2]usize,
    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Tensor {
        const data = try allocator.alloc(f32, rows * cols);
        std.mem.zeroes(f32, data);
        return .{ .data = data, .shape = .{ rows, cols } };
    }
    pub fn deinit(self: *Tensor, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        self.data = &.{};
    }
    pub fn dot(a: Tensor, b: Tensor) !f32 {
        if (a.shape[1] != b.shape[0]) return error.ShapeMismatch;
        var sum: f32 = 0;
        for (a.data) |va, i| {
            sum += va * b.data[i];
        }
        return sum;
    }
};

pub const Expert = struct {
    id: u32,
    weight: Tensor,
    bias: f32,
    pub fn init(allocator: std.mem.Allocator, id: u32, dim: usize) !Expert {
        const w = try Tensor.init(allocator, dim, dim);
        return .{ .id = id, .weight = w, .bias = 0.0 };
    }
    pub fn deinit(self: *Expert, allocator: std.mem.Allocator) void {
        self.weight.deinit(allocator);
    }
    pub fn forward(self: *Expert, input: []const f32) ![]f32 {
        const dim = self.weight.shape[0];
        if (input.len != dim) return error.DimMismatch;
        const out = try std.heap.page_allocator.alloc(f32, dim);
        for (out) |*o, i| {
            var sum: f32 = self.bias;
            for (input) |v, j| {
                sum += v * self.weight.data[i * dim + j];
            }
            o.* = sum;
        }
        return out;
    }
};

pub const AttentionHead = struct {
    q: Tensor,
    k: Tensor,
    v: Tensor,
    pub fn init(allocator: std.mem.Allocator, dim: usize) !AttentionHead {
        return .{
            .q = try Tensor.init(allocator, dim, dim),
            .k = try Tensor.init(allocator, dim, dim),
            .v = try Tensor.init(allocator, dim, dim),
        };
    }
    pub fn deinit(self: *AttentionHead, allocator: std.mem.Allocator) void {
        self.q.deinit(allocator);
        self.k.deinit(allocator);
        self.v.deinit(allocator);
    }
    pub fn compute(self: *AttentionHead, x: []const f32) ![]f32 {
        const dim = self.q.shape[0];
        const q = try self.q.forward(x);
        const k = try self.k.forward(x);
        const v = try self.v.forward(x);
        const scores = try std.heap.page_allocator.alloc(f32, dim);
        for (scores) |*s, i| {
            s.* = try Tensor.dot(.{ .data = q[i * dim .. (i + 1) * dim], .shape = .{ 1, dim } }, .{ .data = k[i * dim .. (i + 1) * dim], .shape = .{ dim, 1 } });
        }
        const out = try std.heap.page_allocator.alloc(f32, dim);
        for (out) |*o, i| {
            var sum: f32 = 0;
            for (scores) |s, j| {
                sum += s * v[j * dim + i];
            }
            o.* = sum;
        }
        return out;
    }
};

pub const FFNBlock = struct {
    experts: []Expert,
    router: Tensor,
    top_k: usize,
    pub fn init(allocator: std.mem.Allocator, num_experts: usize, dim: usize, top_k: usize) !FFNBlock {
        const experts = try allocator.alloc(Expert, num_experts);
        for (experts) |*e, i| {
            e.* = try Expert.init(allocator, @intCast(i), dim);
        }
        const router = try Tensor.init(allocator, dim, num_experts);
        return .{ .experts = experts, .router = router, .top_k = top_k };
    }
    pub fn deinit(self: *FFNBlock, allocator: std.mem.Allocator) void {
        for (self.experts) |*e| {
            e.deinit(allocator);
        }
        allocator.free(self.experts);
        self.router.deinit(allocator);
    }
    pub fn forward(self: *FFNBlock, x: []const f32) ![]f32 {
        const dim = self.router.shape[0];
        const scores = try self.router.forward(x);
        const indices = try std.heap.page_allocator.alloc(usize, self.top_k);
        const selected = try std.heap.page_allocator.alloc(f32, self.top_k);
        var i: usize = 0;
        while (i < self.top_k) : (i += 1) {
            var max_idx: usize = 0;
            var max_val: f32 = -std.math.inf;
            for (scores) |s, j| {
                if (s > max_val) {
                    max_val = s;
                    max_idx = j;
                }
            }
            indices[i] = max_idx;
            selected[i] = max_val;
            scores[max_idx] = -std.math.inf;
        }
        const out = try std.heap.page_allocator.alloc(f32, dim);
        std.mem.zeroes(f32, out);
        for (indices) |idx, i| {
            const expert_out = try self.experts[idx].forward(x);
            for (expert_out) |v, j| {
                out[j] += v * selected[i];
            }
        }
        return out;
    }
};

pub const AFORELayer = struct {
    attention: AttentionHead,
    ffn: FFNBlock,
    pub fn init(allocator: std.mem.Allocator, dim: usize, num_experts: usize, top_k: usize) !AFORELayer {
        return .{
            .attention = try AttentionHead.init(allocator, dim),
            .ffn = try FFNBlock.init(allocator, num_experts, dim, top_k),
        };
    }
    pub fn deinit(self: *AFORELayer, allocator: std.mem.Allocator) void {
        self.attention.deinit(allocator);
        self.ffn.deinit(allocator);
    }
    pub fn forward(self: *AFORELayer, x: []const f32) ![]f32 {
        const attn_out = try self.attention.compute(x);
        const ffn_out = try self.ffn.forward(attn_out);
        return ffn_out;
    }
};
