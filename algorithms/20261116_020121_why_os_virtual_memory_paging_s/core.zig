const std = @import("std");

pub const PageId = u32;

pub const Pager = struct {
    capacity: usize,
    frames: []?PageId,
    last_used: []usize,
    page_to_frame: std.AutoHashMap(PageId, usize),
    time: usize,

    pub fn init(allocator: *std.mem.Allocator, capacity: usize) !Pager {
        var frames = try allocator.alloc(?PageId, capacity);
        var last_used = try allocator.alloc(usize, capacity);
        for (frames) |*slot| slot.* = null;
        for (last_used) |*slot| slot.* = 0;
        return Pager{
            .capacity = capacity,
            .frames = frames,
            .last_used = last_used,
            .page_to_frame = std.AutoHashMap(PageId, usize).init(allocator),
            .time = 0,
        };
    }

    pub fn deinit(self: *Pager, allocator: *std.mem.Allocator) void {
        allocator.free(self.frames);
        allocator.free(self.last_used);
        self.page_to_frame.deinit();
    }

    pub fn access(self: *Pager, page: PageId) bool {
        self.time += 1;
        if (self.page_to_frame.get(page)) |frame_idx| {
            // Hit: update usage timestamp
            self.last_used[frame_idx] = self.time;
            return true;
        } else {
            // Miss: need to load page
            var free_idx: ?usize = null;
            for (self.frames) |opt, idx| {
                if (opt == null) {
                    free_idx = idx;
                    break;
                }
            }
            var target_idx: usize = undefined;
            if (free_idx) |idx| {
                target_idx = idx;
            } else {
                // Evict LRU frame
                var lru_idx: usize = 0;
                var lru_time = self.last_used[0];
                for (self.last_used) |t, i| {
                    if (t < lru_time) {
                        lru_time = t;
                        lru_idx = i;
                    }
                }
                const evicted_page = self.frames[lru_idx].?;
                _ = self.page_to_frame.remove(evicted_page);
                target_idx = lru_idx;
            }
            // Load new page into target frame
            self.frames[target_idx] = page;
            self.last_used[target_idx] = self.time;
            _ = self.page_to_frame.put(page, target_idx);
            return false;
        }
    }

    pub fn loadedCount(self: *Pager) usize {
        var cnt: usize = 0;
        for (self.frames) |opt| {
            if (opt != null) cnt += 1;
        }
        return cnt;
    }
};
