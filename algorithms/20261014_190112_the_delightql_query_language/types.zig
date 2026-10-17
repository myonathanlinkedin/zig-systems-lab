const std = @import("std");

pub const Value = union(enum) {
    Int: i64,
    Str: []const u8,

    pub fn eql(self: Value, other: Value) bool {
        return switch (self) {
            .Int => |a| switch (other) {
                .Int => |b| a == b,
                else => false,
            },
            .Str => |a| switch (other) {
                .Str => |b| std.mem.eql(u8, a, b),
                else => false,
            },
        };
    }
};

pub const Row = struct {
    values: []Value,
};

pub const Table = struct {
    name: []const u8,
    columns: []const []const u8,
    rows: []Row,
};

pub const Condition = struct {
    column: []const u8,
    value: Value,
};

pub const Select = struct {
    // null columns means SELECT *
    columns: ?[]const []const u8,
    table: []const u8,
    where: ?Condition,
};

pub const Result = struct {
    columns: []const []const u8,
    rows: []Row,
};
