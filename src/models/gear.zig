const std = @import("std");
const types = @import("types.zig");

pub const SoftGear = struct {
    id: []const u8,
    name: []const u8,
    category: []const u8,
    brand: []const u8,
    purchase_date: i64,
    notes: []const u8 = &.{},
    status: types.CheckoutStatus = .available,

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, category: []const u8, brand: []const u8, purchase_date: i64) !*SoftGear {
        const gear = try allocator.create(SoftGear);
        gear.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .category = try allocator.dupe(u8, category),
            .brand = try allocator.dupe(u8, brand),
            .purchase_date = purchase_date,
        };
        return gear;
    }

    pub fn deinit(self: *SoftGear, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.category);
        allocator.free(self.brand);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};

pub const NFAItem = struct {
    id: []const u8,
    name: []const u8,
    nfa_type: types.NFAItemType,
    manufacturer: []const u8,
    serial_number: []const u8,
    tax_stamp_id: []const u8,
    caliber_bore: []const u8,
    purchase_date: i64,
    form_type: []const u8 = &.{},
    trust_name: []const u8 = &.{},
    notes: []const u8 = &.{},
    status: types.CheckoutStatus = .available,
    rounds_fired: i32 = 0,
    clean_interval_rounds: i32 = 500,
    oil_interval_days: i32 = 90,
    needs_maintenance: bool = false,
    maintenance_conditions: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, nfa_type: types.NFAItemType, manufacturer: []const u8, serial: []const u8, tax_stamp: []const u8, caliber: []const u8, purchase_date: i64) !*NFAItem {
        const item = try allocator.create(NFAItem);
        item.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .nfa_type = nfa_type,
            .manufacturer = try allocator.dupe(u8, manufacturer),
            .serial_number = try allocator.dupe(u8, serial),
            .tax_stamp_id = try allocator.dupe(u8, tax_stamp),
            .caliber_bore = try allocator.dupe(u8, caliber),
            .purchase_date = purchase_date,
        };
        return item;
    }

    pub fn deinit(self: *NFAItem, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.manufacturer);
        allocator.free(self.serial_number);
        allocator.free(self.tax_stamp_id);
        allocator.free(self.caliber_bore);
        allocator.free(self.form_type);
        allocator.free(self.trust_name);
        allocator.free(self.notes);
        allocator.free(self.maintenance_conditions);
        allocator.destroy(self);
    }
};

pub const Attachment = struct {
    id: []const u8,
    name: []const u8,
    category: []const u8,
    brand: []const u8,
    model: []const u8,
    purchase_date: i64,
    serial_number: []const u8 = &.{},
    mounted_on_firearm_id: ?[]const u8 = null,
    mount_position: []const u8 = &.{},
    zero_distance_yards: ?i32 = null,
    zero_notes: []const u8 = &.{},
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, category: []const u8, brand: []const u8, model: []const u8, purchase_date: i64) !*Attachment {
        const att = try allocator.create(Attachment);
        att.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .category = try allocator.dupe(u8, category),
            .brand = try allocator.dupe(u8, brand),
            .model = try allocator.dupe(u8, model),
            .purchase_date = purchase_date,
        };
        return att;
    }

    pub fn deinit(self: *Attachment, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.category);
        allocator.free(self.brand);
        allocator.free(self.model);
        allocator.free(self.serial_number);
        if (self.mounted_on_firearm_id) |id| allocator.free(id);
        allocator.free(self.mount_position);
        allocator.free(self.zero_notes);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
