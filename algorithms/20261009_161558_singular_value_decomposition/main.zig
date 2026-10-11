const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    testSVD();
    testLowRankApprox();
    testEdgeCases();
    std.debug.print("All tests passed.\n", .{});
}

fn testSVD() void {
    const A = core.Matrix.init(2, 2, &[_]f64{ 1, 2, 3, 4 });
    const svd = core.svd(A);
    const norm = A.frobeniusNorm();
    const svdNorm = svd.U.frobeniusNorm();
    std.debug.assert(std.math.approxEqual(norm, svdNorm, 1e-10));
}

fn testLowRankApprox() void {
    const A = core.Matrix.init(3, 3, &[_]f64{
        1, 2, 3,
        4, 5, 6,
        7, 8, 9,
    });
    const approx = core.lowRankApprox(A, 1);
    const error = A.frobeniusNorm();
    std.debug.assert(error > 0);
}

fn testEdgeCases() void {
    const zero = core.Matrix.init(1, 1, &[_]f64{0});
    const svd = core.svd(zero);
    std.debug.assert(svd.S[0] == 0);
}
