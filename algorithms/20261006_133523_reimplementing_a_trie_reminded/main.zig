const std = @import("std");
const core = @import("core.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const allocator = &gpa.allocator;

    var trie = try core.Trie.init(allocator);
    defer trie.deinit();

    // Insert words
    try trie.insert("hello");
    try trie.insert("hell");
    try trie.insert("heaven");
    try trie.insert("good");
    try trie.insert("go");

    // Search tests
    std.debug.assert(trie.search("hello"));
    std.debug.assert(trie.search("hell"));
    std.debug.assert(!trie.search("hel"));
    std.debug.assert(trie.search("good"));
    std.debug.assert(!trie.search("goo"));

    // Prefix tests
    std.debug.assert(trie.startsWith("he"));
    std.debug.assert(trie.startsWith("go"));
    std.debug.assert(!trie.startsWith("ga"));

    // Autocomplete tests
    var completions = try trie.autocomplete("he");
    defer completions.deinit();
    // Expected: "hell", "hello", "heaven"
    std.debug.assert(completions.items.len == 3);
    const expected_he = [_][]const u8{ "hell", "hello", "heaven" };
    for (expected_he) |exp| {
        var found = false;
        for (completions.items) |got| {
            if (std.mem.eql(u8, got, exp)) {
                found = true;
                break;
            }
        }
        std.debug.assert(found);
    }

    var completions_go = try trie.autocomplete("go");
    defer completions_go.deinit();
    std.debug.assert(completions_go.items.len == 2);
    const expected_go = [_][]const u8{ "go", "good" };
    for (expected_go) |exp| {
        var found = false;
        for (completions_go.items) |got| {
            if (std.mem.eql(u8, got, exp)) {
                found = true;
                break;
            }
        }
        std.debug.assert(found);
    }

    // Autocomplete with no matches
    var completions_none = try trie.autocomplete("xyz");
    defer completions_none.deinit();
    std.debug.assert(completions_none.items.len == 0);
}
