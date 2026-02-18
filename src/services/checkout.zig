const std = @import("std");
const types = @import("../models/types.zig");
const checkout = @import("../models/checkout.zig");
const firearm = @import("../models/firearm.zig");
const gear = @import("../models/gear.zig");

const Database = @import("../repository/database.zig").Database;
const CheckoutRepository = @import("../repository/database.zig").CheckoutRepository;
const FirearmRepository = @import("../repository/database.zig").FirearmRepository;
const SoftGearRepository = @import("../repository/database.zig").SoftGearRepository;
const NFAItemRepository = @import("../repository/database.zig").NFAItemRepository;
const BorrowerRepository = @import("../repository/database.zig").BorrowerRepository;

pub const CheckoutService = struct {
    db: *Database,

    pub fn checkoutItem(
        self: *CheckoutService,
        allocator: std.mem.Allocator,
        item_id: []const u8,
        item_type: types.GearCategory,
        borrower_name: []const u8,
        expected_return: ?i64,
        notes: []const u8,
    ) !CheckoutResult {
        var borrower_repo = BorrowerRepository{ .db = self.db };
        const borrowers = try borrower_repo.getAll(allocator);
        defer borrower_repo.deinitAll(allocator, borrowers);

        var borrower_found: ?checkout.Borrower = null;
        for (borrowers) |b| {
            if (std.mem.eql(u8, b.name, borrower_name)) {
                borrower_found = b;
                break;
            }
        }

        if (borrower_found == null) {
            return CheckoutResult{
                .success = false,
                .message = "Borrower not found",
                .checkout_id = "",
            };
        }

        if (item_type == .firearm) {
            var firearm_repo = FirearmRepository{ .db = self.db };
            const fw = try firearm_repo.getById(allocator, item_id);
            if (fw == null) {
                return CheckoutResult{
                    .success = false,
                    .message = "Firearm not found",
                    .checkout_id = "",
                };
            }
            defer firearm_repo.deinit(allocator, fw.?);

            if (fw.?.status != .available) {
                return CheckoutResult{
                    .success = false,
                    .message = "Firearm is not available",
                    .checkout_id = "",
                };
            }

            if (fw.?.needs_maintenance) {
                return CheckoutResult{
                    .success = false,
                    .message = "Firearm needs maintenance before checkout",
                    .checkout_id = "",
                };
            }

            const now = std.time.timestamp();
            const id = try generateUuid(allocator);
            errdefer allocator.free(id);

            const new_checkout = checkout.Checkout{
                .id = id,
                .item_id = try allocator.dupe(u8, item_id),
                .item_type = item_type,
                .borrower_id = try allocator.dupe(u8, borrower_found.?.id),
                .checkout_date = now,
                .expected_return = expected_return,
                .notes = try allocator.dupe(u8, notes),
            };
            errdefer {
                allocator.free(new_checkout.item_id);
                allocator.free(new_checkout.borrower_id);
                allocator.free(new_checkout.notes);
            }

            var checkout_repo = CheckoutRepository{ .db = self.db };
            try checkout_repo.create(new_checkout);

            try firearm_repo.updateStatus(item_id, .checked_out);

            return CheckoutResult{
                .success = true,
                .message = "",
                .checkout_id = id,
            };
        } else if (item_type == .soft_gear) {
            var softgear_repo = SoftGearRepository{ .db = self.db };
            const sg = try softgear_repo.getById(allocator, item_id);
            if (sg == null) {
                return CheckoutResult{
                    .success = false,
                    .message = "Soft gear not found",
                    .checkout_id = "",
                };
            }
            defer softgear_repo.deinit(allocator, sg.?);

            if (sg.?.status != .available) {
                return CheckoutResult{
                    .success = false,
                    .message = "Soft gear is not available",
                    .checkout_id = "",
                };
            }

            const now = std.time.timestamp();
            const id = try generateUuid(allocator);
            errdefer allocator.free(id);

            const new_checkout = checkout.Checkout{
                .id = id,
                .item_id = try allocator.dupe(u8, item_id),
                .item_type = item_type,
                .borrower_id = try allocator.dupe(u8, borrower_found.?.id),
                .checkout_date = now,
                .expected_return = expected_return,
                .notes = try allocator.dupe(u8, notes),
            };
            errdefer {
                allocator.free(new_checkout.item_id);
                allocator.free(new_checkout.borrower_id);
                allocator.free(new_checkout.notes);
            }

            var checkout_repo = CheckoutRepository{ .db = self.db };
            try checkout_repo.create(new_checkout);

            try softgear_repo.update(sg.?);

            return CheckoutResult{
                .success = true,
                .message = "",
                .checkout_id = id,
            };
        }

        return CheckoutResult{
            .success = false,
            .message = "Unsupported item type",
            .checkout_id = "",
        };
    }

    pub fn returnItem(self: *CheckoutService, allocator: std.mem.Allocator, checkout_id: []const u8) !ReturnResult {
        var checkout_repo = CheckoutRepository{ .db = self.db };
        const co = try checkout_repo.getById(allocator, checkout_id);
        if (co == null) {
            return ReturnResult{ .success = false, .message = "Checkout not found" };
        }
        defer checkout_repo.deinit(allocator, co.?);

        const now = std.time.timestamp();
        var updated = co.?;
        updated.actual_return = now;

        try checkout_repo.update(updated);

        if (co.?.item_type == .firearm) {
            var firearm_repo = FirearmRepository{ .db = self.db };
            try firearm_repo.updateStatus(co.?.item_id, .available);
        } else if (co.?.item_type == .soft_gear) {
            var softgear_repo = SoftGearRepository{ .db = self.db };
            const sg = try softgear_repo.getById(allocator, co.?.item_id);
            if (sg) |s| {
                var updated_sg = s;
                updated_sg.status = .available;
                try softgear_repo.update(updated_sg);
                softgear_repo.deinit(allocator, s);
            }
        }

        return ReturnResult{ .success = true, .message = "" };
    }

    pub fn getActiveCheckouts(self: *CheckoutService, allocator: std.mem.Allocator) ![]checkout.Checkout {
        var repo = CheckoutRepository{ .db = self.db };
        return try repo.getActive(allocator);
    }

    pub fn getCheckoutHistory(self: *CheckoutService, allocator: std.mem.Allocator) ![]checkout.Checkout {
        var repo = CheckoutRepository{ .db = self.db };
        return try repo.getAll(allocator);
    }

    pub fn isItemCheckedOut(self: *CheckoutService, allocator: std.mem.Allocator, item_id: []const u8) !bool {
        var repo = CheckoutRepository{ .db = self.db };
        const all = try repo.getActive(allocator);
        defer repo.deinitAll(allocator, all);

        for (all) |co| {
            if (std.mem.eql(u8, co.item_id, item_id)) {
                return true;
            }
        }
        return false;
    }
};

pub const CheckoutResult = struct {
    success: bool,
    message: []const u8,
    checkout_id: []const u8,
};

pub const ReturnResult = struct {
    success: bool,
    message: []const u8,
};

fn generateUuid(allocator: std.mem.Allocator) ![]u8 {
    var buf: [36]u8 = undefined;
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

    return try allocator.dupe(u8, &buf);
}
