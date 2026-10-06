const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Test 1: Qubit initialization and normalization
    {
        var q = types.Qubit.init(3.0, 4.0);
        q.normalize();
        std.debug.assert(std.math.abs(q.alpha * q.alpha + q.beta * q.beta - 1.0) < 1e-10);
        std.debug.assert(std.math.abs(q.alpha - 0.6) < 1e-10);
        std.debug.assert(std.math.abs(q.beta - 0.8) < 1e-10);
    }

    // Test 2: Qubit measurement
    {
        const q0 = types.Qubit.init(1.0, 0.0);
        std.debug.assert(q0.measure() == 0);

        const q1 = types.Qubit.init(0.0, 1.0);
        std.debug.assert(q1.measure() == 1);

        const q_super = types.Qubit.init(1.0 / std.math.sqrt(2.0), 1.0 / std.math.sqrt(2.0));
        const m = q_super.measure();
        std.debug.assert(m == 0 or m == 1);
    }

    // Test 3: Quantum Register initialization
    {
        var reg = try types.QuantumRegister.init(alloc, 3);
        defer reg.deinit();
        std.debug.assert(reg.qubits.len == 3);
        for (reg.qubits) |q| {
            std.debug.assert(std.math.abs(q.alpha - 1.0) < 1e-10);
            std.debug.assert(std.math.abs(q.beta - 0.0) < 1e-10);
        }
    }

    // Test 4: Hadamard gate
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyHadamard(0);
        const inv_sqrt2 = 1.0 / std.math.sqrt(2.0);
        std.debug.assert(std.math.abs(reg.qubits[0].alpha - inv_sqrt2) < 1e-10);
        std.debug.assert(std.math.abs(reg.qubits[0].beta - inv_sqrt2) < 1e-10);
    }

    // Test 5: X gate
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyX(0);
        std.debug.assert(std.math.abs(reg.qubits[0].alpha - 0.0) < 1e-10);
        std.debug.assert(std.math.abs(reg.qubits[0].beta - 1.0) < 1e-10);
    }

    // Test 6: Z gate
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyZ(0);
        std.debug.assert(std.math.abs(reg.qubits[0].alpha - (-1.0)) < 1e-10);
        std.debug.assert(std.math.abs(reg.qubits[0].beta - 0.0) < 1e-10);
    }

    // Test 7: Classical Optimizer
    {
        var opt = try types.ClassicalOptimizer.init(alloc, 3, 0.1);
        defer opt.deinit();
        std.debug.assert(opt.theta.len == 3);
        std.debug.assert(opt.iterations == 0);

        const gradients = [_]f64{ 0.5, -0.5, 1.0 };
        opt.update(&gradients);
        std.debug.assert(opt.iterations == 1);
        std.debug.assert(std.math.abs(opt.theta[0] - (-0.05)) < 1e-10);
        std.debug.assert(std.math.abs(opt.theta[1] - 0.05) < 1e-10);
        std.debug.assert(std.math.abs(opt.theta[2] - (-0.1)) < 1e-10);
    }

    // Test 8: Hybrid Engine - Basic Execution
    {
        var he = try engine.HybridEngine.init(alloc, 2, 2, 10, 0.01);
        defer he.deinit();

        const result = try he.run();
        std.debug.assert(result.iterations <= 10);
        std.debug.assert(result.classical_solution.len == 2);
        std.debug.assert(result.quantum_measurements.len == 2);
    }

    // Test 9: Hybrid Engine - Convergence
    {
        var he = try engine.HybridEngine.init(alloc, 3, 3, 100, 0.001);
        defer he.deinit();

        const result = try he.run();
        std.debug.assert(result.iterations <= 100);
        std.debug.assert(result.classical_solution.len == 3);
        std.debug.assert(result.quantum_measurements.len == 3);
    }

    // Test 10: Hybrid Engine - Larger System
    {
        var he = try engine.HybridEngine.init(alloc, 5, 5, 50, 0.01);
        defer he.deinit();

        const result = try he.run();
        std.debug.assert(result.iterations <= 50);
        std.debug.assert(result.classical_solution.len == 5);
        std.debug.assert(result.quantum_measurements.len == 5);
    }

    // Test 11: Edge case - Zero qubits
    {
        var he = try engine.HybridEngine.init(alloc, 0, 1, 10, 0.01);
        defer he.deinit();

        const result = try he.run();
        std.debug.assert(result.quantum_measurements.len == 0);
    }

    // Test 12: Edge case - Single iteration
    {
        var he = try engine.HybridEngine.init(alloc, 1, 1, 1, 0.01);
        defer he.deinit();

        const result = try he.run();
        std.debug.assert(result.iterations == 1);
    }

    // Test 13: Qubit normalization edge cases
    {
        var q = types.Qubit.init(0.0, 0.0);
        q.normalize();
        std.debug.assert(std.math.abs(q.alpha - 0.0) < 1e-10);
        std.debug.assert(std.math.abs(q.beta - 0.0) < 1e-10);

        var q2 = types.Qubit.init(1.0, 0.0);
        q2.normalize();
        std.debug.assert(std.math.abs(q2.alpha - 1.0) < 1e-10);
        std.debug.assert(std.math.abs(q2.beta - 0.0) < 1e-10);
    }

    // Test 14: Multiple Hadamard applications
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyHadamard(0);
        reg.applyHadamard(0);
        // H^2 = I, so should be back to |0>
        std.debug.assert(std.math.abs(reg.qubits[0].alpha - 1.0) < 1e-10);
        std.debug.assert(std.math.abs(reg.qubits[0].beta - 0.0) < 1e-10);
    }

    // Test 15: X gate twice
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyX(0);
        reg.applyX(0);
        // X^2 = I
        std.debug.assert(std.math.abs(reg.qubits[0].alpha - 1.0) < 1e-10);
        std.debug.assert(std.math.abs(reg.qubits[0].beta - 0.0) < 1e-10);
    }

    // Test 16: Z gate twice
    {
        var reg = try types.QuantumRegister.init(alloc, 1);
        defer reg.deinit();
        reg.applyZ(0);
        reg.applyZ(0);
}
}
