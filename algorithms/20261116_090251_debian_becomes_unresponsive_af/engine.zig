const std = @import("std");
const types = @import("types.zig");

pub const Engine = struct {
    system: *types.SystemState,
    state_machine: types.StateMachine,
    watchdog: types.Watchdog,
    event_queue: types.EventQueue,
    current_time_ns: u64,
    diagnostic_cache: std.ArrayListUnmanaged(types.DiagnosticResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, system: *types.SystemState) !Engine {
        return Engine{
            .system = system,
            .state_machine = .{
                .current_state = system.state,
                .transition_count = 0,
                .invalid_transition_count = 0,
                .transition_log = .empty,
            },
            .watchdog = .{
                .armed = false,
                .timeout_ns = system.watchdog_timeout_ns,
                .last_ping_ns = 0,
                .current_time_ns = 0,
                .trip_count = 0,
                .reset_count = 0,
            },
            .event_queue = .{
                .events = .empty,
                .max_size = 1024,
                .overflow_count = 0,
            },
            .current_time_ns = 0,
            .diagnostic_cache = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Engine) void {
        self.system.event_log.deinit(self.allocator);
        self.system.state_history.deinit(self.allocator);
        self.system.metrics_history.deinit(self.allocator);
        self.state_machine.transition_log.deinit(self.allocator);
        self.event_queue.events.deinit(self.allocator);
        self.diagnostic_cache.deinit(self.allocator);
    }

    pub fn advanceTime(self: *Engine, delta_ns: u64) void {
        self.current_time_ns += delta_ns;
        self.system.uptime_ns = self.current_time_ns;
        self.watchdog.current_time_ns = self.current_time_ns;
    }

    pub fn updateMetrics(
        self: *Engine,
        cpu_load_percent: f64,
        memory_pressure_percent: f64,
        io_latency_ms: f64,
        network_latency_ms: f64,
        disk_queue_depth: u32,
        interrupt_storm_detected: bool,
        soft_lockup_detected: bool,
        hard_lockup_detected: bool,
        oom_killer_invoked: bool,
        kernel_panic: bool,
    ) !void {
        self.system.cpu_load_percent = cpu_load_percent;
        self.system.memory_pressure_percent = memory_pressure_percent;
        self.system.io_latency_ms = io_latency_ms;
        self.system.network_latency_ms = network_latency_ms;
        self.system.disk_queue_depth = disk_queue_depth;
        self.system.interrupt_storm_detected = interrupt_storm_detected;
        self.system.soft_lockup_detected = soft_lockup_detected;
        self.system.hard_lockup_detected = hard_lockup_detected;
        self.system.oom_killer_invoked = oom_killer_invoked;
        self.system.kernel_panic = kernel_panic;

        const snapshot = types.MetricsSnapshot{
            .timestamp_ns = self.current_time_ns,
            .cpu_load_percent = cpu_load_percent,
            .memory_pressure_percent = memory_pressure_percent,
            .io_latency_ms = io_latency_ms,
            .network_latency_ms = network_latency_ms,
            .disk_queue_depth = disk_queue_depth,
            .interrupt_storm_detected = interrupt_storm_detected,
            .soft_lockup_detected = soft_lockup_detected,
            .hard_lockup_detected = hard_lockup_detected,
            .oom_killer_invoked = oom_killer_invoked,
            .kernel_panic = kernel_panic,
        };
        try self.system.metrics_history.append(self.allocator, snapshot);
    }

    pub fn logEvent(self: *Engine, severity: types.Severity, message: []const u8) !void {
        const event = types.Event{
            .timestamp_ns = self.current_time_ns,
            .severity = severity,
            .message = message,
        };
        try self.system.event_log.append(self.allocator, event);

        if (self.event_queue.events.items.len < self.event_queue.max_size) {
            try self.event_queue.events.append(self.allocator, event);
        } else {
            self.event_queue.overflow_count += 1;
        }
    }

    pub fn transitionState(self: *Engine, new_state: types.State, trigger: []const u8) !void {
        const old_state = self.state_machine.current_state;
        if (!isValidTransition(old_state, new_state)) {
            self.state_machine.invalid_transition_count += 1;
            try self.logEvent(.Warning, "Invalid state transition attempted");
            return;
        }

        const record = types.TransitionRecord{
            .from_state = old_state,
            .to_state = new_state,
            .timestamp_ns = self.current_time_ns,
            .trigger = trigger,
        };
        try self.state_machine.transition_log.append(self.allocator, record);
        self.state_machine.current_state = new_state;
        self.state_machine.transition_count += 1;
        self.system.state = new_state;
        self.system.last_state_change_ns = self.current_time_ns;
        try self.system.state_history.append(self.allocator, new_state);
        try self.logEvent(.Info, "State transition: " ++ @tagName(old_state) ++ " -> " ++ @tagName(new_state));
    }

    pub fn armWatchdog(self: *Engine) void {
        self.watchdog.armed = true;
        self.watchdog.last_ping_ns = self.current_time_ns;
        self.system.is_watchdog_armed = true;
        self.system.watchdog_armed = true;
    }

    pub fn pingWatchdog(self: *Engine) void {
        if (self.watchdog.armed) {
            self.watchdog.last_ping_ns = self.current_time_ns;
            self.system.last_heartbeat_ns = self.current_time_ns;
        }
    }

    pub fn checkWatchdog(self: *Engine) bool {
        if (!self.watchdog.armed) return false;
        const elapsed = self.current_time_ns - self.watchdog.last_ping_ns;
        if (elapsed > self.watchdog.timeout_ns) {
            self.watchdog.trip_count += 1;
            return true;
        }
        return false;
    }

    pub fn resetWatchdog(self: *Engine) void {
        self.watchdog.armed = false;
        self.watchdog.trip_count = 0;
        self.watchdog.reset_count += 1;
        self.system.is_watchdog_armed = false;
        self.system.watchdog_armed = false;
    }

    pub fn computeHealthScore(self: *Engine) types.HealthScore {
        const s = self.system;
        const cpu_score = 100.0 - s.cpu_load_percent;
        const mem_score = 100.0 - s.memory_pressure_percent;
        const io_score = if (s.io_latency_ms > 1000.0) 0.0 else (100.0 - (s.io_latency_ms / 10.0));
        const net_score = if (s.network_latency_ms > 1000.0) 0.0 else (100.0 - (s.network_latency_ms / 10.0));
        const irq_score = if (s.interrupt_storm_detected) 0.0 else 100.0;
        const stability_score = if (s.soft_lockup_detected or s.hard_lockup_detected or s.kernel_panic) 0.0 else 100.0;

        const overall = (cpu_score * 0.25) + (mem_score * 0.25) + (io_score * 0.15) + (net_score * 0.15) + (irq_score * 0.1) + (stability_score * 0.1);

        return types.HealthScore{
            .overall = overall,
            .cpu = cpu_score,
            .memory = mem_score,
            .io = io_score,
            .network = net_score,
            .interrupts = irq_score,
            .stability = stability_score,
        };
    }

    pub fn detectUnresponsiveness(self: *Engine) bool {
        const s = self.system;
        if (s.kernel_panic) return true;
        if (s.hard_lockup_detected) return true;
        if (s.soft_lockup_detected and s.cpu_load_percent > 99.0) return true;
        if (self.checkWatchdog()) return true;
        if (s.cpu_load_percent > s.unresponsive_threshold and s.io_latency_ms > 5000.0) return true;
        return false;
    }

    pub fn detectDegradation(self: *Engine) bool {
        const s = self.system;
        if (s.state == .Unresponsive) return false;
        if (s.cpu_load_percent > s.degraded_threshold) return true;
        if (s.memory_pressure_percent > s.degraded_threshold) return true;
        if (s.io_latency_ms > 1000.0) return true;
        if (s.interrupt_storm_detected) return true;
        if (s.oom_killer_invoked) return true;
        return false;
    }

    pub fn runDiagnostics(self: *Engine) !types.DiagnosticResult {
        const s = self.system;
        var root_cause: []const u8 = "Unknown";
        var confidence: f64 = 0.0;
        var severity: types.Severity = .Info;

        if (s.kernel_panic) {
            root_cause = "Kernel panic";
            confidence = 0.99;
            severity = .Critical;
        } else if (s.hard_lockup_detected) {
            root_cause = "Hard lockup (NMI watchdog)";
            confidence = 0.95;
            severity = .Critical;
        } else if (s.soft_lockup_detected) {
            root_cause = "Soft lockup (CPU stall)";
            confidence = 0.90;
            severity = .Critical;
        } else if (s.oom_killer_invoked) {
            root_cause = "OOM killer invoked (memory exhaustion)";
            confidence = 0.85;
            severity = .Critical;
        } else if (s.interrupt_storm_detected) {
            root_cause = "Interrupt storm (driver bug)";
            confidence = 0.80;
            severity = .Warning;
        } else if (s.cpu_load_percent > s.unresponsive_threshold) {
            root_cause = "CPU saturation (possible kernel bug in 6.1.0-55)";
            confidence = 0.75;
            severity = .Warning;
        } else if (s.io_latency_ms > 5000.0) {
            root_cause = "I/O subsystem hang (block layer issue)";
            confidence = 0.70;
            severity = .Warning;
        } else if (s.memory_pressure_percent > s.degraded_threshold) {
            root_cause = "Memory pressure (possible leak in new kernel)";
            confidence = 0.65;
            severity = .Warning;
        } else {
            root_cause = "No critical issues detected";
            confidence = 0.99;
            severity = .Info;
        }

        const result = types.DiagnosticResult{
            .root_cause = root_cause,
            .confidence = confidence,
            .affected_subsystems = &[_][]const u8{
                "cpu",
                "memory",
                "io",
                "network",
                "interrupts",
            },
            .recommended_actions = &[_][]const u8{
                "Check dmesg for kernel oops",
                "Verify kernel 6.1.0-55 changelog for known bugs",
                "Consider rolling back to 6.1.0-54",
                "Monitor with perf and ftrace",
            },
            .severity = severity,
        };

        try self.diagnostic_cache.append(self.allocator, result);
        return result;
    }

    pub fn generateRecoveryPlan(self: *Engine) !types.RecoveryPlan {
        const s = self.system;
        var actions: [8]types.RecoveryAction = .{ .None } ** 8;
        var count: u8 = 0;
        var estimated_time: u32 = 0;
        var success_prob: f64 = 1.0;

        if (s.kernel_panic) {
            actions[count] = .HardReboot;
            count += 1;
            estimated_time += 30000;
            success_prob *= 0.95;
        } else if (s.hard_lockup_detected) {
            actions[count] = .HardReboot;
            count += 1;
            estimated_time += 30000;
            success_prob *= 0.90;
        } else if (s.soft_lockup_detected) {
            actions[count] = .SoftReboot;
            count += 1;
            estimated_time += 15000;
            success_prob *= 0.85;
        }

        if (s.oom_killer_invoked) {
            actions[count] = .MemoryReclaim;
            count += 1;
            estimated_time += 5000;
            success_prob *= 0.80;
        }

        if (s.interrupt_storm_detected) {
            actions[count] = .InterruptThrottle;
            count += 1;
            estimated_time += 2000;
            success_prob *= 0.75;
        }

        if (s.io_latency_ms > 1000.0) {
            actions[count] = .IOReset;
            count += 1;
            estimated_time += 3000;
            success_prob *= 0.70;
        }

        if (s.network_latency_ms > 1000.0) {
            actions[count] = .NetworkReset;
            count += 1;
            estimated_time += 2000;
            success_prob *= 0.70;
        }

        if (count == 0) {
            actions[0] = .None;
            count = 1;
        }

        if (s.recovery_attempts >= s.max_recovery_attempts) {
            actions[count] = .KernelRollback;
            count += 1;
            estimated_time += 60000;
            success_prob *= 0.95;
        }

        return types.RecoveryPlan{
            .actions = actions,
            .action_count = count,
            .estimated_recovery_time_ms = estimated_time,
            .success_probability = success_prob,
        };
    }

    pub fn executeRecovery(self: *Engine, plan: types.RecoveryPlan) !void {
        for (0..plan.action_count) |i| {
            const action = plan.actions[i];
            switch (action) {
                .None => {},
                .SoftReboot => {
                    try self.logEvent(.Warning, "Executing soft reboot");
                    self.system.state = .Recovered;
                    self.system.recovery_attempts += 1;
                },
                .HardReboot => {
                    try self.logEvent(.Critical, "Executing hard reboot");
                    self.system.state = .Recovered;
                    self.system.recovery_attempts += 1;
                },
                .KernelRollback => {
                    try self.logEvent(.Critical, "Rolling back kernel version");
                    self.system.state = .Recovered;
                    self.system.recovery_attempts += 1;
                },
                .MemoryReclaim => {
                    try self.logEvent(.Warning, "Reclaiming memory");
                    self.system.memory_pressure_percent *= 0.5;
                },
                .IOReset => {
                    try self.logEvent(.Warning, "Resetting I/O subsystem");
                    self.system.io_latency_ms *= 0.1;
                },
                .NetworkReset => {
                    try self.logEvent(.Warning, "Resetting network stack");
                    self.system.network_latency_ms *= 0.1;
                },
                .InterruptThrottle => {
                    try self.logEvent(.Warning, "Throttling interrupts");
                    self.system.interrupt_storm_detected = false;
                },
                .WatchdogReset => {
                    self.resetWatchdog();
                },
            }
        }
    }

    pub fn tick(self: *Engine) !void {
        self.advanceTime(1_000_000_000); // 1 second tick
        self.pingWatchdog();

        if (self.detectUnresponsiveness()) {
            if (self.system.state != .Unresponsive) {
                try self.transitionState(.Unresponsive, "Unresponsiveness detected");
                try self.logEvent(.Critical, "System became unresponsive");
            }
        } else if (self.detectDegradation()) {
            if (self.system.state == .Running or self.system.state == .Booting) {
                try self.transitionState(.Degraded, "Degradation detected");
                try self.logEvent(.Warning, "System entered degraded state");
            }
        } else if (self.system.state == .Degraded) {
            try self.transitionState(.Running, "System recovered from degradation");
            try self.logEvent(.Info, "System returned to running state");
        }
    }

    pub fn simulateKernelBug(
        self: *Engine,
        bug_type: []const u8,
        severity: f64,
    ) !void {
        switch (bug_type) {
            "cpu_spin" => {
                self.system.cpu_load_percent = 100.0 * severity;
                if (severity > 0.9) self.system.soft_lockup_detected = true;
            },
            "memory_leak" => {
                self.system.memory_pressure_percent = 100.0 * severity;
                if (severity > 0.95) self.system.oom_killer_invoked = true;
            },
            "io_hang" => {
                self.system.io_latency_ms = 10000.0 * severity;
                self.system.disk_queue_depth = @intFromFloat(100.0 * severity);
            },
            "irq_storm" => {
                self.system.interrupt_storm_detected = severity > 0.5;
            },
            "hard_lockup" => {
                self.system.hard_lockup_detected = severity > 0.8;
                self.system.cpu_load_percent = 100.0;
            },
            "kernel_panic" => {
                self.system.kernel_panic = true;
                self.system.state = .Crashed;
            },
            else => {
                return types.Error.InvalidState;
            },
        }
        try self.logEvent(.Warning, "Simulated kernel bug: " ++ bug_type);
    }
};

fn isValidTransition(from: types.State, to: types.State) bool {
    return switch (from) {
        .Booting => to == .Running or to == .Crashed,
        .Running => to == .Degraded or to == .Unresponsive or to == .Crashed,
        .Degraded => to == .Running or to == .Unresponsive or to == .Crashed,
        .Unresponsive => to == .Recovered or to == .Crashed,
        .Recovered => to == .Running,
        .Crashed => to == .Booting,
    };
}
