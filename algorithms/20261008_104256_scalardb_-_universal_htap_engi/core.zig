const std = @import("std");

pub const TransactionType = enum {
    read,
    write,
    delete,
};

pub const TransactionStatus = enum {
    pending,
    committed,
    aborted,
};

pub const Transaction = struct {
    id: u64,
    type: TransactionType,
    key: []const u8,
    value: ?[]const u8,
    status: TransactionStatus,
    timestamp: u64,
};

pub const ScalardbEngine = struct {
    const Self = @This();

    data_store: std.StringHashMap(u64),
    transaction_log: std.ArrayList(Transaction),
    next_txn_id: u64,
    current_timestamp: u64,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data_store = std.StringHashMap(u64).init(allocator),
            .transaction_log = std.ArrayList(Transaction).init(allocator),
            .next_txn_id = 1,
            .current_timestamp = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.data_store.deinit();
        self.transaction_log.deinit();
    }

    pub fn advanceClock(self: *Self) void {
        self.current_timestamp += 1;
    }

    pub fn executeTransaction(self: *Self, txn_type: TransactionType, key: []const u8, value: ?[]const u8) !Transaction {
        const txn = Transaction{
            .id = self.next_txn_id,
            .type = txn_type,
            .key = key,
            .value = value,
            .status = .pending,
            .timestamp = self.current_timestamp,
        };

        self.next_txn_id += 1;
        self.advanceClock();

        try self.transaction_log.append(txn);

        switch (txn_type) {
            .read => {
                if (self.data_store.get(key)) |val| {
                    _ = val;
                }
            },
            .write => {
                if (value) |v| {
                    try self.data_store.put(key, v[0]);
                }
            },
            .delete => {
                _ = self.data_store.remove(key);
            },
        }

        const idx = self.transaction_log.items.len - 1;
        self.transaction_log.items[idx].status = .committed;
        return self.transaction_log.items[idx];
    }

    pub fn get(self: *const Self, key: []const u8) ?u64 {
        return self.data_store.get(key);
    }

    pub fn getTransactionLog(self: *const Self) []const Transaction {
        return self.transaction_log.items;
    }

    pub fn getTransactionCount(self: *const Self) usize {
        return self.transaction_log.items.len;
    }
};
