const std = @import("std");
const c = @cImport(@cInclude("sqlite3.h"));
const types = @import("../models/types.zig");
const firearm = @import("../models/firearm.zig");

pub const Database = struct {
    db: ?*c.sqlite3,

    pub fn init(allocator: std.mem.Allocator, db_path: []const u8) !Database {
        std.debug.print("1. Starting init\n", .{});

        var db_ref: ?*c.sqlite3 = null;
        std.debug.print("2. db_ref initialized\n", .{});

        const path_len = db_path.len;
        const path_buf = try allocator.alloc(u8, path_len + 1);
        defer allocator.free(path_buf);
        @memcpy(path_buf[0..path_len], db_path);
        path_buf[path_len] = 0;
        std.debug.print("3. path_buf created: {s}\n", .{path_buf[0..path_len]});

        std.debug.print("4. About to call sqlite3\n", .{});

        const open_result = c.sqlite3_open(@as([*c]const u8, @ptrCast(path_buf.ptr)), @as([*c]?*c.sqlite3, @ptrCast(&db_ref)));
        std.debug.print("5. sqlite3_open result: {d}\n", .{open_result});

        if (open_result != 0) {
            std.debug.print("Failed to open database, error code: {d}\n", .{open_result});
            if (db_ref) |db| {
                const err_msg = c.sqlite3_errmsg(db);
                if (err_msg != 0) {
                    std.debug.print("SQLite error: {s}\n", .{err_msg});
                }
            }
            return error.OpenFailed;
        }

        const db = db_ref orelse return error.OpenFailed;
        std.debug.print("7. Database opened: {*}\n", .{db});
        errdefer _ = c.sqlite3_close(db);

        const exec_result = c.sqlite3_exec(db, "PRAGMA journal_mode = WAL;", null, null, null);
        std.debug.print("8. PRAGMA result: {d}\n", .{exec_result});

        try initSchema(db);

        return Database{ .db = db };
    }

    pub fn deinit(self: *Database) void {
        if (self.db) |db| {
            _ = c.sqlite3_close(db);
        }
    }

    pub fn prepare(self: *Database, sql: [:0]const u8) !?*c.sqlite3_stmt {
        var stmt: ?*c.sqlite3_stmt = null;
        const result = c.sqlite3_prepare_v2(self.db, sql, -1, &stmt, null);
        if (result != c.SQLITE_OK) {
            const err_msg = c.sqlite3_errmsg(self.db);
            if (err_msg != 0) {
                std.debug.print("Prepare error: {s}\n", .{err_msg});
            }
            return error.PrepareFailed;
        }
        return stmt;
    }

    pub fn step(self: *Database, stmt: *c.sqlite3_stmt) !bool {
        const result = c.sqlite3_step(stmt);
        if (result == c.SQLITE_ROW) {
            return true;
        } else if (result == c.SQLITE_DONE) {
            return false;
        } else {
            const err_msg = c.sqlite3_errmsg(self.db);
            if (err_msg != 0) {
                std.debug.print("Step error: {s}\n", .{err_msg});
            }
            return error.StepFailed;
        }
    }

    pub fn columnText(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) []const u8 {
        const text = c.sqlite3_column_text(stmt, col);
        if (text == null) {
            return "";
        }
        return std.mem.span(@as([*:0]const u8, @ptrCast(text)));
    }

    pub fn columnInt(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) c_int {
        return c.sqlite3_column_int(stmt, col);
    }

    pub fn columnInt64(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) c_longlong {
        return c.sqlite3_column_int64(stmt, col);
    }

    pub fn finalize(_: *Database, stmt: *c.sqlite3_stmt) void {
        _ = c.sqlite3_finalize(stmt);
    }

    pub fn exec(self: *Database, sql: [:0]const u8) !void {
        const result = c.sqlite3_exec(self.db, sql, null, null, null);
        if (result != c.SQLITE_OK) {
            const err_msg = c.sqlite3_errmsg(self.db);
            if (err_msg != 0) {
                std.debug.print("Exec error: {s}\n", .{err_msg});
            }
            return error.ExecFailed;
        }
    }
};

fn execSQL(db: *c.sqlite3, sql: [:0]const u8) !void {
    const result = c.sqlite3_exec(db, sql, null, null, null);
    if (result != c.SQLITE_OK) {
        const err_msg = c.sqlite3_errmsg(db);
        if (err_msg != 0) {
            std.debug.print("SQL Error: {s}\n", .{err_msg});
        }
        return error.ExecFailed;
    }
}

