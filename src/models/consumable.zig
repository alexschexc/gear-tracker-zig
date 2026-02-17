const std = @import("std");
const types = @import("types.zig");

pub const Consumable = struct {
    id: []u8,
    name: []u8,
    category: types.ConsumableCategory,
    unit: []u8,
    quantity: i32,
    min_quantity: i32,
    notes: []u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, name: []const u8, category: types.ConsumableCategory, unit: []const u8, quantity: i32, min_quantity: i32) !*Consumable {
        const c = try allocator.create(Consumable);
        c.* = .{
            .id = try allocator.dupe(u8, id),
            .name = try allocator.dupe(u8, name),
            .category = category,
            .unit = try allocator.dupe(u8, unit),
            .quantity = quantity,
            .min_quantity = min_quantity,
        };
        return c;
    }

    pub fn deinit(self: *Consumable, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        allocator.free(self.unit);
        allocator.free(self.notes);
        allocator.destroy(self);
    }

    pub fn isLow(self: *const Consumable) bool {
        return self.quantity <= self.min_quantity;
    }
};

pub const ConsumableTransaction = struct {
    id: []u8,
    consumable_id: []u8,
    transaction_type: types.TransactionType,
    quantity: i32,
    date: i64,
    notes: []u8 = &.{},

    pub fn init(allocator: std.mem.Allocator, id: []const u8, consumable_id: []const u8, transaction_type: types.TransactionType, quantity: i32, date: i64) !*ConsumableTransaction {
        const t = try allocator.create(ConsumableTransaction);
        t.* = .{
            .id = try allocator.dupe(u8, id),
            .consumable_id = try allocator.dupe(u8, consumable_id),
            .transaction_type = transaction_type,
            .quantity = quantity,
            .date = date,
        };
        return t;
    }

    pub fn deinit(self: *ConsumableTransaction, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.consumable_id);
        allocator.free(self.notes);
        allocator.destroy(self);
    }
};
