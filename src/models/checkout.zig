const std = @import("std");
const types = @import("types.zig");

pub const Checkout = struct {
    id: []const u8,
    item_id: []const u8,
    item_type: types.GearCategory,
    borrower_id: []const u8,
    checkout_date: i64,
    expected_return: ?i64 = null,
    actual_return: ?i64 = null,
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, item_id: []const u8, item_type: types.GearCategory, borrower_id: []const u8, checkout_date: i64) !*Checkout {
        const c = try allocator.create(Checkout);
        c.* = .{
            .id = try allocator.dupe(u8, id),
            .item_id = try allocator.dupe(u8, item_id),
            .item_type = item_type,
            .borrower_id = try allocator.dupe(u8, borrower_id),
            .checkout_date = checkout_date,
        };
        return c;
    }

    pub fn deinit(self: *Checkout, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.item_id);
        allocator.free(self.borrower_id);
        allocator.free(self.notes);
        allocator.destroy(self);
    }

    pub fn isActive(self: *const Checkout) bool {
        return self.actual_return == null;
    }
};

pub const Borrower = struct {
    id: []const u8,
    name: []const u8,
    phone: []const u8 = &.{},
    email: []const u8 = &.{},
    notes: []const u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8) !*Borrower {
        const b = try allocator.create(Borrower);
        b.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
        };
        return b;
    }

    pub fn deinit(self: *Borrower, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.phone);
        allocator.free(self.email);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
