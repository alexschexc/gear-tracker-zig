const std = @import("std");
const gear = @import("gearTracker_zig");

pub fn main() void {
    std.debug.print("GearTracker MVP - Zig version initialized!\n", .{});
    std.debug.print("Models available: Firearm, SoftGear, NFAItem, Attachment, Checkout, Borrower,\n", .{});
    std.debug.print("  Loadout, LoadoutItem, Consumable, MaintenanceLog, ReloadBatch\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const home_dir = std.posix.getenv("HOME") orelse ".";
    var db_path_buf: [512]u8 = undefined;
    const db_path = std.fmt.bufPrint(&db_path_buf, "{s}/.gear_tracker/tracker.db", .{home_dir}) catch ".gear_tracker/tracker.db";
    std.debug.print("\nInitializing database at: {s}\n", .{db_path});

    var db = gear.Database.init(allocator, db_path) catch |err| {
        std.debug.print("Failed to init database: {}\n", .{err});
        return;
    };
    defer db.deinit();

    std.debug.print("Database initialized successfully!\n", .{});

    var repo = gear.FirearmRepository{ .db = &db };

    std.debug.print("\n--- Testing Firearm CRUD ---\n", .{});

    // Just test getAll for now
    const all = repo.getAll(allocator) catch |err| {
        std.debug.print("Failed to get all firearms: {}\n", .{err});
        return;
    };
    std.debug.print("Found {d} firearms\n", .{all.len});
    for (all) |f| {
        std.debug.print("  - {s} ({s})\n", .{ f.name, f.caliber });
    }

    std.debug.print("\n--- CRUD Test Complete ---\n", .{});
}
