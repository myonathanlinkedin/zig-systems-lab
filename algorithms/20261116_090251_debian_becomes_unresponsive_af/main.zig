const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test 1: Initialize system state
    const version = types.KernelVersion{
        .major = 6,
        .minor = 1,
        .patch = 0,
        .build = 55,
    };
    var system = try types.initSystemState(allocator, version);
    defer {
        system.event_log.deinit(allocator);
        system.state_history.deinit(allocator);
        system.metrics_history.deinit(allocator);
    }

    std.debug.assert(system.state == .Booting);
    std.debug.assert(system.version.major == 6);
    std.debug.assert(system.version.minor == 1);
    std.debug.assert(system.version.patch == 0);
    std.debug.assert(system.version.build == 55);

    // Test 2: Initialize engine
    var eng = try engine.Engine.init(allocator, &system);
    defer eng.deinit();

    std.debug.assert(eng.state_machine.current_state == .Booting);
    std.debug.assert(eng.watchdog.armed == false);

    // Test 3: Boot transition
    try eng.transitionState(.Running, "Boot complete");
    std.debug.assert(system.state == .Running);
    std.debug.assert(eng.state_machine.transition_count == 1);

    // Test 4: Arm watchdog
    eng.armWatchdog();
    std.debug.assert(eng.watchdog.armed == true);
    std.debug.assert(system.is_watchdog_armed == true);

    // Test 5: Normal operation
    try eng.updateMetrics(25.0, 30.0, 5.0, 10.0, 2, false, false, false, false, false);
    try eng.tick();
    std.debug.assert(system.state == .Running);
    std.debug.assert(system.uptime_ns > 0);

    // Test 6: Health score computation
    const health = eng.computeHealthScore();
    std.debug.assert(health.overall > 50.0);
    std.debug.assert(health.cpu > 50.0);
    std.debug.assert(health.memory > 50.0);

    // Test 7: Simulate CPU spin bug (degradation)
    try eng.simulateKernelBug("cpu_spin", 0.8);
    try eng.tick();
    std.debug.assert(system.state == .Degraded);
    std.debug.assert(system.cpu_load_percent > 70.0);

    // Test 8: Simulate hard lockup (unresponsiveness)
    try eng.simulateKernelBug("hard_lockup", 0.9);
    try eng.tick();
    std.debug.assert(system.state == .Unresponsive);
    std.debug.assert(system.hard_lockup_detected == true);

    // Test 9: Diagnostics
    const diag = try eng.runDiagnostics();
    std.debug.assert(diag.confidence > 0.8);
    std.debug.assert(diag.severity == .Critical);
    std.debug.assert(std.mem.indexOf(u8, diag.root_cause, "lockup") != null);

    // Test 10: Recovery plan
    const plan = try eng.generateRecoveryPlan();
    std.debug.assert(plan.action_count > 0);
    std.debug.assert(plan.success_probability > 0.0);
    std.debug.assert(plan.success_probability <= 1.0);

    // Test 11: Execute recovery
    try eng.executeRecovery(plan);
    std.debug.assert(system.state == .Recovered);
    std.debug.assert(system.recovery_attempts > 0);

    // Test 12: Transition to running after recovery
    try eng.transitionState(.Running, "Post-recovery");
    std.debug.assert(system.state == .Running);

    // Test 13: Invalid transition check
    const before_invalid = eng.state_machine.invalid_transition_count;
    try eng.transitionState(.Crashed, "Invalid: Running -> Crashed is valid, test Booting -> Unresponsive");
    // Actually Running -> Crashed is valid. Let's test an invalid one.
    // From Running, valid transitions are: Degraded, Unresponsive, Crashed
    // So let's test from Recovered -> Unresponsive (invalid)
    try eng.transitionState(.Recovered, "Test");
    try eng.transitionState(.Unresponsive, "Invalid transition test");
    std.debug.assert(eng.state_machine.invalid_transition_count > before_invalid);

    // Test 14: Watchdog timeout
    eng.armWatchdog();
    eng.advanceTime(11_000_000_000); // 11 seconds, exceeds 10s timeout
    std.debug.assert(eng.checkWatchdog() == true);
    std.debug.assert(eng.watchdog.trip_count > 0);

    // Test 15: Watchdog reset
    eng.resetWatchdog();
    std.debug.assert(eng.watchdog.armed == false);
    std.debug.assert(eng.watchdog.reset_count > 0);

    // Test 16: Memory leak simulation
    try eng.simulateKernelBug("memory_leak", 0.96);
    std.debug.assert(system.oom_killer_invoked == true);
    std.debug.assert(system.memory_pressure_percent > 95.0);

    // Test 17: I/O hang simulation
    try eng.simulateKernelBug("io_hang", 0.9);
    std.debug.assert(system.io_latency_ms > 5000.0);
    std.debug.assert(system.disk_queue_depth > 50);

    // Test 18: IRQ storm simulation
    try eng.simulateKernelBug("irq_storm", 0.8);
    std.debug.assert(system.interrupt_storm_detected == true);

    // Test 19: Kernel panic simulation
    try eng.simulateKernelBug("kernel_panic", 1.0);
    std.debug.assert(system.kernel_panic == true);
    std.debug.assert(system.state == .Crashed);

    // Test 20: Event log verification
    std.debug.assert(system.event_log.items.len > 0);
    std.debug.assert(system.state_history.items.len > 0);
    std.debug.assert(system.metrics_history.items.len > 0);

    // Test 21: Transition log verification
    std.debug.assert(eng.state_machine.transition_log.items.len > 0);
    std.debug.assert(eng.state_machine.transition_count > 0);

    // Test 22: Diagnostic cache verification
    std.debug.assert(eng.diagnostic_cache.items.len > 0);

    // Test 23: Edge case - zero metrics
    var system2 = try types.initSystemState(allocator, version);
    defer {
        system2.event_log.deinit(allocator);
        system2.state_history.deinit(allocator);
        system2.metrics_history.deinit(allocator);
    }
    var eng2 = try engine.Engine.init(allocator, &system2);
    defer eng2.deinit();
    try eng2.transitionState(.Running, "Boot");
    try eng2.updateMetrics(0.0, 0.0, 0.0, 0.0, 0, false, false, false, false, false);
    const health2 = eng2.computeHealthScore();
    std.debug.assert(health2.overall > 95.0);
    std.debug.assert(health2.cpu > 95.0);
    std.debug.assert(health2.memory > 95.0);

    // Test 24: Edge case - maximum metrics
    try eng2.updateMetrics(100.0, 100.0, 10000.0, 10000.0, 1000, true, true, true, true, false);
    const health3 = eng2.computeHealthScore();
    std.debug.assert(health3.overall < 10.0);
    std.debug.assert(health3.cpu < 5.0);
    std.debug.assert(health3.memory < 5.0);

    // Test 25: Multiple recovery attempts
    var system3 = try types.initSystemState(allocator, version);
    defer {
        system3.event_log.deinit(allocator);
        system3.state_history.deinit(allocator);
        system3.metrics_history.deinit(allocator);
    }
    var eng3 = try engine.Engine.init(allocator, &system3);
    defer eng3.deinit();
    try eng3.transitionState(.Running, "Boot");
    for (0..5) |_| {
        try eng3.simulateKernelBug("cpu_spin", 0.95);
        try eng3.tick();
        if (system3.state == .Unresponsive) {
            const p = try eng3.generateRecoveryPlan();
            try eng3.executeRecovery(p);
            if (system3.state == .Recovered) {
                try eng3.transitionState(.Running, "Recover");
            }
        }
}
}
