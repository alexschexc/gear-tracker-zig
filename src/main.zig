const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const gear = @import("gearTracker_zig");

var window: *zglfw.Window = undefined;
var allocator: std.mem.Allocator = undefined;
var db: *gear.Database = undefined;

var selected_row: ?usize = null;
var current_category: usize = 0;

const Category = enum {
    firearms,
    soft_gear,
    nfa_items,
    attachments,
};

const DisplayItem = struct {
    name: []const u8,
    col1: []const u8,
    col2: []const u8,
    col3: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    try zglfw.init();
    defer zglfw.terminate();

    const monitor = zglfw.Monitor.getPrimary().?;
    const video_mode = try monitor.getVideoMode();
    const screen_width = @as(u32, @intCast(video_mode.width));
    const screen_height = @as(u32, @intCast(video_mode.height));

    const window_width = @min(screen_width * 80 / 100, 1400);
    const window_height = @min(screen_height * 80 / 100, 900);

    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_forward_compat, true);

    window = try zglfw.Window.create(window_width, window_height, "GearTracker", null, null);
    defer window.destroy();

    const x = @as(c_int, @intCast((screen_width - window_width) / 2));
    const y = @as(c_int, @intCast((screen_height - window_height) / 2));
    window.setPos(x, y);

    zglfw.makeContextCurrent(window);

    const scale = window.getContentScale();
    const font_scale = scale[0];

    zgui.init(allocator);

    var font_config = zgui.FontConfig.init();
    font_config.size_pixels = 16.0 * font_scale;
    _ = zgui.io.addFontDefault(font_config);

    zgui.backend.init(window);
    defer zgui.deinit();

    const home_dir = std.posix.getenv("HOME") orelse ".";
    var db_path_buf: [512]u8 = undefined;
    const db_path = std.fmt.bufPrint(&db_path_buf, "{s}/.gear_tracker/tracker.db", .{home_dir}) catch ".gear_tracker/tracker.db";

    db = try allocator.create(gear.Database);
    db.* = try gear.Database.init(allocator, db_path);
    defer {
        db.deinit();
        allocator.destroy(db);
    }

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const fb_size = window.getFramebufferSize();
        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        try renderUI();

        zgui.backend.draw();

        window.swapBuffers();
    }
}

fn renderUI() !void {
    const window_size = window.getSize();
    const win_w = @as(f32, @floatFromInt(window_size[0]));
    const win_h = @as(f32, @floatFromInt(window_size[1]));

    zgui.setNextWindowPos(.{ .x = 0, .y = 0, .cond = .always });
    zgui.setNextWindowSize(.{ .w = win_w, .h = win_h, .cond = .always });

    if (zgui.begin("GearTracker", .{ .flags = .{} })) {
        defer zgui.end();

        if (zgui.beginTabBar("categories", .{})) {
            if (zgui.beginTabItem("Firearms", .{})) {
                current_category = 0;
                selected_row = null;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Soft Gear", .{})) {
                current_category = 1;
                selected_row = null;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("NFA Items", .{})) {
                current_category = 2;
                selected_row = null;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Attachments", .{})) {
                current_category = 3;
                selected_row = null;
                zgui.endTabItem();
            }
            zgui.endTabBar();
        }

        zgui.separator();

        const data = getDataForCategory(@as(Category, @enumFromInt(current_category)));

        if (data.len == 0) {
            zgui.textDisabled("No items in this category", .{});
        } else {
            const cat: Category = @enumFromInt(current_category);
            const col1_header: [:0]const u8 = switch (cat) {
                .firearms => "Caliber",
                .soft_gear => "Category",
                .nfa_items => "Type",
                .attachments => "Category",
            };
            const col2_header: [:0]const u8 = switch (cat) {
                .firearms => "Serial",
                .soft_gear => "Brand",
                .nfa_items => "Serial",
                .attachments => "Brand",
            };
            const col3_header: [:0]const u8 = switch (cat) {
                .firearms => "Status",
                .soft_gear => "Status",
                .nfa_items => "Tax Stamp",
                .attachments => "Model",
            };

            if (zgui.beginTable("gear", .{ .column = 4, .flags = .{} })) {
                defer zgui.endTable();

                zgui.tableSetupColumn("Name", .{});
                zgui.tableSetupColumn(col1_header, .{});
                zgui.tableSetupColumn(col2_header, .{});
                zgui.tableSetupColumn(col3_header, .{});
                zgui.tableHeadersRow();

                for (data, 0..) |item, i| {
                    zgui.tableNextRow(.{});
                    _ = zgui.tableSetColumnIndex(0);
                    const is_selected = selected_row == i;

                    var id_buf: [32]u8 = undefined;
                    const id = std.fmt.bufPrintZ(&id_buf, "row_{d}", .{i}) catch "row_0";
                    if (zgui.selectable(id, .{ .selected = is_selected })) {
                        selected_row = i;
                    }
                    zgui.textUnformatted(item.name);

                    _ = zgui.tableSetColumnIndex(1);
                    zgui.textUnformatted(item.col1);

                    _ = zgui.tableSetColumnIndex(2);
                    zgui.textUnformatted(item.col2);

                    _ = zgui.tableSetColumnIndex(3);
                    zgui.textUnformatted(item.col3);
                }
            }
        }
    }
}

fn getDataForCategory(cat: Category) []DisplayItem {
    var items: []DisplayItem = &.{};

    switch (cat) {
        .firearms => {
            var repo = gear.FirearmRepository{ .db = db };
            const firearms = repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
            items = allocator.alloc(DisplayItem, firearms.len) catch return &.{};
            for (firearms, 0..) |f, i| {
                items[i] = .{
                    .name = f.name,
                    .col1 = f.caliber,
                    .col2 = f.serial_number,
                    .col3 = @tagName(f.status),
                };
            }
        },
        .soft_gear => {
            var repo = gear.SoftGearRepository{ .db = db };
            const gear_items = repo.getAll(allocator) catch &[_]gear.gear.SoftGear{};
            items = allocator.alloc(DisplayItem, gear_items.len) catch return &.{};
            for (gear_items, 0..) |g, i| {
                items[i] = .{
                    .name = g.name,
                    .col1 = g.category,
                    .col2 = g.brand,
                    .col3 = @tagName(g.status),
                };
            }
        },
        .nfa_items => {
            var repo = gear.NFAItemRepository{ .db = db };
            const nfa_items = repo.getAll(allocator) catch &[_]gear.gear.NFAItem{};
            items = allocator.alloc(DisplayItem, nfa_items.len) catch return &.{};
            for (nfa_items, 0..) |n, i| {
                items[i] = .{
                    .name = n.name,
                    .col1 = @tagName(n.nfa_type),
                    .col2 = n.serial_number,
                    .col3 = n.tax_stamp_id,
                };
            }
        },
        .attachments => {
            var repo = gear.AttachmentRepository{ .db = db };
            const attachments = repo.getAll(allocator) catch &[_]gear.gear.Attachment{};
            items = allocator.alloc(DisplayItem, attachments.len) catch return &.{};
            for (attachments, 0..) |a, i| {
                items[i] = .{
                    .name = a.name,
                    .col1 = a.category,
                    .col2 = a.brand,
                    .col3 = a.model,
                };
            }
        },
    }

    return items;
}