fn initSchema(db: *c.sqlite3) !void {
    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS firearms (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     caliber TEXT NOT NULL,
        \\     serial_number TEXT UNIQUE,
        \\     purchase_date INTEGER NOT NULL,
        \\     notes TEXT,
        \\     status TEXT DEFAULT 'AVAILABLE',
        \\     is_nfa INTEGER DEFAULT 0,
        \\     nfa_type TEXT,
        \\     tax_stamp_id TEXT DEFAULT '',
        \\     form_type TEXT DEFAULT '',
        \\     barrel_length TEXT DEFAULT '',
        \\     trust_name TEXT DEFAULT '',
        \\     transfer_status TEXT DEFAULT 'OWNED',
        \\     rounds_fired INTEGER DEFAULT 0,
        \\     clean_interval_rounds INTEGER DEFAULT 500,
        \\     oil_interval_days INTEGER DEFAULT 90,
        \\     needs_maintenance INTEGER DEFAULT 0,
        \\     maintenance_conditions TEXT DEFAULT ''
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS soft_gear (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     category TEXT NOT NULL,
        \\     brand TEXT,
        \\     purchase_date INTEGER NOT NULL,
        \\     notes TEXT,
        \\     status TEXT DEFAULT 'AVAILABLE'
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS consumables (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     category TEXT NOT NULL,
        \\     unit TEXT NOT NULL,
        \\     quantity INTEGER NOT NULL DEFAULT 0,
        \\     min_quantity INTEGER NOT NULL DEFAULT 0,
        \\     notes TEXT
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS consumable_transactions (
        \\     id TEXT PRIMARY KEY,
        \\     consumable_id TEXT NOT NULL,
        \\     transaction_type TEXT NOT NULL,
        \\     quantity INTEGER NOT NULL,
        \\     date INTEGER NOT NULL,
        \\     notes TEXT,
        \\     FOREIGN KEY(consumable_id) REFERENCES consumables(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS maintenance_logs (
        \\     id TEXT PRIMARY KEY,
        \\     item_id TEXT NOT NULL,
        \\     item_type TEXT NOT NULL,
        \\     log_type TEXT NOT NULL,
        \\     date INTEGER NOT NULL,
        \\     details TEXT,
        \\     ammo_count INTEGER,
        \\     photo_path TEXT
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS borrowers (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     phone TEXT,
        \\     email TEXT,
        \\     notes TEXT
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS checkouts (
        \\     id TEXT PRIMARY KEY,
        \\     item_id TEXT NOT NULL,
        \\     item_type TEXT NOT NULL,
        \\     borrower_id TEXT NOT NULL,
        \\     checkout_date INTEGER NOT NULL,
        \\     expected_return INTEGER,
        \\     actual_return INTEGER,
        \\     notes TEXT,
        \\     FOREIGN KEY(borrower_id) REFERENCES borrowers(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS nfa_items (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     nfa_type TEXT NOT NULL,
        \\     manufacturer TEXT,
        \\     serial_number TEXT,
        \\     tax_stamp_id TEXT NOT NULL,
        \\     caliber_bore TEXT,
        \\     purchase_date INTEGER NOT NULL,
        \\     form_type TEXT,
        \\     trust_name TEXT,
        \\     notes TEXT,
        \\     status TEXT DEFAULT 'AVAILABLE',
        \\     rounds_fired INTEGER DEFAULT 0,
        \\     clean_interval_rounds INTEGER DEFAULT 500,
        \\     oil_interval_days INTEGER DEFAULT 90,
        \\     needs_maintenance INTEGER DEFAULT 0,
        \\     maintenance_conditions TEXT DEFAULT ''
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS transfers (
        \\     id TEXT PRIMARY KEY,
        \\     firearm_id TEXT NOT NULL,
        \\     transfer_date INTEGER NOT NULL,
        \\     buyer_name TEXT NOT NULL,
        \\     buyer_address TEXT NOT NULL,
        \\     buyer_dl_number TEXT NOT NULL,
        \\     buyer_ltc_number TEXT,
        \\     sale_price REAL,
        \\     ffl_dealer TEXT,
        \\     ffl_license TEXT,
        \\     notes TEXT,
        \\     FOREIGN KEY(firearm_id) REFERENCES firearms(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS attachments (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     category TEXT NOT NULL,
        \\     brand TEXT,
        \\     model TEXT,
        \\     serial_number TEXT,
        \\     purchase_date INTEGER,
        \\     mounted_on_firearm_id TEXT,
        \\     mount_position TEXT,
        \\     zero_distance_yards INTEGER,
        \\     zero_notes TEXT,
        \\     notes TEXT,
        \\     FOREIGN KEY(mounted_on_firearm_id) REFERENCES firearms(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS reload_batches (
        \\     id TEXT PRIMARY KEY,
        \\     cartridge TEXT NOT NULL,
        \\     firearm_id TEXT,
        \\     date_created INTEGER NOT NULL,
        \\     bullet_maker TEXT,
        \\     bullet_model TEXT,
        \\     bullet_weight_gr INTEGER,
        \\     powder_name TEXT,
        \\     powder_charge_gr REAL,
        \\     powder_lot TEXT,
        \\     primer_maker TEXT,
        \\     primer_type TEXT,
        \\     case_brand TEXT,
        \\     case_times_fired INTEGER,
        \\     case_prep_notes TEXT,
        \\     coal_in REAL,
        \\     crimp_style TEXT,
        \\     test_date INTEGER,
        \\     avg_velocity INTEGER,
        \\     es INTEGER,
        \\     sd INTEGER,
        \\     group_size_inches REAL,
        \\     group_distance_yards INTEGER,
        \\     intended_use TEXT,
        \\     status TEXT,
        \\     notes TEXT,
        \\     FOREIGN KEY(firearm_id) REFERENCES firearms(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS loadouts (
        \\     id TEXT PRIMARY KEY,
        \\     name TEXT NOT NULL,
        \\     description TEXT,
        \\     created_date INTEGER NOT NULL,
        \\     notes TEXT
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS loadout_items (
        \\     id TEXT PRIMARY KEY,
        \\     loadout_id TEXT NOT NULL,
        \\     item_id TEXT NOT NULL,
        \\     item_type TEXT NOT NULL,
        \\     notes TEXT,
        \\     FOREIGN KEY(loadout_id) REFERENCES loadouts(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS loadout_consumables (
        \\     id TEXT PRIMARY KEY,
        \\     loadout_id TEXT NOT NULL,
        \\     consumable_id TEXT NOT NULL,
        \\     quantity INTEGER NOT NULL,
        \\     notes TEXT,
        \\     FOREIGN KEY(loadout_id) REFERENCES loadouts(id),
        \\     FOREIGN KEY(consumable_id) REFERENCES consumables(id)
        \\ )
    );

    try execSQL(db,
        \\ CREATE TABLE IF NOT EXISTS loadout_checkouts (
        \\     id TEXT PRIMARY KEY,
        \\     loadout_id TEXT NOT NULL,
        \\     checkout_id TEXT NOT NULL,
        \\     return_date INTEGER,
        \\     rounds_fired INTEGER DEFAULT 0,
        \\     rain_exposure INTEGER DEFAULT 0,
        \\     ammo_type TEXT,
        \\     notes TEXT,
        \\     FOREIGN KEY(loadout_id) REFERENCES loadouts(id),
        \\     FOREIGN KEY(checkout_id) REFERENCES checkouts(id)
        \\ )
    );
}

pub const FirearmRepository = struct {
    db: *Database,

    pub fn create(self: *FirearmRepository, fw: firearm.Firearm) !void {
        const sql = "INSERT INTO firearms VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        const now = std.time.timestamp();

        _ = c.sqlite3_bind_text(stmt, 1, fw.id.ptr, @intCast(fw.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, fw.name.ptr, @intCast(fw.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, fw.caliber.ptr, @intCast(fw.caliber.len), null);
        if (fw.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, fw.serial_number.ptr, @intCast(fw.serial_number.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 5, fw.purchase_date);
        if (fw.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, fw.notes.ptr, @intCast(fw.notes.len), null);
        }
        const status_str = types.CheckoutStatus.toString(fw.status);
        _ = c.sqlite3_bind_text(stmt, 7, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 8, if (fw.is_nfa) 1 else 0);
        if (fw.nfa_type) |nfa| {
            const nfa_str = types.NFAFirearmType.toString(nfa);
            _ = c.sqlite3_bind_text(stmt, 9, nfa_str.ptr, @intCast(nfa_str.len), null);
        }
        if (fw.tax_stamp_id.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, fw.tax_stamp_id.ptr, @intCast(fw.tax_stamp_id.len), null);
        }
        if (fw.form_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, fw.form_type.ptr, @intCast(fw.form_type.len), null);
        }
        if (fw.barrel_length.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 12, fw.barrel_length.ptr, @intCast(fw.barrel_length.len), null);
        }
        if (fw.trust_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 13, fw.trust_name.ptr, @intCast(fw.trust_name.len), null);
        }
        const transfer_str = types.TransferStatus.toString(fw.transfer_status);
        _ = c.sqlite3_bind_text(stmt, 14, transfer_str.ptr, @intCast(transfer_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 15, fw.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 16, fw.clean_interval_rounds);
        _ = c.sqlite3_bind_int(stmt, 17, fw.oil_interval_days);
        _ = c.sqlite3_bind_int(stmt, 18, if (fw.needs_maintenance) 1 else 0);
        if (fw.maintenance_conditions.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 19, fw.maintenance_conditions.ptr, @intCast(fw.maintenance_conditions.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 20, 0); // last_cleaned_at
        _ = c.sqlite3_bind_int64(stmt, 21, 0); // last_oiled_at
        _ = c.sqlite3_bind_int64(stmt, 22, now); // created_at
        _ = c.sqlite3_bind_int64(stmt, 23, now); // updated_at

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *FirearmRepository, allocator: std.mem.Allocator) ![]firearm.Firearm {
        const sql = "SELECT id, name, caliber, serial_number, purchase_date, notes, status, is_nfa, nfa_type, tax_stamp_id, form_type, barrel_length, trust_name, transfer_status, rounds_fired, clean_interval_rounds, oil_interval_days, needs_maintenance, maintenance_conditions, last_cleaned_at, last_oiled_at, created_at, updated_at FROM firearms WHERE transfer_status = 'OWNED' OR transfer_status IS NULL ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(firearm.Firearm){};
        errdefer {
            for (items.items) |*fw| {
                allocator.free(fw.id);
                allocator.free(fw.name);
                allocator.free(fw.caliber);
                allocator.free(fw.serial_number);
                allocator.free(fw.notes);
                allocator.free(fw.tax_stamp_id);
                allocator.free(fw.form_type);
                allocator.free(fw.barrel_length);
                allocator.free(fw.trust_name);
                allocator.free(fw.maintenance_conditions);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const fw = try self.rowToFirearm(stmt, allocator);
            try items.append(allocator, fw);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *FirearmRepository, allocator: std.mem.Allocator, id: []const u8) !?firearm.Firearm {
        const sql = "SELECT * FROM firearms WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToFirearm(stmt, allocator);
        }
        return null;
    }

    pub fn updateStatus(self: *FirearmRepository, id: []const u8, status: types.CheckoutStatus) !void {
        const status_str = types.CheckoutStatus.toString(status);
        var buf: [64]u8 = undefined;
        const sql = try std.fmt.bufPrint(&buf, "UPDATE firearms SET status = '{s}' WHERE id = ?\x00", .{status_str});
        const stmt_opt = try self.db.prepare(sql[0 .. sql.len - 1 :0]);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *FirearmRepository, id: []const u8) !void {
        try self.db.exec("DELETE FROM maintenance_logs WHERE item_id = ?");
        try self.db.exec("DELETE FROM checkouts WHERE item_id = ?");

        var buf: [256]u8 = undefined;
        const sql = try std.fmt.bufPrint(&buf, "DELETE FROM firearms WHERE id = '{s}'\x00", .{id});
        try self.db.exec(sql[0 .. sql.len - 1 :0]);
    }

    fn rowToFirearm(self: *FirearmRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !firearm.Firearm {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const caliber = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const serial = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const purchase_date = self.db.columnInt64(stmt, 4);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const status_str = self.db.columnText(stmt, 6);
        const is_nfa = self.db.columnInt(stmt, 7) != 0;
        const nfa_type_str = self.db.columnText(stmt, 8);
        const tax_stamp_id = try allocator.dupe(u8, self.db.columnText(stmt, 9));
        const form_type = try allocator.dupe(u8, self.db.columnText(stmt, 10));
        const barrel_length = try allocator.dupe(u8, self.db.columnText(stmt, 11));
        const trust_name = try allocator.dupe(u8, self.db.columnText(stmt, 12));
        const transfer_str = self.db.columnText(stmt, 13);
        const rounds_fired = self.db.columnInt(stmt, 14);
        const clean_interval = self.db.columnInt(stmt, 15);
        const oil_interval = self.db.columnInt(stmt, 16);
        const needs_maintenance = self.db.columnInt(stmt, 17) != 0;
        const maintenance_conditions = try allocator.dupe(u8, self.db.columnText(stmt, 18));

        return .{
            .id = id,
            .name = name,
            .caliber = caliber,
            .serial_number = serial,
            .purchase_date = purchase_date,
            .notes = notes,
            .status = types.CheckoutStatus.fromString(status_str),
            .is_nfa = is_nfa,
            .nfa_type = if (nfa_type_str.len > 0) types.NFAFirearmType.fromString(nfa_type_str) else null,
            .tax_stamp_id = tax_stamp_id,
            .form_type = form_type,
            .barrel_length = barrel_length,
            .trust_name = trust_name,
            .transfer_status = types.TransferStatus.fromString(transfer_str),
            .rounds_fired = @intCast(rounds_fired),
            .clean_interval_rounds = @intCast(clean_interval),
            .oil_interval_days = @intCast(oil_interval),
            .needs_maintenance = needs_maintenance,
            .maintenance_conditions = maintenance_conditions,
        };
    }
};
