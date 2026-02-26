const std = @import("std");

const ImportDuplicateMode = enum {
    skip,
    overwrite,
    create_new,
};

fn parseSectionName(line: []const u8) ?[]const u8 {
    const trimmed = std.mem.trim(u8, line, "\r");
    if (trimmed.len == 0) return null;

    if (std.mem.startsWith(u8, trimmed, "===")) {
        const section_name = std.mem.trim(u8, trimmed, "= ");
        if (std.mem.eql(u8, section_name, "METADATA")) {
            return null;
        }
        return section_name;
    }
    return null;
}

fn isHeaderLine(line: []const u8, section: ?[]const u8) bool {
    _ = section;
    const trimmed = std.mem.trim(u8, line, "\r");
    if (trimmed.len == 0) return false;
    if (std.mem.startsWith(u8, trimmed, "===")) return false;
    return std.mem.startsWith(u8, trimmed, "id,") or std.mem.startsWith(u8, trimmed, "ID,");
}

fn parseCSVValues(line: []const u8, max_values: usize) struct { values: [][]const u8, count: usize } {
    const trimmed = std.mem.trim(u8, line, "\r");
    if (trimmed.len == 0) return .{ .values = &.{}, .count = 0 };

    var values: [20][]const u8 = undefined;
    var value_count: usize = 0;

    var value_iter = std.mem.splitSequence(u8, trimmed, ",");
    while (value_iter.next()) |v| {
        if (value_count >= max_values) break;
        if (value_count >= 20) break;
        values[value_count] = std.mem.trim(u8, v, " \r");
        value_count += 1;
    }

    return .{ .values = values[0..value_count], .count = value_count };
}

test "parseSectionName - valid section" {
    const result = parseSectionName("===FIREARMS===");
    try std.testing.expect(result != null);
    try std.testing.expect(std.mem.eql(u8, result.?, "FIREARMS"));
}

test "parseSectionName - metadata section" {
    const result = parseSectionName("===METADATA===");
    try std.testing.expect(result == null);
}

test "parseSectionName - empty line" {
    const result = parseSectionName("");
    try std.testing.expect(result == null);
}

test "parseSectionName - whitespace only" {
    const result = parseSectionName("   ");
    try std.testing.expect(result == null);
}

test "parseSectionName - with spaces" {
    const result = parseSectionName("=== CONSUMABLES ===");
    try std.testing.expect(result != null);
    try std.testing.expect(std.mem.eql(u8, result.?, "CONSUMABLES"));
}

test "isHeaderLine - id header" {
    try std.testing.expect(isHeaderLine("id,name,caliber", "FIREARMS"));
    try std.testing.expect(isHeaderLine("ID,Name,Caliber", "FIREARMS"));
    try std.testing.expect(!isHeaderLine("abc123,My Gun,9mm", "FIREARMS"));
    try std.testing.expect(!isHeaderLine("", "FIREARMS"));
    try std.testing.expect(!isHeaderLine("===FIREARMS===", "FIREARMS"));
}

test "parseCSVValues - basic line" {
    const result = parseCSVValues("id1,Glock 19,9mm,ABC123", 20);
    try std.testing.expect(result.count == 4);
    try std.testing.expect(std.mem.eql(u8, result.values[0], "id1"));
    try std.testing.expect(std.mem.eql(u8, result.values[1], "Glock 19"));
    try std.testing.expect(std.mem.eql(u8, result.values[2], "9mm"));
    try std.testing.expect(std.mem.eql(u8, result.values[3], "ABC123"));
}

test "parseCSVValues - with spaces" {
    const result = parseCSVValues(" id1 , Glock 19 , 9mm ", 20);
    try std.testing.expect(result.count == 3);
    try std.testing.expect(std.mem.eql(u8, result.values[0], "id1"));
    try std.testing.expect(std.mem.eql(u8, result.values[1], "Glock 19"));
    try std.testing.expect(std.mem.eql(u8, result.values[2], "9mm"));
}

test "parseCSVValues - empty line" {
    const result = parseCSVValues("", 20);
    try std.testing.expect(result.count == 0);
}

test "parseCSVValues - max values limit" {
    const result = parseCSVValues("1,2,3,4,5,6,7,8,9,10,11,12,13,14,15", 5);
    try std.testing.expect(result.count == 5);
}

test "parseCSVValues - with carriage returns" {
    const result = parseCSVValues("id1,Glock 19\r", 20);
    try std.testing.expect(result.count == 2);
    try std.testing.expect(std.mem.eql(u8, result.values[1], "Glock 19"));
}

pub fn main() !void {
    std.debug.print("Running CSV parsing tests...\n", .{});
}
