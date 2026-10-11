const std = @import("std");

pub const Qubit = struct {
    alpha: f64,
    beta: f64,

    pub fn init(alpha: f64, beta: f64) Qubit {
        return .{ .alpha = alpha, .beta = beta };
    }

    pub fn normalize(self: *Qubit) void {
        const norm = std.math.sqrt(self.alpha * self.alpha + self.beta * self.beta);
        if (norm > 0) {
            self.alpha /= norm;
            self.beta /= norm;
        }
    }

    pub fn measure(self: Qubit) u1 {
        const p0 = self.alpha * self.alpha;
        const p1 = self.beta * self.beta;
        // Deterministic measurement for testing: return 0 if p0 >= p1 else 1
        return if (p0 >= p1) 0 else 1;
    }
};

pub const QuantumRegister = struct {
    qubits: []Qubit,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, n: usize) !QuantumRegister {
        const qubits = try allocator.alloc(Qubit, n);
        for (qubits) |*q| {
            q.* = Qubit.init(1.0, 0.0); // |0> state
        }
        return .{ .qubits = qubits, .allocator = allocator };
    }

    pub fn deinit(self: *QuantumRegister) void {
        self.allocator.free(self.qubits);
        self.* = undefined;
    }

    pub fn applyHadamard(self: *QuantumRegister, index: usize) void {
        const q = &self.qubits[index];
        const a = q.alpha;
        const b = q.beta;
        const inv_sqrt2 = 1.0 / std.math.sqrt(2.0);
        q.alpha = (a + b) * inv_sqrt2;
        q.beta = (a - b) * inv_sqrt2;
    }

    pub fn applyX(self: *QuantumRegister, index: usize) void {
        const q = &self.qubits[index];
        const tmp = q.alpha;
        q.alpha = q.beta;
        q.beta = tmp;
    }

    pub fn applyZ(self: *QuantumRegister, index: usize) void {
        const q = &self.qubits[index];
        q.alpha = -q.alpha;
    }

    pub fn applyCNOT(self: *QuantumRegister, control: usize, target: usize) void {
        // Simplified: only works if control is in |0> or |1> basis state
        // For superposition, this is a simplification for the hybrid demo
        const c = self.qubits[control];
        const t = &self.qubits[target];
        // If control is |1>, flip target
        // In full quantum, this requires entanglement handling
        // Here we approximate for the hybrid algorithm demo
        if (c.beta * c.beta > 0.5) {
            const tmp = t.alpha;
            t.alpha = t.beta;
            t.beta = tmp;
        }
    }

    pub fn measureAll(self: *QuantumRegister) []u1 {
        const results = self.allocator.alloc(u1, self.qubits.len) catch unreachable;
        for (self.qubits, results) |q, *r| {
            r.* = q.measure();
        }
        return results;
    }
};

pub const ClassicalOptimizer = struct {
    iterations: usize,
    learning_rate: f64,
    theta: []f64,

    pub fn init(allocator: std.mem.Allocator, n_params: usize, learning_rate: f64) !ClassicalOptimizer {
        const theta = try allocator.alloc(f64, n_params);
        for (theta) |*t| t.* = 0.0;
        return .{ .iterations = 0, .learning_rate = learning_rate, .theta = theta };
    }

    pub fn deinit(self: *ClassicalOptimizer) void {
        self.allocator.free(self.theta);
        self.* = undefined;
    }

    pub fn update(self: *ClassicalOptimizer, gradients: []const f64) void {
        for (self.theta, gradients) |*t, g| {
            t.* -= self.learning_rate * g;
        }
        self.iterations += 1;
    }
};

pub const HybridResult = struct {
    classical_solution: []f64,
    quantum_measurements: []u1,
    iterations: usize,
    convergence: bool,
};
