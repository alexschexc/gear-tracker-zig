const std = @import("std");
const types = @import("../models/types.zig");
const loadout = @import("../models/loadout.zig");

const Database = @import("../repository/database.zig").Database;
const LoadoutRepository = @import("../repository/database.zig").LoadoutRepository;
const LoadoutItemRepository = @import("../repository/database.zig").LoadoutItemRepository;
const LoadoutConsumableRepository = @import("../repository/database.zig").LoadoutConsumableRepository;
const LoadoutCheckoutRepository = @import("../repository/database.zig").LoadoutCheckoutRepository;

pub const LoadoutService = struct {
    db: *Database,

    pub fn createLoadout(self: *LoadoutService, allocator: std.mem.Allocator, name: []const u8, description: []const u8, notes: []const u8) !loadout.Loadout {
        _ = allocator;
        var repo = LoadoutRepository{ .db = self.db };
        const now = std.time.timestamp();

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const new_loadout = loadout.Loadout{
            .id = id,
            .name = name,
            .description = description,
            .created_date = now,
            .notes = notes,
        };
        try repo.create(new_loadout);

        return new_loadout;
    }

    pub fn getAllLoadouts(self: *LoadoutService, allocator: std.mem.Allocator) ![]loadout.Loadout {
        var repo = LoadoutRepository{ .db = self.db };
        return try repo.getAll(allocator);
    }

    pub fn getLoadoutById(self: *LoadoutService, allocator: std.mem.Allocator, id: []const u8) !?loadout.Loadout {
        var repo = LoadoutRepository{ .db = self.db };
        return try repo.getById(allocator, id);
    }

    pub fn updateLoadout(self: *LoadoutService, l: loadout.Loadout) !void {
        var repo = LoadoutRepository{ .db = self.db };
        try repo.update(l);
    }

    pub fn deleteLoadout(self: *LoadoutService, id: []const u8) !void {
        var item_repo = LoadoutItemRepository{ .db = self.db };
        var consumable_repo = LoadoutConsumableRepository{ .db = self.db };
        var checkout_repo = LoadoutCheckoutRepository{ .db = self.db };
        var loadout_repo = LoadoutRepository{ .db = self.db };

        const items = try item_repo.getByLoadoutId(std.heap.page_allocator, id);
        for (items) |item| {
            std.heap.page_allocator.free(item.id);
            std.heap.page_allocator.free(item.loadout_id);
            std.heap.page_allocator.free(item.item_id);
            std.heap.page_allocator.free(item.notes);
        }
        std.heap.page_allocator.free(items);

        const consumables = try consumable_repo.getByLoadoutId(std.heap.page_allocator, id);
        for (consumables) |c| {
            std.heap.page_allocator.free(c.id);
            std.heap.page_allocator.free(c.loadout_id);
            std.heap.page_allocator.free(c.consumable_id);
            std.heap.page_allocator.free(c.notes);
        }
        std.heap.page_allocator.free(consumables);

        const checkouts = try checkout_repo.getByLoadoutId(std.heap.page_allocator, id);
        for (checkouts) |c| {
            std.heap.page_allocator.free(c.id);
            std.heap.page_allocator.free(c.loadout_id);
            std.heap.page_allocator.free(c.checkout_id);
        }
        std.heap.page_allocator.free(checkouts);

        try loadout_repo.delete(id);
    }

    pub fn addItemToLoadout(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8, item_id: []const u8, item_type: types.GearCategory, notes: []const u8) !loadout.LoadoutItem {
        _ = allocator;
        var repo = LoadoutItemRepository{ .db = self.db };

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const item = loadout.LoadoutItem{
            .id = id,
            .loadout_id = loadout_id,
            .item_id = item_id,
            .item_type = item_type,
            .notes = notes,
        };
        try repo.create(item);

        return item;
    }

    pub fn removeItemFromLoadout(self: *LoadoutService, item_id: []const u8) !void {
        var repo = LoadoutItemRepository{ .db = self.db };
        try repo.delete(item_id);
    }

    pub fn getLoadoutItems(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutItem {
        var repo = LoadoutItemRepository{ .db = self.db };
        return try repo.getByLoadoutId(allocator, loadout_id);
    }

    pub fn addConsumableToLoadout(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8, consumable_id: []const u8, quantity: i32, notes: []const u8) !loadout.LoadoutConsumable {
        _ = allocator;
        var repo = LoadoutConsumableRepository{ .db = self.db };

        var id_buf: [36]u8 = undefined;
        const id = try generateUuidStr(&id_buf);

        const item = loadout.LoadoutConsumable{
            .id = id,
            .loadout_id = loadout_id,
            .consumable_id = consumable_id,
            .quantity = quantity,
            .notes = notes,
        };
        try repo.create(item);

        return item;
    }

    pub fn removeConsumableFromLoadout(self: *LoadoutService, consumable_id: []const u8) !void {
        var repo = LoadoutConsumableRepository{ .db = self.db };
        try repo.delete(consumable_id);
    }

    pub fn getLoadoutConsumables(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutConsumable {
        var repo = LoadoutConsumableRepository{ .db = self.db };
        return try repo.getByLoadoutId(allocator, loadout_id);
    }

    pub fn checkoutLoadout(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8, borrower_name: []const u8, expected_return: ?i64, notes: []const u8) !LoadoutCheckoutResult {
        _ = borrower_name;
        _ = expected_return;
        var loadout_repo = LoadoutRepository{ .db = self.db };
        const lo = try loadout_repo.getById(allocator, loadout_id);
        if (lo == null) {
            return LoadoutCheckoutResult{
                .success = false,
                .message = "Loadout not found",
                .loadout_checkout_id = "",
            };
        }
        defer loadout_repo.deinit(allocator, lo.?);

        var items_repo = LoadoutItemRepository{ .db = self.db };
        const items = try items_repo.getByLoadoutId(allocator, loadout_id);
        defer items_repo.deinitAll(allocator, items);

        var checkout_repo = LoadoutCheckoutRepository{ .db = self.db };
        var id_buf: [36]u8 = undefined;
        const checkout_id = try generateUuidStr(&id_buf);

        const loadout_checkout = loadout.LoadoutCheckout{
            .id = checkout_id,
            .loadout_id = loadout_id,
            .checkout_id = "",
            .notes = notes,
        };
        try checkout_repo.create(loadout_checkout);

        return LoadoutCheckoutResult{
            .success = true,
            .message = "",
            .loadout_checkout_id = checkout_id,
        };
    }

    pub fn getLoadoutCheckouts(self: *LoadoutService, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutCheckout {
        var repo = LoadoutCheckoutRepository{ .db = self.db };
        return try repo.getByLoadoutId(allocator, loadout_id);
    }
};

pub const LoadoutCheckoutResult = struct {
    success: bool,
    message: []const u8,
    loadout_checkout_id: []const u8,
};

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
