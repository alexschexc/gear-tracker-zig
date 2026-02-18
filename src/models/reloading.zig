const std = @import("std");
const types = @import("types.zig");

pub const ReloadBatch = struct {
    id: []const u8,
    cartridge: []const u8,
    firearm_id: ?[]const u8 = null,
    date_created: i64,
    bullet_maker: []const u8 = &.{},
    bullet_model: []const u8 = &.{},
    bullet_weight_gr: ?i32 = null,
    powder_name: []const u8 = &.{},
    powder_charge_gr: ?f64 = null,
    powder_lot: []const u8 = &.{},
    primer_maker: []const u8 = &.{},
    primer_type: []const u8 = &.{},
    case_brand: []const u8 = &.{},
    case_times_fired: ?i32 = null,
    case_prep_notes: []const u8 = &.{},
    coal_in: ?f64 = null,
    crimp_style: []const u8 = &.{},
    test_date: ?i64 = null,
    avg_velocity: ?i32 = null,
    es: ?i32 = null,
    sd: ?i32 = null,
    group_size_inches: ?f64 = null,
    group_distance_yards: ?i32 = null,
    intended_use: []const u8 = &.{},
    status: types.ReloadStatus = .workup,
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, cartridge: []const u8, date_created: i64) !*ReloadBatch {
        const rb = try allocator.create(ReloadBatch);
        rb.* = .{
            .id = try allocator.dupe(u8, id),
            .cartridge = try allocator.dupe(u8, cartridge),
            .date_created = date_created,
        };
        return rb;
    }

    pub fn deinit(self: *ReloadBatch, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.cartridge);
        if (self.firearm_id) |id| allocator.free(id);
        allocator.free(self.bullet_maker);
        allocator.free(self.bullet_model);
        allocator.free(self.powder_name);
        allocator.free(self.powder_lot);
        allocator.free(self.primer_maker);
        allocator.free(self.primer_type);
        allocator.free(self.case_brand);
        allocator.free(self.case_prep_notes);
        allocator.free(self.crimp_style);
        allocator.free(self.intended_use);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
