const std = @import("std");

pub const VMError = error{
    StackUnderflow,
    StackOverflow,
    DivisionByZero,
    InvalidOpcode,
    UnexpectedEOF,
};

pub const Opcode = enum(u8) {
    // Stack manipulation
    PUSH_I32 = 0x01,
    POP      = 0x02,
    DUP      = 0x03,
    SWAP     = 0x04,
    // Arithmetic
    ADD      = 0x10,
    SUB      = 0x11,
    MUL      = 0x12,
    DIV      = 0x13,
    NEG      = 0x14,
    // Control
    HALT     = 0xFF,
};

pub const VM = struct {
    const StackSize = 1024;

    code: []const u8,
    ip: usize = 0,
    stack: [StackSize]i32 = undefined,
    sp: usize = 0, // points to next free slot

    pub fn init(code: []const u8) VM {
        return VM{
            .code = code,
        };
    }

    fn push(self: *VM, value: i32) VMError!void {
        if (self.sp >= StackSize) return VMError.StackOverflow;
        self.stack[self.sp] = value;
        self.sp += 1;
    }

    fn pop(self: *VM) VMError!i32 {
        if (self.sp == 0) return VMError.StackUnderflow;
        self.sp -= 1;
        return self.stack[self.sp];
    }

    fn peek(self: *VM) VMError!i32 {
        if (self.sp == 0) return VMError.StackUnderflow;
        return self.stack[self.sp - 1];
    }

    fn read_u8(self: *VM) VMError!u8 {
        if (self.ip >= self.code.len) return VMError.UnexpectedEOF;
        const b = self.code[self.ip];
        self.ip += 1;
        return b;
    }

    fn read_i32(self: *VM) VMError!i32 {
        // little‑endian 4‑byte integer
        if (self.ip + 4 > self.code.len) return VMError.UnexpectedEOF;
        const slice = self.code[self.ip .. self.ip + 4];
        self.ip += 4;
        return @as(i32, @intFromBytes(slice));
    }

    pub fn run(self: *VM) VMError!void {
        while (true) {
            const opcode_byte = try self.read_u8();
            const opcode = @intToEnum(Opcode, opcode_byte) catch return VMError.InvalidOpcode;
            switch (opcode) {
                .PUSH_I32 => {
                    const val = try self.read_i32();
                    try self.push(val);
                },
                .POP => {
                    _ = try self.pop();
                },
                .DUP => {
                    const val = try self.peek();
                    try self.push(val);
                },
                .SWAP => {
                    if (self.sp < 2) return VMError.StackUnderflow;
                    const a = self.stack[self.sp - 1];
                    const b = self.stack[self.sp - 2];
                    self.stack[self.sp - 1] = b;
                    self.stack[self.sp - 2] = a;
                },
                .ADD => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a + b);
                },
                .SUB => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a - b);
                },
                .MUL => {
                    const b = try self.pop();
                    const a = try self.pop();
                    try self.push(a * b);
                },
                .DIV => {
                    const b = try self.pop();
                    if (b == 0) return VMError.DivisionByZero;
                    const a = try self.pop();
                    try self.push(a / b);
                },
                .NEG => {
                    const a = try self.pop();
                    try self.push(-a);
                },
                .HALT => return,
            }
        }
    }

    /// Returns the current stack contents as a slice (top‑most element last).
    pub fn stackSnapshot(self: *VM) []i32 {
        return self.stack[0..self.sp];
    }
};
