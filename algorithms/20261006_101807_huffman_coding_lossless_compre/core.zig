const std = @import("std");

pub const Symbol = u8;

pub const Code = struct {
    bits: u64,
    len: u8,
};

fn Node(comptime T: type) type {
    return struct {
        symbol: ?Symbol,
        left: ?*Node(T),
        right: ?*Node(T),
        freq: usize,
    };
}

fn buildFreqTable(data: []const u8) [256]usize {
    var freq: [256]usize = [_]usize{0} ** 256;
    for (data) |b| {
        freq[b] +%= 1;
    }
    return freq;
}

fn buildTree(allocator: *std.mem.Allocator, freq: [256]usize) ?*Node(void) {
    var nodes = std.ArrayList(*Node(void)).init(allocator);
    defer nodes.deinit();

    for (freq) |f, i| {
        if (f > 0) {
            const n = allocator.create(Node(void)) catch return null;
            n.* = .{
                .symbol = @intCast(Symbol, i),
                .left = null,
                .right = null,
                .freq = f,
            };
            nodes.append(n) catch return null;
        }
    }

    if (nodes.items.len == 0) return null;
    while (nodes.items.len > 1) {
        // simple selection sort for two smallest
        std.sort.sort(*Node(void), nodes.items, {}, struct {
            fn less(_: void, a: *Node(void), b: *Node(void)) bool {
                return a.freq < b.freq;
            }
        }.less);
        const left = nodes.pop();
        const right = nodes.pop();
        const parent = allocator.create(Node(void)) catch return null;
        parent.* = .{
            .symbol = null,
            .left = left,
            .right = right,
            .freq = left.freq + right.freq,
        };
        nodes.append(parent) catch return null;
    }
    return nodes.pop();
}

fn generateCodes(node: ?*Node(void), prefix: u64, plen: u8, codes: *[256]Code) void {
    if (node) |n| {
        if (n.symbol) |sym| {
            codes[sym] = .{ .bits = prefix, .len = plen };
        } else {
            // left -> add 0 bit
            generateCodes(n.left, prefix << 1, plen + 1, codes);
            // right -> add 1 bit
            generateCodes(n.right, (prefix << 1) | 1, plen + 1, codes);
        }
    }
}

fn writeBits(buf: *std.ArrayList(u8), bit_buf: *u8, bit_cnt: *u8, bits: u64, len: u8) void {
    var remaining = len;
    var src = bits;
    while (remaining > 0) {
        const take = @min(8 - bit_cnt.*, remaining);
        const shift = remaining - take;
        const chunk = @intCast(u8, (src >> shift) & ((1 << take) - 1));
        bit_buf.* = (bit_buf.* << @intCast(u8, take)) | chunk;
        bit_cnt.* += @intCast(u8, take);
        remaining -= take;
        if (bit_cnt.* == 8) {
            buf.append(bit_buf.*) catch {};
            bit_buf.* = 0;
            bit_cnt.* = 0;
        }
    }
}

fn flushBits(buf: *std.ArrayList(u8), bit_buf: u8, bit_cnt: u8) void {
    if (bit_cnt > 0) {
        const padded = bit_buf << (8 - bit_cnt);
        buf.append(padded) catch {};
    }
}

pub fn compress(allocator: *std.mem.Allocator, data: []const u8) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    const freq = buildFreqTable(data);
    // write frequencies as u32 little endian
    for (freq) |f| {
        var v = @intCast(u32, f);
        out.appendSlice(&.{ @intCast(u8, v & 0xFF), @intCast(u8, (v >> 8) & 0xFF), @intCast(u8, (v >> 16) & 0xFF), @intCast(u8, (v >> 24) & 0xFF) }) catch {};
    }

    const root = buildTree(allocator, freq) orelse {
        // empty input
        return out.toOwnedSlice();
    };

    var codes: [256]Code = undefined;
    for (codes) |*c| c.* = .{ .bits = 0, .len = 0 };
    generateCodes(root, 0, 0, &codes);

    var bit_buf: u8 = 0;
    var bit_cnt: u8 = 0;
    for (data) |b| {
        const c = codes[b];
        writeBits(&out, &bit_buf, &bit_cnt, c.bits, c.len);
    }
    flushBits(&out, bit_buf, bit_cnt);
    return out.toOwnedSlice();
}

fn readU32Le(slice: []const u8, idx: usize) u32 {
    return @intCast(u32, slice[idx]) |
        (@intCast(u32, slice[idx + 1]) << 8) |
        (@intCast(u32, slice[idx + 2]) << 16) |
        (@intCast(u32, slice[idx + 3]) << 24);
}

pub fn decompress(allocator: *std.mem.Allocator, comp: []const u8) ![]u8 {
    if (comp.len < 1024) return error.InvalidFormat;
    var freq: [256]usize = undefined;
    var sum: usize = 0;
    var i: usize = 0;
    while (i < 256) : (i += 1) {
        const f = readU32Le(comp, i * 4);
        freq[i] = @intCast(usize, f);
        sum += freq[i];
    }
    const data_start = 1024;
    const root = buildTree(allocator, freq) orelse {
        // empty original data
        return allocator.alloc(u8, 0);
    };
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var node = root;
    var bit_idx: usize = data_start * 8;
    var total_bits = (comp.len - data_start) * 8;
    var decoded: usize = 0;
    while (decoded < sum and bit_idx < total_bits) {
        const byte_pos = bit_idx / 8;
        const bit_off = @intCast(u3, bit_idx % 8);
        const cur_byte = comp[byte_pos];
        const bit = (cur_byte >> (7 - bit_off)) & 1;
        node = if (bit == 0) node.left.? else node.right.?;
        if (node.symbol) |sym| {
            out.append(sym) catch {};
            node = root;
            decoded += 1;
        }
        bit_idx += 1;
    }
    return out.toOwnedSlice();
}
