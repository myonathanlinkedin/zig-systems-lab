const std = @import("std");
const types = @import("types.zig");

pub const ParseError = error{
    InvalidSyntax,
    UnknownValue,
};

pub fn parseQuery(input: []const u8) ParseError!types.Select {
    var it = std.mem.split(u8, input, " ");
    // Expect SELECT
    const first = it.next() orelse return ParseError.InvalidSyntax;
    if (!std.mem.eql(u8, first, "SELECT")) return ParseError.InvalidSyntax;

    // Columns token (may contain commas)
    const colsToken = it.next() orelse return ParseError.InvalidSyntax;
    var columns: ?[]const []const u8 = null;
    if (!std.mem.eql(u8, colsToken, "*")) {
        // split by ','
        var colList = std.ArrayList([]const u8).init(std.heap.page_allocator);
        defer colList.deinit();
        var colIt = std.mem.split(u8, colsToken, ",");
        while (colIt.next()) |c| {
            try colList.append(std.mem.trim(u8, c, &std.ascii.whitespace));
        }
        columns = try colList.toOwnedSlice();
    }

    // Expect FROM
    const fromTok = it.next() orelse return ParseError.InvalidSyntax;
    if (!std.mem.eql(u8, fromTok, "FROM")) return ParseError.InvalidSyntax;

    // Table name
    const tableName = it.next() orelse return ParseError.InvalidSyntax;

    // Optional WHERE
    var whereCond: ?types.Condition = null;
    const maybeWhere = it.next();
    if (maybeWhere) |tok| {
        if (std.mem.eql(u8, tok, "WHERE")) {
            // column
            const col = it.next() orelse return ParseError.InvalidSyntax;
            // '='
            const eq = it.next() orelse return ParseError.InvalidSyntax;
            if (!std.mem.eql(u8, eq, "=")) return ParseError.InvalidSyntax;
            // value (may be quoted string or integer)
            const valTok = it.next() orelse return ParseError.InvalidSyntax;
            const value = try parseValue(valTok);
            whereCond = types.Condition{
                .column = col,
                .value = value,
            };
        } else {
            // Unexpected token after table name
            return ParseError.InvalidSyntax;
        }
    }

    return types.Select{
        .columns = columns,
        .table = tableName,
        .where = whereCond,
    };
}

fn parseValue(tok: []const u8) ParseError!types.Value {
    // String literal must start and end with single quote
    if (tok.len >= 2 and tok[0] == '\'' and tok[tok.len - 1] == '\'') {
        const inner = tok[1 .. tok.len - 1];
        return types.Value{ .Str = inner };
    } else {
        // Try integer
        const parsed = std.fmt.parseInt(i64, tok, 10) catch {
            return ParseError.UnknownValue;
        };
        return types.Value{ .Int = parsed };
    }
}

pub const ExecError = error{
    TableNotFound,
    ColumnNotFound,
};

pub fn executeQuery(q: types.Select, tables: []const types.Table) ExecError!types.Result {
    // Locate table
    var tblOpt: ?*const types.Table = null;
    for (tables) |*t| {
        if (std.mem.eql(u8, t.name, q.table)) {
            tblOpt = t;
            break;
        }
    }
    const tbl = tblOpt orelse return ExecError.TableNotFound;

    // Determine output columns
    const outCols: []const []const u8 = blk: {
        if (q.columns) |cols| {
            // verify each column exists
            for (cols) |c| {
                _ = try columnIndex(tbl, c);
            }
            break :blk cols;
        } else {
            // SELECT *
            break :blk tbl.columns;
        }
    };

    // Prepare result rows
    var resultRows = std.ArrayList(types.Row).init(std.heap.page_allocator);
    defer resultRows.deinit();

    // Iterate rows
    for (tbl.rows) |row| {
        // Apply WHERE if present
        if (q.where) |cond| {
            const colIdx = try columnIndex(tbl, cond.column);
            const cell = row.values[colIdx];
            if (!cell.eql(cond.value)) continue;
        }
        // Project columns
        var projVals = std.ArrayList(types.Value).init(std.heap.page_allocator);
        defer projVals.deinit();
        for (outCols) |c| {
            const idx = try columnIndex(tbl, c);
            try projVals.append(row.values[idx]);
        }
        const projSlice = try projVals.toOwnedSlice();
        try resultRows.append(types.Row{ .values = projSlice });
    }

    const rowsSlice = try resultRows.toOwnedSlice();
    return types.Result{
        .columns = outCols,
        .rows = rowsSlice,
    };
}

fn columnIndex(tbl: *const types.Table, name: []const u8) ExecError!usize {
    for (tbl.columns, 0..) |c, i| {
        if (std.mem.eql(u8, c, name)) return i;
    }
    return ExecError.ColumnNotFound;
}
