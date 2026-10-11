const std = @import("std");

pub const CowVec = struct {
    allocator: *std.mem.Allocator,
    buffer: *Buffer,
    len: usize,

    const Buffer = struct {
        refCount: usize,
        data: []u8,

        pub fn new(allocator: *std.mem.Allocator, capacity: usize) !*Buffer {
            const buf = try allocator.create(Buffer);
            buf.* = Buffer{
                .refCount = 1,
                .data = try allocator.alloc(u8, capacity),
            };
            return buf;
        }

        pub fn incRef(self: *Buffer) void {
            self.refCount += 1;
        }

        pub fn decRef(self: *Buffer, allocator: *std.mem.Allocator) void {
            self.refCount -= 1;
            if (self.refCount == 0) {
                allocator.free(self.data);
                allocator.destroy(self);
            }
        }
    };

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !CowVec {
        const buf = try Buffer.new(allocator, capacity);
        return CowVec{
            .allocator = allocator,
            .buffer = buf,
            .len = 0,
        };
    }

    pub fn clone(self: CowVec) CowVec {
        self.buffer.incRef();
        return CowVec{
            .allocator = self.allocator,
            .buffer = self.buffer,
            .len = self.len,
        };
    }

    fn ensureUnique(self: *CowVec) !void {
        if (self.buffer.refCount > 1) {
            const new_buf = try Buffer.new(self.allocator, self.buffer.data.len);
            @memcpy(new_buf.data[0..self.len], self.buffer.data[0..self.len]);
            self.buffer.decRef(self.allocator);
            self.buffer = new_buf;
        }
    }

    pub fn push(self: *CowVec, value: u8) !void {
        if (self.len == self.buffer.data.len) {
            try self.grow();
        }
        try self.ensureUnique();
        self.buffer.data[self.len] = value;
        self.len += 1;
    }

    fn grow(self: *CowVec) !void {
        const new_cap = if (self.buffer.data.len == 0) 1 else self.buffer.data.len * 2;
        const new_buf = try Buffer.new(self.allocator, new_cap);
        @memcpy(new_buf.data[0..self.len], self.buffer.data[0..self.len]);
        self.buffer.decRef(self.allocator);
        self.buffer = new_buf;
    }

    pub fn pop(self: *CowVec) ?u8 {
        if (self.len == 0) return null;
        try self.ensureUnique();
        self.len -= 1;
        return self.buffer.data[self.len];
    }

    pub fn get(self: CowVec, index: usize) u8 {
        std.debug.assert(index < self.len);
        return self.buffer.data[index];
    }

    pub fn set(self: *CowVec, index: usize, value: u8) !void {
        std.debug.assert(index < self.len);
        try self.ensureUnique();
        self.buffer.data[index] = value;
    }

    pub fn len(self: CowVec) usize {
        return self.len;
    }

    pub fn capacity(self: CowVec) usize {
        return self.buffer.data.len;
    }

    pub fn deinit(self: *CowVec) void {
        self.buffer.decRef(self.allocator);
        self.* = undefined;
    }
};
