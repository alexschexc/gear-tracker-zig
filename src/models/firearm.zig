const std = @import("std");
const types = @import("types.zig");

pub const Firearm = struct {
    id: []const u8,
    name: []const u8,
    caliber: []const u8,
    serial_number: []const u8,
    purchase_date: i64,
    notes: []const u8 = &.{},
    status: types.CheckoutStatus = .available,
    is_nfa: bool = false,
    nfa_type: ?types.NFAFirearmType = null,
    tax_stamp_id: []const u8 = &.{},
    form_type: []const u8 = &.{},
    barrel_length: []const u8 = &.{},
    trust_name: []const u8 = &.{},
    transfer_status: types.TransferStatus = .owned,
    rounds_fired: i32 = 0,
    clean_interval_rounds: i32 = 500,
    oil_interval_days: i32 = 90,
    needs_maintenance: bool = false,
    maintenance_conditions: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, caliber: []const u8, serial: []const u8, purchase_date: i64) !*Firearm {
        const fw = try allocator.create(Firearm);
        fw.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .caliber = try allocator.dupe(u8, caliber),
            .serial_number = try allocator.dupe(u8, serial),
            .purchase_date = purchase_date,
        };
        return fw;
    }

    pub fn deinit(self: *Firearm, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.caliber);
        allocator.free(self.serial_number);
        allocator.free(self.notes);
        allocator.free(self.tax_stamp_id);
        allocator.free(self.form_type);
        allocator.free(self.barrel_length);
        allocator.free(self.trust_name);
        allocator.free(self.maintenance_conditions);
        allocator.destroy(self);
    }

    pub fn checkMaintenance(self: *const Firearm) bool {
        return self.rounds_fired >= self.clean_interval_rounds;
    }
};

pub const Transfer = struct {
    id: []u8,
    firearm_id: []u8,
    transfer_date: i64,
    buyer_name: []u8,
    buyer_address: []u8,
    buyer_dl_number: []u8,
    buyer_ltc_number: []u8 = &.{},
    sale_price: f64 = 0.0,
    ffl_dealer: []u8 = &.{},
    ffl_license: []u8 = &.{},
    notes: []u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, firearm_id: []const u8, transfer_date: i64, buyer_name: []const u8, buyer_address: []const u8, buyer_dl: []const u8) !*Transfer {
        const t = try allocator.create(Transfer);
        t.* = .{
            .id = try allocator.dupe(u8, id),
            .firearm_id = try allocator.dupe(u8, firearm_id),
            .transfer_date = transfer_date,
            .buyer_name = try allocator.dupe(u8, buyer_name),
            .buyer_address = try allocator.dupe(u8, buyer_address),
            .buyer_dl_number = try allocator.dupe(u8, buyer_dl),
        };
        return t;
    }

    pub fn deinit(self: *Transfer, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.firearm_id);
        allocator.free(self.buyer_name);
        allocator.free(self.buyer_address);
        allocator.free(self.buyer_dl_number);
        allocator.free(self.buyer_ltc_number);
        allocator.free(self.ffl_dealer);
        allocator.free(self.ffl_license);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
