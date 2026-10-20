const std = @import("std");
const core = @import("core.zig");
const PageTable = core.PageTable;
const COWEngine = core.COWEngine;
const ForkError = core.ForkError;
const Page = core.Page;
const PageId = core.PageId;
const MAX_PAGES = core.MAX_PAGES;
const PAGE_SIZE = core.PAGE_SIZE;

fn testPageTableInit() void {
    var pt = PageTable.init();
    std.debug.assert(pt.count == 0);
    std.debug.assert(pt.totalDirtyBytes() == 0);
}

fn testPageTableMapUnmap() void {
    var pt = PageTable.init();
    const id: PageId = 0;
    const data: Page = 0xDEADBEEF;
    pt.map(id, data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(pt.count == 1);
    std.debug.assert(pt.isDirty(id));
    std.debug.assert(pt.get(id) == data);
    pt.unmap(id) catch |e| std.debug.assert(e == ForkError.PageNotMapped);
    std.debug.assert(pt.count == 0);
    std.debug.assert(!pt.isDirty(id));
    std.debug.assert(pt.get(id) == null);
}

fn testPageTableInvalidId() void {
    var pt = PageTable.init();
    const bad_id: PageId = MAX_PAGES;
    pt.map(bad_id, 0) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    pt.unmap(bad_id) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    pt.markDirty(bad_id) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(!pt.isDirty(bad_id));
    std.debug.assert(pt.get(bad_id) == null);
}

fn testCOWForkBasic() void {
    var engine = COWEngine.init();
    var data: [4]Page = .{ 0x1111, 0x2222, 0x3333, 0x4444 };
    engine.loadParentMemory(&data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.parent.count == 4);
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.shared_pages == 4);
    std.debug.assert(engine.copied_pages == 0);
    std.debug.assert(engine.memoryUsage() == 4 * PAGE_SIZE);
}

fn testCOWChildWrite() void {
    var engine = COWEngine.init();
    var data: [4]Page = .{ 0x1111, 0x2222, 0x3333, 0x4444 };
    engine.loadParentMemory(&data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    const id: PageId = 1;
    const new_data: Page = 0x9999;
    engine.childWrite(id, new_data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.copied_pages == 1);
    std.debug.assert(engine.shared_pages == 3);
    std.debug.assert(engine.child.get(id) == new_data);
    std.debug.assert(engine.parent.get(id) == data[1]);
    std.debug.assert(engine.memoryUsage() == 5 * PAGE_SIZE);
}

fn testCOWParentWrite() void {
    var engine = COWEngine.init();
    var data: [4]Page = .{ 0x1111, 0x2222, 0x3333, 0x4444 };
    engine.loadParentMemory(&data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    const id: PageId = 2;
    const new_data: Page = 0xAAAA;
    engine.parentWrite(id, new_data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.copied_pages == 1);
    std.debug.assert(engine.shared_pages == 3);
    std.debug.assert(engine.parent.get(id) == new_data);
    std.debug.assert(engine.child.get(id) == data[2]);
    std.debug.assert(engine.memoryUsage() == 5 * PAGE_SIZE);
}

fn testCOWMultipleWrites() void {
    var engine = COWEngine.init();
    var data: [8]Page = .{ 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0x8 };
    engine.loadParentMemory(&data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.childWrite(0, 0x100) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.childWrite(1, 0x200) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.parentWrite(2, 0x300) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.copied_pages == 3);
    std.debug.assert(engine.shared_pages == 5);
    std.debug.assert(engine.memoryUsage() == 11 * PAGE_SIZE);
    std.debug.assert(engine.copyOnWriteRatio() > 0.3);
}

fn testCOWNoWrites() void {
    var engine = COWEngine.init();
    var data: [4]Page = .{ 0x1111, 0x2222, 0x3333, 0x4444 };
    engine.loadParentMemory(&data) catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.copied_pages == 0);
    std.debug.assert(engine.shared_pages == 4);
    std.debug.assert(engine.memoryUsage() == 4 * PAGE_SIZE);
    std.debug.assert(engine.copyOnWriteRatio() == 0.0);
}

fn testCOWEdgeCaseEmpty() void {
    var engine = COWEngine.init();
    engine.fork() catch |e| std.debug.assert(e == ForkError.InvalidPageId);
    std.debug.assert(engine.shared_pages == 0);
    std.debug.assert(engine.copied_pages == 0);
    std.debug.assert(engine.memoryUsage() == 0);
    std.debug.assert(engine.copyOnWriteRatio() == 0.0);
}

pub fn main() !void {
    testPageTableInit();
    testPageTableMapUnmap();
    testPageTableInvalidId();
    testCOWForkBasic();
    testCOWChildWrite();
    testCOWParentWrite();
    testCOWMultipleWrites();
    testCOWNoWrites();
    testCOWEdgeCaseEmpty();
    std.debug.print("All tests passed.\n", .{});
}
