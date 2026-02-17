const std = @import("std");
const types = @import("types.zig");

pub const MaintenanceLog = struct {
    id: []u8,
    item_id: []u8,
    item_type: types.GearCategory,
    log_type: types.MaintenanceType,
    date: i64,
    details: []u8 = &.{},
    ammo_count: ?i32 = null,
    photo_path: ?[]u8 = null,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, item_id: []const u8, item_type: types.GearCategory, log_type: types.MaintenanceType, date: i64) !*MaintenanceLog {
        const m = try allocator.create(MaintenanceLog);
        m.* = .{
            .id = try allocator.dupe(u8, id),
            .item_id = try allocator.dupe(u8, item_id),
            .item_type = item_type,
            .log_type = log_type,
            .date = date,
        };
        return m;
    }

    pub fn deinit(self: *MaintenanceLog, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.item_id);
        allocator.free(self.details);
        if (self.photo_path) |p| allocator.free(p);
        allocator.destroy(self);
    }
};
