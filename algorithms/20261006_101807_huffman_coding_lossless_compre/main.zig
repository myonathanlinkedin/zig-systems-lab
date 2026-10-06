const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    // Test 1: typical string
    const text = "this is an example for huffman encoding";
    const compressed = try core.compress(allocator, text);
    const decompressed = try core.decompress(allocator, compressed);
    std.debug.assert(std.mem.eql(u8, text, decompressed));

    // Test 2: empty input
    const empty: []const u8 = "";
    const comp_empty = try core.compress(allocator, empty);
    const decomp_empty = try core.decompress(allocator, comp_empty);
    std.debug.assert(decomp_empty.len == 0);

    // Test 3: single repeated character
    const repeated = "aaaaaaaaaaaaaa";
    const comp_rep = try core.compress(allocator, repeated);
    const decomp_rep = try core.decompress(allocator, comp_rep);
    std.debug.assert(std.mem.eql(u8, repeated, decomp_rep));

    // Test 4: all possible byte values (small size)
    var all: [256]u8 = undefined;
    var idx: usize = 0;
    while (idx < 256) : (idx += 1) {
        all[idx] = @intCast(u8, idx);
    }
    const comp_all = try core.compress(allocator, all[0..256]);
    const decomp_all = try core.decompress(allocator, comp_all);
    std.debug.assert(std.mem.eql(u8, all[0..256], decomp_all));

    // Simple benchmark (not required to be precise)
    const data = try std.mem.concat(allocator, u8, &.{ text, text, text, text, text });
    const start = std.time.milliTimestamp();
    const comp = try core.compress(allocator, data);
    const _ = try core.decompress(allocator, comp);
    const elapsed = std.time.milliTimestamp() - start;
    std.debug.print("Compression+Decompression of {} bytes took {} ms\n", .{ data.len, elapsed });
}
