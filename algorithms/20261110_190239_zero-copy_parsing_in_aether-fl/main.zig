const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    test_take();
    test_take_while();
    test_parse_uint_success();
    test_parse_uint_failure();
    std.debug.print("All zero‑copy parser tests passed.\n", .{});
}

// ---------- Test helpers ----------
fn assertResultOk(comptime T: type, res: core.Result(T), expectedValue: T, expectedRest: []const u8) void {
    std.debug.assert(res.err == null);
    std.debug.assert(res.value == expectedValue);
    std.debug.assert(res.rest.ptr == expectedRest.ptr and res.rest.len == expectedRest.len);
}

fn assertResultErr(comptime T: type, res: core.Result(T), expectedErr: anytype) void {
    std.debug.assert(res.err != null);
    std.debug.assert(res.err.? == expectedErr);
}

// ---------- Unit tests ----------
fn test_take() void {
    const parser = core.parsers.take(3);
    const input = "abcdef";
    const res = parser(input);
    assertResultOk([]const u8, res, "abc", "def");
    const short = "ab";
    const res2 = parser(short);
    assertResultErr([]const u8, res2, core.ParseError.UnexpectedEof);
}

fn test_take_while() void {
    const isAlpha = fn (b: u8) bool { return (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z'); };
    const parser = core.parsers.takeWhile(isAlpha);
    const input = "Hello123World";
    const res = parser(input);
    assertResultOk([]const u8, res, "Hello", "123World");
    const allDigits = "12345";
    const res2 = parser(allDigits);
    assertResultOk([]const u8, res2, "", "12345");
}

fn test_parse_uint_success() void {
    const input = "42xyz";
    const res = core.parsers.parseUint(input);
    assertResultOk(u64, res, 42, "xyz");
    const big = "18446744073709551615END"; // max u64
    const res2 = core.parsers.parseUint(big);
    assertResultOk(u64, res2, std.math.maxInt(u64), "END");
}

fn test_parse_uint_failure() void {
    const empty = "";
    const res = core.parsers.parseUint(empty);
    assertResultErr(u64, res, core.ParseError.InvalidDigit);
    const noDigits = "abc123";
    const res2 = core.parsers.parseUint(noDigits);
    assertResultErr(u64, res2, core.ParseError.InvalidDigit);
    const overflow = "18446744073709551616X"; // max+1
    const res3 = core.parsers.parseUint(overflow);
    assertResultErr(u64, res3, core.ParseError.InvalidDigit);
}
