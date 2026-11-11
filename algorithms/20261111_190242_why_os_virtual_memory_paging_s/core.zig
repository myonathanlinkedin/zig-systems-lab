const std = @import("std");

pub const Pager = struct {
    allocator: *std.mem.Allocator,
    page_size: usize,
    num_pages: usize,
    num_frames: usize,
    backing_store: []u8,
    frame_data: []u8,
    frames: []?usize,          // frame -> virtual page (or null)
    page_table: []?usize,      // virtual page -> frame (or null)
    lru: std.ArrayList(usize), // most‑recently used at the back

    pub fn init(
        allocator: *std.mem.Allocator,
        num_pages: usize,
        page_size: usize,
        num_frames: usize,
    ) !Pager {
        const backing = try allocator.alloc(u8, num_pages * page_size);
        std.mem.set(u8, backing, 0);
        const frames_mem = try allocator.alloc(u8, num_frames * page_size);
        std.mem.set(u8, frames_mem, 0);
        const frames = try allocator.alloc(?usize, num_frames);
        for (frames) |*slot| slot.* = null;
        const pgt = try allocator.alloc(?usize, num_pages);
        for (pgt) |*slot| slot.* = null;
        var lru = std.ArrayList(usize).init(allocator);
        return Pager{
            .allocator = allocator,
            .page_size = page_size,
            .num_pages = num_pages,
            .num_frames = num_frames,
            .backing_store = backing,
            .frame_data = frames_mem,
            .frames = frames,
            .page_table = pgt,
            .lru = lru,
        };
    }

    pub fn deinit(self: *Pager) void {
        self.lru.deinit();
        self.allocator.free(self.backing_store);
        self.allocator.free(self.frame_data);
        self.allocator.free(self.frames);
        self.allocator.free(self.page_table);
    }

    fn update_lru(self: *Pager, frame: usize) void {
        // Remove if already present.
        for (self.lru.items, 0..) |f, idx| {
            if (f == frame) {
                _ = self.lru.orderedRemove(idx);
                break;
            }
        }
        // Append as most‑recent.
        _ = self.lru.append(frame);
    }

    fn evict_lru(self: *Pager) !usize {
        if (self.lru.items.len == 0) return error.NoFrames;
        const evict_frame = self.lru.items[0];
        _ = self.lru.orderedRemove(0);
        const vpage_opt = self.frames[evict_frame];
        const vpage = vpage_opt orelse return error.CorruptState;
        // Write back to backing store.
        const src = evict_frame * self.page_size;
        const dst = vpage * self.page_size;
        std.mem.copy(u8,
            self.backing_store[dst .. dst + self.page_size],
            self.frame_data[src .. src + self.page_size]);
        // Clear mappings.
        self.page_table[vpage] = null;
        self.frames[evict_frame] = null;
        return evict_frame;
    }

    fn access_page(self: *Pager, page: usize) !usize {
        if (page >= self.num_pages) return error.InvalidPage;
        if (self.page_table[page]) |frame| {
            self.update_lru(frame);
            return frame;
        }
        // Find a free frame.
        var free: ?usize = null;
        for (self.frames, 0..) |opt, i| {
            if (opt == null) {
                free = i;
                break;
            }
        }
        const frame = if (free) |f| f else try self.evict_lru();
        // Load page from backing store.
        const src = page * self.page_size;
        const dst = frame * self.page_size;
        std.mem.copy(u8,
            self.frame_data[dst .. dst + self.page_size],
            self.backing_store[src .. src + self.page_size]);
        // Update tables.
        self.frames[frame] = page;
        self.page_table[page] = frame;
        self.update_lru(frame);
        return frame;
    }

    pub fn read(self: *Pager, addr: usize) !u8 {
        const page = addr / self.page_size;
        const offset = addr % self.page_size;
        const frame = try self.access_page(page);
        return self.frame_data[frame * self.page_size + offset];
    }

    pub fn write(self: *Pager, addr: usize, value: u8) !void {
        const page = addr / self.page_size;
        const offset = addr % self.page_size;
        const frame = try self.access_page(page);
        self.frame_data[frame * self.page_size + offset] = value;
    }

    pub const error = error{
        NoFrames,
        InvalidPage,
        CorruptState,
    };
};
