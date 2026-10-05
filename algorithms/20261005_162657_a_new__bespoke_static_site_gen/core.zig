const std = @import("std");

pub const Config = struct {
    input_dir: []const u8,
    output_dir: []const u8,
    template_path: []const u8,
};

pub fn readFile(allocator: *std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{ .read = true });
    defer file.close();
    const stat = try file.stat();
    const buf = try allocator.alloc(u8, stat.size);
    _ = try file.readAll(buf);
    return buf;
}

pub fn writeFile(path: []const u8, data: []const u8) !void {
    const dir = std.fs.cwd();
    const file = try dir.createFile(path, .{ .truncate = true });
    defer file.close();
    try file.writeAll(data);
}

fn isHeading(line: []const u8, level: *u8) bool {
    var i: usize = 0;
    while (i < line.len and line[i] == '#') : (i += 1) {}
    if (i == 0 or i > 6) return false;
    if (i < line.len and line[i] == ' ') {
        level.* = @intCast(u8, i);
        return true;
    }
    return false;
}

pub fn parseMarkdown(allocator: *std.mem.Allocator, src: []const u8) ![]u8 {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var it = std.mem.split(u8, src, "\n");
    while (it.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \r\t");
        if (line.len == 0) {
            // blank line -> paragraph break
            try out.appendSlice("\n");
            continue;
        }
        var lvl: u8 = 0;
        if (isHeading(line, &lvl)) {
            const content = line[lvl + 1 ..];
            const open = try std.fmt.allocPrint(allocator, "<h{}>", .{lvl});
            const close = try std.fmt.allocPrint(allocator, "</h{}>", .{lvl});
            defer allocator.free(open);
            defer allocator.free(close);
            try out.appendSlice(open);
            try out.appendSlice(content);
            try out.appendSlice(close);
            try out.appendSlice("\n");
        } else {
            const open = "<p>";
            const close = "</p>\n";
            try out.appendSlice(open);
            try out.appendSlice(line);
            try out.appendSlice(close);
        }
    }
    return out.toOwnedSlice();
}

pub fn applyTemplate(allocator: *std.mem.Allocator, template: []const u8, content: []const u8) ![]u8 {
    const placeholder = "{{content}}";
    const idx = std.mem.indexOf(u8, template, placeholder) orelse return error.PlaceholderNotFound;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    try out.appendSlice(template[0..idx]);
    try out.appendSlice(content);
    try out.appendSlice(template[idx + placeholder.len ..]);
    return out.toOwnedSlice();
}

pub fn generateSite(allocator: *std.mem.Allocator, cfg: Config) !void {
    const cwd = std.fs.cwd();

    // ensure output dir exists
    _ = try cwd.makeDir(cfg.output_dir);

    // load template once
    const tmpl_raw = try readFile(allocator, cfg.template_path);
    defer allocator.free(tmpl_raw);
    const template = try std.mem.concat(allocator, u8, &.{ tmpl_raw });
    defer allocator.free(template);

    var dir = try cwd.openDir(cfg.input_dir, .{});
    defer dir.close();

    var it = try dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".md")) continue;

        const in_path = try std.fs.path.join(allocator, &.{ cfg.input_dir, entry.name });
        defer allocator.free(in_path);
        const src = try readFile(allocator, in_path);
        defer allocator.free(src);

        const html = try parseMarkdown(allocator, src);
        defer allocator.free(html);

        const final = try applyTemplate(allocator, template, html);
        defer allocator.free(final);

        const base = std.fs.path.basename(entry.name);
        const name_no_ext = std.mem.sliceTo(base, '.');
        const out_name = try std.mem.concat(allocator, u8, &.{ name_no_ext, ".html" });
        defer allocator.free(out_name);
        const out_path = try std.fs.path.join(allocator, &.{ cfg.output_dir, out_name });
        defer allocator.free(out_path);

        try writeFile(out_path, final);
    }
}
