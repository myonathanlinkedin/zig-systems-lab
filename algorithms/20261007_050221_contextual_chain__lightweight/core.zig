const std = @import("std");

pub const ContextualChain = struct {
    const Self = @This();

    const Entry = struct {
        context: []const u8,
        hash: [32]u8,
    };

    entries: std.ArrayList(Entry),

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .entries = std.ArrayList(Entry).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.entries.deinit();
    }

    /// Compute a SHA‑256 hash over (prev_hash || context || secret).
    pub fn computeHash(prev_hash: []const u8, context: []const u8, secret: []const u8) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init();
        hasher.update(prev_hash);
        hasher.update(context);
        hasher.update(secret);
        return hasher.finalResult();
    }

    pub fn addEntry(self: *Self, context: []const u8, secret: []const u8) !void {
        const prev_hash_slice = if (self.entries.items.len == 0)
            &([_]u8{0} ** 32)
        else
            &self.entries.items[self.entries.items.len - 1].hash;

        const hash = computeHash(prev_hash_slice, context, secret);
        try self.entries.append(Entry{
            .context = context,
            .hash = hash,
        });
    }

    /// Verify the entire chain using the supplied secret.
    pub fn verify(self: *Self, secret: []const u8) bool {
        var prev_hash: [32]u8 = [_]u8{0} ** 32;
        for (self.entries.items) |entry| {
            const expected = computeHash(&prev_hash, entry.context, secret);
            if (!std.mem.eql(u8, &expected, &entry.hash)) {
                return false;
            }
            prev_hash = entry.hash;
        }
        return true;
    }

    /// Return the hash of the last entry, or null if the chain is empty.
    pub fn lastHash(self: *Self) ?[32]u8 {
        if (self.entries.items.len == 0) return null;
        return self.entries.items[self.entries.items.len - 1].hash;
    }
};
