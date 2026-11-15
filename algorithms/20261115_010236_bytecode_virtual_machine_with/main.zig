const std = @import("std");
const core = @import("core.zig");
const VM = core.VM;
const VMError = core.VMError;
const Opcode = core.Opcode;

fn encodePush(value: i32) []u8 {
    var buf: [5]u8 = undefined;
    buf[0] = @intFromEnum(Opcode.PUSH_I32);
    const bytes = @as([4]u8, @intToBytes(value));
    buf[1..5].* = bytes;
    return buf[0..];
}

fn encode(op: Opcode) []u8 {
    var buf: [1]u8 = undefined;
    buf[0] = @intFromEnum(op);
    return buf[0..];
}

pub fn main() !void {
    // Test 1: simple arithmetic 2 + 3 * 4 = 14
    {
        const program = &[_]u8{
            // push 2
            @intFromEnum(Opcode.PUSH_I32), 2, 0, 0, 0,
            // push 3
            @intFromEnum(Opcode.PUSH_I32), 3, 0, 0, 0,
            // push 4
            @intFromEnum(Opcode.PUSH_I32), 4, 0, 0, 0,
            // mul   (3 * 4)
            @intFromEnum(Opcode.MUL),
            // add   (2 + 12)
            @intFromEnum(Opcode.ADD),
            // halt
            @intFromEnum(Opcode.HALT),
        };
        var vm = VM.init(program);
        try vm.run();
        const stack = vm.stackSnapshot();
        std.debug.assert(stack.len == 1);
        std.debug.assert(stack[0] == 14);
    }

    // Test 2: division by zero detection
    {
        const program = &[_]u8{
            @intFromEnum(Opcode.PUSH_I32), 10, 0, 0, 0,
            @intFromEnum(Opcode.PUSH_I32), 0, 0, 0, 0,
            @intFromEnum(Opcode.DIV),
            @intFromEnum(Opcode.HALT),
        };
        var vm = VM.init(program);
        const err = vm.run() catch |e| e;
        std.debug.assert(err == VMError.DivisionByZero);
    }

    // Test 3: stack underflow on ADD
    {
        const program = &[_]u8{
            @intFromEnum(Opcode.PUSH_I32), 5, 0, 0, 0,
            @intFromEnum(Opcode.ADD),
            @intFromEnum(Opcode.HALT),
        };
        var vm = VM.init(program);
        const err = vm.run() catch |e| e;
        std.debug.assert(err == VMError.StackUnderflow);
    }

    // Test 4: DUP and SWAP
    {
        const program = &[_]u8{
            @intFromEnum(Opcode.PUSH_I32), 1, 0, 0, 0, // [1]
            @intFromEnum(Opcode.DUP),                // [1,1]
            @intFromEnum(Opcode.PUSH_I32), 2, 0, 0, 0, // [1,1,2]
            @intFromEnum(Opcode.SWAP),               // [1,2,1]
            @intFromEnum(Opcode.ADD),                // pop 1,2 -> push 3 => [1,3]
            @intFromEnum(Opcode.HALT),
        };
        var vm = VM.init(program);
        try vm.run();
        const stack = vm.stackSnapshot();
        std.debug.assert(stack.len == 2);
        std.debug.assert(stack[0] == 1);
        std.debug.assert(stack[1] == 3);
    }

    // Test 5: NEG operation
    {
        const program = &[_]u8{
            @intFromEnum(Opcode.PUSH_I32), 42, 0, 0, 0,
            @intFromEnum(Opcode.NEG),
            @intFromEnum(Opcode.HALT),
        };
        var vm = VM.init(program);
        try vm.run();
        const stack = vm.stackSnapshot();
        std.debug.assert(stack.len == 1);
        std.debug.assert(stack[0] == -42);
    }

    // All tests passed
    std.debug.print("All VM tests passed.\n", .{});
}
