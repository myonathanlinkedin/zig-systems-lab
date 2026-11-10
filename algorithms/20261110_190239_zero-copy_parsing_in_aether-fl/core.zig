const std = @import("std");

pub const ParseError = error{
    UnexpectedEof,
    PredicateFailed,
    InvalidDigit,
};

pub fn Result(comptime T: type) type {
    return struct {
        value: T,
        rest: []const u8,
        err: ?ParseError,
    };
}

// ---------- Primitive parsers ----------
pub fn take(comptime n: usize) fn (input: []const u8) Result([]const u8) {
    return struct {
        pub fn parse(input: []const u8) Result([]const u8) {
            if (input.len < n) {
                return .{ .value = undefined, .rest = input, .err = ParseError.UnexpectedEof };
            }
            return .{
                .value = input[0..n],
                .rest = input[n..],
                .err = null,
            };
        }
    }.parse;
}

pub fn takeWhile(comptime predicate: fn (u8) bool) fn (input: []const u8) Result([]const u8) {
    return struct {
        pub fn parse(input: []const u8) Result([]const u8) {
            var i: usize = 0;
            while (i < input.len and predicate(input[i])) : (i += 1) {}
            return .{
                .value = input[0..i],
                .rest = input[i..],
                .err = null,
            };
        }
    }.parse;
}

// ---------- Combinators ----------
pub fn map(
    comptime InT: type,
    comptime OutT: type,
    comptime parser: fn ([]const u8) Result(InT),
    comptime mapper: fn (InT) OutT,
) fn (input: []const u8) Result(OutT) {
    return struct {
        pub fn parse(input: []const u8) Result(OutT) {
            const res = parser(input);
            if (res.err) |e| {
                return .{ .value = undefined, .rest = res.rest, .err = e };
            }
            return .{
                .value = mapper(res.value),
                .rest = res.rest,
                .err = null,
            };
        }
    }.parse;
}

pub fn andThen(
    comptime A: type,
    comptime B: type,
    comptime first: fn ([]const u8) Result(A),
    comptime second: fn ([]const u8) Result(B),
) fn (input: []const u8) Result(B) {
    return struct {
        pub fn parse(input: []const u8) Result(B) {
            const r1 = first(input);
            if (r1.err) |e| {
                return .{ .value = undefined, .rest = r1.rest, .err = e };
            }
            const r2 = second(r1.rest);
            if (r2.err) |e| {
                return .{ .value = undefined, .rest = r2.rest, .err = e };
            }
            return r2;
        }
    }.parse;
}

// ---------- Helper predicates ----------
pub fn isDigit(b: u8) bool {
    return b >= '0' and b <= '9';
}

// ---------- Example parser: unsigned integer ----------
pub fn parseUint(input: []const u8) Result(u64) {
    const digitSlice = takeWhile(isDigit)(input);
    if (digitSlice.value.len == 0) {
        return .{ .value = undefined, .rest = input, .err = ParseError.InvalidDigit };
    }
    var acc: u64 = 0;
    for (digitSlice.value) |c| {
        const digit = @intFromChar(c) - @intFromChar('0');
        // overflow check (simple, safe for demonstration)
        if (acc > (std.math.maxInt(u64) - digit) / 10) {
            return .{ .value = undefined, .rest = digitSlice.rest, .err = ParseError.InvalidDigit };
        }
        acc = acc * 10 + digit;
    }
    return .{
        .value = acc,
        .rest = digitSlice.rest,
        .err = null,
    };
}

// ---------- Exported symbols ----------
pub const parsers = struct {
    pub const take = take;
    pub const takeWhile = takeWhile;
    pub const map = map;
    pub const andThen = andThen;
    pub const parseUint = parseUint;
};
