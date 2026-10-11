const std = @import("std");

pub const SRWLOCK = ?*anyopaque;
pub const CONDITION_VARIABLE = ?*anyopaque;

pub extern "kernel32" fn InitializeSRWLock(SRWLock: *SRWLOCK) callconv(.winapi) void;
pub extern "kernel32" fn AcquireSRWLockExclusive(SRWLock: *SRWLOCK) callconv(.winapi) void;
pub extern "kernel32" fn ReleaseSRWLockExclusive(SRWLock: *SRWLOCK) callconv(.winapi) void;
pub extern "kernel32" fn InitializeConditionVariable(ConditionVariable: *CONDITION_VARIABLE) callconv(.winapi) void;
pub extern "kernel32" fn SleepConditionVariableSRW(ConditionVariable: *CONDITION_VARIABLE, SRWLock: *SRWLOCK, dwMilliseconds: u32, Flags: u32) callconv(.winapi) c_int;
pub extern "kernel32" fn WakeConditionVariable(ConditionVariable: *CONDITION_VARIABLE) callconv(.winapi) void;
pub extern "kernel32" fn WakeAllConditionVariable(ConditionVariable: *CONDITION_VARIABLE) callconv(.winapi) void;

pub const QueueError = error{
    InvalidCapacity,
    OutOfMemory,
};

pub fn BoundedBlockingQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        buffer: []?T,
        capacity: usize,
        head: usize,
        tail: usize,
        size: usize,
        lock: SRWLOCK,
        not_empty: CONDITION_VARIABLE,
        not_full: CONDITION_VARIABLE,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, capacity: usize) QueueError!Self {
            if (capacity == 0) return error.InvalidCapacity;
            const buf = allocator.alloc(?T, capacity) catch return error.OutOfMemory;
            for (buf) |*slot| slot.* = null;

            var self = Self{
                .buffer = buf,
                .capacity = capacity,
                .head = 0,
                .tail = 0,
                .size = 0,
                .lock = null,
                .not_empty = null,
                .not_full = null,
                .allocator = allocator,
            };
            InitializeSRWLock(&self.lock);
            InitializeConditionVariable(&self.not_empty);
            InitializeConditionVariable(&self.not_full);
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.buffer);
        }

        pub fn enqueue(self: *Self, item: T) void {
            AcquireSRWLockExclusive(&self.lock);
            while (self.size == self.capacity) {
                _ = SleepConditionVariableSRW(&self.not_full, &self.lock, 0xFFFFFFFF, 0);
            }

            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % self.capacity;
            self.size += 1;

            WakeConditionVariable(&self.not_empty);
            ReleaseSRWLockExclusive(&self.lock);
        }

        pub fn dequeue(self: *Self) T {
            AcquireSRWLockExclusive(&self.lock);
            while (self.size == 0) {
                _ = SleepConditionVariableSRW(&self.not_empty, &self.lock, 0xFFFFFFFF, 0);
            }

            const opt = self.buffer[self.head];
            const result = opt.?;
            self.buffer[self.head] = null;
            self.head = (self.head + 1) % self.capacity;
            self.size -= 1;

            WakeConditionVariable(&self.not_full);
            ReleaseSRWLockExclusive(&self.lock);
            return result;
        }
    };
}
