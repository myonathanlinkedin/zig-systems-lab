const std = @import("std");

pub const Model = struct {
    name: []const u8,
    size: u32,
    latency: u32,
    accuracy: f64,

    pub fn new(name: []const u8, size: u32, latency: u32, accuracy: f64) Model {
        return .{ .name = name, .size = size, .latency = latency, .accuracy = accuracy };
    }
};

pub const Client = struct {
    id: u32,
    local_model: Model,
    data_size: u32,
    compute_cost: u32,
    comm_cost: u32,
    total_cost: u32,
    is_active: bool,

    pub fn new(id: u32, model: Model, data_size: u32) Client {
        return .{
            .id = id,
            .local_model = model,
            .data_size = data_size,
            .compute_cost = 0,
            .comm_cost = 0,
            .total_cost = 0,
            .is_active = true,
        };
    }
};

pub const Server = struct {
    global_model: Model,
    clients: std.ArrayList(Client),
    total_comm_cost: u32,
    total_compute_cost: u32,
    total_cost: u32,
    epoch: u32,

    pub fn init(allocator: std.mem.Allocator, global_model: Model) !Server {
        return .{
            .global_model = global_model,
            .clients = std.ArrayList(Client).init(allocator),
            .total_comm_cost = 0,
            .total_compute_cost = 0,
            .total_cost = 0,
            .epoch = 0,
        };
    }

    pub fn deinit(self: *Server) void {
        self.clients.deinit();
    }

    pub fn addClient(self: *Server, client: Client) !void {
        try self.clients.append(client);
    }

    pub fn removeClient(self: *Server, id: u32) bool {
        for (self.clients.items, 0..) |*c, i| {
            if (c.id == id) {
                self.clients.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn trainEpoch(self: *Server) !void {
        self.epoch += 1;
        var epoch_comm: u32 = 0;
        var epoch_compute: u32 = 0;

        for (self.clients.items) |*client| {
            if (!client.is_active) continue;

            // Simulate local training: compute cost proportional to data size and model size
            client.compute_cost = @intCast(client.data_size * client.local_model.size / 1000);
            epoch_compute += client.compute_cost;

            // Simulate communication: upload local model, download global model
            // In Tram-FL, sequential model reduces communication by only sending deltas
            const delta_size = @min(client.local_model.size, 100);
            client.comm_cost = delta_size + self.global_model.size;
            epoch_comm += client.comm_cost;
        }

        self.total_comm_cost += epoch_comm;
        self.total_compute_cost += epoch_compute;
        self.total_cost = self.total_comm_cost + self.total_compute_cost;

        // Update global model (simulated aggregation)
        self.global_model.latency = @intCast(self.global_model.latency / 2 + 1);
    }

    pub fn getCostBreakdown(self: *const Server) struct { comm: u32, compute: u32, total: u32 } {
        return .{
            .comm = self.total_comm_cost,
            .compute = self.total_compute_cost,
            .total = self.total_cost,
        };
    }

    pub fn getActiveClientCount(self: *const Server) u32 {
        var count: u32 = 0;
        for (self.clients.items) |c| {
            if (c.is_active) count += 1;
        }
        return count;
    }
};
