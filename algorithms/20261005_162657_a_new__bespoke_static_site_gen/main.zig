const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    try testParseMarkdown();
    try testApplyTemplate();
    try testGenerateSite();
    std.debug.print("All tests passed.\n", .{});
}

// ---------- Unit Tests ----------
fn testParseMarkdown() !void {
    const allocator = std.testing.allocator;
    const src = "# Title\n\nHello world\n## Sub\nMore text";
    const html = try core.parseMarkdown(allocator, src);
    defer allocator.free(html);
    const expected = "<h1>Title</h1>\n<p>Hello world</p>\n<h2>Sub</h2>\n<p>More text</p>\n";
    std.debug.assert(std.mem.eql(u8, html, expected));
}

fn testApplyTemplate() !void {
    const allocator = std.testing.allocator;
    const tmpl = "<html><body>{{content}}</body></html>";
    const cont = "<p>Hi</p>";
    const out = try core.applyTemplate(allocator, tmpl, cont);
    defer allocator.free(out);
    const expected = "<html><body><p>Hi</p></body></html>";
    std.debug.assert(std.mem.eql(u8, out, expected));
}

fn testGenerateSite() !void {
    const allocator = std.testing.allocator;
    const cwd = std.fs.cwd();

    // Setup temporary dirs
    const in_dir = "tmp_input";
    const out_dir = "tmp_output";
    const tmpl_path = "tmp_template.html";

    // Clean previous runs
    _ = cwd.deleteTree(in_dir) catch {};
    _ = cwd.deleteTree(out_dir) catch {};
    _ = cwd.deleteFile(tmpl_path) catch {};

    try cwd.makeDir(in_dir);
    try cwd.makeDir(out_dir);

    // Write template
    const tmpl_content = "<html><head></head><body>{{content}}</body></html>";
    try core.writeFile(tmpl_path, tmpl_content);

    // Write markdown file
    const md_name = "index.md";
    const md_path = try std.fs.path.join(allocator, &.{ in_dir, md_name });
    defer allocator.free(md_path);
    const md_content = "# Hello\n\nThis is a test.";
    try core.writeFile(md_path, md_content);

    // Run generator
    const cfg = core.Config{
        .input_dir = in_dir,
        .output_dir = out_dir,
        .template_path = tmpl_path,
    };
    try core.generateSite(allocator, cfg);

    // Verify output
    const out_file = try std.fs.path.join(allocator, &.{ out_dir, "index.html" });
    defer allocator.free(out_file);
    const result = try core.readFile(allocator, out_file);
    defer allocator.free(result);
    const expected_body = "<h1>Hello</h1>\n<p>This is a test.</p>\n";
    const expected = "<html><head></head><body>" ++ expected_body ++ "</body></html>";
    std.debug.assert(std.mem.eql(u8, result, expected));

    // Cleanup
    try cwd.deleteTree(in_dir);
    try cwd.deleteTree(out_dir);
    try cwd.deleteFile(tmpl_path);
}

// ---------- Simple Benchmark ----------
pub fn benchmark() !void {
    const allocator = std.heap.page_allocator;
    const cfg = core.Config{
        .input_dir = "bench_input",
        .output_dir = "bench_output",
        .template_path = "bench_template.html",
    };
    const start = std.time.milliTimestamp();
    try core.generateSite(allocator, cfg);
    const elapsed = std.time.milliTimestamp() - start;
    std.debug.print("Generation took {d} ms\n", .{elapsed});
}
