const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();

    const allocator = gpa.allocator();

    // Root context
    const root = try core.ModelContext.init(&allocator, null);
    defer root.deinit();

    // Basic set/get
    try root.set("alpha", "root_val");
    const rootVal = root.get("alpha") orelse std.debug.panic("root missing alpha");
    std.debug.assert(std.mem.eql(u8, rootVal, "root_val"));

    // Child inherits from root
    const child = try root.child();
    defer child.deinit();

    const inherited = child.get("alpha") orelse std.debug.panic("child failed inheritance");
    std.debug.assert(std.mem.eql(u8, inherited, "root_val"));

    // Override in child
    try child.set("alpha", "child_val");
    const childVal = child.get("alpha") orelse std.debug.panic("child missing overridden alpha");
    std.debug.assert(std.mem.eql(u8, childVal, "child_val"));

    // Ensure root unchanged
    const rootAfter = root.get("alpha") orelse std.debug.panic("root lost alpha");
    std.debug.assert(std.mem.eql(u8, rootAfter, "root_val"));

    // Deeper chain
    const grand = try child.child();
    defer grand.deinit();

    // Missing key returns null
    std.debug.assert(grand.get("beta") == null);

    // Set in root, visible deep
    try root.set("beta", "deep");
    const deepVal = grand.get("beta") orelse std.debug.panic("grand missing beta");
    std.debug.assert(std.mem.eql(u8, deepVal, "deep"));

    // Override deep in grand
    try grand.set("beta", "grand_val");
    const overridden = grand.get("beta") orelse std.debug.panic("grand missing overridden beta");
    std.debug.assert(std.mem.eql(u8, overridden, "grand_val"));

    // Child still sees root's value
    const childBeta = child.get("beta") orelse std.debug.panic("child missing beta");
    std.debug.assert(std.mem.eql(u8, childBeta, "deep"));

    // Non‑existent key on root
    std.debug.assert(root.get("nonexistent") == null);
}
