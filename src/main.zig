const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const gear = @import("gearTracker_zig");

var window: *zglfw.Window = undefined;
var allocator: std.mem.Allocator = undefined;
var db: *gear.Database = undefined;

var selected_row: ?usize = null;
var current_category: usize = 0;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_forward_compat, true);

    window = try zglfw.Window.create(900, 600, "GearTracker", null, null);
    defer window.destroy();

    zglfw.makeContextCurrent(window);

    zgui.init(allocator);
    defer zgui.deinit();

    zgui.backend.init(window);

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
    zgui.setNextWindowSize(.{ .w = 900, .h = 600, .cond = .always });
    if (zgui.begin("GearTracker", .{})) {
        defer zgui.end();

        if (zgui.beginTabBar("categories", .{})) {
            if (zgui.tabItemButton("Firearms", .{})) {
                current_category = 0;
                selected_row = null;
            }
            if (zgui.tabItemButton("Soft Gear", .{})) {
                current_category = 1;
                selected_row = null;
            }
            if (zgui.tabItemButton("NFA Items", .{})) {
                current_category = 2;
                selected_row = null;
            }
            if (zgui.tabItemButton("Attachments", .{})) {
                current_category = 3;
                selected_row = null;
            }
            zgui.endTabBar();
        }

        zgui.separator();

        if (zgui.beginTable("gear", .{ .column = 3, .flags = .{} })) {
            defer zgui.endTable();

            zgui.tableSetupColumn("Name", .{});
            zgui.tableSetupColumn("Caliber", .{});
            zgui.tableSetupColumn("Serial", .{});
            zgui.tableHeadersRow();

            const data = getDataForCategory(current_category);

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
                zgui.textUnformatted(item.caliber);

                _ = zgui.tableSetColumnIndex(2);
                zgui.textUnformatted(item.serial_number);
            }
        }
    }
}

fn getDataForCategory(_: usize) []gear.firearm.Firearm {
    var repo = gear.FirearmRepository{ .db = db };
    return repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
}
