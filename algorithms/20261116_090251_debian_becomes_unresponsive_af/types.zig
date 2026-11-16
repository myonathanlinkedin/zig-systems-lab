const std = @import("std");

pub const Error = error{
    InvalidState,
    BufferOverflow,
    InvalidTransition,
    InvalidIndex,
    Timeout,
};

pub const State = enum {
    Booting,
    Running,
    Degraded,
    Unresponsive,
    Recovered,
    Crashed,
};

pub const Severity = enum {
    Info,
    Warning,
    Critical,
};

pub const Event = struct {
    timestamp_ns: u64,
    severity: Severity,
    message: []const u8,
};

pub const KernelVersion = struct {
    major: u16,
    minor: u16,
    patch: u16,
    build: u16,
};

pub const SystemState = struct {
    version: KernelVersion,
    state: State,
    uptime_ns: u64,
    event_log: std.ArrayListUnmanaged(Event),
    watchdog_timer_ns: u64,
    last_heartbeat_ns: u64,
    watchdog_timeout_ns: u64,
    is_watchdog_armed: bool,
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
    recovery_attempts: u32,
    max_recovery_attempts: u32,
    degraded_threshold: f64,
    unresponsive_threshold: f64,
    watchdog_armed: bool,
    last_state_change_ns: u64,
    state_history: std.ArrayListUnmanaged(State),
    metrics_history: std.ArrayListUnmanaged(MetricsSnapshot),
};

pub const MetricsSnapshot = struct {
    timestamp_ns: u64,
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
};

pub const DiagnosticResult = struct {
    root_cause: []const u8,
    confidence: f64,
    affected_subsystems: []const []const u8,
    recommended_actions: []const []const u8,
    severity: Severity,
};

pub const RecoveryAction = enum {
    None,
    SoftReboot,
    HardReboot,
    KernelRollback,
    MemoryReclaim,
    IOReset,
    NetworkReset,
    InterruptThrottle,
    WatchdogReset,
};

pub const RecoveryPlan = struct {
    actions: [8]RecoveryAction,
    action_count: u8,
    estimated_recovery_time_ms: u32,
    success_probability: f64,
};

pub const HealthScore = struct {
    overall: f64,
    cpu: f64,
    memory: f64,
    io: f64,
    network: f64,
    interrupts: f64,
    stability: f64,
};

pub const TransitionRecord = struct {
    from_state: State,
    to_state: State,
    timestamp_ns: u64,
    trigger: []const u8,
};

pub const StateMachine = struct {
    current_state: State,
    transition_count: u32,
    invalid_transition_count: u32,
    transition_log: std.ArrayListUnmanaged(TransitionRecord),
};

pub const Watchdog = struct {
    armed: bool,
    timeout_ns: u64,
    last_ping_ns: u64,
    current_time_ns: u64,
    trip_count: u32,
    reset_count: u32,
};

pub const EventQueue = struct {
    events: std.ArrayListUnmanaged(Event),
    max_size: u32,
    overflow_count: u32,
};

pub const DiagnosticEngine = struct {
    system: *SystemState,
    state_machine: StateMachine,
    watchdog: Watchdog,
    event_queue: EventQueue,
    current_time_ns: u64,
    diagnostic_cache: std.ArrayListUnmanaged(DiagnosticResult),
};

pub fn initSystemState(allocator: std.mem.Allocator, version: KernelVersion) !SystemState {
    return SystemState{
        .version = version,
        .state = .Booting,
        .uptime_ns = 0,
        .event_log = .empty,
        .watchdog_timer_ns = 0,
        .last_heartbeat_ns = 0,
        .watchdog_timeout_ns = 10_000_000_000, // 10 seconds
        .is_watchdog_armed = false,
        .cpu_load_percent = 0.0,
        .memory_pressure_percent = 0.0,
        .io_latency_ms = 0.0,
        .network_latency_ms = 0.0,
        .disk_queue_depth = 0,
        .interrupt_storm_detected = false,
        .soft_lockup_detected = false,
        .hard_lockup_detected = false,
        .oom_killer_invoked = false,
        .kernel_panic = false,
        .recovery_attempts = 0,
        .max_recovery_attempts = 5,
        .degraded_threshold = 70.0,
        .unresponsive_threshold = 95.0,
        .watchdog_armed = false,
        .last_state_change_ns = 0,
        .state_history = .empty,
        .metrics_history = .empty,
    };
}

pub fn initDiagnosticEngine(allocator: std.mem.Allocator, system: *SystemState) !DiagnosticEngine {
    _ = allocator;
    return DiagnosticEngine{
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
        .deinit = undefined,
        .diagnostic_cache = .empty,
    };
}
