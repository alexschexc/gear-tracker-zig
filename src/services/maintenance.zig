const std = @import("std");
const types = @import("../models/types.zig");
const maintenance = @import("../models/maintenance.zig");

const Database = @import("../repository/database.zig").Database;
const FirearmRepository = @import("../repository/database.zig").FirearmRepository;
const MaintenanceLogRepository = @import("../repository/database.zig").MaintenanceLogRepository;

pub const MaintenanceService = struct {
    db: *Database,

    pub fn logCleaning(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8, details: []const u8) !void {
        _ = allocator;
        var repo = MaintenanceLogRepository{ .db = self.db };
        const now = std.time.timestamp();

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const log = maintenance.MaintenanceLog{
            .id = id,
            .item_id = firearm_id,
            .item_type = .firearm,
            .log_type = .cleaning,
            .date = now,
            .details = details,
            .ammo_count = null,
            .photo_path = null,
        };
        try repo.create(log);

        var firearm_repo = FirearmRepository{ .db = self.db };
        try firearm_repo.updateStatus(firearm_id, .available);
    }

    pub fn logFiredRounds(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8, rounds: i32, details: []const u8) !void {
        var repo = MaintenanceLogRepository{ .db = self.db };
        const now = std.time.timestamp();

        var details_buf: [64]u8 = undefined;
        const details_str = if (details.len > 0)
            details
        else
            try std.fmt.bufPrint(&details_buf, "Rounds fired: {d}", .{rounds});

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const log = maintenance.MaintenanceLog{
            .id = id,
            .item_id = firearm_id,
            .item_type = .firearm,
            .log_type = .other,
            .date = now,
            .details = details_str,
            .ammo_count = rounds,
            .photo_path = null,
        };
        try repo.create(log);

        var firearm_repo = FirearmRepository{ .db = self.db };
        const fw = try firearm_repo.getById(allocator, firearm_id);
        if (fw) |f| {
            var updated = f;
            updated.rounds_fired += rounds;
            try firearm_repo.update(updated);
            firearm_repo.deinit(allocator, f);
        }
    }

    pub fn logLubrication(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8, details: []const u8) !void {
        _ = allocator;
        var repo = MaintenanceLogRepository{ .db = self.db };
        const now = std.time.timestamp();

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const log = maintenance.MaintenanceLog{
            .id = id,
            .item_id = firearm_id,
            .item_type = .firearm,
            .log_type = .oil,
            .date = now,
            .details = details,
            .ammo_count = null,
            .photo_path = null,
        };
        try repo.create(log);
    }

    pub fn logRepair(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8, details: []const u8) !void {
        _ = allocator;
        var repo = MaintenanceLogRepository{ .db = self.db };
        const now = std.time.timestamp();

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const log = maintenance.MaintenanceLog{
            .id = id,
            .item_id = firearm_id,
            .item_type = .firearm,
            .log_type = .repair,
            .date = now,
            .details = details,
            .ammo_count = null,
            .photo_path = null,
        };
        try repo.create(log);
    }

    pub fn logInspection(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8, details: []const u8) !void {
        _ = allocator;
        var repo = MaintenanceLogRepository{ .db = self.db };
        const now = std.time.timestamp();

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const log = maintenance.MaintenanceLog{
            .id = id,
            .item_id = firearm_id,
            .item_type = .firearm,
            .log_type = .inspection,
            .date = now,
            .details = details,
            .ammo_count = null,
            .photo_path = null,
        };
        try repo.create(log);
    }

    pub fn getMaintenanceHistory(self: *MaintenanceService, allocator: std.mem.Allocator, item_id: []const u8) ![]maintenance.MaintenanceLog {
        var repo = MaintenanceLogRepository{ .db = self.db };
        return try repo.getByItemId(allocator, item_id);
    }

    pub fn getMaintenanceStatus(self: *MaintenanceService, allocator: std.mem.Allocator, firearm_id: []const u8) !MaintenanceStatus {
        var firearm_repo = FirearmRepository{ .db = self.db };
        const fw = try firearm_repo.getById(allocator, firearm_id);

        if (fw == null) {
            return MaintenanceStatus{
                .needs_maintenance = false,
                .reasons = &.{},
            };
        }
        defer firearm_repo.deinit(allocator, fw.?);

        var reasons = std.ArrayListUnmanaged([]const u8){};
        errdefer {
            for (reasons.items) |r| allocator.free(r);
            allocator.free(reasons.items);
        }

        if (fw.?.needs_maintenance) {
            try reasons.append(allocator, "Needs maintenance based on rounds fired");
        }

        if (fw.?.rounds_fired >= fw.?.clean_interval_rounds) {
            try reasons.append(allocator, "Rounds fired exceeds clean interval");
        }

        return MaintenanceStatus{
            .needs_maintenance = reasons.items.len > 0,
            .reasons = try reasons.toOwnedSlice(allocator),
        };
    }

    pub fn getFirearmsNeedingMaintenance(self: *MaintenanceService, allocator: std.mem.Allocator) !NeedingMaintenanceList {
        var firearm_repo = FirearmRepository{ .db = self.db };
        const all = try firearm_repo.getAll(allocator);
        defer firearm_repo.deinitAll(allocator, all);

        var result = std.ArrayListUnmanaged(NeedingMaintenanceItem){};
        errdefer {
            for (result.items) |*item| {
                allocator.free(item.reasons);
            }
            allocator.free(result.items);
        }

        for (all) |fw| {
            const status = try self.getMaintenanceStatus(allocator, fw.id);
            if (status.needs_maintenance) {
                try result.append(allocator, .{
                    .firearm_id = fw.id,
                    .firearm_name = fw.name,
                    .reasons = status.reasons,
                });
            } else {
                allocator.free(status.reasons);
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

pub const MaintenanceStatus = struct {
    needs_maintenance: bool,
    reasons: [][]const u8,
};

pub const NeedingMaintenanceItem = struct {
    firearm_id: []const u8,
    firearm_name: []const u8,
    reasons: [][]const u8,
};

pub const NeedingMaintenanceList = []NeedingMaintenanceItem;

fn generateUuidStr(buf: *[36]u8) ![]const u8 {
    const seed = std.time.timestamp();
    const rng = std.rand.DefaultPrng.init(@intCast(seed));
    const random = rng.random();

    const hex_chars = "0123456789abcdef";
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        buf[i] = hex_chars[random.int(u8) % 16];
    }
    buf[8] = '-';
    i = 9;
    while (i < 13) : (i += 1) {
        buf[i] = hex_chars[random.int(u8) % 16];
    }
    buf[13] = '-';
    i = 14;
    while (i < 18) : (i += 1) {
        buf[i] = hex_chars[random.int(u8) % 16];
    }
    buf[18] = '-';
    i = 19;
    while (i < 23) : (i += 1) {
        buf[i] = hex_chars[random.int(u8) % 16];
    }
    buf[23] = '-';
    i = 24;
    while (i < 36) : (i += 1) {
        buf[i] = hex_chars[random.int(u8) % 16];
    }

    return buf[0..36];
}
