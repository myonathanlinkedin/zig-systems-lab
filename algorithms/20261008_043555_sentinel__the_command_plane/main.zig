const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());

    const allocator = &gpa.allocator;

    // Test 1: basic addition and execution order
    {
        var plane = try core.CommandPlane.init(allocator);
        defer plane.deinit();

        var counter: usize = 0;

        const inc_by_one: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 1;
            }
        }.f;

        const inc_by_two: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 2;
            }
        }.f;

        const inc_by_three: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 3;
            }
        }.f;

        try plane.add(inc_by_one, &counter);
        try plane.add(inc_by_two, &counter);
        try plane.add(inc_by_three, &counter);

        std.debug.assert(plane.count() == 3);
        plane.executeAll();
        std.debug.assert(counter == 6);
    }

    // Test 2: re‑execution without re‑adding
    {
        var plane = try core.CommandPlane.init(allocator);
        defer plane.deinit();

        var counter: usize = 0;

        const inc: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 1;
            }
        }.f;

        try plane.add(inc, &counter);
        std.debug.assert(plane.count() == 1);
        plane.executeAll();
        std.debug.assert(counter == 1);
        // Execute again; should increment again
        plane.executeAll();
        std.debug.assert(counter == 2);
    }

    // Test 3: adding after execution
    {
        var plane = try core.CommandPlane.init(allocator);
        defer plane.deinit();

        var counter: usize = 0;

        const inc_one: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 1;
            }
        }.f;

        const inc_five: core.Command = struct {
            fn f(ctx: *anyopaque) void {
                const p = @ptrCast(*usize, ctx);
                p.* += 5;
            }
        }.f;

        try plane.add(inc_one, &counter);
        plane.executeAll();
        std.debug.assert(counter == 1);

        try plane.add(inc_five, &counter);
        std.debug.assert(plane.count() == 2);
        plane.executeAll();
        // Should run inc_one then inc_five again
        std.debug.assert(counter == 1 + 1 + 5);
    }

    // Test 4: ensure sentinel never executes a command
    {
        var plane = try core.CommandPlane.init(allocator);
        defer plane.deinit();

        var executed = false;

        const set_true: core.Command = struct {
            fn f(_: *anyopaque) void {
                executed = true;
            }
        }.f;

        // No commands added; executeAll should do nothing.
        plane.executeAll();
        std.debug.assert(!executed);
    }

    // All tests passed
    std.debug.print("All Sentinel CommandPlane tests passed.\n", .{});
}
