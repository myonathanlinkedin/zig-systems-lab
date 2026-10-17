const std = @import("std");
const types = @import("types.zig");
const engine = @import("engine.zig");

pub fn main() !void {
    // Build sample table "users"
    const users = buildUsersTable();

    const tables = [_]*const types.Table{ &users };

    // Test 1: SELECT id,name FROM users WHERE age = 30
    const query1 = "SELECT id,name FROM users WHERE age = 30";
    const sel1 = try engine.parseQuery(query1);
    const res1 = try engine.executeQuery(sel1, tables);
    std.debug.assert(std.mem.eql(u8, res1.columns[0], "id"));
    std.debug.assert(std.mem.eql(u8, res1.columns[1], "name"));
    std.debug.assert(res1.rows.len == 2);
    // Row 0: (1, "Alice")
    std.debug.assert(res1.rows[0].values[0].Int == 1);
    std.debug.assert(std.mem.eql(u8, res1.rows[0].values[1].Str, "Alice"));
    // Row 1: (3, "Charlie")
    std.debug.assert(res1.rows[1].values[0].Int == 3);
    std.debug.assert(std.mem.eql(u8, res1.rows[1].values[1].Str, "Charlie"));

    // Test 2: SELECT * FROM users
    const query2 = "SELECT * FROM users";
    const sel2 = try engine.parseQuery(query2);
    const res2 = try engine.executeQuery(sel2, tables);
    std.debug.assert(res2.columns.len == users.columns.len);
    for (res2.columns, users.columns) |rc, uc| {
        std.debug.assert(std.mem.eql(u8, rc, uc));
    }
    std.debug.assert(res2.rows.len == users.rows.len);
    // Verify first row matches original
    for (res2.rows, users.rows) |rRes, rOrig| {
        for (rRes.values, rOrig.values) |vRes, vOrig| {
            std.debug.assert(vRes.eql(vOrig));
        }
    }

    // Edge case: WHERE with string literal
    const query3 = "SELECT name FROM users WHERE name = 'Bob'";
    const sel3 = try engine.parseQuery(query3);
    const res3 = try engine.executeQuery(sel3, tables);
    std.debug.assert(res3.columns.len == 1);
    std.debug.assert(std.mem.eql(u8, res3.columns[0], "name"));
    std.debug.assert(res3.rows.len == 1);
    std.debug.assert(std.mem.eql(u8, res3.rows[0].values[0].Str, "Bob"));

    // All assertions passed
    std.debug.print("All DelightQL tests passed.\n", .{});
}

// Helper to construct the users table with static data
fn buildUsersTable() types.Table {
    const allocator = std.heap.page_allocator;

    // Columns
    const cols = [_][]const u8{ "id", "name", "age" };

    // Rows data
    const rowData = [_][3]types.Value{
        .{ .Int = 1, .Str = "Alice", .Int = 30 },
        .{ .Int = 2, .Str = "Bob", .Int = 25 },
        .{ .Int = 3, .Str = "Charlie", .Int = 30 },
    };

    var rowsList = std.ArrayList(types.Row).init(allocator);
    defer rowsList.deinit();

    for (rowData) |vals| {
        // Copy values into heap slice
        var valsCopy = std.ArrayList(types.Value).init(allocator);
        defer valsCopy.deinit();
        for (vals) |v| {
            valsCopy.append(v) catch unreachable;
        }
        const slice = valsCopy.toOwnedSlice() catch unreachable;
        rowsList.append(types.Row{ .values = slice }) catch unreachable;
    }

    const rowsSlice = rowsList.toOwnedSlice() catch unreachable;

    return types.Table{
        .name = "users",
        .columns = &cols,
        .rows = rowsSlice,
    };
}
