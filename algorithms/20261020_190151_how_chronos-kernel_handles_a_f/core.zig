const std = @import("std");
const mem = std.mem;

pub const Page = u64;
pub const PageId = u32;
pub const DirtyBit = u1;
pub const CleanBit = u0;

pub const MAX_PAGES = 1024;
pub const PAGE_SIZE = 4096;

pub const ForkError = error{
    OutOfMemory,
    PageTableFull,
    InvalidPageId,
    PageAlreadyMapped,
    PageNotMapped,
    DirtyPageConflict,
};

pub const PageTable = struct {
    pages: [MAX_PAGES]Page = undefined,
    dirty: [MAX_PAGES]u1 = undefined,
    count: usize = 0,

    pub fn init() PageTable {
        var pt: PageTable = undefined;
        for (&pt.pages) |*p| p.* = 0;
        for (&pt.dirty) |*d| d.* = CleanBit;
        pt.count = 0;
        return pt;
    }

    pub fn map(self: *PageTable, id: PageId, data: Page) ForkError!void {
        if (id >= MAX_PAGES) return ForkError.InvalidPageId;
        if (self.dirty[id] == DirtyBit) return ForkError.PageAlreadyMapped;
        self.pages[id] = data;
        self.dirty[id] = CleanBit;
        self.count += 1;
    }

    pub fn unmap(self: *PageTable, id: PageId) ForkError!void {
        if (id >= MAX_PAGES) return ForkError.InvalidPageId;
        if (self.dirty[id] == CleanBit) return ForkError.PageNotMapped;
        self.dirty[id] = CleanBit;
        self.count -= 1;
    }

    pub fn markDirty(self: *PageTable, id: PageId) ForkError!void {
        if (id >= MAX_PAGES) return ForkError.InvalidPageId;
        if (self.dirty[id] == DirtyBit) return ForkError.PageNotMapped;
        self.dirty[id] = DirtyBit;
    }

    pub fn isDirty(self: *const PageTable, id: PageId) bool {
        if (id >= MAX_PAGES) return false;
        return self.dirty[id] == DirtyBit;
    }

    pub fn get(self: *const PageTable, id: PageId) ?Page {
        if (id >= MAX_PAGES) return null;
        if (self.dirty[id] == CleanBit) return null;
        return self.pages[id];
    }

    pub fn totalDirtyBytes(self: *const PageTable) usize {
        var total: usize = 0;
        for (self.dirty) |d| {
            if (d == DirtyBit) total += PAGE_SIZE;
        }
        return total;
    }
};

pub const COWEngine = struct {
    parent: PageTable,
    child: PageTable,
    shared_pages: usize = 0,
    copied_pages: usize = 0,

    pub fn init() COWEngine {
        return .{
            .parent = PageTable.init(),
            .child = PageTable.init(),
            .shared_pages = 0,
            .copied_pages = 0,
        };
    }

    pub fn loadParentMemory(self: *COWEngine, data: []const Page) ForkError!void {
        for (data, 0..) |page, i| {
            const id: PageId = @intCast(i);
            try self.parent.map(id, page);
            try self.parent.markDirty(id);
        }
    }

    pub fn fork(self: *COWEngine) ForkError!void {
        self.child = PageTable.init();
        self.shared_pages = self.parent.count;
        self.copied_pages = 0;
    }

    pub fn childWrite(self: *COWEngine, id: PageId, new_data: Page) ForkError!void {
        if (id >= MAX_PAGES) return ForkError.InvalidPageId;
        const parent_page = self.parent.get(id) orelse return ForkError.PageNotMapped;
        if (self.child.isDirty(id)) {
            self.child.pages[id] = new_data;
            return;
        }
        self.child.pages[id] = new_data;
        self.child.dirty[id] = DirtyBit;
        self.copied_pages += 1;
        self.shared_pages -= 1;
    }

    pub fn parentWrite(self: *COWEngine, id: PageId, new_data: Page) ForkError!void {
        if (id >= MAX_PAGES) return ForkError.InvalidPageId;
        if (self.child.isDirty(id)) {
            self.parent.pages[id] = new_data;
            return;
        }
        self.parent.pages[id] = new_data;
        self.parent.dirty[id] = DirtyBit;
        self.copied_pages += 1;
        self.shared_pages -= 1;
    }

    pub fn memoryUsage(self: *const COWEngine) usize {
        return self.parent.totalDirtyBytes() + self.child.totalDirtyBytes();
    }

    pub fn copyOnWriteRatio(self: *const COWEngine) f64 {
        const total = self.parent.count;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(self.copied_pages)) / @as(f64, @floatFromInt(total));
    }
};
