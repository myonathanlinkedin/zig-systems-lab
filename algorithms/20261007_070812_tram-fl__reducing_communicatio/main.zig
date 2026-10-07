const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Test 1: Basic Server Initialization
    {
        const model = core.Model.new("base_model", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        std.debug.assert(server.epoch == 0);
        std.debug.assert(server.total_cost == 0);
        std.debug.assert(server.global_model.name.len == 10);
        std.debug.assert(server.global_model.size == 1000);
        std.debug.assert(server.global_model.accuracy == 0.85);
        std.debug.assert(server.getActiveClientCount() == 0);
    }

    // Test 2: Add and Remove Clients
    {
        const model = core.Model.new("base_model", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        const client1 = core.Client.new(1, core.Model.new("client1_model", 500, 30, 0.80), 1000);
        const client2 = core.Client.new(2, core.Model.new("client2_model", 800, 40, 0.82), 2000);

        try server.addClient(client1);
        try server.addClient(client2);

        std.debug.assert(server.clients.items.len == 2);
        std.debug.assert(server.getActiveClientCount() == 2);

        const removed = server.removeClient(1);
        std.debug.assert(removed == true);
        std.debug.assert(server.clients.items.len == 1);
        std.debug.assert(server.getActiveClientCount() == 1);

        const not_found = server.removeClient(999);
        std.debug.assert(not_found == false);
    }

    // Test 3: Training Epoch Cost Calculation
    {
        const model = core.Model.new("base_model", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        const client1 = core.Client.new(1, core.Model.new("c1", 500, 30, 0.80), 1000);
        const client2 = core.Client.new(2, core.Model.new("c2", 800, 40, 0.82), 2000);

        try server.addClient(client1);
        try server.addClient(client2);

        try server.trainEpoch();

        std.debug.assert(server.epoch == 1);
        std.debug.assert(server.total_cost > 0);

        const breakdown = server.getCostBreakdown();
        std.debug.assert(breakdown.total == breakdown.comm + breakdown.compute);
        std.debug.assert(breakdown.comm > 0);
        std.debug.assert(breakdown.compute > 0);
    }

    // Test 4: Multiple Epochs
    {
        const model = core.Model.new("base_model", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        const client = core.Client.new(1, core.Model.new("c1", 500, 30, 0.80), 1000);
        try server.addClient(client);

        const cost_after_1 = server.total_cost;
        try server.trainEpoch();
        std.debug.assert(server.epoch == 1);
        std.debug.assert(server.total_cost >= cost_after_1);

        const cost_after_2 = server.total_cost;
        try server.trainEpoch();
        std.debug.assert(server.epoch == 2);
        std.debug.assert(server.total_cost >= cost_after_2);
    }

    // Test 5: Inactive Client Exclusion
    {
        const model = core.Model.new("base_model", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        var client1 = core.Client.new(1, core.Model.new("c1", 500, 30, 0.80), 1000);
        var client2 = core.Client.new(2, core.Model.new("c2", 800, 40, 0.82), 2000);
        client2.is_active = false;

        try server.addClient(client1);
        try server.addClient(client2);

        std.debug.assert(server.getActiveClientCount() == 1);

        try server.trainEpoch();
        std.debug.assert(server.epoch == 1);
        std.debug.assert(server.total_cost > 0);
    }

    // Test 6: Model Properties
    {
        const m1 = core.Model.new("small", 100, 10, 0.70);
        const m2 = core.Model.new("large", 5000, 200, 0.95);

        std.debug.assert(m1.size < m2.size);
        std.debug.assert(m1.latency < m2.latency);
        std.debug.assert(m1.accuracy < m2.accuracy);
        std.debug.assert(std.mem.eql(u8, m1.name, "small"));
        std.debug.assert(std.mem.eql(u8, m2.name, "large"));
    }

    // Test 7: Client Properties
    {
        const model = core.Model.new("test", 100, 10, 0.75);
        const client = core.Client.new(42, model, 5000);

        std.debug.assert(client.id == 42);
        std.debug.assert(client.data_size == 5000);
        std.debug.assert(client.is_active == true);
        std.debug.assert(client.compute_cost == 0);
        std.debug.assert(client.comm_cost == 0);
        std.debug.assert(client.total_cost == 0);
    }

    // Test 8: Edge Case - Empty Server Training
    {
        const model = core.Model.new("base", 100, 10, 0.70);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        try server.trainEpoch();
        std.debug.assert(server.epoch == 1);
        std.debug.assert(server.total_cost == 0);
    }

    // Test 9: Cost Monotonicity
    {
        const model = core.Model.new("base", 1000, 50, 0.85);
        var server = try core.Server.init(alloc, model);
        defer server.deinit();

        const client = core.Client.new(1, core.Model.new("c", 500, 30, 0.80), 1000);
        try server.addClient(client);

        var prev_cost: u32 = 0;
        for (0..5) |_| {
            try server.trainEpoch();
            std.debug.assert(server.total_cost >= prev_cost);
            prev_cost = server.total_cost;
        }
    }

    std.debug.print("All Tram-FL tests passed.\n", .{});
}
