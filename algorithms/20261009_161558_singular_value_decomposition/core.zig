const std = @import("std");

pub const Matrix = struct {
    rows: usize,
    cols: usize,
    data: []f64,

    pub fn init(rows: usize, cols: usize, data: []f64) Matrix {
        return .{ .rows = rows, .cols = cols, .data = data };
    }

    pub fn get(self: Matrix, r: usize, c: usize) f64 {
        return self.data[r * self.cols + c];
    }

    pub fn set(self: Matrix, r: usize, c: usize, v: f64) void {
        self.data[r * self.cols + c] = v;
    }

    pub fn transpose(self: Matrix) Matrix {
        var t = Matrix.init(self.cols, self.rows, &self.data);
        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            var j: usize = i + 1;
            while (j < self.cols) : (j += 1) {
                const tmp = self.data[i * self.cols + j];
                self.data[i * self.cols + j] = self.data[j * self.cols + i];
                self.data[j * self.cols + i] = tmp;
            }
        }
        return t;
    }

    pub fn multiply(self: Matrix, other: Matrix) Matrix {
        const result = Matrix.init(self.rows, other.cols, &self.data);
        var i: usize = 0;
        while (i < self.rows) : (i += 1) {
            var j: usize = 0;
            while (j < other.cols) : (j += 1) {
                var sum: f64 = 0;
                var k: usize = 0;
                while (k < self.cols) : (k += 1) {
                    sum += self.data[i * self.cols + k] * other.data[k * other.cols + j];
                }
                result.data[i * other.cols + j] = sum;
            }
        }
        return result;
    }

    pub fn frobeniusNorm(self: Matrix) f64 {
        var sum: f64 = 0;
        for (self.data) |v| sum += v * v;
        return std.math.sqrt(sum);
    }
};

pub const SVDResult = struct {
    U: Matrix,
    S: []f64,
    Vt: Matrix,
};

pub fn svd(A: Matrix) SVDResult {
    const m = A.rows;
    const n = A.cols;
    const k = @min(m, n);

    var U = Matrix.init(m, m, &A.data);
    var Vt = Matrix.init(n, n, &A.data);
    var S = A.data[0..k];

    var i: usize = 0;
    while (i < k) : (i += 1) {
        var j: usize = i + 1;
        while (j < k) : (j += 1) {
            const a = A.data[i * n + i];
            const b = A.data[i * n + j];
            const c = A.data[j * n + i];
            const d = A.data[j * n + j];
            const r = std.math.sqrt(a * a + b * b + c * c + d * d);
            if (r == 0) continue;
            const alpha = (a + d) / r;
            const beta = (b + c) / r;
            const gamma = (a * d - b * c) / (r * r);
            const theta = std.math.atan2(gamma, alpha);
            const ct = std.math.cos(theta);
            const st = std.math.sin(theta);

            var p: usize = 0;
            while (p < m) : (p += 1) {
                const up = U.data[p * m + i];
                const vp = Vt.data[i * n + p];
                U.data[p * m + i] = up * ct - vp * st;
                U.data[p * m + j] = up * st + vp * ct;
            }
            var q: usize = 0;
            while (q < n) : (q += 1) {
                const uq = U.data[i * m + q];
                const vq = Vt.data[j * n + q];
                Vt.data[i * n + q] = uq * ct + vq * st;
                Vt.data[j * n + q] = -uq * st + vq * ct;
            }
        }
    }

    var idx: usize = 0;
    while (idx < k) : (idx += 1) {
        S[idx] = std.math.sqrt(A.data[idx * n + idx] * A.data[idx * n + idx]);
    }

    return .{ .U = U, .S = S, .Vt = Vt };
}

pub fn lowRankApprox(A: Matrix, rank: usize) Matrix {
    const svd = svd(A);
    const r = @min(rank, @min(A.rows, A.cols));
    var result = Matrix.init(A.rows, A.cols, &A.data);

    var i: usize = 0;
    while (i < A.rows) : (i += 1) {
        var j: usize = 0;
        while (j < A.cols) : (j += 1) {
            var sum: f64 = 0;
            var k: usize = 0;
            while (k < r) : (k += 1) {
                sum += svd.U.data[i * A.rows + k] * svd.S[k] * svd.Vt.data[k * A.cols + j];
            }
            result.data[i * A.cols + j] = sum;
        }
    }
    return result;
}
