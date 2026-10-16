const std = @import("std");
const CowVec = @import("core.zig").CowVec;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Test initialization and push
    var vec = try CowVec.init(allocator, 2);
    defer vec.deinit();
    try vec.push(10);
    try vec.push(20);
    std.debug.assert(vec.len() == 2);
    std.debug.assert(vec.capacity() >= 2);
    std.debug.assert(vec.get(0) == 10);
    std.debug.assert(vec.get(1) == 20);

    // Test clone and copy-on-write
    var vec2 = vec.clone();
    defer vec2.deinit();
    try vec2.push(30);
    std.debug.assert(vec.len() == 2); // original unchanged
    std.debug.assert(vec2.len() == 3);
    std.debug.assert(vec2.get(2) == 30);

    // Test set with copy-on-write
    try vec.set(0, 99);
    std.debug.assert(vec.get(0) == 99);
    std.debug.assert(vec2.get(0) == 10); // vec2 unchanged

    // Test pop
    const popped = vec.pop();
    std.debug.assert(popped.? == 99);
    std.debug.assert(vec.len() == 1);

    // Test capacity growth
    var vec3 = try CowVec.init(allocator, 1);
    defer vec3.deinit();
    try vec3.push(1);
    try vec3.push(2); // should trigger grow
    std.debug.assert(vec3.capacity() >= 2);
    std.debug.assert(vec3.len() == 2);
    std.debug.assert(vec3.get(1) == 2);

    // Test multiple clones
    var vec4 = vec3.clone();
    defer vec4.deinit();
    var vec5 = vec4.clone();
    defer vec5.deinit();
    try vec5.push(3);
    std.debug.assert(vec3.len() == 2);
    std.debug.assert(vec4.len() == 2);
    std.debug.assert(vec5.len() == 3);
    std.debug.assert(vec5.get(2) == 3);

    // All tests passed
    std.debug.print("All tests passed\n", .{});
}
