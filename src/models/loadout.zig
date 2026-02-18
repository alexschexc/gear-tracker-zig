const std = @import("std");
const types = @import("types.zig");

pub const Loadout = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8 = &.{},
    created_date: i64,
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, created_date: i64) !*Loadout {
        const l = try allocator.create(Loadout);
        l.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .created_date = created_date,
        };
        return l;
    }

    pub fn deinit(self: *Loadout, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};

pub const LoadoutItem = struct {
    id: []const u8,
    loadout_id: []const u8,
    item_id: []const u8,
    item_type: types.GearCategory,
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, loadout_id: []const u8, item_id: []const u8, item_type: types.GearCategory) !*LoadoutItem {
        const li = try allocator.create(LoadoutItem);
        li.* = .{
            .id = try allocator.dupe(u8, id),
            .loadout_id = try allocator.dupe(u8, loadout_id),
            .item_id = try allocator.dupe(u8, item_id),
            .item_type = item_type,
        };
        return li;
    }

    pub fn deinit(self: *LoadoutItem, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.loadout_id);
        allocator.free(self.item_id);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};

pub const LoadoutConsumable = struct {
    id: []const u8,
    loadout_id: []const u8,
    consumable_id: []const u8,
    quantity: i32,
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, loadout_id: []const u8, consumable_id: []const u8, quantity: i32) !*LoadoutConsumable {
        const lc = try allocator.create(LoadoutConsumable);
        lc.* = .{
            .id = try allocator.dupe(u8, id),
            .loadout_id = try allocator.dupe(u8, loadout_id),
            .consumable_id = try allocator.dupe(u8, consumable_id),
            .quantity = quantity,
        };
        return lc;
    }

    pub fn deinit(self: *LoadoutConsumable, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.loadout_id);
        allocator.free(self.consumable_id);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};

pub const LoadoutCheckout = struct {
    id: []const u8,
    loadout_id: []const u8,
    checkout_id: []const u8,
    return_date: ?i64 = null,
    rounds_fired: i32 = 0,
    rain_exposure: bool = false,
    ammo_type: []const u8 = &.{},
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, loadout_id: []const u8, checkout_id: []const u8) !*LoadoutCheckout {
        const lc = try allocator.create(LoadoutCheckout);
        lc.* = .{
            .id = try allocator.dupe(u8, id),
            .loadout_id = try allocator.dupe(u8, loadout_id),
            .checkout_id = try allocator.dupe(u8, checkout_id),
        };
        return lc;
    }

    pub fn deinit(self: *LoadoutCheckout, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.loadout_id);
        allocator.free(self.checkout_id);
        allocator.free(self.ammo_type);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
