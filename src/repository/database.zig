const std = @import("std");
const c = @cImport(@cInclude("sqlite3.h"));
const types = @import("../models/types.zig");
const firearm = @import("../models/firearm.zig");
const gear = @import("../models/gear.zig");
const consumable = @import("../models/consumable.zig");
const checkout = @import("../models/checkout.zig");
const loadout = @import("../models/loadout.zig");
const maintenance = @import("../models/maintenance.zig");
const reloading = @import("../models/reloading.zig");

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

        try migrateIfNeeded(db);

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

    pub fn columnTextNullable(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) ?[]const u8 {
        const text = c.sqlite3_column_text(stmt, col);
        if (text == null) {
            return null;
        }
        return std.mem.span(@as([*:0]const u8, @ptrCast(text)));
    }

    pub fn columnIntNullable(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) ?c_int {
        if (c.sqlite3_column_type(stmt, col) == c.SQLITE_NULL) {
            return null;
        }
        return c.sqlite3_column_int(stmt, col);
    }

    pub fn columnInt64Nullable(_: *Database, stmt: *c.sqlite3_stmt, col: c_int) ?c_longlong {
        if (c.sqlite3_column_type(stmt, col) == c.SQLITE_NULL) {
            return null;
        }
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

fn migrateIfNeeded(db: *c.sqlite3) !void {
    {
        const stmt_opt = try prepareStmt(db, "PRAGMA table_info(attachments)");
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer finalizeStmt(stmt);

        var has_misspelled = false;
        while (true) {
            const has_row = try stepStmt(stmt);
            if (!has_row) break;
            const col_name = columnText(stmt, 1);
            if (std.mem.eql(u8, col_name, "mount_postion")) {
                has_misspelled = true;
                break;
            }
        }
        if (has_misspelled) {
            try execSQL(db, "ALTER TABLE attachments RENAME COLUMN mount_postion TO mount_position");
        }
    }

    const migrations = [_]struct { table: [:0]const u8, column: [:0]const u8, col_type: [:0]const u8, default_val: ?[:0]const u8 }{
        .{ .table = "firearms", .column = "last_cleaned_at", .col_type = "INTEGER", .default_val = null },
        .{ .table = "firearms", .column = "last_oiled_at", .col_type = "INTEGER", .default_val = null },
        .{ .table = "firearms", .column = "created_at", .col_type = "INTEGER", .default_val = null },
        .{ .table = "firearms", .column = "updated_at", .col_type = "INTEGER", .default_val = null },
        .{ .table = "soft_gear", .column = "status", .col_type = "TEXT", .default_val = "AVAILABLE" },
        .{ .table = "attachments", .column = "mount_position", .col_type = "TEXT", .default_val = "" },
        .{ .table = "attachments", .column = "zero_distance_yards", .col_type = "INTEGER", .default_val = null },
        .{ .table = "attachments", .column = "zero_notes", .col_type = "TEXT", .default_val = "" },
        .{ .table = "nfa_items", .column = "rounds_fired", .col_type = "INTEGER", .default_val = "0" },
        .{ .table = "nfa_items", .column = "clean_interval_rounds", .col_type = "INTEGER", .default_val = "500" },
        .{ .table = "nfa_items", .column = "oil_interval_days", .col_type = "INTEGER", .default_val = "90" },
        .{ .table = "nfa_items", .column = "needs_maintenance", .col_type = "INTEGER", .default_val = "0" },
        .{ .table = "nfa_items", .column = "maintenance_conditions", .col_type = "TEXT", .default_val = "" },
    };

    for (migrations) |m| {
        const col_exists = try columnExists(db, m.table, m.column);
        if (!col_exists) {
            var sql_buf: [256]u8 = undefined;
            const sql = if (m.default_val) |def|
                try std.fmt.bufPrintZ(&sql_buf, "ALTER TABLE {s} ADD COLUMN {s} {s} DEFAULT '{s}'", .{ m.table, m.column, m.col_type, def })
            else
                try std.fmt.bufPrintZ(&sql_buf, "ALTER TABLE {s} ADD COLUMN {s} {s}", .{ m.table, m.column, m.col_type });
            try execSQL(db, sql);
        }
    }
}

fn columnExists(db: *c.sqlite3, table_name: []const u8, column_name: []const u8) !bool {
    var buf: [128]u8 = undefined;
    const sql = try std.fmt.bufPrintZ(&buf, "PRAGMA table_info({s})", .{table_name});
    const stmt_opt = try prepareStmt(db, sql);
    const stmt = stmt_opt orelse return error.PrepareFailed;
    defer finalizeStmt(stmt);

    while (true) {
        const has_row = try stepStmt(stmt);
        if (!has_row) break;
        const col = columnText(stmt, 1);
        if (std.mem.eql(u8, col, column_name)) {
            return true;
        }
    }
    return false;
}

fn prepareStmt(db: *c.sqlite3, sql: [:0]const u8) !?*c.sqlite3_stmt {
    var stmt: ?*c.sqlite3_stmt = null;
    const result = c.sqlite3_prepare_v2(db, sql, -1, &stmt, null);
    if (result != c.SQLITE_OK) {
        const err_msg = c.sqlite3_errmsg(db);
        if (err_msg != 0) {
            std.debug.print("Prepare error: {s}\n", .{err_msg});
        }
        return error.PrepareFailed;
    }
    return stmt;
}

fn stepStmt(stmt: *c.sqlite3_stmt) !bool {
    const result = c.sqlite3_step(stmt);
    if (result == c.SQLITE_ROW) {
        return true;
    } else if (result == c.SQLITE_DONE) {
        return false;
    } else {
        return error.StepFailed;
    }
}

fn finalizeStmt(stmt: *c.sqlite3_stmt) void {
    _ = c.sqlite3_finalize(stmt);
}

fn columnText(stmt: *c.sqlite3_stmt, col: c_int) []const u8 {
    const text = c.sqlite3_column_text(stmt, col);
    if (text == null) {
        return "";
    }
    return std.mem.span(@as([*:0]const u8, @ptrCast(text)));
}

pub const FirearmRepository = struct {
    db: *Database,

    pub fn create(self: *FirearmRepository, fw: firearm.Firearm) !void {
        const sql = "INSERT INTO firearms (name, caliber, serial_number, purchase_date, notes, status, is_nfa, nfa_type, tax_stamp_id, form_type, barrel_length, trust_name, transfer_status, rounds_fired, clean_interval_rounds, oil_interval_days, needs_maintenance, maintenance_conditions, last_cleaned_at, last_oiled_at, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        const now = std.time.timestamp();

        _ = c.sqlite3_bind_text(stmt, 1, fw.name.ptr, @intCast(fw.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, fw.caliber.ptr, @intCast(fw.caliber.len), null);
        if (fw.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, fw.serial_number.ptr, @intCast(fw.serial_number.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 3);
        }
        _ = c.sqlite3_bind_int64(stmt, 4, fw.purchase_date);
        if (fw.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, fw.notes.ptr, @intCast(fw.notes.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 5);
        }
        const status_str = types.CheckoutStatus.toString(fw.status);
        _ = c.sqlite3_bind_text(stmt, 6, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 7, if (fw.is_nfa) 1 else 0);
        if (fw.nfa_type) |nfa| {
            const nfa_str = types.NFAFirearmType.toString(nfa);
            _ = c.sqlite3_bind_text(stmt, 8, nfa_str.ptr, @intCast(nfa_str.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 8);
        }
        if (fw.tax_stamp_id.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, fw.tax_stamp_id.ptr, @intCast(fw.tax_stamp_id.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 9);
        }
        if (fw.form_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, fw.form_type.ptr, @intCast(fw.form_type.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 10);
        }
        if (fw.barrel_length.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, fw.barrel_length.ptr, @intCast(fw.barrel_length.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 11);
        }
        if (fw.trust_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 12, fw.trust_name.ptr, @intCast(fw.trust_name.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 12);
        }
        const transfer_str = types.TransferStatus.toString(fw.transfer_status);
        _ = c.sqlite3_bind_text(stmt, 13, transfer_str.ptr, @intCast(transfer_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 14, fw.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 15, fw.clean_interval_rounds);
        _ = c.sqlite3_bind_int(stmt, 16, fw.oil_interval_days);
        _ = c.sqlite3_bind_int(stmt, 17, if (fw.needs_maintenance) 1 else 0);
        if (fw.maintenance_conditions.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 18, fw.maintenance_conditions.ptr, @intCast(fw.maintenance_conditions.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 18);
        }
        _ = c.sqlite3_bind_int64(stmt, 19, 0); // last_cleaned_at
        _ = c.sqlite3_bind_int64(stmt, 20, 0); // last_oiled_at
        _ = c.sqlite3_bind_int64(stmt, 21, now); // created_at
        _ = c.sqlite3_bind_int64(stmt, 22, now); // updated_at

        std.debug.print("DEBUG: About to step, sql has ? placeholders\n", .{});
        const result = self.db.step(stmt);
        std.debug.print("DEBUG: step result = {!}\n", .{result});
        if (result) |_| {} else |err| {
            std.debug.print("DEBUG: step failed with error\n", .{});
            return err;
        }
    }

    pub fn getAll(self: *FirearmRepository, allocator: std.mem.Allocator) ![]firearm.Firearm {
        const sql = "SELECT id, name, caliber, serial_number, purchase_date, notes, status, is_nfa, nfa_type, tax_stamp_id, form_type, barrel_length, trust_name, transfer_status, rounds_fired, clean_interval_rounds, oil_interval_days, needs_maintenance, maintenance_conditions, last_cleaned_at, last_oiled_at, created_at, updated_at FROM firearms ORDER BY name";
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
        const sql = "UPDATE firearms SET status = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn update(self: *FirearmRepository, fw: firearm.Firearm) !void {
        const sql = "UPDATE firearms SET name = ?, caliber = ?, serial_number = ?, notes = ?, status = ?, is_nfa = ?, nfa_type = ?, tax_stamp_id = ?, form_type = ?, barrel_length = ?, trust_name = ?, transfer_status = ?, rounds_fired = ?, clean_interval_rounds = ?, oil_interval_days = ?, needs_maintenance = ?, maintenance_conditions = ?, updated_at = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        const now = std.time.timestamp();

        _ = c.sqlite3_bind_text(stmt, 1, fw.name.ptr, @intCast(fw.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, fw.caliber.ptr, @intCast(fw.caliber.len), null);
        if (fw.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, fw.serial_number.ptr, @intCast(fw.serial_number.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 3);
        }
        if (fw.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, fw.notes.ptr, @intCast(fw.notes.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 4);
        }
        const status_str = types.CheckoutStatus.toString(fw.status);
        _ = c.sqlite3_bind_text(stmt, 5, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 6, if (fw.is_nfa) 1 else 0);
        if (fw.nfa_type) |nfa| {
            const nfa_str = types.NFAFirearmType.toString(nfa);
            _ = c.sqlite3_bind_text(stmt, 7, nfa_str.ptr, @intCast(nfa_str.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 7);
        }
        if (fw.tax_stamp_id.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 8, fw.tax_stamp_id.ptr, @intCast(fw.tax_stamp_id.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 8);
        }
        if (fw.form_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, fw.form_type.ptr, @intCast(fw.form_type.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 9);
        }
        if (fw.barrel_length.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, fw.barrel_length.ptr, @intCast(fw.barrel_length.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 10);
        }
        if (fw.trust_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, fw.trust_name.ptr, @intCast(fw.trust_name.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 11);
        }
        const transfer_str = types.TransferStatus.toString(fw.transfer_status);
        _ = c.sqlite3_bind_text(stmt, 12, transfer_str.ptr, @intCast(transfer_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 13, fw.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 14, fw.clean_interval_rounds);
        _ = c.sqlite3_bind_int(stmt, 15, fw.oil_interval_days);
        _ = c.sqlite3_bind_int(stmt, 16, if (fw.needs_maintenance) 1 else 0);
        if (fw.maintenance_conditions.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 17, fw.maintenance_conditions.ptr, @intCast(fw.maintenance_conditions.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 17);
        }
        _ = c.sqlite3_bind_int64(stmt, 18, now);
        _ = c.sqlite3_bind_text(stmt, 19, fw.id.ptr, @intCast(fw.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *FirearmRepository, id: []const u8) !void {
        const sql_del = "DELETE FROM firearms WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql_del);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *FirearmRepository, allocator: std.mem.Allocator, items: []firearm.Firearm) void {
        for (items) |*fw| {
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
        allocator.free(items);
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
        const last_cleaned_at = self.db.columnInt64Nullable(stmt, 19) orelse 0;
        const last_oiled_at = self.db.columnInt64Nullable(stmt, 20) orelse 0;
        const created_at = self.db.columnInt64Nullable(stmt, 21) orelse 0;
        const updated_at = self.db.columnInt64Nullable(stmt, 22) orelse 0;

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
            .last_cleaned_at = last_cleaned_at,
            .last_oiled_at = last_oiled_at,
            .created_at = created_at,
            .updated_at = updated_at,
        };
    }
};

pub const SoftGearRepository = struct {
    db: *Database,

    pub fn create(self: *SoftGearRepository, sg: gear.SoftGear) !void {
        const sql = "INSERT INTO soft_gear VALUES (?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, sg.id.ptr, @intCast(sg.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, sg.name.ptr, @intCast(sg.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, sg.category.ptr, @intCast(sg.category.len), null);
        _ = c.sqlite3_bind_text(stmt, 4, sg.brand.ptr, @intCast(sg.brand.len), null);
        _ = c.sqlite3_bind_int64(stmt, 5, sg.purchase_date);
        if (sg.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, sg.notes.ptr, @intCast(sg.notes.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 6);
        }
        const status_str = types.CheckoutStatus.toString(sg.status);
        _ = c.sqlite3_bind_text(stmt, 7, status_str.ptr, @intCast(status_str.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *SoftGearRepository, allocator: std.mem.Allocator) ![]gear.SoftGear {
        const sql = "SELECT id, name, category, brand, purchase_date, notes, status FROM soft_gear ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(gear.SoftGear){};
        errdefer {
            for (items.items) |*sg| {
                allocator.free(sg.id);
                allocator.free(sg.name);
                allocator.free(sg.category);
                allocator.free(sg.brand);
                allocator.free(sg.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const sg = try self.rowToSoftGear(stmt, allocator);
            try items.append(allocator, sg);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *SoftGearRepository, allocator: std.mem.Allocator, id: []const u8) !?gear.SoftGear {
        const sql = "SELECT id, name, category, brand, purchase_date, notes, status FROM soft_gear WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToSoftGear(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *SoftGearRepository, sg: gear.SoftGear) !void {
        const sql = "UPDATE soft_gear SET name = ?, category = ?, brand = ?, purchase_date = ?, notes = ?, status = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, sg.name.ptr, @intCast(sg.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, sg.category.ptr, @intCast(sg.category.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, sg.brand.ptr, @intCast(sg.brand.len), null);
        _ = c.sqlite3_bind_int64(stmt, 4, sg.purchase_date);
        if (sg.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, sg.notes.ptr, @intCast(sg.notes.len), null);
        }
        const status_str = types.CheckoutStatus.toString(sg.status);
        _ = c.sqlite3_bind_text(stmt, 6, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 7, sg.id.ptr, @intCast(sg.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *SoftGearRepository, id: []const u8) !void {
        const sql = "DELETE FROM soft_gear WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *SoftGearRepository, allocator: std.mem.Allocator, items: []gear.SoftGear) void {
        for (items) |*sg| {
            allocator.free(sg.id);
            allocator.free(sg.name);
            allocator.free(sg.category);
            allocator.free(sg.brand);
            allocator.free(sg.notes);
        }
        allocator.free(items);
    }

    pub fn deinit(_: *SoftGearRepository, allocator: std.mem.Allocator, item: gear.SoftGear) void {
        allocator.free(item.id);
        allocator.free(item.name);
        allocator.free(item.category);
        allocator.free(item.brand);
        allocator.free(item.notes);
    }

    fn rowToSoftGear(self: *SoftGearRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !gear.SoftGear {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const category = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const brand = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const purchase_date = self.db.columnInt64(stmt, 4);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const status_str = self.db.columnText(stmt, 6);

        return .{
            .id = id,
            .name = name,
            .category = category,
            .brand = brand,
            .purchase_date = purchase_date,
            .notes = notes,
            .status = types.CheckoutStatus.fromString(status_str),
        };
    }
};

pub const ConsumableRepository = struct {
    db: *Database,

    pub fn create(self: *ConsumableRepository, csm: consumable.Consumable) !void {
        const sql = "INSERT INTO consumables VALUES (?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, csm.id.ptr, @intCast(csm.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, csm.name.ptr, @intCast(csm.name.len), null);
        const cat_str = types.ConsumableCategory.toString(csm.category);
        _ = c.sqlite3_bind_text(stmt, 3, cat_str.ptr, @intCast(cat_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 4, csm.unit.ptr, @intCast(csm.unit.len), null);
        _ = c.sqlite3_bind_int(stmt, 5, csm.quantity);
        _ = c.sqlite3_bind_int(stmt, 6, csm.min_quantity);
        if (csm.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, csm.notes.ptr, @intCast(csm.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *ConsumableRepository, allocator: std.mem.Allocator) ![]consumable.Consumable {
        const sql = "SELECT id, name, category, unit, quantity, min_quantity, notes FROM consumables ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(consumable.Consumable){};
        errdefer {
            for (items.items) |*csm| {
                allocator.free(csm.id);
                allocator.free(csm.name);
                allocator.free(csm.unit);
                allocator.free(csm.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const csm = try self.rowToConsumable(stmt, allocator);
            try items.append(allocator, csm);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *ConsumableRepository, allocator: std.mem.Allocator, id: []const u8) !?consumable.Consumable {
        const sql = "SELECT id, name, category, unit, quantity, min_quantity, notes FROM consumables WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToConsumable(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *ConsumableRepository, csm: consumable.Consumable) !void {
        const sql = "UPDATE consumables SET name = ?, category = ?, unit = ?, quantity = ?, min_quantity = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, csm.name.ptr, @intCast(csm.name.len), null);
        const cat_str = types.ConsumableCategory.toString(csm.category);
        _ = c.sqlite3_bind_text(stmt, 2, cat_str.ptr, @intCast(cat_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, csm.unit.ptr, @intCast(csm.unit.len), null);
        _ = c.sqlite3_bind_int(stmt, 4, csm.quantity);
        _ = c.sqlite3_bind_int(stmt, 5, csm.min_quantity);
        if (csm.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, csm.notes.ptr, @intCast(csm.notes.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 7, csm.id.ptr, @intCast(csm.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *ConsumableRepository, id: []const u8) !void {
        const sql = "DELETE FROM consumables WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *ConsumableRepository, allocator: std.mem.Allocator, items: []consumable.Consumable) void {
        for (items) |*csm| {
            allocator.free(csm.id);
            allocator.free(csm.name);
            allocator.free(csm.unit);
            allocator.free(csm.notes);
        }
        allocator.free(items);
    }

    pub fn deinit(_: *ConsumableRepository, allocator: std.mem.Allocator, item: consumable.Consumable) void {
        allocator.free(item.id);
        allocator.free(item.name);
        allocator.free(item.unit);
        allocator.free(item.notes);
    }

    fn rowToConsumable(self: *ConsumableRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !consumable.Consumable {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const cat_str = self.db.columnText(stmt, 2);
        const unit = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const quantity = self.db.columnInt(stmt, 4);
        const min_quantity = self.db.columnInt(stmt, 5);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 6));

        return .{
            .id = id,
            .name = name,
            .category = types.ConsumableCategory.fromString(cat_str),
            .unit = unit,
            .quantity = @intCast(quantity),
            .min_quantity = @intCast(min_quantity),
            .notes = notes,
        };
    }
};

pub const ConsumableTransactionRepository = struct {
    db: *Database,

    pub fn create(self: *ConsumableTransactionRepository, tx: consumable.ConsumableTransaction) !void {
        const sql = "INSERT INTO consumable_transactions VALUES (?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, tx.id.ptr, @intCast(tx.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, tx.consumable_id.ptr, @intCast(tx.consumable_id.len), null);
        const type_str = types.TransactionType.toString(tx.transaction_type);
        _ = c.sqlite3_bind_text(stmt, 3, type_str.ptr, @intCast(type_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 4, tx.quantity);
        _ = c.sqlite3_bind_int64(stmt, 5, tx.date);
        if (tx.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, tx.notes.ptr, @intCast(tx.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *ConsumableTransactionRepository, allocator: std.mem.Allocator) ![]consumable.ConsumableTransaction {
        const sql = "SELECT id, consumable_id, transaction_type, quantity, date, notes FROM consumable_transactions ORDER BY date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(consumable.ConsumableTransaction){};
        errdefer {
            for (items.items) |*tx| {
                allocator.free(tx.id);
                allocator.free(tx.consumable_id);
                allocator.free(tx.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const tx = try self.rowToTransaction(stmt, allocator);
            try items.append(allocator, tx);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getByConsumableId(self: *ConsumableTransactionRepository, allocator: std.mem.Allocator, consumable_id: []const u8) ![]consumable.ConsumableTransaction {
        const sql = "SELECT id, consumable_id, transaction_type, quantity, date, notes FROM consumable_transactions WHERE consumable_id = ? ORDER BY date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, consumable_id.ptr, @intCast(consumable_id.len), null);

        var items = std.ArrayListUnmanaged(consumable.ConsumableTransaction){};
        errdefer {
            for (items.items) |*tx| {
                allocator.free(tx.id);
                allocator.free(tx.consumable_id);
                allocator.free(tx.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const tx = try self.rowToTransaction(stmt, allocator);
            try items.append(allocator, tx);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *ConsumableTransactionRepository, id: []const u8) !void {
        const sql = "DELETE FROM consumable_transactions WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *ConsumableTransactionRepository, allocator: std.mem.Allocator, items: []consumable.ConsumableTransaction) void {
        for (items) |*tx| {
            allocator.free(tx.id);
            allocator.free(tx.consumable_id);
            allocator.free(tx.notes);
        }
        allocator.free(items);
    }

    fn rowToTransaction(self: *ConsumableTransactionRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !consumable.ConsumableTransaction {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const consumable_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const type_str = self.db.columnText(stmt, 2);
        const quantity = self.db.columnInt(stmt, 3);
        const date = self.db.columnInt64(stmt, 4);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 5));

        return .{
            .id = id,
            .consumable_id = consumable_id,
            .transaction_type = types.TransactionType.fromString(type_str),
            .quantity = @intCast(quantity),
            .date = date,
            .notes = notes,
        };
    }
};

pub const BorrowerRepository = struct {
    db: *Database,

    pub fn create(self: *BorrowerRepository, b: checkout.Borrower) !void {
        const sql = "INSERT INTO borrowers VALUES (?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, b.id.ptr, @intCast(b.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, b.name.ptr, @intCast(b.name.len), null);
        if (b.phone.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, b.phone.ptr, @intCast(b.phone.len), null);
        }
        if (b.email.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, b.email.ptr, @intCast(b.email.len), null);
        }
        if (b.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, b.notes.ptr, @intCast(b.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *BorrowerRepository, allocator: std.mem.Allocator) ![]checkout.Borrower {
        const sql = "SELECT id, name, phone, email, notes FROM borrowers ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(checkout.Borrower){};
        errdefer {
            for (items.items) |*b| {
                allocator.free(b.id);
                allocator.free(b.name);
                allocator.free(b.phone);
                allocator.free(b.email);
                allocator.free(b.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const b = try self.rowToBorrower(stmt, allocator);
            try items.append(allocator, b);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *BorrowerRepository, allocator: std.mem.Allocator, id: []const u8) !?checkout.Borrower {
        const sql = "SELECT id, name, phone, email, notes FROM borrowers WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToBorrower(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *BorrowerRepository, b: checkout.Borrower) !void {
        const sql = "UPDATE borrowers SET name = ?, phone = ?, email = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, b.name.ptr, @intCast(b.name.len), null);
        if (b.phone.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 2, b.phone.ptr, @intCast(b.phone.len), null);
        }
        if (b.email.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, b.email.ptr, @intCast(b.email.len), null);
        }
        if (b.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, b.notes.ptr, @intCast(b.notes.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 5, b.id.ptr, @intCast(b.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *BorrowerRepository, id: []const u8) !void {
        const sql = "DELETE FROM borrowers WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *BorrowerRepository, allocator: std.mem.Allocator, items: []checkout.Borrower) void {
        for (items) |*b| {
            allocator.free(b.id);
            allocator.free(b.name);
            allocator.free(b.phone);
            allocator.free(b.email);
            allocator.free(b.notes);
        }
        allocator.free(items);
    }

    pub fn deinit(_: *BorrowerRepository, allocator: std.mem.Allocator, item: checkout.Borrower) void {
        allocator.free(item.id);
        allocator.free(item.name);
        allocator.free(item.phone);
        allocator.free(item.email);
        allocator.free(item.notes);
    }

    fn rowToBorrower(self: *BorrowerRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !checkout.Borrower {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const phone = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const email = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 4));

        return .{
            .id = id,
            .name = name,
            .phone = phone,
            .email = email,
            .notes = notes,
        };
    }
};

pub const CheckoutRepository = struct {
    db: *Database,

    pub fn create(self: *CheckoutRepository, co: checkout.Checkout) !void {
        const sql = "INSERT INTO checkouts VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, co.id.ptr, @intCast(co.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, co.item_id.ptr, @intCast(co.item_id.len), null);
        const type_str = types.GearCategory.toString(co.item_type);
        _ = c.sqlite3_bind_text(stmt, 3, type_str.ptr, @intCast(type_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 4, co.borrower_id.ptr, @intCast(co.borrower_id.len), null);
        _ = c.sqlite3_bind_int64(stmt, 5, co.checkout_date);
        if (co.expected_return) |exp| {
            _ = c.sqlite3_bind_int64(stmt, 6, exp);
        }
        if (co.actual_return) |act| {
            _ = c.sqlite3_bind_int64(stmt, 7, act);
        }
        if (co.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 8, co.notes.ptr, @intCast(co.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *CheckoutRepository, allocator: std.mem.Allocator) ![]checkout.Checkout {
        const sql = "SELECT id, item_id, item_type, borrower_id, checkout_date, expected_return, actual_return, notes FROM checkouts ORDER BY checkout_date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(checkout.Checkout){};
        errdefer {
            for (items.items) |*co| {
                allocator.free(co.id);
                allocator.free(co.item_id);
                allocator.free(co.borrower_id);
                allocator.free(co.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const co = try self.rowToCheckout(stmt, allocator);
            try items.append(allocator, co);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *CheckoutRepository, allocator: std.mem.Allocator, id: []const u8) !?checkout.Checkout {
        const sql = "SELECT id, item_id, item_type, borrower_id, checkout_date, expected_return, actual_return, notes FROM checkouts WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToCheckout(stmt, allocator);
        }
        return null;
    }

    pub fn getActive(self: *CheckoutRepository, allocator: std.mem.Allocator) ![]checkout.Checkout {
        const sql = "SELECT id, item_id, item_type, borrower_id, checkout_date, expected_return, actual_return, notes FROM checkouts WHERE actual_return IS NULL ORDER BY checkout_date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(checkout.Checkout){};
        errdefer {
            for (items.items) |*co| {
                allocator.free(co.id);
                allocator.free(co.item_id);
                allocator.free(co.borrower_id);
                allocator.free(co.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const co = try self.rowToCheckout(stmt, allocator);
            try items.append(allocator, co);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn update(self: *CheckoutRepository, co: checkout.Checkout) !void {
        const sql = "UPDATE checkouts SET item_id = ?, item_type = ?, borrower_id = ?, checkout_date = ?, expected_return = ?, actual_return = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, co.item_id.ptr, @intCast(co.item_id.len), null);
        const type_str = types.GearCategory.toString(co.item_type);
        _ = c.sqlite3_bind_text(stmt, 2, type_str.ptr, @intCast(type_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, co.borrower_id.ptr, @intCast(co.borrower_id.len), null);
        _ = c.sqlite3_bind_int64(stmt, 4, co.checkout_date);
        if (co.expected_return) |exp| {
            _ = c.sqlite3_bind_int64(stmt, 5, exp);
        }
        if (co.actual_return) |act| {
            _ = c.sqlite3_bind_int64(stmt, 6, act);
        }
        if (co.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, co.notes.ptr, @intCast(co.notes.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 8, co.id.ptr, @intCast(co.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *CheckoutRepository, id: []const u8) !void {
        const sql = "DELETE FROM checkouts WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *CheckoutRepository, allocator: std.mem.Allocator, items: []checkout.Checkout) void {
        for (items) |*co| {
            allocator.free(co.id);
            allocator.free(co.item_id);
            allocator.free(co.borrower_id);
            allocator.free(co.notes);
        }
        allocator.free(items);
    }

    fn rowToCheckout(self: *CheckoutRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !checkout.Checkout {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const item_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const type_str = self.db.columnText(stmt, 2);
        const borrower_id = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const checkout_date = self.db.columnInt64(stmt, 4);
        const expected_return = self.db.columnInt64Nullable(stmt, 5);
        const actual_return = self.db.columnInt64Nullable(stmt, 6);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 7));

        return .{
            .id = id,
            .item_id = item_id,
            .item_type = types.GearCategory.fromString(type_str),
            .borrower_id = borrower_id,
            .checkout_date = checkout_date,
            .expected_return = expected_return,
            .actual_return = actual_return,
            .notes = notes,
        };
    }
};

pub const MaintenanceLogRepository = struct {
    db: *Database,

    pub fn create(self: *MaintenanceLogRepository, ml: maintenance.MaintenanceLog) !void {
        const sql = "INSERT INTO maintenance_logs VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, ml.id.ptr, @intCast(ml.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, ml.item_id.ptr, @intCast(ml.item_id.len), null);
        const type_str = types.GearCategory.toString(ml.item_type);
        _ = c.sqlite3_bind_text(stmt, 3, type_str.ptr, @intCast(type_str.len), null);
        const log_type_str = types.MaintenanceType.toString(ml.log_type);
        _ = c.sqlite3_bind_text(stmt, 4, log_type_str.ptr, @intCast(log_type_str.len), null);
        _ = c.sqlite3_bind_int64(stmt, 5, ml.date);
        if (ml.details.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, ml.details.ptr, @intCast(ml.details.len), null);
        }
        if (ml.ammo_count) |ac| {
            _ = c.sqlite3_bind_int(stmt, 7, ac);
        }
        if (ml.photo_path) |pp| {
            _ = c.sqlite3_bind_text(stmt, 8, pp.ptr, @intCast(pp.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *MaintenanceLogRepository, allocator: std.mem.Allocator) ![]maintenance.MaintenanceLog {
        const sql = "SELECT id, item_id, item_type, log_type, date, details, ammo_count, photo_path FROM maintenance_logs ORDER BY date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(maintenance.MaintenanceLog){};
        errdefer {
            for (items.items) |*ml| {
                allocator.free(ml.id);
                allocator.free(ml.item_id);
                allocator.free(ml.details);
                if (ml.photo_path) |pp| allocator.free(pp);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const ml = try self.rowToMaintenanceLog(stmt, allocator);
            try items.append(allocator, ml);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getByItemId(self: *MaintenanceLogRepository, allocator: std.mem.Allocator, item_id: []const u8) ![]maintenance.MaintenanceLog {
        const sql = "SELECT id, item_id, item_type, log_type, date, details, ammo_count, photo_path FROM maintenance_logs WHERE item_id = ? ORDER BY date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, item_id.ptr, @intCast(item_id.len), null);

        var items = std.ArrayListUnmanaged(maintenance.MaintenanceLog){};
        errdefer {
            for (items.items) |*ml| {
                allocator.free(ml.id);
                allocator.free(ml.item_id);
                allocator.free(ml.details);
                if (ml.photo_path) |pp| allocator.free(pp);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const ml = try self.rowToMaintenanceLog(stmt, allocator);
            try items.append(allocator, ml);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *MaintenanceLogRepository, id: []const u8) !void {
        const sql = "DELETE FROM maintenance_logs WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *MaintenanceLogRepository, allocator: std.mem.Allocator, items: []maintenance.MaintenanceLog) void {
        for (items) |*ml| {
            allocator.free(ml.id);
            allocator.free(ml.item_id);
            allocator.free(ml.details);
            if (ml.photo_path) |pp| allocator.free(pp);
        }
        allocator.free(items);
    }

    fn rowToMaintenanceLog(self: *MaintenanceLogRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !maintenance.MaintenanceLog {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const item_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const item_type_str = self.db.columnText(stmt, 2);
        const log_type_str = self.db.columnText(stmt, 3);
        const date = self.db.columnInt64(stmt, 4);
        const details = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const ammo_count = self.db.columnIntNullable(stmt, 6);
        const photo_path_null = self.db.columnTextNullable(stmt, 7);

        return .{
            .id = id,
            .item_id = item_id,
            .item_type = types.GearCategory.fromString(item_type_str),
            .log_type = types.MaintenanceType.fromString(log_type_str),
            .date = date,
            .details = details,
            .ammo_count = if (ammo_count) |ac| @intCast(ac) else null,
            .photo_path = if (photo_path_null) |pp| try allocator.dupe(u8, pp) else null,
        };
    }
};

pub const NFAItemRepository = struct {
    db: *Database,

    pub fn create(self: *NFAItemRepository, nfa: gear.NFAItem) !void {
        const sql = "INSERT INTO nfa_items VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, nfa.id.ptr, @intCast(nfa.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, nfa.name.ptr, @intCast(nfa.name.len), null);
        const nfa_type_str = types.NFAItemType.toString(nfa.nfa_type);
        _ = c.sqlite3_bind_text(stmt, 3, nfa_type_str.ptr, @intCast(nfa_type_str.len), null);
        if (nfa.manufacturer.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, nfa.manufacturer.ptr, @intCast(nfa.manufacturer.len), null);
        }
        if (nfa.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, nfa.serial_number.ptr, @intCast(nfa.serial_number.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 6, nfa.tax_stamp_id.ptr, @intCast(nfa.tax_stamp_id.len), null);
        if (nfa.caliber_bore.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, nfa.caliber_bore.ptr, @intCast(nfa.caliber_bore.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 8, nfa.purchase_date);
        if (nfa.form_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, nfa.form_type.ptr, @intCast(nfa.form_type.len), null);
        }
        if (nfa.trust_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, nfa.trust_name.ptr, @intCast(nfa.trust_name.len), null);
        }
        if (nfa.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, nfa.notes.ptr, @intCast(nfa.notes.len), null);
        }
        const status_str = types.CheckoutStatus.toString(nfa.status);
        _ = c.sqlite3_bind_text(stmt, 12, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 13, nfa.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 14, nfa.clean_interval_rounds);
        _ = c.sqlite3_bind_int(stmt, 15, nfa.oil_interval_days);
        _ = c.sqlite3_bind_int(stmt, 16, if (nfa.needs_maintenance) 1 else 0);
        if (nfa.maintenance_conditions.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 17, nfa.maintenance_conditions.ptr, @intCast(nfa.maintenance_conditions.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *NFAItemRepository, allocator: std.mem.Allocator) ![]gear.NFAItem {
        const sql = "SELECT id, name, nfa_type, manufacturer, serial_number, tax_stamp_id, caliber_bore, purchase_date, form_type, trust_name, notes, status, rounds_fired, clean_interval_rounds, oil_interval_days, needs_maintenance, maintenance_conditions FROM nfa_items ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(gear.NFAItem){};
        errdefer {
            for (items.items) |*nfa| {
                allocator.free(nfa.id);
                allocator.free(nfa.name);
                allocator.free(nfa.manufacturer);
                allocator.free(nfa.serial_number);
                allocator.free(nfa.tax_stamp_id);
                allocator.free(nfa.caliber_bore);
                allocator.free(nfa.form_type);
                allocator.free(nfa.trust_name);
                allocator.free(nfa.notes);
                allocator.free(nfa.maintenance_conditions);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const nfa = try self.rowToNFAItem(stmt, allocator);
            try items.append(allocator, nfa);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *NFAItemRepository, allocator: std.mem.Allocator, id: []const u8) !?gear.NFAItem {
        const sql = "SELECT id, name, nfa_type, manufacturer, serial_number, tax_stamp_id, caliber_bore, purchase_date, form_type, trust_name, notes, status, rounds_fired, clean_interval_rounds, oil_interval_days, needs_maintenance, maintenance_conditions FROM nfa_items WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToNFAItem(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *NFAItemRepository, nfa: gear.NFAItem) !void {
        const sql = "UPDATE nfa_items SET name = ?, nfa_type = ?, manufacturer = ?, serial_number = ?, tax_stamp_id = ?, caliber_bore = ?, purchase_date = ?, form_type = ?, trust_name = ?, notes = ?, status = ?, rounds_fired = ?, clean_interval_rounds = ?, oil_interval_days = ?, needs_maintenance = ?, maintenance_conditions = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, nfa.name.ptr, @intCast(nfa.name.len), null);
        const nfa_type_str = types.NFAItemType.toString(nfa.nfa_type);
        _ = c.sqlite3_bind_text(stmt, 2, nfa_type_str.ptr, @intCast(nfa_type_str.len), null);
        if (nfa.manufacturer.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, nfa.manufacturer.ptr, @intCast(nfa.manufacturer.len), null);
        }
        if (nfa.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, nfa.serial_number.ptr, @intCast(nfa.serial_number.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 5, nfa.tax_stamp_id.ptr, @intCast(nfa.tax_stamp_id.len), null);
        if (nfa.caliber_bore.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, nfa.caliber_bore.ptr, @intCast(nfa.caliber_bore.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 7, nfa.purchase_date);
        if (nfa.form_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 8, nfa.form_type.ptr, @intCast(nfa.form_type.len), null);
        }
        if (nfa.trust_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, nfa.trust_name.ptr, @intCast(nfa.trust_name.len), null);
        }
        if (nfa.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, nfa.notes.ptr, @intCast(nfa.notes.len), null);
        }
        const status_str = types.CheckoutStatus.toString(nfa.status);
        _ = c.sqlite3_bind_text(stmt, 11, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_int(stmt, 12, nfa.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 13, nfa.clean_interval_rounds);
        _ = c.sqlite3_bind_int(stmt, 14, nfa.oil_interval_days);
        _ = c.sqlite3_bind_int(stmt, 15, if (nfa.needs_maintenance) 1 else 0);
        if (nfa.maintenance_conditions.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 16, nfa.maintenance_conditions.ptr, @intCast(nfa.maintenance_conditions.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 17, nfa.id.ptr, @intCast(nfa.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *NFAItemRepository, id: []const u8) !void {
        const sql = "DELETE FROM nfa_items WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn updateStatus(self: *NFAItemRepository, id: []const u8, status: types.CheckoutStatus) !void {
        const sql = "UPDATE nfa_items SET status = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        const status_str = types.CheckoutStatus.toString(status);
        _ = c.sqlite3_bind_text(stmt, 1, status_str.ptr, @intCast(status_str.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *NFAItemRepository, allocator: std.mem.Allocator, items: []gear.NFAItem) void {
        for (items) |*nfa| {
            allocator.free(nfa.id);
            allocator.free(nfa.name);
            allocator.free(nfa.manufacturer);
            allocator.free(nfa.serial_number);
            allocator.free(nfa.tax_stamp_id);
            allocator.free(nfa.caliber_bore);
            allocator.free(nfa.form_type);
            allocator.free(nfa.trust_name);
            allocator.free(nfa.notes);
            allocator.free(nfa.maintenance_conditions);
        }
        allocator.free(items);
    }

    fn rowToNFAItem(self: *NFAItemRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !gear.NFAItem {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const nfa_type_str = self.db.columnText(stmt, 2);
        const manufacturer = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const serial_number = try allocator.dupe(u8, self.db.columnText(stmt, 4));
        const tax_stamp_id = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const caliber_bore = try allocator.dupe(u8, self.db.columnText(stmt, 6));
        const purchase_date = self.db.columnInt64(stmt, 7);
        const form_type = try allocator.dupe(u8, self.db.columnText(stmt, 8));
        const trust_name = try allocator.dupe(u8, self.db.columnText(stmt, 9));
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 10));
        const status_str = self.db.columnText(stmt, 11);
        const rounds_fired = self.db.columnInt(stmt, 12);
        const clean_interval = self.db.columnInt(stmt, 13);
        const oil_interval = self.db.columnInt(stmt, 14);
        const needs_maintenance = self.db.columnInt(stmt, 15) != 0;
        const maintenance_conditions = try allocator.dupe(u8, self.db.columnText(stmt, 16));

        return .{
            .id = id,
            .name = name,
            .nfa_type = types.NFAItemType.fromString(nfa_type_str),
            .manufacturer = manufacturer,
            .serial_number = serial_number,
            .tax_stamp_id = tax_stamp_id,
            .caliber_bore = caliber_bore,
            .purchase_date = purchase_date,
            .form_type = form_type,
            .trust_name = trust_name,
            .notes = notes,
            .status = types.CheckoutStatus.fromString(status_str),
            .rounds_fired = @intCast(rounds_fired),
            .clean_interval_rounds = @intCast(clean_interval),
            .oil_interval_days = @intCast(oil_interval),
            .needs_maintenance = needs_maintenance,
            .maintenance_conditions = maintenance_conditions,
        };
    }
};

pub const AttachmentRepository = struct {
    db: *Database,

    pub fn create(self: *AttachmentRepository, att: gear.Attachment) !void {
        const sql = "INSERT INTO attachments VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, att.id.ptr, @intCast(att.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, att.name.ptr, @intCast(att.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, att.category.ptr, @intCast(att.category.len), null);
        if (att.brand.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 4, att.brand.ptr, @intCast(att.brand.len), null);
        }
        if (att.model.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, att.model.ptr, @intCast(att.model.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 6, att.purchase_date);
        if (att.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, att.serial_number.ptr, @intCast(att.serial_number.len), null);
        }
        if (att.mounted_on_firearm_id) |fid| {
            _ = c.sqlite3_bind_text(stmt, 8, fid.ptr, @intCast(fid.len), null);
        }
        if (att.mount_position.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, att.mount_position.ptr, @intCast(att.mount_position.len), null);
        }
        if (att.zero_distance_yards) |zdy| {
            _ = c.sqlite3_bind_int(stmt, 10, zdy);
        }
        if (att.zero_notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, att.zero_notes.ptr, @intCast(att.zero_notes.len), null);
        }
        if (att.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 12, att.notes.ptr, @intCast(att.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *AttachmentRepository, allocator: std.mem.Allocator) ![]gear.Attachment {
        const sql = "SELECT id, name, category, brand, model, purchase_date, serial_number, mounted_on_firearm_id, mount_position, zero_distance_yards, zero_notes, notes FROM attachments ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(gear.Attachment){};
        errdefer {
            for (items.items) |*att| {
                allocator.free(att.id);
                allocator.free(att.name);
                allocator.free(att.category);
                allocator.free(att.brand);
                allocator.free(att.model);
                allocator.free(att.serial_number);
                if (att.mounted_on_firearm_id) |fid| allocator.free(fid);
                allocator.free(att.mount_position);
                allocator.free(att.zero_notes);
                allocator.free(att.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const att = try self.rowToAttachment(stmt, allocator);
            try items.append(allocator, att);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getByFirearmId(self: *AttachmentRepository, allocator: std.mem.Allocator, firearm_id: []const u8) ![]gear.Attachment {
        const sql = "SELECT id, name, category, brand, model, purchase_date, serial_number, mounted_on_firearm_id, mount_position, zero_distance_yards, zero_notes, notes FROM attachments WHERE mounted_on_firearm_id = ? ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, firearm_id.ptr, @intCast(firearm_id.len), null);

        var items = std.ArrayListUnmanaged(gear.Attachment){};
        errdefer {
            for (items.items) |*att| {
                allocator.free(att.id);
                allocator.free(att.name);
                allocator.free(att.category);
                allocator.free(att.brand);
                allocator.free(att.model);
                allocator.free(att.serial_number);
                if (att.mounted_on_firearm_id) |fid| allocator.free(fid);
                allocator.free(att.mount_position);
                allocator.free(att.zero_notes);
                allocator.free(att.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const att = try self.rowToAttachment(stmt, allocator);
            try items.append(allocator, att);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *AttachmentRepository, id: []const u8) !void {
        const sql = "DELETE FROM attachments WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn getById(self: *AttachmentRepository, allocator: std.mem.Allocator, id: []const u8) !?gear.Attachment {
        const sql = "SELECT id, name, category, brand, model, purchase_date, serial_number, mounted_on_firearm_id, mount_position, zero_distance_yards, zero_notes, notes FROM attachments WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToAttachment(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *AttachmentRepository, att: gear.Attachment) !void {
        const sql = "UPDATE attachments SET name = ?, category = ?, brand = ?, model = ?, serial_number = ?, mount_position = ?, zero_distance_yards = ?, zero_notes = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, att.name.ptr, @intCast(att.name.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, att.category.ptr, @intCast(att.category.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, att.brand.ptr, @intCast(att.brand.len), null);
        _ = c.sqlite3_bind_text(stmt, 4, att.model.ptr, @intCast(att.model.len), null);
        if (att.serial_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, att.serial_number.ptr, @intCast(att.serial_number.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 5);
        }
        _ = c.sqlite3_bind_text(stmt, 6, att.mount_position.ptr, @intCast(att.mount_position.len), null);
        if (att.zero_distance_yards) |zdy| {
            _ = c.sqlite3_bind_int(stmt, 7, zdy);
        } else {
            _ = c.sqlite3_bind_null(stmt, 7);
        }
        _ = c.sqlite3_bind_text(stmt, 8, att.zero_notes.ptr, @intCast(att.zero_notes.len), null);
        if (att.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, att.notes.ptr, @intCast(att.notes.len), null);
        } else {
            _ = c.sqlite3_bind_null(stmt, 9);
        }
        _ = c.sqlite3_bind_text(stmt, 10, att.id.ptr, @intCast(att.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *AttachmentRepository, allocator: std.mem.Allocator, items: []gear.Attachment) void {
        for (items) |*att| {
            allocator.free(att.id);
            allocator.free(att.name);
            allocator.free(att.category);
            allocator.free(att.brand);
            allocator.free(att.model);
            allocator.free(att.serial_number);
            if (att.mounted_on_firearm_id) |fid| allocator.free(fid);
            allocator.free(att.mount_position);
            allocator.free(att.zero_notes);
            allocator.free(att.notes);
        }
        allocator.free(items);
    }

    fn rowToAttachment(self: *AttachmentRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !gear.Attachment {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const category = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const brand = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const model = try allocator.dupe(u8, self.db.columnText(stmt, 4));
        const purchase_date = self.db.columnInt64(stmt, 5);
        const serial_number = try allocator.dupe(u8, self.db.columnText(stmt, 6));
        const mounted_on_firearm_id_null = self.db.columnTextNullable(stmt, 7);
        const mount_position = try allocator.dupe(u8, self.db.columnText(stmt, 8));
        const zero_distance_yards = self.db.columnIntNullable(stmt, 9);
        const zero_notes = try allocator.dupe(u8, self.db.columnText(stmt, 10));
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 11));

        return .{
            .id = id,
            .name = name,
            .category = category,
            .brand = brand,
            .model = model,
            .purchase_date = purchase_date,
            .serial_number = serial_number,
            .mounted_on_firearm_id = if (mounted_on_firearm_id_null) |fid| try allocator.dupe(u8, fid) else null,
            .mount_position = mount_position,
            .zero_distance_yards = if (zero_distance_yards) |zdy| @intCast(zdy) else null,
            .zero_notes = zero_notes,
            .notes = notes,
        };
    }
};

pub const TransferRepository = struct {
    db: *Database,

    pub fn create(self: *TransferRepository, t: firearm.Transfer) !void {
        const sql = "INSERT INTO transfers VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, t.id.ptr, @intCast(t.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, t.firearm_id.ptr, @intCast(t.firearm_id.len), null);
        _ = c.sqlite3_bind_int64(stmt, 3, t.transfer_date);
        _ = c.sqlite3_bind_text(stmt, 4, t.buyer_name.ptr, @intCast(t.buyer_name.len), null);
        _ = c.sqlite3_bind_text(stmt, 5, t.buyer_address.ptr, @intCast(t.buyer_address.len), null);
        _ = c.sqlite3_bind_text(stmt, 6, t.buyer_dl_number.ptr, @intCast(t.buyer_dl_number.len), null);
        if (t.buyer_ltc_number.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, t.buyer_ltc_number.ptr, @intCast(t.buyer_ltc_number.len), null);
        }
        _ = c.sqlite3_bind_double(stmt, 8, t.sale_price);
        if (t.ffl_dealer.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 9, t.ffl_dealer.ptr, @intCast(t.ffl_dealer.len), null);
        }
        if (t.ffl_license.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, t.ffl_license.ptr, @intCast(t.ffl_license.len), null);
        }
        if (t.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, t.notes.ptr, @intCast(t.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *TransferRepository, allocator: std.mem.Allocator) ![]firearm.Transfer {
        const sql = "SELECT id, firearm_id, transfer_date, buyer_name, buyer_address, buyer_dl_number, buyer_ltc_number, sale_price, ffl_dealer, ffl_license, notes FROM transfers ORDER BY transfer_date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(firearm.Transfer){};
        errdefer {
            for (items.items) |*t| {
                allocator.free(t.id);
                allocator.free(t.firearm_id);
                allocator.free(t.buyer_name);
                allocator.free(t.buyer_address);
                allocator.free(t.buyer_dl_number);
                allocator.free(t.buyer_ltc_number);
                allocator.free(t.ffl_dealer);
                allocator.free(t.ffl_license);
                allocator.free(t.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const t = try self.rowToTransfer(stmt, allocator);
            try items.append(allocator, t);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getByFirearmId(self: *TransferRepository, allocator: std.mem.Allocator, firearm_id: []const u8) ![]firearm.Transfer {
        const sql = "SELECT id, firearm_id, transfer_date, buyer_name, buyer_address, buyer_dl_number, buyer_ltc_number, sale_price, ffl_dealer, ffl_license, notes FROM transfers WHERE firearm_id = ? ORDER BY transfer_date DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, firearm_id.ptr, @intCast(firearm_id.len), null);

        var items = std.ArrayListUnmanaged(firearm.Transfer){};
        errdefer {
            for (items.items) |*t| {
                allocator.free(t.id);
                allocator.free(t.firearm_id);
                allocator.free(t.buyer_name);
                allocator.free(t.buyer_address);
                allocator.free(t.buyer_dl_number);
                allocator.free(t.buyer_ltc_number);
                allocator.free(t.ffl_dealer);
                allocator.free(t.ffl_license);
                allocator.free(t.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const t = try self.rowToTransfer(stmt, allocator);
            try items.append(allocator, t);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *TransferRepository, id: []const u8) !void {
        const sql = "DELETE FROM transfers WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *TransferRepository, allocator: std.mem.Allocator, items: []firearm.Transfer) void {
        for (items) |*t| {
            allocator.free(t.id);
            allocator.free(t.firearm_id);
            allocator.free(t.buyer_name);
            allocator.free(t.buyer_address);
            allocator.free(t.buyer_dl_number);
            allocator.free(t.buyer_ltc_number);
            allocator.free(t.ffl_dealer);
            allocator.free(t.ffl_license);
            allocator.free(t.notes);
        }
        allocator.free(items);
    }

    fn rowToTransfer(self: *TransferRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !firearm.Transfer {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const firearm_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const transfer_date = self.db.columnInt64(stmt, 2);
        const buyer_name = try allocator.dupe(u8, self.db.columnText(stmt, 3));
        const buyer_address = try allocator.dupe(u8, self.db.columnText(stmt, 4));
        const buyer_dl_number = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const buyer_ltc_number = try allocator.dupe(u8, self.db.columnText(stmt, 6));
        const sale_price = c.sqlite3_column_double(stmt, 7);
        const ffl_dealer = try allocator.dupe(u8, self.db.columnText(stmt, 8));
        const ffl_license = try allocator.dupe(u8, self.db.columnText(stmt, 9));
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 10));

        return .{
            .id = id,
            .firearm_id = firearm_id,
            .transfer_date = transfer_date,
            .buyer_name = buyer_name,
            .buyer_address = buyer_address,
            .buyer_dl_number = buyer_dl_number,
            .buyer_ltc_number = buyer_ltc_number,
            .sale_price = sale_price,
            .ffl_dealer = ffl_dealer,
            .ffl_license = ffl_license,
            .notes = notes,
        };
    }
};

pub const ReloadBatchRepository = struct {
    db: *Database,

    pub fn create(self: *ReloadBatchRepository, rb: reloading.ReloadBatch) !void {
        const sql = "INSERT INTO reload_batches VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, rb.id.ptr, @intCast(rb.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, rb.cartridge.ptr, @intCast(rb.cartridge.len), null);
        if (rb.firearm_id) |fid| {
            _ = c.sqlite3_bind_text(stmt, 3, fid.ptr, @intCast(fid.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 4, rb.date_created);
        if (rb.bullet_maker.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, rb.bullet_maker.ptr, @intCast(rb.bullet_maker.len), null);
        }
        if (rb.bullet_model.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 6, rb.bullet_model.ptr, @intCast(rb.bullet_model.len), null);
        }
        if (rb.bullet_weight_gr) |bwg| {
            _ = c.sqlite3_bind_int(stmt, 7, bwg);
        }
        if (rb.powder_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 8, rb.powder_name.ptr, @intCast(rb.powder_name.len), null);
        }
        if (rb.powder_charge_gr) |pcg| {
            _ = c.sqlite3_bind_double(stmt, 9, pcg);
        }
        if (rb.powder_lot.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 10, rb.powder_lot.ptr, @intCast(rb.powder_lot.len), null);
        }
        if (rb.primer_maker.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 11, rb.primer_maker.ptr, @intCast(rb.primer_maker.len), null);
        }
        if (rb.primer_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 12, rb.primer_type.ptr, @intCast(rb.primer_type.len), null);
        }
        if (rb.case_brand.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 13, rb.case_brand.ptr, @intCast(rb.case_brand.len), null);
        }
        if (rb.case_times_fired) |ctf| {
            _ = c.sqlite3_bind_int(stmt, 14, ctf);
        }
        if (rb.case_prep_notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 15, rb.case_prep_notes.ptr, @intCast(rb.case_prep_notes.len), null);
        }
        if (rb.coal_in) |ci| {
            _ = c.sqlite3_bind_double(stmt, 16, ci);
        }
        if (rb.crimp_style.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 17, rb.crimp_style.ptr, @intCast(rb.crimp_style.len), null);
        }
        if (rb.test_date) |td| {
            _ = c.sqlite3_bind_int64(stmt, 18, td);
        }
        if (rb.avg_velocity) |av| {
            _ = c.sqlite3_bind_int(stmt, 19, av);
        }
        if (rb.es) |es| {
            _ = c.sqlite3_bind_int(stmt, 20, es);
        }
        if (rb.sd) |sd| {
            _ = c.sqlite3_bind_int(stmt, 21, sd);
        }
        if (rb.group_size_inches) |gsi| {
            _ = c.sqlite3_bind_double(stmt, 22, gsi);
        }
        if (rb.group_distance_yards) |gdy| {
            _ = c.sqlite3_bind_int(stmt, 23, gdy);
        }
        if (rb.intended_use.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 24, rb.intended_use.ptr, @intCast(rb.intended_use.len), null);
        }
        const status_str = types.ReloadStatus.toString(rb.status);
        _ = c.sqlite3_bind_text(stmt, 25, status_str.ptr, @intCast(status_str.len), null);
        if (rb.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 26, rb.notes.ptr, @intCast(rb.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *ReloadBatchRepository, allocator: std.mem.Allocator) ![]reloading.ReloadBatch {
        const sql = "SELECT * FROM reload_batches ORDER BY date_created DESC";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(reloading.ReloadBatch){};
        errdefer {
            for (items.items) |*rb| {
                allocator.free(rb.id);
                allocator.free(rb.cartridge);
                if (rb.firearm_id) |fid| allocator.free(fid);
                allocator.free(rb.bullet_maker);
                allocator.free(rb.bullet_model);
                allocator.free(rb.powder_name);
                allocator.free(rb.powder_lot);
                allocator.free(rb.primer_maker);
                allocator.free(rb.primer_type);
                allocator.free(rb.case_brand);
                allocator.free(rb.case_prep_notes);
                allocator.free(rb.crimp_style);
                allocator.free(rb.intended_use);
                allocator.free(rb.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const rb = try self.rowToReloadBatch(stmt, allocator);
            try items.append(allocator, rb);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *ReloadBatchRepository, allocator: std.mem.Allocator, id: []const u8) !?reloading.ReloadBatch {
        const sql = "SELECT * FROM reload_batches WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToReloadBatch(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *ReloadBatchRepository, rb: reloading.ReloadBatch) !void {
        const sql = "UPDATE reload_batches SET cartridge = ?, firearm_id = ?, bullet_maker = ?, bullet_model = ?, bullet_weight_gr = ?, powder_name = ?, powder_charge_gr = ?, powder_lot = ?, primer_maker = ?, primer_type = ?, case_brand = ?, case_times_fired = ?, case_prep_notes = ?, coal_in = ?, crimp_style = ?, test_date = ?, avg_velocity = ?, es = ?, sd = ?, group_size_inches = ?, group_distance_yards = ?, intended_use = ?, status = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var bind_idx: i32 = 1;

        _ = c.sqlite3_bind_text(stmt, bind_idx, rb.cartridge.ptr, @intCast(rb.cartridge.len), null);
        bind_idx += 1;
        if (rb.firearm_id) |fid| {
            _ = c.sqlite3_bind_text(stmt, bind_idx, fid.ptr, @intCast(fid.len), null);
        }
        bind_idx += 1;
        if (rb.bullet_maker.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.bullet_maker.ptr, @intCast(rb.bullet_maker.len), null);
        }
        bind_idx += 1;
        if (rb.bullet_model.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.bullet_model.ptr, @intCast(rb.bullet_model.len), null);
        }
        bind_idx += 1;
        if (rb.bullet_weight_gr) |bwg| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, bwg);
        }
        bind_idx += 1;
        if (rb.powder_name.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.powder_name.ptr, @intCast(rb.powder_name.len), null);
        }
        bind_idx += 1;
        if (rb.powder_charge_gr) |pcg| {
            _ = c.sqlite3_bind_double(stmt, bind_idx, pcg);
        }
        bind_idx += 1;
        if (rb.powder_lot.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.powder_lot.ptr, @intCast(rb.powder_lot.len), null);
        }
        bind_idx += 1;
        if (rb.primer_maker.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.primer_maker.ptr, @intCast(rb.primer_maker.len), null);
        }
        bind_idx += 1;
        if (rb.primer_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.primer_type.ptr, @intCast(rb.primer_type.len), null);
        }
        bind_idx += 1;
        if (rb.case_brand.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.case_brand.ptr, @intCast(rb.case_brand.len), null);
        }
        bind_idx += 1;
        if (rb.case_times_fired) |ctf| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, ctf);
        }
        bind_idx += 1;
        if (rb.case_prep_notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.case_prep_notes.ptr, @intCast(rb.case_prep_notes.len), null);
        }
        bind_idx += 1;
        if (rb.coal_in) |ci| {
            _ = c.sqlite3_bind_double(stmt, bind_idx, ci);
        }
        bind_idx += 1;
        if (rb.crimp_style.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.crimp_style.ptr, @intCast(rb.crimp_style.len), null);
        }
        bind_idx += 1;
        if (rb.test_date) |td| {
            _ = c.sqlite3_bind_int64(stmt, bind_idx, td);
        }
        bind_idx += 1;
        if (rb.avg_velocity) |av| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, av);
        }
        bind_idx += 1;
        if (rb.es) |es| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, es);
        }
        bind_idx += 1;
        if (rb.sd) |sd| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, sd);
        }
        bind_idx += 1;
        if (rb.group_size_inches) |gsi| {
            _ = c.sqlite3_bind_double(stmt, bind_idx, gsi);
        }
        bind_idx += 1;
        if (rb.group_distance_yards) |gdy| {
            _ = c.sqlite3_bind_int(stmt, bind_idx, gdy);
        }
        bind_idx += 1;
        if (rb.intended_use.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.intended_use.ptr, @intCast(rb.intended_use.len), null);
        }
        bind_idx += 1;
        const status_str = types.ReloadStatus.toString(rb.status);
        _ = c.sqlite3_bind_text(stmt, bind_idx, status_str.ptr, @intCast(status_str.len), null);
        bind_idx += 1;
        if (rb.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, bind_idx, rb.notes.ptr, @intCast(rb.notes.len), null);
        }
        bind_idx += 1;
        _ = c.sqlite3_bind_text(stmt, bind_idx, rb.id.ptr, @intCast(rb.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *ReloadBatchRepository, id: []const u8) !void {
        const sql = "DELETE FROM reload_batches WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *ReloadBatchRepository, allocator: std.mem.Allocator, items: []reloading.ReloadBatch) void {
        for (items) |*rb| {
            allocator.free(rb.id);
            allocator.free(rb.cartridge);
            if (rb.firearm_id) |fid| allocator.free(fid);
            allocator.free(rb.bullet_maker);
            allocator.free(rb.bullet_model);
            allocator.free(rb.powder_name);
            allocator.free(rb.powder_lot);
            allocator.free(rb.primer_maker);
            allocator.free(rb.primer_type);
            allocator.free(rb.case_brand);
            allocator.free(rb.case_prep_notes);
            allocator.free(rb.crimp_style);
            allocator.free(rb.intended_use);
            allocator.free(rb.notes);
        }
        allocator.free(items);
    }

    fn rowToReloadBatch(self: *ReloadBatchRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !reloading.ReloadBatch {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const cartridge = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const firearm_id_null = self.db.columnTextNullable(stmt, 2);
        const date_created = self.db.columnInt64(stmt, 3);
        const bullet_maker = try allocator.dupe(u8, self.db.columnText(stmt, 4));
        const bullet_model = try allocator.dupe(u8, self.db.columnText(stmt, 5));
        const bullet_weight_gr = self.db.columnIntNullable(stmt, 6);
        const powder_name = try allocator.dupe(u8, self.db.columnText(stmt, 7));
        const powder_charge_gr = if (c.sqlite3_column_type(stmt, 8) != c.SQLITE_NULL) c.sqlite3_column_double(stmt, 8) else null;
        const powder_lot = try allocator.dupe(u8, self.db.columnText(stmt, 9));
        const primer_maker = try allocator.dupe(u8, self.db.columnText(stmt, 10));
        const primer_type = try allocator.dupe(u8, self.db.columnText(stmt, 11));
        const case_brand = try allocator.dupe(u8, self.db.columnText(stmt, 12));
        const case_times_fired = self.db.columnIntNullable(stmt, 13);
        const case_prep_notes = try allocator.dupe(u8, self.db.columnText(stmt, 14));
        const coal_in = if (c.sqlite3_column_type(stmt, 15) != c.SQLITE_NULL) c.sqlite3_column_double(stmt, 15) else null;
        const crimp_style = try allocator.dupe(u8, self.db.columnText(stmt, 16));
        const test_date = self.db.columnInt64Nullable(stmt, 17);
        const avg_velocity = self.db.columnIntNullable(stmt, 18);
        const es = self.db.columnIntNullable(stmt, 19);
        const sd = self.db.columnIntNullable(stmt, 20);
        const group_size_inches = if (c.sqlite3_column_type(stmt, 21) != c.SQLITE_NULL) c.sqlite3_column_double(stmt, 21) else null;
        const group_distance_yards = self.db.columnIntNullable(stmt, 22);
        const intended_use = try allocator.dupe(u8, self.db.columnText(stmt, 23));
        const status_str = self.db.columnText(stmt, 24);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 25));

        return .{
            .id = id,
            .cartridge = cartridge,
            .firearm_id = if (firearm_id_null) |fid| try allocator.dupe(u8, fid) else null,
            .date_created = date_created,
            .bullet_maker = bullet_maker,
            .bullet_model = bullet_model,
            .bullet_weight_gr = if (bullet_weight_gr) |bwg| @intCast(bwg) else null,
            .powder_name = powder_name,
            .powder_charge_gr = powder_charge_gr,
            .powder_lot = powder_lot,
            .primer_maker = primer_maker,
            .primer_type = primer_type,
            .case_brand = case_brand,
            .case_times_fired = if (case_times_fired) |ctf| @intCast(ctf) else null,
            .case_prep_notes = case_prep_notes,
            .coal_in = coal_in,
            .crimp_style = crimp_style,
            .test_date = test_date,
            .avg_velocity = if (avg_velocity) |av| @intCast(av) else null,
            .es = if (es) |e| @intCast(e) else null,
            .sd = if (sd) |s| @intCast(s) else null,
            .group_size_inches = group_size_inches,
            .group_distance_yards = if (group_distance_yards) |gdy| @intCast(gdy) else null,
            .intended_use = intended_use,
            .status = types.ReloadStatus.fromString(status_str),
            .notes = notes,
        };
    }
};

pub const LoadoutRepository = struct {
    db: *Database,

    pub fn create(self: *LoadoutRepository, l: loadout.Loadout) !void {
        const sql = "INSERT INTO loadouts VALUES (?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, l.id.ptr, @intCast(l.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, l.name.ptr, @intCast(l.name.len), null);
        if (l.description.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, l.description.ptr, @intCast(l.description.len), null);
        }
        _ = c.sqlite3_bind_int64(stmt, 4, l.created_date);
        if (l.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, l.notes.ptr, @intCast(l.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getAll(self: *LoadoutRepository, allocator: std.mem.Allocator) ![]loadout.Loadout {
        const sql = "SELECT id, name, description, created_date, notes FROM loadouts ORDER BY name";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        var items = std.ArrayListUnmanaged(loadout.Loadout){};
        errdefer {
            for (items.items) |*l| {
                allocator.free(l.id);
                allocator.free(l.name);
                allocator.free(l.description);
                allocator.free(l.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const l = try self.rowToLoadout(stmt, allocator);
            try items.append(allocator, l);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn getById(self: *LoadoutRepository, allocator: std.mem.Allocator, id: []const u8) !?loadout.Loadout {
        const sql = "SELECT id, name, description, created_date, notes FROM loadouts WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);

        if (try self.db.step(stmt)) {
            return try self.rowToLoadout(stmt, allocator);
        }
        return null;
    }

    pub fn update(self: *LoadoutRepository, l: loadout.Loadout) !void {
        const sql = "UPDATE loadouts SET name = ?, description = ?, notes = ? WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, l.name.ptr, @intCast(l.name.len), null);
        if (l.description.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 2, l.description.ptr, @intCast(l.description.len), null);
        }
        if (l.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 3, l.notes.ptr, @intCast(l.notes.len), null);
        }
        _ = c.sqlite3_bind_text(stmt, 4, l.id.ptr, @intCast(l.id.len), null);

        _ = try self.db.step(stmt);
    }

    pub fn delete(self: *LoadoutRepository, id: []const u8) !void {
        const sql = "DELETE FROM loadouts WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn countItems(self: *LoadoutRepository, loadout_id: []const u8) !i32 {
        const sql = "SELECT COUNT(*) FROM loadout_items WHERE loadout_id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, loadout_id.ptr, @intCast(loadout_id.len), null);

        if (try self.db.step(stmt)) {
            return c.sqlite3_column_int(stmt, 0);
        }
        return 0;
    }

    pub fn countConsumables(self: *LoadoutRepository, loadout_id: []const u8) !i32 {
        const sql = "SELECT COUNT(*) FROM loadout_consumables WHERE loadout_id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, loadout_id.ptr, @intCast(loadout_id.len), null);

        if (try self.db.step(stmt)) {
            return c.sqlite3_column_int(stmt, 0);
        }
        return 0;
    }

    pub fn deinitAll(_: *LoadoutRepository, allocator: std.mem.Allocator, items: []loadout.Loadout) void {
        for (items) |*l| {
            allocator.free(l.id);
            allocator.free(l.name);
            allocator.free(l.description);
            allocator.free(l.notes);
        }
        allocator.free(items);
    }

    pub fn deinit(_: *LoadoutRepository, allocator: std.mem.Allocator, item: loadout.Loadout) void {
        allocator.free(item.id);
        allocator.free(item.name);
        allocator.free(item.description);
        allocator.free(item.notes);
    }

    fn rowToLoadout(self: *LoadoutRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !loadout.Loadout {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const name = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const description = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const created_date = self.db.columnInt64(stmt, 3);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 4));

        return .{
            .id = id,
            .name = name,
            .description = description,
            .created_date = created_date,
            .notes = notes,
        };
    }
};

pub const LoadoutItemRepository = struct {
    db: *Database,

    pub fn create(self: *LoadoutItemRepository, li: loadout.LoadoutItem) !void {
        const sql = "INSERT INTO loadout_items VALUES (?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, li.id.ptr, @intCast(li.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, li.loadout_id.ptr, @intCast(li.loadout_id.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, li.item_id.ptr, @intCast(li.item_id.len), null);
        const type_str = types.GearCategory.toString(li.item_type);
        _ = c.sqlite3_bind_text(stmt, 4, type_str.ptr, @intCast(type_str.len), null);
        if (li.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, li.notes.ptr, @intCast(li.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getByLoadoutId(self: *LoadoutItemRepository, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutItem {
        const sql = "SELECT id, loadout_id, item_id, item_type, notes FROM loadout_items WHERE loadout_id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, loadout_id.ptr, @intCast(loadout_id.len), null);

        var items = std.ArrayListUnmanaged(loadout.LoadoutItem){};
        errdefer {
            for (items.items) |*li| {
                allocator.free(li.id);
                allocator.free(li.loadout_id);
                allocator.free(li.item_id);
                allocator.free(li.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const li = try self.rowToLoadoutItem(stmt, allocator);
            try items.append(allocator, li);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *LoadoutItemRepository, id: []const u8) !void {
        const sql = "DELETE FROM loadout_items WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *LoadoutItemRepository, allocator: std.mem.Allocator, items: []loadout.LoadoutItem) void {
        for (items) |*li| {
            allocator.free(li.id);
            allocator.free(li.loadout_id);
            allocator.free(li.item_id);
            allocator.free(li.notes);
        }
        allocator.free(items);
    }

    fn rowToLoadoutItem(self: *LoadoutItemRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !loadout.LoadoutItem {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const loadout_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const item_id = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const type_str = self.db.columnText(stmt, 3);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 4));

        return .{
            .id = id,
            .loadout_id = loadout_id,
            .item_id = item_id,
            .item_type = types.GearCategory.fromString(type_str),
            .notes = notes,
        };
    }
};

pub const LoadoutConsumableRepository = struct {
    db: *Database,

    pub fn create(self: *LoadoutConsumableRepository, lc: loadout.LoadoutConsumable) !void {
        const sql = "INSERT INTO loadout_consumables VALUES (?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, lc.id.ptr, @intCast(lc.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, lc.loadout_id.ptr, @intCast(lc.loadout_id.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, lc.consumable_id.ptr, @intCast(lc.consumable_id.len), null);
        _ = c.sqlite3_bind_int(stmt, 4, lc.quantity);
        if (lc.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 5, lc.notes.ptr, @intCast(lc.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getByLoadoutId(self: *LoadoutConsumableRepository, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutConsumable {
        const sql = "SELECT id, loadout_id, consumable_id, quantity, notes FROM loadout_consumables WHERE loadout_id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, loadout_id.ptr, @intCast(loadout_id.len), null);

        var items = std.ArrayListUnmanaged(loadout.LoadoutConsumable){};
        errdefer {
            for (items.items) |*lc| {
                allocator.free(lc.id);
                allocator.free(lc.loadout_id);
                allocator.free(lc.consumable_id);
                allocator.free(lc.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const lc = try self.rowToLoadoutConsumable(stmt, allocator);
            try items.append(allocator, lc);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *LoadoutConsumableRepository, id: []const u8) !void {
        const sql = "DELETE FROM loadout_consumables WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *LoadoutConsumableRepository, allocator: std.mem.Allocator, items: []loadout.LoadoutConsumable) void {
        for (items) |*lc| {
            allocator.free(lc.id);
            allocator.free(lc.loadout_id);
            allocator.free(lc.consumable_id);
            allocator.free(lc.notes);
        }
        allocator.free(items);
    }

    fn rowToLoadoutConsumable(self: *LoadoutConsumableRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !loadout.LoadoutConsumable {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const loadout_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const consumable_id = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const quantity = self.db.columnInt(stmt, 3);
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 4));

        return .{
            .id = id,
            .loadout_id = loadout_id,
            .consumable_id = consumable_id,
            .quantity = @intCast(quantity),
            .notes = notes,
        };
    }
};

pub const LoadoutCheckoutRepository = struct {
    db: *Database,

    pub fn create(self: *LoadoutCheckoutRepository, lc: loadout.LoadoutCheckout) !void {
        const sql = "INSERT INTO loadout_checkouts VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, lc.id.ptr, @intCast(lc.id.len), null);
        _ = c.sqlite3_bind_text(stmt, 2, lc.loadout_id.ptr, @intCast(lc.loadout_id.len), null);
        _ = c.sqlite3_bind_text(stmt, 3, lc.checkout_id.ptr, @intCast(lc.checkout_id.len), null);
        if (lc.return_date) |rd| {
            _ = c.sqlite3_bind_int64(stmt, 4, rd);
        }
        _ = c.sqlite3_bind_int(stmt, 5, lc.rounds_fired);
        _ = c.sqlite3_bind_int(stmt, 6, if (lc.rain_exposure) 1 else 0);
        if (lc.ammo_type.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 7, lc.ammo_type.ptr, @intCast(lc.ammo_type.len), null);
        }
        if (lc.notes.len > 0) {
            _ = c.sqlite3_bind_text(stmt, 8, lc.notes.ptr, @intCast(lc.notes.len), null);
        }

        _ = try self.db.step(stmt);
    }

    pub fn getByLoadoutId(self: *LoadoutCheckoutRepository, allocator: std.mem.Allocator, loadout_id: []const u8) ![]loadout.LoadoutCheckout {
        const sql = "SELECT id, loadout_id, checkout_id, return_date, rounds_fired, rain_exposure, ammo_type, notes FROM loadout_checkouts WHERE loadout_id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, loadout_id.ptr, @intCast(loadout_id.len), null);

        var items = std.ArrayListUnmanaged(loadout.LoadoutCheckout){};
        errdefer {
            for (items.items) |*lc| {
                allocator.free(lc.id);
                allocator.free(lc.loadout_id);
                allocator.free(lc.checkout_id);
                allocator.free(lc.ammo_type);
                allocator.free(lc.notes);
            }
            allocator.free(items.items);
        }

        while (try self.db.step(stmt)) {
            const lc = try self.rowToLoadoutCheckout(stmt, allocator);
            try items.append(allocator, lc);
        }

        return items.toOwnedSlice(allocator);
    }

    pub fn delete(self: *LoadoutCheckoutRepository, id: []const u8) !void {
        const sql = "DELETE FROM loadout_checkouts WHERE id = ?";
        const stmt_opt = try self.db.prepare(sql);
        const stmt = stmt_opt orelse return error.PrepareFailed;
        defer self.db.finalize(stmt);

        _ = c.sqlite3_bind_text(stmt, 1, id.ptr, @intCast(id.len), null);
        _ = try self.db.step(stmt);
    }

    pub fn deinitAll(_: *LoadoutCheckoutRepository, allocator: std.mem.Allocator, items: []loadout.LoadoutCheckout) void {
        for (items) |*lc| {
            allocator.free(lc.id);
            allocator.free(lc.loadout_id);
            allocator.free(lc.checkout_id);
            allocator.free(lc.ammo_type);
            allocator.free(lc.notes);
        }
        allocator.free(items);
    }

    fn rowToLoadoutCheckout(self: *LoadoutCheckoutRepository, stmt: *c.sqlite3_stmt, allocator: std.mem.Allocator) !loadout.LoadoutCheckout {
        const id = try allocator.dupe(u8, self.db.columnText(stmt, 0));
        const loadout_id = try allocator.dupe(u8, self.db.columnText(stmt, 1));
        const checkout_id = try allocator.dupe(u8, self.db.columnText(stmt, 2));
        const return_date = self.db.columnInt64Nullable(stmt, 3);
        const rounds_fired = self.db.columnInt(stmt, 4);
        const rain_exposure = self.db.columnInt(stmt, 5) != 0;
        const ammo_type = try allocator.dupe(u8, self.db.columnText(stmt, 6));
        const notes = try allocator.dupe(u8, self.db.columnText(stmt, 7));

        return .{
            .id = id,
            .loadout_id = loadout_id,
            .checkout_id = checkout_id,
            .return_date = return_date,
            .rounds_fired = @intCast(rounds_fired),
            .rain_exposure = rain_exposure,
            .ammo_type = ammo_type,
            .notes = notes,
        };
    }
};
