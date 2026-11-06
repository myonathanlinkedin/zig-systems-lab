const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    // Run unit tests manually (Zig's test blocks are also compiled, but we keep them here)
    try testCompileAndInterpret();
    try testDivisionByZero();
    try testKernelSuccess();
    try testKernelHang();
}

// ---------- Tests ----------
fn testCompileAndInterpret() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const expr = "2 + 3 * 4 - 5";
    const bytecode = try core.compile(expr, &gpa.allocator);
    defer gpa.allocator.free(bytecode);

    const result = try core.interpret(bytecode);
    std.debug.assert(result == 9); // 2 + (3*4) -5 = 9
}

fn testDivisionByZero() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const expr = "10 / (3 - 3)";
    const bytecode = try core.compile(expr, &gpa.allocator);
    defer gpa.allocator.free(bytecode);

    const res = core.interpret(bytecode);
    std.debug.assert(res == core.RuntimeError.DivisionByZero);
}

// ---------- Kernel Tasks ----------
const Counter = struct {
    value: usize,
    limit: usize,
};

fn counterTask(ctx: *anyopaque) bool {
    const c = @ptrCast(*Counter, ctx);
    if (c.value >= c.limit) return false;
    c.value += 1;
    return true;
}

fn hangingTask(_: *anyopaque) bool {
    // never finishes
    return true;
}

// ---------- Kernel Tests ----------
fn testKernelSuccess() !void {
    var counter = Counter{ .value = 0, .limit = 5 };
    var tasks = [_]core.Task{
        .{ .ctx = &counter, .func = counterTask },
    };
    try core.runKernel(&tasks, 10);
    std.debug.assert(counter.value == 5);
}

fn testKernelHang() !void {
    var counter = Counter{ .value = 0, .limit = 3 };
    var tasks = [_]core.Task{
        .{ .ctx = &counter, .func = counterTask },
        .{ .ctx = null, .func = hangingTask },
    };
    const res = core.runKernel(&tasks, 5);
    std.debug.assert(res == core.KernelError.HangDetected);
}
