const std = @import("std");

pub const OpCode = enum {
    PushConst,
    Add,
    Sub,
    Mul,
    Div,
    Halt,
};

pub const Instruction = struct {
    opcode: OpCode,
    operand: i64 = 0, // only used for PushConst
};

pub const CompileError = error{
    UnexpectedChar,
    MismatchedParen,
    EmptyInput,
};

fn isSpace(c: u8) bool {
    return c == ' ' or c == '\t' or c == '\n' or c == '\r';
}
fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

// ---------- Shunting‑Yard ----------
pub fn compile(expr: []const u8, allocator: *std.mem.Allocator) CompileError![]Instruction {
    var output = std.ArrayList(Instruction).init(allocator);
    defer if (output.deinit()) {} // keep for error path

    var opStack = std.ArrayList(OpCode).init(allocator);
    defer if (opStack.deinit()) {} // keep for error path

    var i: usize = 0;
    while (i < expr.len) : (i += 1) {
        const c = expr[i];
        if (isSpace(c)) continue;

        if (isDigit(c)) {
            var num: i64 = 0;
            while (i < expr.len and isDigit(expr[i])) : (i += 1) {
                num = num * 10 + @intCast(i64, expr[i] - '0');
            }
            i -= 1; // step back for outer loop increment
            try output.append(Instruction{ .opcode = .PushConst, .operand = num });
        } else switch (c) {
            '+' => try pushOp(.Add, &opStack, &output),
            '-' => try pushOp(.Sub, &opStack, &output),
            '*' => try pushOp(.Mul, &opStack, &output),
            '/' => try pushOp(.Div, &opStack, &output),
            '(' => try opStack.append(.Halt), // sentinel for '('
            ')' => {
                var found = false;
                while (opStack.items.len > 0) {
                    const top = opStack.pop();
                    if (top == .Halt) {
                        found = true;
                        break;
                    } else {
                        try output.append(Instruction{ .opcode = top });
                    }
                }
                if (!found) return CompileError.MismatchedParen;
            },
            else => return CompileError.UnexpectedChar,
        }
    }

    while (opStack.items.len > 0) {
        const top = opStack.pop();
        if (top == .Halt) return CompileError.MismatchedParen;
        try output.append(Instruction{ .opcode = top });
    }

    try output.append(Instruction{ .opcode = .Halt });
    return output.toOwnedSlice();
}

fn precedence(op: OpCode) u8 {
    return switch (op) {
        .Add, .Sub => 1,
        .Mul, .Div => 2,
        else => 0,
    };
}

fn pushOp(op: OpCode, opStack: *std.ArrayList(OpCode), output: *std.ArrayList(Instruction)) !void {
    while (opStack.items.len > 0) {
        const top = opStack.items[opStack.items.len - 1];
        if (top == .Halt) break;
        if (precedence(top) >= precedence(op)) {
            _ = opStack.pop();
            try output.append(Instruction{ .opcode = top });
        } else break;
    }
    try opStack.append(op);
}

// ---------- Interpreter ----------
pub const RuntimeError = error{
    DivisionByZero,
    StackUnderflow,
};

pub fn interpret(instructions: []const Instruction) RuntimeError!i64 {
    var stack = std.ArrayList(i64).init(std.heap.page_allocator);
    defer stack.deinit();

    var pc: usize = 0;
    while (pc < instructions.len) : (pc += 1) {
        const ins = instructions[pc];
        switch (ins.opcode) {
            .PushConst => try stack.append(ins.operand),
            .Add => {
                const b = try pop(&stack);
                const a = try pop(&stack);
                try stack.append(a + b);
            },
            .Sub => {
                const b = try pop(&stack);
                const a = try pop(&stack);
                try stack.append(a - b);
            },
            .Mul => {
                const b = try pop(&stack);
                const a = try stack.pop();
                try stack.append(a * b);
            },
            .Div => {
                const b = try pop(&stack);
                if (b == 0) return RuntimeError.DivisionByZero;
                const a = try pop(&stack);
                try stack.append(a / b);
            },
            .Halt => break,
        }
    }
    if (stack.items.len != 1) return RuntimeError.StackUnderflow;
    return stack.items[0];
}

fn pop(stack: *std.ArrayList(i64)) RuntimeError!i64 {
    if (stack.items.len == 0) return RuntimeError.StackUnderflow;
    const val = stack.pop();
    return val;
}

// ---------- Kernel ----------
pub const KernelError = error{
    HangDetected,
};

pub const TaskFn = fn (ctx: *anyopaque) bool; // return true if still alive

pub const Task = struct {
    ctx: *anyopaque,
    func: TaskFn,
};

pub fn runKernel(tasks: []Task, maxSteps: usize) KernelError!void {
    var alive = std.ArrayList(bool).init(std.heap.page_allocator);
    defer alive.deinit();
    try alive.resize(tasks.len);
    for (alive.items) |*b| b.* = true;

    var step: usize = 0;
    while (step < maxSteps) : (step += 1) {
        var anyAlive = false;
        for (tasks, 0..) |t, idx| {
            if (!alive.items[idx]) continue;
            const still = t.func(t.ctx);
            alive.items[idx] = still;
            anyAlive = anyAlive or still;
        }
        if (!anyAlive) return;
    }
    return KernelError.HangDetected;
}
);
