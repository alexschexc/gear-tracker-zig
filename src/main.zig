const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const gear = @import("gearTracker_zig");

var window: *zglfw.Window = undefined;
var allocator: std.mem.Allocator = undefined;
var db: *gear.Database = undefined;

var selected_id: ?[]const u8 = null;
var current_category: usize = 0;
var search_buffer: [256:0]u8 = .{0} ** 256;

var modal_open: bool = false;
var modal_mode: enum { none, add, edit } = .none;

var loadout_modal_open: bool = false;
var loadout_modal_mode: enum { none, add, edit } = .none;
var loadout_item_tab: usize = 0;

var maint_modal_open: bool = false;
var history_modal_open: bool = false;
var transfer_modal_open: bool = false;
var checkout_modal_open: bool = false;
var return_modal_open: bool = false;

var loadout_name: [256:0]u8 = .{0} ** 256;
var loadout_description: [256:0]u8 = .{0} ** 256;
var loadout_notes: [1024:0]u8 = .{0} ** 1024;
var loadout_selected_items: std.ArrayListUnmanaged(struct { id: []const u8, item_type: gear.types.GearCategory }) = .{};

var checkout_borrower_name: [256:0]u8 = .{0} ** 256;

var form_name: [256:0]u8 = .{0} ** 256;
var form_caliber: [256:0]u8 = .{0} ** 256;
var form_serial: [256:0]u8 = .{0} ** 256;
var form_barrel: [256:0]u8 = .{0} ** 256;
var form_trust: [256:0]u8 = .{0} ** 256;
var form_notes: [1024:0]u8 = .{0} ** 1024;

var form_clean_interval: i32 = 500;
var form_oil_interval: i32 = 90;
var form_status: usize = 0;

var form_manufacturer: [256:0]u8 = .{0} ** 256;
var form_tax_stamp: [256:0]u8 = .{0} ** 256;
var form_caliber_bore: [256:0]u8 = .{0} ** 256;
var form_form_type: [256:0]u8 = .{0} ** 256;
var form_model: [256:0]u8 = .{0} ** 256;
var form_mounted_on: [256:0]u8 = .{0} ** 256;
var form_mount_position: [256:0]u8 = .{0} ** 256;
var form_zero_distance: i32 = 0;
var form_zero_notes: [256:0]u8 = .{0} ** 256;

var form_category: [256:0]u8 = .{0} ** 256;
var form_unit: [256:0]u8 = .{0} ** 256;
var form_quantity: i32 = 0;
var form_min_quantity: i32 = 0;
var form_nfa_type: i32 = 0;
var form_mounted_firearm_index: i32 = 0;
var form_consumable_category: i32 = 0;
var form_consumable_unit: i32 = 0;

var stock_modal_open: bool = false;
var stock_is_add: bool = true;
var stock_quantity: i32 = 1;

var maint_type: i32 = 0;
var maint_type_buf: [64:0]u8 = .{0} ** 64;
var maint_rounds: i32 = 0;
var maint_reset_rounds: bool = false;
var maint_details: [512:0]u8 = .{0} ** 512;

var transfer_buyer_name: [256:0]u8 = .{0} ** 256;
var transfer_address: [512:0]u8 = .{0} ** 512;
var transfer_dl: [256:0]u8 = .{0} ** 256;
var transfer_ltc: [256:0]u8 = .{0} ** 256;
var transfer_price: f64 = 0.0;
var transfer_ffl: [256:0]u8 = .{0} ** 256;
var transfer_notes: [512:0]u8 = .{0} ** 512;

var checkout_is_loadout: bool = false;
var checkout_item_category: i32 = 0;

var reload_results_modal_open: bool = false;
var reload_status: i32 = 0;
var reload_velocity: i32 = 0;
var reload_es: i32 = 0;
var reload_sd: i32 = 0;
var reload_group_size: f64 = 0.0;
var reload_group_distance: i32 = 100;
var import_modal_open: bool = false;
var import_filename: [512:0]u8 = .{0} ** 512;
var import_duplicate_mode: i32 = 0;
var import_result_message: [1024:0]u8 = .{0} ** 1024;
var import_success_count: i32 = 0;
var import_error_count: i32 = 0;

const ImportDuplicateMode = enum { skip, overwrite, create_new };

var form_cartridge: [256:0]u8 = .{0} ** 256;
var form_firearm_id: [256:0]u8 = .{0} ** 256;
var form_bullet_maker: [256:0]u8 = .{0} ** 256;
var form_bullet_model: [256:0]u8 = .{0} ** 256;
var form_bullet_weight: i32 = 0;
var form_powder_name: [256:0]u8 = .{0} ** 256;
var form_powder_charge: f64 = 0.0;
var form_powder_lot: [256:0]u8 = .{0} ** 256;
var form_primer_maker: [256:0]u8 = .{0} ** 256;
var form_primer_type: [256:0]u8 = .{0} ** 256;
var form_case_brand: [256:0]u8 = .{0} ** 256;
var form_case_times_fired: i32 = 0;
var form_coal: f64 = 0.0;
var form_crimp_style: [256:0]u8 = .{0} ** 256;
var form_intended_use: [256:0]u8 = .{0} ** 256;

var test_velocity: i32 = 0;
var test_es: i32 = 0;
var test_sd: i32 = 0;
var test_group_size: f64 = 0.0;
var test_group_distance: i32 = 0;

var reload_notes: [512:0]u8 = .{0} ** 512;

const Category = enum {
    firearms,
    soft_gear,
    nfa_items,
    attachments,
    consumables,
    reloading,
    loadouts,
    checkouts,
    borrowers,
    transfers,
    import_export,
};

const DisplayItem = struct {
    id: []const u8,
    name: []const u8,
    col1: []const u8,
    col2: []const u8,
    col3: []const u8,
    rounds: i32 = 0,
    last_cleaned: []const u8 = "",
    notes: []const u8 = "",
    created: []const u8 = "",
    price: f64 = 0.0,
};

const StatusOptions = [_][:0]const u8{ "AVAILABLE", "CHECKED_OUT", "MAINTENANCE", "RETIRED" };
const MaintTypeOptions = [_][:0]const u8{ "CLEANING", "LUBRICATION", "REPAIR", "ZEROING", "HUNTING", "INSPECTION", "FIRED_ROUNDS", "OILING", "RAIN_EXPOSURE", "CORROSIVE_AMMO", "LEAD_AMMO", "OIL", "OTHER" };
const MaintTypeOptionsStr: [:0]const u8 = MaintTypeOptions[0] ++ "\x00" ++ MaintTypeOptions[1] ++ "\x00" ++ MaintTypeOptions[2] ++ "\x00" ++ MaintTypeOptions[3] ++ "\x00" ++ MaintTypeOptions[4] ++ "\x00" ++ MaintTypeOptions[5] ++ "\x00" ++ MaintTypeOptions[6] ++ "\x00" ++ MaintTypeOptions[7] ++ "\x00" ++ MaintTypeOptions[8] ++ "\x00" ++ MaintTypeOptions[9] ++ "\x00" ++ MaintTypeOptions[10] ++ "\x00" ++ MaintTypeOptions[11] ++ "\x00" ++ MaintTypeOptions[12] ++ "\x00";

const NFAItemTypeOptions = [_][:0]const u8{ "SUPPRESSOR", "SBR", "SBS", "AOW", "DD" };
const NFAItemTypeOptionsStr: [:0]const u8 = NFAItemTypeOptions[0] ++ "\x00" ++ NFAItemTypeOptions[1] ++ "\x00" ++ NFAItemTypeOptions[2] ++ "\x00" ++ NFAItemTypeOptions[3] ++ "\x00" ++ NFAItemTypeOptions[4] ++ "\x00";

const ConsumableCategoryOptions = [_][:0]const u8{ "AMMO", "BATTERIES", "HYGIENE", "MEDICAL", "CLEANING", "OTHER" };
const ConsumableCategoryOptionsStr: [:0]const u8 = ConsumableCategoryOptions[0] ++ "\x00" ++ ConsumableCategoryOptions[1] ++ "\x00" ++ ConsumableCategoryOptions[2] ++ "\x00" ++ ConsumableCategoryOptions[3] ++ "\x00" ++ ConsumableCategoryOptions[4] ++ "\x00" ++ ConsumableCategoryOptions[5] ++ "\x00";

const ConsumableUnitOptions = [_][:0]const u8{ "rounds", "count", "oz", "pairs", "boxes" };
const ConsumableUnitOptionsStr: [:0]const u8 = ConsumableUnitOptions[0] ++ "\x00" ++ ConsumableUnitOptions[1] ++ "\x00" ++ ConsumableUnitOptions[2] ++ "\x00" ++ ConsumableUnitOptions[3] ++ "\x00" ++ ConsumableUnitOptions[4] ++ "\x00";

const ReloadStatusOptions = [_][:0]const u8{ "WORKUP", "APPROVED", "REJECTED" };
const ReloadStatusOptionsStr: [:0]const u8 = ReloadStatusOptions[0] ++ "\x00" ++ ReloadStatusOptions[1] ++ "\x00" ++ ReloadStatusOptions[2] ++ "\x00";

fn getFirearmNamesStr() [:0]const u8 {
    var fw_repo = gear.FirearmRepository{ .db = db };
    const firearms = fw_repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};

    var buf: [4096]u8 = undefined;
    var pos: usize = 0;

    for (firearms) |f| {
        const name_len = f.name.len;
        if (pos + name_len + 1 >= buf.len) break;
        std.mem.copyForwards(u8, buf[pos..], f.name);
        pos += name_len;
        buf[pos] = 0;
        pos += 1;
    }

    if (pos == 0) {
        buf[0] = 0;
    }

    return buf[0..pos :0];
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    allocator = gpa.allocator();

    try zglfw.init();
    defer zglfw.terminate();

    const monitor = zglfw.Monitor.getPrimary().?;
    const video_mode = try monitor.getVideoMode();
    const screen_width = @as(u32, @intCast(video_mode.width));
    const screen_height = @as(u32, @intCast(video_mode.height));

    const window_width = @min(screen_width * 80 / 100, 1400);
    const window_height = @min(screen_height * 80 / 100, 900);

    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_forward_compat, true);
    zglfw.windowHint(.decorated, false);

    window = try zglfw.Window.create(window_width, window_height, "GearTracker", null, null);
    defer window.destroy();

    const x = @as(c_int, @intCast((screen_width - window_width) / 2));
    const y = @as(c_int, @intCast((screen_height - window_height) / 2));
    window.setPos(x, y);

    zglfw.makeContextCurrent(window);

    const scale = window.getContentScale();
    const font_scale = scale[0];

    zgui.init(allocator);

    var font_config = zgui.FontConfig.init();
    font_config.size_pixels = 16.0 * font_scale;
    _ = zgui.io.addFontDefault(font_config);

    zgui.backend.init(window);
    defer zgui.deinit();

    const home_dir = std.posix.getenv("HOME") orelse ".";
    var db_path_buf: [512]u8 = undefined;
    const db_path = std.fmt.bufPrint(&db_path_buf, "{s}/.gear_tracker/tracker.db", .{home_dir}) catch ".gear_tracker/tracker.db";

    db = try allocator.create(gear.Database);
    db.* = try gear.Database.init(allocator, db_path);
    defer {
        db.deinit();
        allocator.destroy(db);
    }

    while (!window.shouldClose()) {
        zglfw.pollEvents();

        const fb_size = window.getFramebufferSize();
        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));

        try renderUI();

        zgui.backend.draw();

        window.swapBuffers();
    }
}

fn renderUI() !void {
    try renderItemModal();
    try renderMaintenanceModal();
    try renderHistoryModal();
    try renderTransferModal();
    try renderStockModal();
    try renderCheckoutModal();
    try renderReturnModal();
    try renderLoadoutModal();
    renderImportModal();
    try renderReloadResultsModal();

    const window_size = window.getSize();
    const win_w = @as(f32, @floatFromInt(window_size[0]));
    const win_h = @as(f32, @floatFromInt(window_size[1]));

    zgui.setNextWindowPos(.{ .x = 0, .y = 0, .cond = .always });
    zgui.setNextWindowSize(.{ .w = win_w, .h = win_h, .cond = .always });

    if (zgui.begin("GearTracker", .{ .flags = .{ .no_collapse = true } })) {
        defer zgui.end();

        if (zgui.beginTabBar("categories", .{})) {
            if (zgui.beginTabItem("Firearms", .{})) {
                if (current_category != 0) {
                    selected_id = null;
                }
                current_category = 0;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Soft Gear", .{})) {
                if (current_category != 1) {
                    selected_id = null;
                }
                current_category = 1;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("NFA Items", .{})) {
                if (current_category != 2) {
                    selected_id = null;
                }
                current_category = 2;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Attachments", .{})) {
                if (current_category != 3) {
                    selected_id = null;
                }
                current_category = 3;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Consumables", .{})) {
                if (current_category != 4) {
                    selected_id = null;
                }
                current_category = 4;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Reloading", .{})) {
                if (current_category != 5) {
                    selected_id = null;
                }
                current_category = 5;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Loadouts", .{})) {
                if (current_category != 6) {
                    selected_id = null;
                }
                current_category = 6;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Checkouts", .{})) {
                if (current_category != 7) {
                    selected_id = null;
                }
                current_category = 7;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Borrowers", .{})) {
                if (current_category != 8) {
                    selected_id = null;
                }
                current_category = 8;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Transfers", .{})) {
                if (current_category != 9) {
                    selected_id = null;
                }
                current_category = 9;
                zgui.endTabItem();
            }
            if (zgui.beginTabItem("Import/Export", .{})) {
                if (current_category != 10) {
                    selected_id = null;
                }
                current_category = 10;
                zgui.endTabItem();
            }
            zgui.endTabBar();
        }

        zgui.separator();

        _ = zgui.inputText("Search", .{ .buf = &search_buffer });

        const cat: Category = @enumFromInt(current_category);
        if (cat == .import_export) {
            try renderImportExport();
        } else {
            const data = getDataForCategory(cat);
            const filtered_data = filterData(data, search_buffer);

            if (filtered_data.len == 0) {
                try renderTable(&.{});
                try renderButtons();
            } else {
                try renderTable(filtered_data);
                try renderDetails();
                try renderButtons();
            }
        }
    }
}

fn renderItemModal() !void {
    if (modal_open) {
        zgui.openPopup("ItemModal", .{});
    }
    if (zgui.beginPopup("ItemModal", .{})) {
        const cat: Category = @enumFromInt(current_category);
        if (modal_mode == .edit) {
            zgui.text("Edit Item", .{});
        } else {
            zgui.text("Add Item", .{});
        }
        zgui.separator();

        zgui.text("Name:", .{});
        _ = zgui.inputText("##name", .{ .buf = &form_name });

        if (cat == .firearms) {
            zgui.text("Caliber:", .{});
            _ = zgui.inputText("##caliber", .{ .buf = &form_caliber });

            zgui.text("Serial Number:", .{});
            _ = zgui.inputText("##serial", .{ .buf = &form_serial });

            zgui.text("Barrel Length:", .{});
            _ = zgui.inputText("##barrel", .{ .buf = &form_barrel });
            zgui.sameLine(.{});
            zgui.textDisabled("(e.g., 16\")", .{});

            zgui.text("Trust Name:", .{});
            _ = zgui.inputText("##trust", .{ .buf = &form_trust });

            zgui.text("Status:", .{});
            _ = zgui.inputText("##status", .{ .buf = &form_caliber });
            zgui.sameLine(.{});
            zgui.textDisabled("(AVAILABLE, CHECKED_OUT, MAINTENANCE, RETIRED)", .{});

            zgui.text("Clean Interval:", .{});
            _ = zgui.inputInt("##clean_int", .{ .v = &form_clean_interval, .step = 100, .step_fast = 500 });

            zgui.text("Oil Interval (days):", .{});
            _ = zgui.inputInt("##oil_int", .{ .v = &form_oil_interval, .step = 30, .step_fast = 90 });
        } else if (cat == .soft_gear) {
            zgui.text("Category:", .{});
            _ = zgui.inputText("##category", .{ .buf = &form_caliber });

            zgui.text("Brand:", .{});
            _ = zgui.inputText("##brand", .{ .buf = &form_serial });
        } else if (cat == .nfa_items) {
            zgui.text("NFA Type:", .{});
            _ = zgui.combo("##nfa_type", .{ .current_item = &form_nfa_type, .items_separated_by_zeros = NFAItemTypeOptionsStr });

            zgui.text("Manufacturer:", .{});
            _ = zgui.inputText("##manufacturer", .{ .buf = &form_manufacturer });

            zgui.text("Serial Number:", .{});
            _ = zgui.inputText("##serial", .{ .buf = &form_serial });

            zgui.text("Tax Stamp ID:", .{});
            _ = zgui.inputText("##tax_stamp", .{ .buf = &form_tax_stamp });

            zgui.text("Caliber/Bore:", .{});
            _ = zgui.inputText("##caliber_bore", .{ .buf = &form_caliber_bore });

            zgui.text("Form Type:", .{});
            _ = zgui.inputText("##form_type", .{ .buf = &form_form_type });

            zgui.text("Trust Name:", .{});
            _ = zgui.inputText("##trust_name", .{ .buf = &form_trust });

            zgui.text("Clean Interval:", .{});
            _ = zgui.inputInt("##clean_int", .{ .v = &form_clean_interval, .step = 100, .step_fast = 500 });

            zgui.text("Oil Interval (days):", .{});
            _ = zgui.inputInt("##oil_int", .{ .v = &form_oil_interval, .step = 30, .step_fast = 90 });
        } else if (cat == .attachments) {
            zgui.text("Category:", .{});
            _ = zgui.inputText("##category", .{ .buf = &form_caliber });

            zgui.text("Brand:", .{});
            _ = zgui.inputText("##brand", .{ .buf = &form_serial });

            zgui.text("Model:", .{});
            _ = zgui.inputText("##model", .{ .buf = &form_model });

            zgui.text("Serial Number:", .{});
            _ = zgui.inputText("##serial_attach", .{ .buf = &form_barrel });

            zgui.text("Mounted On:", .{});
            const fw_names = getFirearmNamesStr();
            _ = zgui.combo("##mounted_on", .{ .current_item = &form_mounted_firearm_index, .items_separated_by_zeros = fw_names });

            zgui.text("Mount Position:", .{});
            _ = zgui.inputText("##mount_position", .{ .buf = &form_mount_position });

            zgui.text("Zero Distance (yards):", .{});
            _ = zgui.inputInt("##zero_distance", .{ .v = &form_zero_distance, .step = 100 });

            zgui.text("Zero Notes:", .{});
            _ = zgui.inputTextMultiline("##zero_notes", .{ .buf = &form_zero_notes });
        } else if (cat == .consumables) {
            zgui.text("Category:", .{});
            _ = zgui.combo("##cons_category", .{ .current_item = &form_consumable_category, .items_separated_by_zeros = ConsumableCategoryOptionsStr });

            zgui.text("Unit:", .{});
            _ = zgui.combo("##unit", .{ .current_item = &form_consumable_unit, .items_separated_by_zeros = ConsumableUnitOptionsStr });

            zgui.text("Quantity:", .{});
            _ = zgui.inputInt("##quantity", .{ .v = &form_quantity, .step = 1 });

            zgui.text("Min Quantity (for alerts):", .{});
            _ = zgui.inputInt("##min_quantity", .{ .v = &form_min_quantity, .step = 1 });
        } else if (cat == .reloading) {
            zgui.text("Cartridge:", .{});
            _ = zgui.inputText("##cartridge", .{ .buf = &form_cartridge });

            zgui.text("Associated Firearm:", .{});
            _ = zgui.inputText("##firearm", .{ .buf = &form_firearm_id });
            zgui.sameLine(.{});
            zgui.textDisabled("(optional)", .{});

            zgui.text("Bullet Maker:", .{});
            _ = zgui.inputText("##bullet_maker", .{ .buf = &form_bullet_maker });

            zgui.text("Bullet Model:", .{});
            _ = zgui.inputText("##bullet_model", .{ .buf = &form_bullet_model });

            zgui.text("Bullet Weight (gr):", .{});
            _ = zgui.inputInt("##bullet_weight", .{ .v = &form_bullet_weight, .step = 1 });

            zgui.text("Powder Name:", .{});
            _ = zgui.inputText("##powder_name", .{ .buf = &form_powder_name });

            zgui.text("Powder Charge (gr):", .{});
            _ = zgui.inputDouble("##powder_charge", .{ .v = &form_powder_charge, .step = 0.1 });

            zgui.text("Powder Lot:", .{});
            _ = zgui.inputText("##powder_lot", .{ .buf = &form_powder_lot });

            zgui.text("Primer Maker:", .{});
            _ = zgui.inputText("##primer_maker", .{ .buf = &form_primer_maker });

            zgui.text("Primer Type:", .{});
            _ = zgui.inputText("##primer_type", .{ .buf = &form_primer_type });

            zgui.text("Case Brand:", .{});
            _ = zgui.inputText("##case_brand", .{ .buf = &form_case_brand });

            zgui.text("Times Fired:", .{});
            _ = zgui.inputInt("##case_times", .{ .v = &form_case_times_fired, .step = 1 });

            zgui.text("COAL (inches):", .{});
            _ = zgui.inputDouble("##coal", .{ .v = &form_coal, .step = 0.001 });

            zgui.text("Crimp Style:", .{});
            _ = zgui.inputText("##crimp", .{ .buf = &form_crimp_style });

            zgui.text("Intended Use:", .{});
            _ = zgui.inputText("##intended_use", .{ .buf = &form_intended_use });
        } else if (cat == .borrowers) {
            zgui.text("Phone:", .{});
            _ = zgui.inputText("##phone", .{ .buf = &form_caliber });

            zgui.text("Email:", .{});
            _ = zgui.inputText("##email", .{ .buf = &form_serial });
        }

        zgui.text("Notes:", .{});
        _ = zgui.inputTextMultiline("##notes", .{ .buf = &form_notes, .flags = .{ .allow_tab_input = true } });

        zgui.separator();
        if (zgui.button("Save", .{})) {
            saveItem() catch {};
            modal_open = false;
            modal_mode = .none;
            clearForm();
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            modal_open = false;
            modal_mode = .none;
            clearForm();
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn renderMaintenanceModal() !void {
    if (maint_modal_open) {
        zgui.openPopup("MaintenanceModal", .{});
    }
    if (zgui.beginPopup("MaintenanceModal", .{})) {
        zgui.text("Log Maintenance", .{});
        zgui.separator();

        zgui.text("Type:", .{});
        _ = zgui.combo("##maint_type", .{ .current_item = &maint_type, .items_separated_by_zeros = MaintTypeOptionsStr });

        zgui.text("Rounds Fired:", .{});
        _ = zgui.inputInt("##maint_rounds", .{ .v = &maint_rounds, .step = 10, .step_fast = 100 });

        _ = zgui.checkbox("Reset rounds counter", .{ .v = &maint_reset_rounds });

        zgui.text("Details:", .{});
        _ = zgui.inputTextMultiline("##maint_details", .{ .buf = &maint_details });

        zgui.separator();
        if (zgui.button("Save", .{})) {
            if (selected_id != null) {
                try saveMaintenance();
            }
            maint_modal_open = false;
            @memset(&maint_details, 0);
            maint_rounds = 0;
            maint_reset_rounds = false;
            maint_type = 0;
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            maint_modal_open = false;
            @memset(&maint_details, 0);
            maint_rounds = 0;
            maint_reset_rounds = false;
            maint_type = 0;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn renderHistoryModal() !void {
    if (history_modal_open) {
        zgui.openPopup("HistoryModal", .{});
    }
    if (zgui.beginPopup("HistoryModal", .{})) {
        const cat: Category = @enumFromInt(current_category);

        if (cat == .consumables) {
            zgui.text("Stock History", .{});
            zgui.separator();

            if (zgui.beginTable("tx_history", .{ .column = 4, .flags = .{ .resizable = true } })) {
                zgui.tableSetupColumn("Date", .{});
                zgui.tableSetupColumn("Type", .{});
                zgui.tableSetupColumn("Quantity", .{});
                zgui.tableSetupColumn("Notes", .{});
                zgui.tableHeadersRow();

                if (selected_id != null) {
                    var tx_repo = gear.ConsumableTransactionRepository{ .db = db };
                    const txs = tx_repo.getByConsumableId(allocator, selected_id.?) catch &[_]gear.consumable.ConsumableTransaction{};

                    for (txs) |tx| {
                        zgui.tableNextRow(.{});

                        _ = zgui.tableSetColumnIndex(0);
                        var date_buf: [32]u8 = undefined;
                        const date_str = formatTimestamp(tx.date, &date_buf);
                        zgui.textUnformatted(date_str);

                        _ = zgui.tableSetColumnIndex(1);
                        const tx_type = if (tx.transaction_type == .add) "ADD" else "USE";
                        zgui.textUnformatted(tx_type);

                        _ = zgui.tableSetColumnIndex(2);
                        zgui.text("{d}", .{tx.quantity});

                        _ = zgui.tableSetColumnIndex(3);
                        zgui.textUnformatted(tx.notes);
                    }
                }
                zgui.endTable();
            }
        } else {
            zgui.text("Maintenance History", .{});
            zgui.separator();

            if (zgui.beginTable("history", .{ .column = 4, .flags = .{ .resizable = true } })) {
                zgui.tableSetupColumn("Date", .{});
                zgui.tableSetupColumn("Type", .{});
                zgui.tableSetupColumn("Details", .{});
                zgui.tableSetupColumn("Rounds", .{});
                zgui.tableHeadersRow();

                if (selected_id != null) {
                    var repo = gear.MaintenanceLogRepository{ .db = db };
                    const logs = repo.getByItemId(allocator, selected_id.?) catch &[_]gear.maintenance.MaintenanceLog{};

                    for (logs) |log| {
                        zgui.tableNextRow(.{});

                        _ = zgui.tableSetColumnIndex(0);
                        var date_buf: [32]u8 = undefined;
                        const date_str = formatTimestamp(log.date, &date_buf);
                        zgui.textUnformatted(date_str);

                        _ = zgui.tableSetColumnIndex(1);
                        zgui.textUnformatted(@tagName(log.log_type));

                        _ = zgui.tableSetColumnIndex(2);
                        zgui.textUnformatted(log.details);

                        _ = zgui.tableSetColumnIndex(3);
                        if (log.ammo_count) |count| {
                            zgui.text("{d}", .{count});
                        } else {
                            zgui.text("-", .{});
                        }
                    }
                }
                zgui.endTable();
            }
        }

        zgui.separator();
        if (zgui.button("Close", .{})) {
            history_modal_open = false;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn renderImportExport() !void {
    zgui.text("Export Data", .{});
    zgui.separator();

    if (zgui.button("Export All to CSV", .{})) {
        try exportAllToCSV();
    }
    zgui.sameLine(.{});
    if (zgui.button("Export Firearms", .{})) {
        try exportCategoryToCSV(.firearms);
    }
    zgui.sameLine(.{});
    if (zgui.button("Export Soft Gear", .{})) {
        try exportCategoryToCSV(.soft_gear);
    }
    zgui.sameLine(.{});
    if (zgui.button("Export Consumables", .{})) {
        try exportCategoryToCSV(.consumables);
    }

    zgui.separator();
    zgui.text("Import Data", .{});
    zgui.separator();

    if (zgui.button("Import Firearms (CSV)", .{})) {
        try importFromCSV(.firearms);
    }
    zgui.sameLine(.{});
    if (zgui.button("Import Soft Gear (CSV)", .{})) {
        try importFromCSV(.soft_gear);
    }
    zgui.sameLine(.{});
    if (zgui.button("Import Consumables (CSV)", .{})) {
        try importFromCSV(.consumables);
    }

    zgui.separator();
    zgui.text("Templates", .{});
    zgui.separator();

    if (zgui.button("Generate Firearms Template", .{})) {
        try generateTemplate(.firearms);
    }
    zgui.sameLine(.{});
    if (zgui.button("Generate Consumables Template", .{})) {
        try generateTemplate(.consumables);
    }
}

fn exportAllToCSV() !void {
    const home_dir = std.posix.getenv("HOME") orelse ".";
    const timestamp = std.time.timestamp();

    var filename_buf: [512]u8 = undefined;
    const filename = std.fmt.bufPrint(&filename_buf, "{s}/Downloads/gearTracker_export_{d}.csv", .{ home_dir, timestamp }) catch return;

    var file = try std.fs.createFileAbsolute(filename, .{});
    defer file.close();

    var date_buf: [32]u8 = undefined;
    const date_str = formatTimestamp(@intCast(timestamp), &date_buf);

    try file.writeAll("=== METADATA ===\n");
    try file.writeAll("Export Date,Version,Export Type,Dry Run\n");
    try file.writeAll(date_str);
    try file.writeAll(",0.1.3-alpha,FULL,FALSE\n\n");

    try exportCategoryToCSV(.firearms);
    try exportCategoryToCSV(.soft_gear);
    try exportCategoryToCSV(.consumables);
    try exportCategoryToCSV(.nfa_items);
    try exportCategoryToCSV(.attachments);
    try exportCategoryToCSV(.reloading);
    try exportCategoryToCSV(.loadouts);
}

fn exportCategoryToCSV(cat: Category) !void {
    const home_dir = std.posix.getenv("HOME") orelse ".";
    const timestamp = std.time.timestamp();

    var filename_buf: [512]u8 = undefined;
    const filename = switch (cat) {
        .firearms => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/firearms_{d}.csv", .{ home_dir, timestamp }),
        .soft_gear => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/soft_gear_{d}.csv", .{ home_dir, timestamp }),
        .nfa_items => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/nfa_items_{d}.csv", .{ home_dir, timestamp }),
        .attachments => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/attachments_{d}.csv", .{ home_dir, timestamp }),
        .consumables => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/consumables_{d}.csv", .{ home_dir, timestamp }),
        .reloading => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/reload_batches_{d}.csv", .{ home_dir, timestamp }),
        .loadouts => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/loadouts_{d}.csv", .{ home_dir, timestamp }),
        else => std.fmt.bufPrint(&filename_buf, "{s}/Downloads/export_{d}.csv", .{ home_dir, timestamp }),
    } catch return;

    var file = try std.fs.createFileAbsolute(filename, .{});
    defer file.close();

    const data = getDataForCategory(cat);

    const headers = switch (cat) {
        .firearms => "name,caliber,serial_number,barrel_length,trust_name,notes,status,rounds_fired,clean_interval,oiling_interval",
        .soft_gear => "name,category,brand,notes,status",
        .nfa_items => "name,nfa_type,serial_number,tax_stamp_id,manufacturer,notes,status",
        .attachments => "name,category,brand,model,serial_number,mounted_on",
        .consumables => "name,category,unit,quantity,min_quantity,notes",
        .reloading => "cartridge,bullet,powder,primer,case,status",
        .loadouts => "name,description,notes",
        else => "name,notes",
    };

    try file.writeAll(headers);
    try file.writeAll("\n");

    for (data) |item| {
        try file.writeAll(item.name);
        try file.writeAll(",");
        try file.writeAll(item.col1);
        try file.writeAll(",");
        try file.writeAll(item.col2);
        try file.writeAll(",");
        try file.writeAll(item.col3);
        try file.writeAll(",");
        try file.writeAll(item.notes);
        try file.writeAll("\n");
    }
}

fn importFromCSV(cat: Category) !void {
    import_modal_open = true;
    import_success_count = 0;
    import_error_count = 0;
    @memset(&import_result_message, 0);

    const home_dir = std.posix.getenv("HOME") orelse ".";
    const prefix = switch (cat) {
        .firearms => "firearms",
        .soft_gear => "soft_gear",
        .consumables => "consumables",
        else => "data",
    };

    var filename_buf: [512]u8 = undefined;
    const default_filename = std.fmt.bufPrint(&filename_buf, "{s}/Downloads/{s}.csv", .{ home_dir, prefix }) catch return;

    @memset(&import_filename, 0);
    std.mem.copyForwards(u8, &import_filename, default_filename);
    import_filename[default_filename.len] = 0;
}

fn renderImportModal() void {
    if (!import_modal_open) return;

    zgui.setNextWindowSize(.{ .w = 500, .h = 400, .cond = .always });
    zgui.setNextWindowPos(.{ .x = 100, .y = 100, .cond = .always });

    if (zgui.begin("Import CSV", .{ .flags = .{} })) {
        zgui.text("Import from CSV", .{});
        zgui.separator();

        zgui.text("File:", .{});
        _ = zgui.inputText("##import_file", .{ .buf = &import_filename, .flags = .{ .read_only = true } });

        zgui.text("Duplicate Handling:", .{});
        _ = zgui.combo("##duplicate_mode", .{ .current_item = &import_duplicate_mode, .items_separated_by_zeros = "Skip Existing\x00Overwrite Existing\x00Create New\x00" });

        zgui.separator();

        if (zgui.button("Import", .{})) {
            import_success_count = 0;
            import_error_count = 0;
            @memset(&import_result_message, 0);

            const filename = std.mem.sliceTo(&import_filename, 0);
            importCSVFile(filename, @enumFromInt(import_duplicate_mode));
        }

        zgui.sameLine(.{});

        if (zgui.button("Close", .{})) {
            import_modal_open = false;
        }

        if (import_success_count > 0 or import_error_count > 0) {
            zgui.separator();
            zgui.text("{d} imported, {d} errors", .{ import_success_count, import_error_count });
        }

        zgui.end();
    }
}

fn importCSVFile(filename: []const u8, _: ImportDuplicateMode) void {
    const file = std.fs.openFileAbsolute(filename, .{ .mode = .read_only }) catch {
        import_error_count = 1;
        return;
    };
    defer file.close();

    const content = file.readToEndAlloc(allocator, 1024 * 1024) catch {
        import_error_count = 1;
        return;
    };
    defer allocator.free(content);

    var lines_iter = std.mem.splitSequence(u8, content, "\n");
    var section: ?[]const u8 = null;
    var in_header: bool = true;

    while (lines_iter.next()) |line| {
        const trimmed = std.mem.trim(u8, line, "\r");

        if (trimmed.len == 0) continue;

        if (std.mem.startsWith(u8, trimmed, "===")) {
            const section_name = std.mem.trim(u8, trimmed, "= ");
            if (std.mem.eql(u8, section_name, "METADATA")) {
                section = null;
                in_header = true;
            } else {
                section = section_name;
                in_header = true;
            }
            continue;
        }

        if (section == null) continue;

        if (in_header) {
            in_header = false;
            continue;
        }

        var value_iter = std.mem.splitSequence(u8, trimmed, ",");
        var values: [20][]const u8 = undefined;
        var value_count: usize = 0;

        while (value_iter.next()) |v| {
            if (value_count >= 20) break;
            values[value_count] = std.mem.trim(u8, v, " \r");
            value_count += 1;
        }

        const sec = section.?;
        if (std.mem.eql(u8, sec, "FIREARMS")) {
            importFirearm(values[0..value_count], .skip);
        } else if (std.mem.eql(u8, sec, "CONSUMABLES")) {
            importConsumable(values[0..value_count], .skip);
            importSoftGear(values[0..value_count], .skip);
            importNFAItem(values[0..value_count], .skip);
            importAttachment(values[0..value_count], .skip);
            importReloadBatch(values[0..value_count], .skip);
            importBorrower(values[0..value_count], .skip);
            importLoadout(values[0..value_count], .skip);
        }
    }
}

fn importFirearm(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";
    const caliber = if (values.len > 2) values[2] else "";
    const serial = if (values.len > 3) values[3] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.FirearmRepository{ .db = db };
    const timestamp = std.time.timestamp();

    if (repo.getById(allocator, id) catch null == null) {
        const fw = gear.firearm.Firearm{
            .id = id,
            .name = name,
            .caliber = caliber,
            .serial_number = serial,
            .purchase_date = timestamp,
            .created_at = timestamp,
            .updated_at = timestamp,
        };
        repo.create(fw) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importFirearmAsNew(name: []const u8, caliber: []const u8, serial: []const u8) void {
    const id = generateId();
    const timestamp = std.time.timestamp();

    var repo = gear.FirearmRepository{ .db = db };
    const fw = gear.firearm.Firearm{
        .id = id,
        .name = name,
        .caliber = caliber,
        .serial_number = serial,
        .purchase_date = timestamp,
        .created_at = timestamp,
        .updated_at = timestamp,
    };
    repo.create(fw) catch {
        import_error_count += 1;
        return;
    };

    import_success_count += 1;
}

fn importConsumable(values: []const []const u8, mode: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const name = if (values.len > 1) values[1] else "";
    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const category = if (values.len > 1) values[1] else "OTHER";
    const unit = if (values.len > 2) values[2] else "count";
    const qty = if (values.len > 3 and values[3].len > 0) std.fmt.parseInt(i32, values[3], 10) catch 0 else 0;
    const min_qty = if (values.len > 4 and values[4].len > 0) std.fmt.parseInt(i32, values[4], 10) catch 0 else 0;
    const notes = if (values.len > 5) values[5] else "";

    var repo = gear.ConsumableRepository{ .db = db };
    const existing = repo.getById(allocator, id) catch null;

    if (existing != null) {
        defer repo.deinit(allocator, existing.?);
        switch (mode) {
            .skip => return,
            .overwrite => {},
            .create_new => {
                const new_id = generateId();
                const csm = gear.consumable.Consumable{
                    .id = new_id,
                    .name = name,
                    .category = gear.types.ConsumableCategory.fromString(category),
                    .unit = unit,
                    .quantity = qty,
                    .min_quantity = min_qty,
                    .notes = notes,
                };
                repo.create(csm) catch {
                    import_error_count += 1;
                    return;
                };
                import_success_count += 1;
                return;
            },
        }
    }

    if (existing == null) {
        const csm = gear.consumable.Consumable{
            .id = id,
            .name = name,
            .category = gear.types.ConsumableCategory.fromString(category),
            .unit = unit,
            .quantity = qty,
            .min_quantity = min_qty,
            .notes = notes,
        };
        repo.create(csm) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importSoftGear(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";
    const category = if (values.len > 2) values[2] else "OTHER";
    const brand = if (values.len > 3) values[3] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.SoftGearRepository{ .db = db };
    const timestamp = std.time.timestamp();

    if (repo.getById(allocator, id) catch null == null) {
        const sg = gear.gear.SoftGear{
            .id = id,
            .name = name,
            .category = category,
            .brand = brand,
            .purchase_date = timestamp,
        };
        repo.create(sg) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importNFAItem(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.NFAItemRepository{ .db = db };
    const timestamp = std.time.timestamp();

    if (repo.getById(allocator, id) catch null == null) {
        const nfa = gear.gear.NFAItem{
            .id = id,
            .name = name,
            .nfa_type = .suppressor,
            .manufacturer = "",
            .serial_number = "",
            .tax_stamp_id = "",
            .caliber_bore = "",
            .purchase_date = timestamp,
        };
        repo.create(nfa) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importAttachment(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.AttachmentRepository{ .db = db };
    const timestamp = std.time.timestamp();

    if (repo.getById(allocator, id) catch null == null) {
        const att = gear.gear.Attachment{
            .id = id,
            .name = name,
            .category = "OPTICS",
            .brand = "",
            .model = "",
            .purchase_date = timestamp,
        };
        repo.create(att) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importReloadBatch(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const cartridge = if (values.len > 1) values[1] else "";

    if (cartridge.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.ReloadBatchRepository{ .db = db };
    const timestamp = std.time.timestamp();

    if (repo.getById(allocator, id) catch null == null) {
        const batch = gear.reloading.ReloadBatch{
            .id = id,
            .cartridge = cartridge,
            .date_created = timestamp,
        };
        repo.create(batch) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importBorrower(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.BorrowerRepository{ .db = db };

    if (repo.getById(allocator, id) catch null == null) {
        const borrower = gear.checkout.Borrower{
            .id = id,
            .name = name,
        };
        repo.create(borrower) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn importLoadout(values: []const []const u8, _: ImportDuplicateMode) void {
    if (values.len < 2) {
        import_error_count += 1;
        return;
    }

    const id = if (values.len > 0 and values[0].len > 0) values[0] else generateId();
    const name = if (values.len > 1) values[1] else "";

    if (name.len == 0) {
        import_error_count += 1;
        return;
    }

    var repo = gear.LoadoutRepository{ .db = db };

    if (repo.getById(allocator, id) catch null == null) {
        const loadout = gear.loadout.Loadout{
            .id = id,
            .name = name,
            .created_date = std.time.timestamp(),
        };
        repo.create(loadout) catch {
            import_error_count += 1;
            return;
        };
    }

    import_success_count += 1;
}

fn generateId() []const u8 {
    var buf: [32]u8 = undefined;
    const rand = std.time.timestamp();
    const id = std.fmt.bufPrint(&buf, "import_{d}", .{rand}) catch "import_0";
    return id;
}

fn parseDate(date_str: []const u8) i64 {
    if (date_str.len != 10) return std.time.timestamp();

    var parts_iter = std.mem.split(u8, date_str, "-");
    const year = parts_iter.next() orelse return std.time.timestamp();
    const month = parts_iter.next() orelse return std.time.timestamp();
    const day = parts_iter.next() orelse return std.time.timestamp();

    const y = std.fmt.parseInt(i64, year, 10) catch return std.time.timestamp();
    const m = std.fmt.parseInt(i64, month, 10) catch return std.time.timestamp();
    const d = std.fmt.parseInt(i64, day, 10) catch return std.time.timestamp();

    const days_since_epoch = @as(i64, (y - 1970) * 365) + @as(i64, (y - 1970) / 4) + @as(i64, (m - 1) * 30 + d);
    return days_since_epoch * 86400;
}

fn parseStatus(status_str: []const u8) gear.types.CheckoutStatus {
    if (std.mem.eql(u8, status_str, "CHECKED_OUT")) return .checked_out;
    if (std.mem.eql(u8, status_str, "MAINTENANCE")) return .maintenance;
    if (std.mem.eql(u8, status_str, "RETIRED")) return .retired;
    return .available;
}

fn parseConsumableCategory(cat: []const u8) gear.types.GearCategory {
    if (std.mem.eql(u8, cat, "AMMO")) return .ammo;
    if (std.mem.eql(u8, cat, "BATTERIES")) return .batteries;
    if (std.mem.eql(u8, cat, "HYGIENE")) return .hygiene;
    if (std.mem.eql(u8, cat, "MEDICAL")) return .medical;
    if (std.mem.eql(u8, cat, "CLEANING")) return .cleaning;
    return .other;
}

fn generateTemplate(cat: Category) !void {
    const home_dir = std.posix.getenv("HOME") orelse ".";
    const prefix = switch (cat) {
        .firearms => "firearms_template",
        .consumables => "consumables_template",
        else => "template",
    };

    var filename_buf: [512]u8 = undefined;
    const filename = std.fmt.bufPrint(&filename_buf, "{s}/Downloads/{s}.csv", .{ home_dir, prefix }) catch return;

    var file = try std.fs.createFileAbsolute(filename, .{});
    defer file.close();

    switch (cat) {
        .firearms => {
            try file.writeAll("name,caliber,serial_number,barrel_length,trust_name,notes\n");
            try file.writeAll("Example Rifle,5.56mm,SN123456,16in,My Trust,Range use only\n");
        },
        .consumables => {
            try file.writeAll("name,category,unit,quantity,min_quantity,notes\n");
            try file.writeAll("9mm NATO,AMMO,rounds,500,100,Range ammo\n");
        },
        else => {},
    }
}

fn renderTransferModal() !void {
    if (transfer_modal_open) {
        zgui.openPopup("TransferModal", .{});
    }
    if (zgui.beginPopup("TransferModal", .{})) {
        zgui.text("Transfer/Sell Firearm", .{});
        zgui.separator();

        zgui.text("Buyer Name*:", .{});
        _ = zgui.inputText("##buyer_name", .{ .buf = &transfer_buyer_name });

        zgui.text("Address*:", .{});
        _ = zgui.inputTextMultiline("##buyer_address", .{ .buf = &transfer_address });

        zgui.text("DL Number*:", .{});
        _ = zgui.inputText("##buyer_dl", .{ .buf = &transfer_dl });

        zgui.text("LTC Number:", .{});
        _ = zgui.inputText("##buyer_ltc", .{ .buf = &transfer_ltc });

        zgui.text("Sale Price ($):", .{});
        _ = zgui.inputDouble("##sale_price", .{ .v = &transfer_price, .step = 100, .step_fast = 1000 });

        zgui.text("FFL Dealer:", .{});
        _ = zgui.inputText("##ffl_dealer", .{ .buf = &transfer_ffl });

        zgui.text("Notes:", .{});
        _ = zgui.inputTextMultiline("##transfer_notes", .{ .buf = &transfer_notes });

        zgui.separator();
        const buyer_name = std.mem.sliceTo(&transfer_buyer_name, 0);
        const buyer_address = std.mem.sliceTo(&transfer_address, 0);
        const buyer_dl = std.mem.sliceTo(&transfer_dl, 0);
        const can_save = buyer_name.len > 0 and buyer_address.len > 0 and buyer_dl.len > 0;

        if (!can_save) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Transfer", .{})) {
            if (selected_id != null and can_save) {
                try saveTransfer();
            }
            transfer_modal_open = false;
            clearTransferForm();
            zgui.closeCurrentPopup();
        }
        if (!can_save) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            transfer_modal_open = false;
            clearTransferForm();
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn renderStockModal() !void {
    if (stock_modal_open) {
        zgui.openPopup("StockModal", .{});
    }
    if (zgui.beginPopup("StockModal", .{})) {
        if (stock_is_add) {
            zgui.text("Add Stock", .{});
        } else {
            zgui.text("Use Stock", .{});
        }
        zgui.separator();

        zgui.text("Quantity:", .{});
        _ = zgui.inputInt("##stock_qty", .{ .v = &stock_quantity, .step = 1 });

        zgui.separator();
        if (zgui.button("Save", .{})) {
            if (selected_id != null and stock_quantity > 0) {
                try saveStockTransaction();
            }
            stock_modal_open = false;
            stock_quantity = 1;
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            stock_modal_open = false;
            stock_quantity = 1;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn saveStockTransaction() !void {
    if (selected_id == null or stock_quantity <= 0) return;

    const timestamp = std.time.timestamp();
    var id_buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;

    const tx_type: gear.TransactionType = if (stock_is_add) .add else .use;

    const tx = gear.consumable.ConsumableTransaction{
        .id = id_str,
        .consumable_id = selected_id.?,
        .transaction_type = tx_type,
        .quantity = stock_quantity,
        .date = timestamp,
    };

    var tx_repo = gear.ConsumableTransactionRepository{ .db = db };
    try tx_repo.create(tx);

    var repo = gear.ConsumableRepository{ .db = db };
    const item = repo.getById(allocator, selected_id.?) catch null;
    if (item) |i| {
        var updated = i;
        if (stock_is_add) {
            updated.quantity += stock_quantity;
        } else {
            updated.quantity = @max(0, updated.quantity - stock_quantity);
        }
        try repo.update(updated);
    }
}

fn renderCheckoutModal() !void {
    if (checkout_modal_open) {
        zgui.openPopup("CheckoutModal", .{});
    }
    if (zgui.beginPopup("CheckoutModal", .{})) {
        if (checkout_is_loadout) {
            zgui.text("Checkout Loadout", .{});
            zgui.separator();

            zgui.text("Borrower Name:", .{});
            _ = zgui.inputText("##borrower", .{ .buf = &checkout_borrower_name });

            zgui.separator();
            if (zgui.button("Checkout", .{})) {
                if (selected_id != null) {
                    try checkoutLoadout();
                }
                checkout_modal_open = false;
                @memset(&checkout_borrower_name, 0);
                zgui.closeCurrentPopup();
            }
            zgui.sameLine(.{});
            if (zgui.button("Cancel", .{})) {
                checkout_modal_open = false;
                @memset(&checkout_borrower_name, 0);
                zgui.closeCurrentPopup();
            }
        } else {
            zgui.text("Checkout Item", .{});
            zgui.separator();

            zgui.text("Item Type:", .{});
            _ = zgui.combo("##checkout_item_type", .{ .current_item = &checkout_item_category, .items_separated_by_zeros = "Firearm\x00Soft Gear\x00NFA Item\x00" });

            zgui.text("Borrower Name:", .{});
            _ = zgui.inputText("##borrower", .{ .buf = &checkout_borrower_name });

            zgui.text("Notes:", .{});
            _ = zgui.inputTextMultiline("##checkout_notes", .{ .buf = &maint_details });

            zgui.separator();
            if (zgui.button("Checkout", .{})) {
                if (selected_id != null) {
                    try checkoutItem();
                }
                checkout_modal_open = false;
                @memset(&checkout_borrower_name, 0);
                @memset(&maint_details, 0);
                checkout_item_category = 0;
                zgui.closeCurrentPopup();
            }
            zgui.sameLine(.{});
            if (zgui.button("Cancel", .{})) {
                checkout_modal_open = false;
                @memset(&checkout_borrower_name, 0);
                @memset(&maint_details, 0);
                checkout_item_category = 0;
                zgui.closeCurrentPopup();
            }
        }
        zgui.endPopup();
    }
}

fn checkoutLoadout() !void {
    if (selected_id == null) return;

    const borrower_name = std.mem.sliceTo(&checkout_borrower_name, 0);
    if (borrower_name.len == 0) return;

    var borrower_id: []const u8 = "";

    var borrower_repo = gear.BorrowerRepository{ .db = db };
    const borrowers = borrower_repo.getAll(allocator) catch &[_]gear.checkout.Borrower{};
    for (borrowers) |b| {
        if (std.mem.eql(u8, b.name, borrower_name)) {
            borrower_id = b.id;
            break;
        }
    }

    if (borrower_id.len == 0) {
        const timestamp = std.time.timestamp();
        var id_buf: [32]u8 = undefined;
        const new_borrower_id = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
        const new_borrower = gear.checkout.Borrower{
            .id = new_borrower_id,
            .name = borrower_name,
            .phone = "",
            .email = "",
            .notes = "",
        };
        try borrower_repo.create(new_borrower);
        borrower_id = new_borrower_id;
    }

    var checkout_id_buf: [32]u8 = undefined;
    const checkout_id = std.fmt.bufPrint(&checkout_id_buf, "{d}-{x}", .{ std.time.timestamp(), @abs(std.crypto.random.int(u32)) }) catch return;

    const loadout_checkout = gear.loadout.LoadoutCheckout{
        .id = checkout_id,
        .loadout_id = selected_id.?,
        .checkout_id = checkout_id,
    };

    var loadout_checkout_repo = gear.LoadoutCheckoutRepository{ .db = db };
    try loadout_checkout_repo.create(loadout_checkout);
}

fn checkoutItem() !void {
    if (selected_id == null) return;

    const borrower_name = std.mem.sliceTo(&checkout_borrower_name, 0);
    if (borrower_name.len == 0) return;

    var borrower_id: []const u8 = "";

    var borrower_repo = gear.BorrowerRepository{ .db = db };
    const borrowers = borrower_repo.getAll(allocator) catch &[_]gear.checkout.Borrower{};
    for (borrowers) |b| {
        if (std.mem.eql(u8, b.name, borrower_name)) {
            borrower_id = b.id;
            break;
        }
    }

    if (borrower_id.len == 0) {
        const timestamp = std.time.timestamp();
        var id_buf: [32]u8 = undefined;
        const new_borrower_id = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
        const new_borrower = gear.checkout.Borrower{
            .id = new_borrower_id,
            .name = borrower_name,
            .phone = "",
            .email = "",
            .notes = "",
        };
        try borrower_repo.create(new_borrower);
        borrower_id = new_borrower_id;
    }

    const timestamp = std.time.timestamp();
    var checkout_id_buf: [32]u8 = undefined;
    const checkout_id = std.fmt.bufPrint(&checkout_id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;

    const item_type: gear.GearCategory = switch (checkout_item_category) {
        0 => .firearm,
        1 => .soft_gear,
        else => .nfa_item,
    };

    const checkout = gear.checkout.Checkout{
        .id = checkout_id,
        .item_id = selected_id.?,
        .item_type = item_type,
        .borrower_id = borrower_id,
        .checkout_date = timestamp,
        .expected_return = null,
        .actual_return = null,
        .notes = std.mem.sliceTo(&maint_details, 0),
    };

    var checkout_repo = gear.CheckoutRepository{ .db = db };
    try checkout_repo.create(checkout);

    if (item_type == .firearm) {
        var fw_repo = gear.FirearmRepository{ .db = db };
        try fw_repo.updateStatus(selected_id.?, .checked_out);
    } else if (item_type == .nfa_item) {
        var nfa_repo = gear.NFAItemRepository{ .db = db };
        try nfa_repo.updateStatus(selected_id.?, .checked_out);
    }
}

fn renderReturnModal() !void {
    if (return_modal_open) {
        zgui.openPopup("ReturnModal", .{});
    }
    if (zgui.beginPopup("ReturnModal", .{})) {
        zgui.text("Return Item", .{});
        zgui.separator();

        zgui.text("Rounds Fired:", .{});
        _ = zgui.inputInt("##return_rounds", .{ .v = &maint_rounds, .step = 10, .step_fast = 100 });

        _ = zgui.checkbox("Rain Exposure", .{ .v = &maint_reset_rounds });

        zgui.text("Ammo Type:", .{});
        _ = zgui.inputText("##ammo_type", .{ .buf = &form_trust });

        zgui.text("Notes:", .{});
        _ = zgui.inputTextMultiline("##return_notes", .{ .buf = &maint_details });

        zgui.separator();
        if (zgui.button("Return", .{})) {
            if (selected_id != null) {
                try returnCheckout();
            }
            return_modal_open = false;
            @memset(&maint_details, 0);
            @memset(&form_trust, 0);
            maint_rounds = 0;
            maint_reset_rounds = false;
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            return_modal_open = false;
            @memset(&maint_details, 0);
            @memset(&form_trust, 0);
            maint_rounds = 0;
            maint_reset_rounds = false;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn returnCheckout() !void {
    if (selected_id == null) return;

    var repo = gear.CheckoutRepository{ .db = db };
    const checkout = repo.getById(allocator, selected_id.?) catch null;
    if (checkout) |c| {
        const timestamp = std.time.timestamp();
        var updated = c;
        updated.actual_return = timestamp;
        try repo.update(updated);

        if (c.item_type == .firearm and maint_rounds > 0) {
            var fw_repo = gear.FirearmRepository{ .db = db };
            const fw = fw_repo.getById(allocator, c.item_id) catch null;
            if (fw) |f| {
                var updated_fw = f;
                updated_fw.rounds_fired += maint_rounds;
                updated_fw.last_cleaned_at = timestamp;
                try fw_repo.update(updated_fw);
            }
        }
    }
}

fn renderReloadResultsModal() !void {
    if (reload_results_modal_open) {
        zgui.openPopup("ReloadResultsModal", .{});
    }
    if (zgui.beginPopup("ReloadResultsModal", .{})) {
        zgui.text("Log Test Results", .{});
        zgui.separator();

        zgui.text("Status:", .{});
        _ = zgui.combo("##reload_status", .{ .current_item = &reload_status, .items_separated_by_zeros = ReloadStatusOptionsStr });

        zgui.text("Avg Velocity (fps):", .{});
        _ = zgui.inputInt("##reload_velocity", .{ .v = &reload_velocity, .step = 10, .step_fast = 100 });

        zgui.text("Extreme Spread:", .{});
        _ = zgui.inputInt("##reload_es", .{ .v = &reload_es, .step = 5, .step_fast = 25 });

        zgui.text("Std Deviation:", .{});
        _ = zgui.inputInt("##reload_sd", .{ .v = &reload_sd, .step = 1, .step_fast = 10 });

        zgui.text("Group Size (inches):", .{});
        _ = zgui.inputDouble("##reload_group", .{ .v = &reload_group_size, .step = 0.01 });

        zgui.text("Group Distance (yds):", .{});
        _ = zgui.inputInt("##reload_dist", .{ .v = &reload_group_distance, .step = 25 });

        zgui.text("Notes:", .{});
        _ = zgui.inputTextMultiline("##reload_notes", .{ .buf = &reload_notes });

        zgui.separator();
        if (zgui.button("Save", .{})) {
            if (selected_id != null) {
                try saveReloadResults();
            }
            reload_results_modal_open = false;
            @memset(&reload_notes, 0);
            reload_velocity = 0;
            reload_es = 0;
            reload_sd = 0;
            reload_group_size = 0;
            reload_group_distance = 100;
            reload_status = 0;
            zgui.closeCurrentPopup();
        }
        zgui.sameLine(.{});
        if (zgui.button("Cancel", .{})) {
            reload_results_modal_open = false;
            @memset(&reload_notes, 0);
            reload_velocity = 0;
            reload_es = 0;
            reload_sd = 0;
            reload_group_size = 0;
            reload_group_distance = 100;
            reload_status = 0;
            zgui.closeCurrentPopup();
        }
        zgui.endPopup();
    }
}

fn saveReloadResults() !void {
    if (selected_id == null) return;

    var repo = gear.ReloadBatchRepository{ .db = db };
    const batch = repo.getById(allocator, selected_id.?) catch null;
    if (batch) |b| {
        var updated = b;
        updated.test_date = std.time.timestamp();
        updated.avg_velocity = reload_velocity;
        updated.es = reload_es;
        updated.sd = reload_sd;
        updated.group_size_inches = if (reload_group_size > 0) reload_group_size else null;
        updated.group_distance_yards = if (reload_group_distance > 0) reload_group_distance else null;
        updated.status = gear.ReloadStatus.fromString(ReloadStatusOptions[@as(usize, @intCast(reload_status))]);
        updated.notes = std.mem.sliceTo(&reload_notes, 0);
        try repo.update(updated);
    }
}

fn duplicateReloadBatch() !void {
    if (selected_id == null) return;
    var repo = gear.ReloadBatchRepository{ .db = db };
    const batch = repo.getById(allocator, selected_id.?) catch null;
    if (batch) |b| {
        const timestamp = std.time.timestamp();
        var id_buf: [32]u8 = undefined;
        const new_id = std.fmt.bufPrintZ(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;

        var name_buf: [256]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (Copy)", .{b.cartridge}) catch b.cartridge;

        const new_batch = gear.reloading.ReloadBatch{
            .id = new_id,
            .cartridge = new_name,
            .date_created = timestamp,
            .bullet_maker = b.bullet_maker,
            .bullet_model = b.bullet_model,
            .bullet_weight_gr = b.bullet_weight_gr,
            .powder_name = b.powder_name,
            .powder_charge_gr = b.powder_charge_gr,
            .powder_lot = b.powder_lot,
            .primer_maker = b.primer_maker,
            .primer_type = b.primer_type,
            .case_brand = b.case_brand,
            .case_times_fired = b.case_times_fired,
            .coal_in = b.coal_in,
            .crimp_style = b.crimp_style,
            .intended_use = b.intended_use,
            .test_date = null,
            .avg_velocity = null,
            .es = null,
            .sd = null,
            .group_size_inches = null,
            .group_distance_yards = null,
            .status = gear.ReloadStatus.workup,
            .notes = b.notes,
        };
        try repo.create(new_batch);
    }
}

fn renderTable(data: []DisplayItem) !void {
    const cat: Category = @enumFromInt(current_category);
    const is_firearms = cat == .firearms;
    const is_loadouts = cat == .loadouts;

    if (is_loadouts) {
        if (zgui.beginTable("loadouts", .{ .column = 5, .flags = .{ .sortable = true, .resizable = true } })) {
            defer zgui.endTable();

            zgui.tableSetupColumn("Name", .{});
            zgui.tableSetupColumn("Description", .{});
            zgui.tableSetupColumn("Items", .{});
            zgui.tableSetupColumn("Consumables", .{});
            zgui.tableSetupColumn("Created", .{});
            zgui.tableHeadersRow();

            const specs = zgui.tableGetSortSpecs();
            var current_sort_col: i32 = 0;
            var current_sort_asc: bool = true;
            if (specs != null and specs.?.count > 0) {
                current_sort_col = specs.?.specs[0].index;
                current_sort_asc = specs.?.specs[0].sort_direction == .ascending;
            }

            const sorted_data = sortData(data, current_sort_col, current_sort_asc);

            for (sorted_data) |item| {
                zgui.tableNextRow(.{});

                _ = zgui.tableSetColumnIndex(0);
                const is_selected = selected_id != null and std.mem.eql(u8, selected_id.?, item.id);

                var name_buf: [128]u8 = undefined;
                const name_len = @min(item.name.len, 127);
                @memcpy(name_buf[0..name_len], item.name[0..name_len]);
                name_buf[name_len] = 0;
                const name_z: [:0]const u8 = name_buf[0..name_len :0];
                if (zgui.selectable(name_z, .{ .selected = is_selected })) {
                    selected_id = item.id;
                }

                _ = zgui.tableSetColumnIndex(1);
                zgui.textUnformatted(item.col1);

                _ = zgui.tableSetColumnIndex(2);
                zgui.textUnformatted(item.col2);

                _ = zgui.tableSetColumnIndex(3);
                zgui.textUnformatted(item.col3);

                _ = zgui.tableSetColumnIndex(4);
                zgui.textUnformatted(item.created);
            }
        }
        return;
    }

    const col1_header: [:0]const u8 = if (is_firearms) "Caliber" else switch (cat) {
        .soft_gear => "Category",
        .nfa_items => "Type",
        .attachments => "Category",
        .transfers => "Serial",
        else => "Category",
    };
    const col2_header: [:0]const u8 = if (is_firearms) "Serial" else switch (cat) {
        .soft_gear => "Brand",
        .nfa_items => "Serial",
        .attachments => "Brand",
        .transfers => "Buyer",
        else => "Brand",
    };
    const col3_header: [:0]const u8 = if (is_firearms) "Status" else switch (cat) {
        .soft_gear => "Status",
        .nfa_items => "Tax Stamp",
        .attachments => "Model",
        .transfers => "Date",
        else => "Status",
    };

    const is_consumables = cat == .consumables;

    const num_cols: u16 = if (is_firearms) 8 else 4;

    if (zgui.beginTable("gear", .{ .column = num_cols, .flags = .{ .sortable = true, .resizable = true } })) {
        defer zgui.endTable();

        if (is_firearms) {
            zgui.tableSetupColumn("#", .{});
        }
        zgui.tableSetupColumn("Name", .{});
        zgui.tableSetupColumn(col1_header, .{});
        zgui.tableSetupColumn(col2_header, .{});
        zgui.tableSetupColumn(col3_header, .{});
        if (is_firearms) {
            zgui.tableSetupColumn("Rounds", .{});
            zgui.tableSetupColumn("Last Cleaned", .{});
            zgui.tableSetupColumn("Notes", .{});
        }
        zgui.tableHeadersRow();

        const specs = zgui.tableGetSortSpecs();
        var current_sort_col: i32 = 0;
        var current_sort_asc: bool = true;
        if (specs != null and specs.?.count > 0) {
            current_sort_col = specs.?.specs[0].index;
            current_sort_asc = specs.?.specs[0].sort_direction == .ascending;
        }

        const sorted_data = sortData(data, current_sort_col, current_sort_asc);

        for (sorted_data, 0..) |item, i| {
            zgui.tableNextRow(.{});

            if (is_firearms) {
                _ = zgui.tableSetColumnIndex(0);
                zgui.text("{d}", .{i + 1});
            }

            _ = zgui.tableSetColumnIndex(if (is_firearms) 1 else 0);
            const is_selected = selected_id != null and std.mem.eql(u8, selected_id.?, item.id);

            var name_buf: [128]u8 = undefined;
            const name_len = @min(item.name.len, 127);
            @memcpy(name_buf[0..name_len], item.name[0..name_len]);
            name_buf[name_len] = 0;
            const name_z: [:0]const u8 = name_buf[0..name_len :0];
            if (zgui.selectable(name_z, .{ .selected = is_selected })) {
                selected_id = item.id;
            }

            _ = zgui.tableSetColumnIndex(if (is_firearms) 2 else 1);
            zgui.textUnformatted(item.col1);

            _ = zgui.tableSetColumnIndex(if (is_firearms) 3 else 2);
            zgui.textUnformatted(item.col2);

            _ = zgui.tableSetColumnIndex(if (is_firearms) 4 else 3);
            if (is_consumables and std.mem.eql(u8, item.col3, "LOW")) {
                zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 0.0, 0.0, 1.0 } });
                zgui.textUnformatted(item.col3);
                zgui.popStyleColor(.{ .count = 1 });
            } else {
                zgui.textUnformatted(item.col3);
            }

            if (is_firearms) {
                _ = zgui.tableSetColumnIndex(5);
                zgui.text("{d}", .{item.rounds});

                _ = zgui.tableSetColumnIndex(6);
                zgui.textUnformatted(item.last_cleaned);

                _ = zgui.tableSetColumnIndex(7);
                var notes_buf: [64]u8 = undefined;
                const truncated = if (item.notes.len > 60)
                    std.fmt.bufPrint(&notes_buf, "{s}...", .{item.notes[0..60]}) catch item.notes
                else
                    item.notes;
                zgui.textUnformatted(truncated);
            }
        }
    }
}

fn renderDetails() !void {
    zgui.separator();

    if (selected_id) |sel_id| {
        const detail_data = getDataForCategory(@as(Category, @enumFromInt(current_category)));
        const cat: Category = @enumFromInt(current_category);
        for (detail_data) |item| {
            if (std.mem.eql(u8, item.id, sel_id)) {
                zgui.text("Selected: ", .{});
                zgui.sameLine(.{});
                zgui.textUnformatted(item.name);
                zgui.text("Details: ", .{});
                zgui.sameLine(.{});
                zgui.textUnformatted(item.col1);
                zgui.text(" / ", .{});
                zgui.textUnformatted(item.col2);
                zgui.text(" / ", .{});
                zgui.textUnformatted(item.col3);
                if (cat == .transfers and item.price > 0) {
                    var price_buf: [32]u8 = undefined;
                    const price_str = std.fmt.bufPrintZ(&price_buf, "${d:.2}", .{item.price}) catch "";
                    zgui.text("Price: ", .{});
                    zgui.sameLine(.{});
                    zgui.textUnformatted(price_str);
                }
                break;
            }
        }
    } else {
        zgui.textDisabled("No item selected", .{});
    }
}

fn renderButtons() !void {
    zgui.separator();
    const cat: Category = @enumFromInt(current_category);

    if (cat == .loadouts) {
        if (zgui.button("Create Loadout", .{})) {
            @memset(&loadout_name, 0);
            @memset(&loadout_description, 0);
            @memset(&loadout_notes, 0);
            loadout_selected_items.clearAndFree(allocator);
            loadout_modal_mode = .add;
            loadout_modal_open = true;
        }
        zgui.sameLine(.{});

        const has_selection = selected_id != null;
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Edit Loadout", .{})) {
            if (selected_id != null) {
                try loadLoadoutForEdit();
            }
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});

        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Duplicate Loadout", .{})) {
            if (selected_id != null) {
                try duplicateLoadout();
            }
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});

        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.2, 0.4, 0.8, 1.0 } });
        if (zgui.button("Checkout Loadout", .{})) {
            if (selected_id != null) {
                checkout_is_loadout = true;
                checkout_modal_open = true;
            }
        }
        zgui.popStyleColor(.{});
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});

        const delete_disabled = selected_id == null;
        if (delete_disabled) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.8, 0.2, 0.2, 1.0 } });
        if (zgui.button("Delete", .{})) {
            if (selected_id != null) {
                try deleteSelectedItem();
            }
        }
        zgui.popStyleColor(.{});
        if (delete_disabled) {
            zgui.endDisabled();
        }
        return;
    }

    const btn_label: [:0]const u8 = switch (cat) {
        .firearms => "Add Firearm",
        .soft_gear => "Add Gear",
        .nfa_items => "Add NFA Item",
        .attachments => "Add Attachment",
        .consumables => "Add Consumable",
        .reloading => "Add Reload Batch",
        .loadouts => "Add Loadout",
        .checkouts => "Checkout Item",
        .borrowers => "Add Borrower",
        .transfers => "",
        .import_export => "",
    };
    if (cat == .checkouts) {
        if (zgui.button("Checkout Item", .{})) {
            checkout_is_loadout = false;
            checkout_item_category = 0;
            checkout_modal_open = true;
        }
    } else if (cat == .transfers or cat == .import_export) {
        // No add button for these categories
    } else {
        if (zgui.button(btn_label, .{})) {
            clearForm();
            modal_mode = .add;
            modal_open = true;
        }
    }
    zgui.sameLine(.{});

    const has_selection = selected_id != null;

    if (cat == .firearms or cat == .nfa_items) {
        if (zgui.button("Log Maintenance", .{})) {
            maint_modal_open = true;
        }
        zgui.sameLine(.{});

        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("View History", .{})) {
            history_modal_open = true;
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});
    }

    if (!has_selection) {
        zgui.beginDisabled(.{ .disabled = true });
    }
    if (zgui.button("Edit", .{})) {
        if (selected_id != null) {
            try loadItemForEdit();
        }
    }
    if (!has_selection) {
        zgui.endDisabled();
    }
    zgui.sameLine(.{});

    const delete_disabled = selected_id == null;
    if (delete_disabled) {
        zgui.beginDisabled(.{ .disabled = true });
    }
    zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.8, 0.2, 0.2, 1.0 } });
    if (zgui.button("Delete", .{})) {
        if (selected_id != null) {
            try deleteSelectedItem();
        }
    }
    zgui.popStyleColor(.{});
    if (delete_disabled) {
        zgui.endDisabled();
    }
    zgui.sameLine(.{});

    if (cat == .firearms and !has_selection) {
        zgui.beginDisabled(.{ .disabled = true });
    }
    if (zgui.button("Transfer/Sell", .{})) {
        if (selected_id != null) {
            transfer_modal_open = true;
        }
    }
    if (cat == .firearms and !has_selection) {
        zgui.endDisabled();
    }

    if (cat == .consumables) {
        zgui.sameLine(.{});
        if (zgui.button("Add Stock", .{})) {
            stock_is_add = true;
            stock_quantity = 1;
            stock_modal_open = true;
        }
        zgui.sameLine(.{});
        if (zgui.button("Use Stock", .{})) {
            stock_is_add = false;
            stock_quantity = 1;
            stock_modal_open = true;
        }
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("View History", .{})) {
            history_modal_open = true;
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
    }

    if (cat == .reloading) {
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Edit Batch", .{})) {
            if (selected_id != null) {
                try loadItemForEdit();
            }
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Duplicate Batch", .{})) {
            if (selected_id != null) {
                try duplicateReloadBatch();
            }
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Log Results", .{})) {
            reload_results_modal_open = true;
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
    }

    if (cat == .loadouts) {
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Checkout Loadout", .{})) {
            checkout_modal_open = true;
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
    }

    if (cat == .checkouts) {
        zgui.sameLine(.{});
        if (!has_selection) {
            zgui.beginDisabled(.{ .disabled = true });
        }
        if (zgui.button("Return Item", .{})) {
            return_modal_open = true;
        }
        if (!has_selection) {
            zgui.endDisabled();
        }
    }
}

fn clearForm() void {
    @memset(&form_name, 0);
    @memset(&form_caliber, 0);
    @memset(&form_serial, 0);
    @memset(&form_barrel, 0);
    @memset(&form_trust, 0);
    @memset(&form_notes, 0);
    @memset(&form_manufacturer, 0);
    @memset(&form_tax_stamp, 0);
    @memset(&form_caliber_bore, 0);
    @memset(&form_form_type, 0);
    @memset(&form_model, 0);
    @memset(&form_mounted_on, 0);
    @memset(&form_mount_position, 0);
    @memset(&form_zero_notes, 0);
    @memset(&form_category, 0);
    @memset(&form_unit, 0);
    form_clean_interval = 500;
    form_oil_interval = 90;
    form_zero_distance = 0;
    form_quantity = 0;
    form_min_quantity = 0;
    form_status = 0;
    form_nfa_type = 0;
    form_mounted_firearm_index = 0;
    form_consumable_category = 0;
    form_consumable_unit = 0;
}

fn clearTransferForm() void {
    @memset(&transfer_buyer_name, 0);
    @memset(&transfer_address, 0);
    @memset(&transfer_dl, 0);
    @memset(&transfer_ltc, 0);
    @memset(&transfer_ffl, 0);
    @memset(&transfer_notes, 0);
    transfer_price = 0.0;
}

fn loadItemForEdit() !void {
    const cat: Category = @enumFromInt(current_category);
    clearForm();

    switch (cat) {
        .firearms => {
            var repo = gear.FirearmRepository{ .db = db };
            const fw = repo.getById(allocator, selected_id.?) catch null;
            if (fw) |f| {
                std.mem.copyForwards(u8, &form_name, f.name);
                std.mem.copyForwards(u8, &form_caliber, f.caliber);
                std.mem.copyForwards(u8, &form_serial, f.serial_number);
                std.mem.copyForwards(u8, &form_barrel, f.barrel_length);
                std.mem.copyForwards(u8, &form_trust, f.trust_name);
                std.mem.copyForwards(u8, &form_notes, f.notes);
                form_clean_interval = f.clean_interval_rounds;
                form_oil_interval = f.oil_interval_days;
                form_status = switch (f.status) {
                    .available => 0,
                    .checked_out => 1,
                    .lost => 2,
                    .retired => 3,
                    .transferred => 4,
                };
                modal_mode = .edit;
                modal_open = true;
            }
        },
        .soft_gear => {
            var repo = gear.SoftGearRepository{ .db = db };
            const sg = repo.getById(allocator, selected_id.?) catch null;
            if (sg) |g| {
                defer repo.deinit(allocator, g);
                std.mem.copyForwards(u8, &form_name, g.name);
                std.mem.copyForwards(u8, &form_caliber, g.category);
                std.mem.copyForwards(u8, &form_serial, g.brand);
                std.mem.copyForwards(u8, &form_notes, g.notes);
                modal_mode = .edit;
                modal_open = true;
            }
        },
        .consumables => {
            var repo = gear.ConsumableRepository{ .db = db };
            const item = repo.getById(allocator, selected_id.?) catch null;
            if (item) |c| {
                std.mem.copyForwards(u8, &form_name, c.name);
                std.mem.copyForwards(u8, &form_notes, c.notes);
                form_quantity = c.quantity;
                form_min_quantity = c.min_quantity;

                const cat_str = gear.ConsumableCategory.toString(c.category);
                for (ConsumableCategoryOptions, 0..) |opt, i| {
                    if (std.mem.eql(u8, opt, cat_str)) {
                        form_consumable_category = @intCast(i);
                        break;
                    }
                }

                for (ConsumableUnitOptions, 0..) |opt, i| {
                    if (std.mem.eql(u8, opt, c.unit)) {
                        form_consumable_unit = @intCast(i);
                        break;
                    }
                }

                modal_mode = .edit;
                modal_open = true;
            }
        },
        .nfa_items => {
            var repo = gear.NFAItemRepository{ .db = db };
            const item = repo.getById(allocator, selected_id.?) catch null;
            if (item) |n| {
                std.mem.copyForwards(u8, &form_name, n.name);
                std.mem.copyForwards(u8, &form_manufacturer, n.manufacturer);
                std.mem.copyForwards(u8, &form_serial, n.serial_number);
                std.mem.copyForwards(u8, &form_tax_stamp, n.tax_stamp_id);
                std.mem.copyForwards(u8, &form_caliber_bore, n.caliber_bore);
                std.mem.copyForwards(u8, &form_form_type, n.form_type);
                std.mem.copyForwards(u8, &form_trust, n.trust_name);
                std.mem.copyForwards(u8, &form_notes, n.notes);
                form_clean_interval = n.clean_interval_rounds;
                form_oil_interval = n.oil_interval_days;
                form_nfa_type = switch (n.nfa_type) {
                    .suppressor => 0,
                    .sbr => 1,
                    .sbs => 2,
                    .aow => 3,
                    .dd => 4,
                };
                modal_mode = .edit;
                modal_open = true;
            }
        },
        .attachments => {
            var repo = gear.AttachmentRepository{ .db = db };
            const item = repo.getById(allocator, selected_id.?) catch null;
            if (item) |a| {
                std.mem.copyForwards(u8, &form_name, a.name);
                std.mem.copyForwards(u8, &form_caliber, a.category);
                std.mem.copyForwards(u8, &form_serial, a.brand);
                std.mem.copyForwards(u8, &form_model, a.model);
                std.mem.copyForwards(u8, &form_barrel, a.serial_number);
                std.mem.copyForwards(u8, &form_mount_position, a.mount_position);
                std.mem.copyForwards(u8, &form_zero_notes, a.zero_notes);
                std.mem.copyForwards(u8, &form_notes, a.notes);
                form_zero_distance = a.zero_distance_yards orelse 0;

                if (a.mounted_on_firearm_id) |fw_id| {
                    var fw_repo = gear.FirearmRepository{ .db = db };
                    const firearms = fw_repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
                    for (firearms, 0..) |fw, i| {
                        if (std.mem.eql(u8, fw.id, fw_id)) {
                            form_mounted_firearm_index = @intCast(i);
                            break;
                        }
                    }
                } else {
                    form_mounted_firearm_index = 0;
                }
                modal_mode = .edit;
                modal_open = true;
            }
        },
        .reloading => {
            var repo = gear.ReloadBatchRepository{ .db = db };
            const batch = repo.getById(allocator, selected_id.?) catch null;
            if (batch) |b| {
                std.mem.copyForwards(u8, &form_cartridge, b.cartridge);
                std.mem.copyForwards(u8, &form_bullet_maker, b.bullet_maker);
                std.mem.copyForwards(u8, &form_bullet_model, b.bullet_model);
                std.mem.copyForwards(u8, &form_powder_name, b.powder_name);
                std.mem.copyForwards(u8, &form_powder_lot, b.powder_lot);
                std.mem.copyForwards(u8, &form_primer_maker, b.primer_maker);
                std.mem.copyForwards(u8, &form_primer_type, b.primer_type);
                std.mem.copyForwards(u8, &form_case_brand, b.case_brand);
                std.mem.copyForwards(u8, &form_crimp_style, b.crimp_style);
                std.mem.copyForwards(u8, &form_intended_use, b.intended_use);
                std.mem.copyForwards(u8, &form_notes, b.notes);
                form_bullet_weight = b.bullet_weight_gr orelse 0;
                form_powder_charge = b.powder_charge_gr orelse 0.0;
                form_case_times_fired = b.case_times_fired orelse 0;
                form_coal = b.coal_in orelse 0.0;
                modal_mode = .edit;
                modal_open = true;
            }
        },
        .borrowers => {
            var repo = gear.BorrowerRepository{ .db = db };
            const borrower = repo.getById(allocator, selected_id.?) catch null;
            if (borrower) |b| {
                std.mem.copyForwards(u8, &form_name, b.name);
                std.mem.copyForwards(u8, &form_caliber, b.phone);
                std.mem.copyForwards(u8, &form_serial, b.email);
                std.mem.copyForwards(u8, &form_notes, b.notes);
                modal_mode = .edit;
                modal_open = true;
            }
        },
        else => {},
    }
}

fn duplicateLoadout() !void {
    if (selected_id == null) return;
    var loadout_repo = gear.LoadoutRepository{ .db = db };
    const loadout = loadout_repo.getById(allocator, selected_id.?) catch null;
    if (loadout) |l| {
        defer loadout_repo.deinit(allocator, l);
        const timestamp = std.time.timestamp();
        var id_buf: [32]u8 = undefined;
        const new_id = std.fmt.bufPrintZ(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch "";
        var new_name_buf: [256]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&new_name_buf, "{s} (Copy)", .{l.name}) catch l.name;
        const new_loadout = gear.loadout.Loadout{
            .id = new_id,
            .name = new_name,
            .description = l.description,
            .created_date = std.time.timestamp(),
            .notes = l.notes,
        };
        try loadout_repo.create(new_loadout);
    }
    selected_id = null;
}

fn loadLoadoutForEdit() !void {
    if (selected_id == null) return;
    var repo = gear.LoadoutRepository{ .db = db };
    const l = repo.getById(allocator, selected_id.?) catch null;
    if (l) |loadout| {
        defer repo.deinit(allocator, loadout);
        @memset(&loadout_name, 0);
        @memset(&loadout_description, 0);
        @memset(&loadout_notes, 0);
        std.mem.copyForwards(u8, &loadout_name, loadout.name);
        std.mem.copyForwards(u8, &loadout_description, loadout.description);
        std.mem.copyForwards(u8, &loadout_notes, loadout.notes);
        loadout_selected_items.clearAndFree(allocator);

        var item_repo = gear.LoadoutItemRepository{ .db = db };
        const items = item_repo.getByLoadoutId(allocator, selected_id.?) catch &[_]gear.loadout.LoadoutItem{};
        for (items) |item| {
            try loadout_selected_items.append(allocator, .{ .id = item.item_id, .item_type = item.item_type });
        }
        loadout_item_tab = 0;
        loadout_modal_mode = .edit;
        loadout_modal_open = true;
    }
}

fn renderLoadoutModal() !void {
    if (!loadout_modal_open) return;

    zgui.openPopup("LoadoutModal", .{});

    const viewport = zgui.getMainViewport();
    const modal_w: f32 = 600;
    const modal_h: f32 = 550;
    const cx = viewport.*.pos[0] + (viewport.*.size[0] - modal_w) / 2;
    const cy = viewport.*.pos[1] + (viewport.*.size[1] - modal_h) / 2;
    zgui.setNextWindowPos(.{ .x = cx, .y = cy, .cond = .always });
    zgui.setNextWindowSize(.{ .w = modal_w, .h = modal_h, .cond = .always });

    if (!zgui.beginPopup("LoadoutModal", .{})) return;

    zgui.pushStyleColor4f(.{ .idx = .window_bg, .c = .{ 0.15, 0.15, 0.2, 0.95 } });

    const title = if (loadout_modal_mode == .edit) "Edit Loadout" else "Create Loadout";
    zgui.textUnformatted(title);
    zgui.separator();

    zgui.text("Name:", .{});
    _ = zgui.inputText("##loadout_name", .{ .buf = &loadout_name });

    zgui.text("Description:", .{});
    _ = zgui.inputText("##loadout_desc", .{ .buf = &loadout_description });

    zgui.text("Notes:", .{});
    _ = zgui.inputTextMultiline("##loadout_notes", .{ .buf = &loadout_notes, .h = 80 });

    zgui.separator();
    zgui.text("Select Items:", .{});

    if (zgui.beginTabBar("loadout_items", .{})) {
        if (zgui.beginTabItem("Firearms", .{})) {
            loadout_item_tab = 0;
            try renderLoadoutItemList(.firearms);
            zgui.endTabItem();
        }
        if (zgui.beginTabItem("Soft Gear", .{})) {
            loadout_item_tab = 1;
            try renderLoadoutItemList(.soft_gear);
            zgui.endTabItem();
        }
        if (zgui.beginTabItem("NFA Items", .{})) {
            loadout_item_tab = 2;
            try renderLoadoutItemList(.nfa_items);
            zgui.endTabItem();
        }
        if (zgui.beginTabItem("Consumables", .{})) {
            loadout_item_tab = 3;
            try renderLoadoutItemList(.consumables);
            zgui.endTabItem();
        }
        zgui.endTabBar();
    }

    zgui.separator();

    const save_btn_w = modal_w * 0.55;
    const cancel_btn_w = modal_w * 0.35;
    const btn_y = zgui.getCursorPosY();

    zgui.setCursorPosY(btn_y + 5);
    zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.2, 0.4, 0.8, 1.0 } });
    if (zgui.button("Save Loadout", .{ .w = save_btn_w })) {
        try saveLoadout();
        loadout_modal_open = false;
    }
    zgui.popStyleColor(.{});

    zgui.sameLine(.{ .spacing = 10 });
    if (zgui.button("Cancel", .{ .w = cancel_btn_w })) {
        loadout_modal_open = false;
    }

    zgui.popStyleColor(.{});
    zgui.endPopup();
}

fn renderLoadoutItemList(target_cat: Category) !void {
    const items: []DisplayItem = switch (target_cat) {
        .firearms => getFirearmsForLoadout(),
        .soft_gear => getSoftGearForLoadout(),
        .nfa_items => getNFAItemsForLoadout(),
        .consumables => getConsumablesForLoadout(),
        else => &.{},
    };
    defer if (items.len > 0) allocator.free(items);

    for (items) |item| {
        var is_checked = false;
        for (loadout_selected_items.items) |selected| {
            if (std.mem.eql(u8, selected.id, item.id)) {
                is_checked = true;
                break;
            }
        }

        var checkbox_id: [64]u8 = undefined;
        const check_label = std.fmt.bufPrintZ(&checkbox_id, "##check_{s}", .{item.id}) catch "";
        if (zgui.checkbox(check_label, .{ .v = &is_checked })) {
            if (is_checked) {
                const item_type: gear.types.GearCategory = switch (target_cat) {
                    .firearms => .firearm,
                    .soft_gear => .soft_gear,
                    .nfa_items => .nfa_item,
                    .consumables => .consumable,
                    else => .firearm,
                };
                try loadout_selected_items.append(allocator, .{ .id = item.id, .item_type = item_type });
            } else {
                var idx: usize = 0;
                for (loadout_selected_items.items, 0..) |selected, i| {
                    if (std.mem.eql(u8, selected.id, item.id)) {
                        idx = i;
                        break;
                    }
                }
                if (idx < loadout_selected_items.items.len) {
                    _ = loadout_selected_items.orderedRemove(idx);
                }
            }
        }
        zgui.sameLine(.{});
        const icon = switch (target_cat) {
            .firearms => "🔫",
            .soft_gear => "🎒",
            .nfa_items => "🔴",
            .consumables => "📦",
            else => "",
        };
        zgui.text("{s} {s}", .{ icon, item.name });
    }
}

fn getFirearmsForLoadout() []DisplayItem {
    var repo = gear.FirearmRepository{ .db = db };
    const firearms = repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
    var items = allocator.alloc(DisplayItem, firearms.len) catch return &.{};
    for (firearms, 0..) |f, i| {
        items[i] = .{
            .id = f.id,
            .name = f.name,
            .col1 = "",
            .col2 = "",
            .col3 = "",
        };
    }
    return items;
}

fn getSoftGearForLoadout() []DisplayItem {
    var repo = gear.SoftGearRepository{ .db = db };
    const gear_items = repo.getAll(allocator) catch &[_]gear.gear.SoftGear{};
    var items = allocator.alloc(DisplayItem, gear_items.len) catch return &.{};
    for (gear_items, 0..) |g, i| {
        items[i] = .{
            .id = g.id,
            .name = g.name,
            .col1 = "",
            .col2 = "",
            .col3 = "",
        };
    }
    return items;
}

fn getNFAItemsForLoadout() []DisplayItem {
    var repo = gear.NFAItemRepository{ .db = db };
    const nfa_items = repo.getAll(allocator) catch &[_]gear.gear.NFAItem{};
    var items = allocator.alloc(DisplayItem, nfa_items.len) catch return &.{};
    for (nfa_items, 0..) |n, i| {
        items[i] = .{
            .id = n.id,
            .name = n.name,
            .col1 = "",
            .col2 = "",
            .col3 = "",
        };
    }
    return items;
}

fn getConsumablesForLoadout() []DisplayItem {
    var repo = gear.ConsumableRepository{ .db = db };
    const consumables = repo.getAll(allocator) catch &[_]gear.consumable.Consumable{};
    var items = allocator.alloc(DisplayItem, consumables.len) catch return &.{};
    for (consumables, 0..) |c, i| {
        items[i] = .{
            .id = c.id,
            .name = c.name,
            .col1 = "",
            .col2 = "",
            .col3 = "",
        };
    }
    return items;
}

fn saveLoadout() !void {
    const name_z = std.mem.sliceTo(&loadout_name, 0);
    if (name_z.len == 0) return;

    const desc_z = std.mem.sliceTo(&loadout_description, 0);
    const notes_z = std.mem.sliceTo(&loadout_notes, 0);
    const timestamp = std.time.timestamp();

    var id_buf: [32]u8 = undefined;
    const id = if (loadout_modal_mode == .edit and selected_id != null)
        selected_id.?
    else
        std.fmt.bufPrintZ(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch "";

    var repo = gear.LoadoutRepository{ .db = db };
    const loadout = gear.loadout.Loadout{
        .id = id,
        .name = name_z,
        .description = desc_z,
        .created_date = timestamp,
        .notes = notes_z,
    };

    if (loadout_modal_mode == .edit) {
        try repo.update(loadout);
    } else {
        try repo.create(loadout);
    }

    var item_repo = gear.LoadoutItemRepository{ .db = db };
    const existing = item_repo.getByLoadoutId(allocator, id) catch &[_]gear.loadout.LoadoutItem{};
    for (existing) |e| {
        try item_repo.delete(e.id);
    }

    for (loadout_selected_items.items) |selected| {
        var item_id_buf: [32]u8 = undefined;
        const item_id = std.fmt.bufPrintZ(&item_id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch "";
        const new_item = gear.loadout.LoadoutItem{
            .id = item_id,
            .loadout_id = id,
            .item_id = selected.id,
            .item_type = selected.item_type,
            .notes = "",
        };
        try item_repo.create(new_item);
    }

    selected_id = null;
}

fn deleteSelectedItem() !void {
    const cat: Category = @enumFromInt(current_category);
    const data = getDataForCategory(cat);
    for (data) |item| {
        if (std.mem.eql(u8, item.id, selected_id.?)) {
            switch (cat) {
                .firearms => {
                    var repo = gear.FirearmRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .soft_gear => {
                    var repo = gear.SoftGearRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .nfa_items => {
                    var repo = gear.NFAItemRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .attachments => {
                    var repo = gear.AttachmentRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .consumables => {
                    var repo = gear.ConsumableRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .reloading => {
                    var repo = gear.ReloadBatchRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .loadouts => {
                    var repo = gear.LoadoutRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .checkouts => {
                    var repo = gear.CheckoutRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .borrowers => {
                    var repo = gear.BorrowerRepository{ .db = db };
                    try repo.delete(item.id);
                },
                .transfers => {},
                .import_export => {},
            }
            selected_id = null;
            break;
        }
    }
}

fn saveMaintenance() !void {
    if (selected_id == null) return;

    const timestamp = std.time.timestamp();
    var id_buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;

    const maint_type_str = MaintTypeOptions[@as(usize, @intCast(maint_type))];
    const log_type = gear.MaintenanceType.fromString(maint_type_str);

    const cat: Category = @enumFromInt(current_category);
    const is_nfa = (cat == .nfa_items);

    const log = gear.maintenance.MaintenanceLog{
        .id = id_str,
        .item_id = selected_id.?,
        .item_type = if (is_nfa) .nfa_item else .firearm,
        .log_type = log_type,
        .date = timestamp,
        .details = std.mem.sliceTo(&maint_details, 0),
        .ammo_count = if (maint_rounds > 0) maint_rounds else null,
    };

    var repo = gear.MaintenanceLogRepository{ .db = db };
    try repo.create(log);

    if (maint_rounds > 0 or maint_reset_rounds) {
        if (is_nfa) {
            var nfa_repo = gear.NFAItemRepository{ .db = db };
            const nfa = nfa_repo.getById(allocator, selected_id.?) catch null;
            if (nfa) |n| {
                var updated_nfa = n;
                if (maint_reset_rounds) {
                    updated_nfa.rounds_fired = 0;
                } else {
                    updated_nfa.rounds_fired += maint_rounds;
                }
                try nfa_repo.update(updated_nfa);
            }
        } else {
            var fw_repo = gear.FirearmRepository{ .db = db };
            const fw = fw_repo.getById(allocator, selected_id.?) catch null;
            if (fw) |f| {
                var updated_fw = f;
                if (maint_reset_rounds) {
                    updated_fw.rounds_fired = 0;
                } else {
                    updated_fw.rounds_fired += maint_rounds;
                }
                updated_fw.last_cleaned_at = timestamp;
                try fw_repo.update(updated_fw);
            }
        }
    }
}

fn saveTransfer() !void {
    if (selected_id == null) return;

    var fw_repo = gear.FirearmRepository{ .db = db };
    const fw = fw_repo.getById(allocator, selected_id.?) catch null;
    if (fw) |f| {
        if (f.status == .checked_out) {
            return;
        }
    }

    const timestamp = std.time.timestamp();
    var id_buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;

    const transfer = gear.firearm.Transfer{
        .id = id_str,
        .firearm_id = selected_id.?,
        .transfer_date = timestamp,
        .buyer_name = std.mem.sliceTo(&transfer_buyer_name, 0),
        .buyer_address = std.mem.sliceTo(&transfer_address, 0),
        .buyer_dl_number = std.mem.sliceTo(&transfer_dl, 0),
        .buyer_ltc_number = std.mem.sliceTo(&transfer_ltc, 0),
        .sale_price = transfer_price,
        .ffl_dealer = std.mem.sliceTo(&transfer_ffl, 0),
        .notes = std.mem.sliceTo(&transfer_notes, 0),
    };

    var repo = gear.TransferRepository{ .db = db };
    try repo.create(transfer);

    try fw_repo.updateStatus(selected_id.?, .transferred);
}

fn formatTimestamp(ts: i64, buf: *[32]u8) []const u8 {
    if (ts == 0) return "Never";
    const secs_per_day: i64 = 86400;
    const days_since_epoch = @divFloor(ts, secs_per_day);
    const year: i64 = 1970 + @divFloor(days_since_epoch, 365);
    const day_of_year = @mod(days_since_epoch, 365);
    const month = @min(@divFloor(day_of_year, 30) + 1, 12);
    const day = @mod(@divFloor(day_of_year, 30) * 30 + 1, 30) + 1;
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day }) catch "Unknown";
}

fn filterData(items: []DisplayItem, search_buf: [256:0]u8) []DisplayItem {
    const search_term = std.mem.sliceTo(&search_buf, 0);
    if (search_term.len == 0) return items;

    const lower_search = allocator.alloc(u8, search_term.len) catch return items;
    defer allocator.free(lower_search);
    for (search_term, 0..) |c, i| {
        lower_search[i] = std.ascii.toLower(c);
    }

    var filtered: []DisplayItem = &.{};
    for (items) |item| {
        const lower_name = allocator.alloc(u8, item.name.len) catch continue;
        defer allocator.free(lower_name);
        for (item.name, 0..) |c, i| {
            lower_name[i] = std.ascii.toLower(c);
        }
        if (std.mem.indexOf(u8, lower_name, lower_search) != null) {
            filtered = allocator.realloc(filtered, filtered.len + 1) catch continue;
            filtered[filtered.len - 1] = item;
        }
    }

    return filtered;
}

fn sortData(items: []DisplayItem, sort_col: i32, ascending: bool) []DisplayItem {
    if (items.len <= 1) return items;

    const sort_ctx = .{ .col = sort_col, .asc = ascending };
    std.mem.sort(DisplayItem, items, sort_ctx, struct {
        fn cmp(ctx: @TypeOf(sort_ctx), a: DisplayItem, b: DisplayItem) bool {
            const a_val: []const u8 = switch (ctx.col) {
                0 => a.name,
                1 => a.col1,
                2 => a.col2,
                else => a.col3,
            };
            const b_val: []const u8 = switch (ctx.col) {
                0 => b.name,
                1 => b.col1,
                2 => b.col2,
                else => b.col3,
            };
            const ord = std.mem.order(u8, a_val, b_val);
            return if (ctx.asc) ord == .lt else ord == .gt;
        }
    }.cmp);

    return items;
}

fn getDataForCategory(cat: Category) []DisplayItem {
    var items: []DisplayItem = &.{};

    switch (cat) {
        .firearms => {
            var repo = gear.FirearmRepository{ .db = db };
            const firearms = repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
            items = allocator.alloc(DisplayItem, firearms.len) catch return &.{};
            for (firearms, 0..) |f, i| {
                var last_cleaned_str: [32]u8 = undefined;
                const lc = if (f.last_cleaned_at > 0) formatTimestamp(f.last_cleaned_at, &last_cleaned_str) else "Never";
                items[i] = .{
                    .id = f.id,
                    .name = f.name,
                    .col1 = f.caliber,
                    .col2 = f.serial_number,
                    .col3 = @tagName(f.status),
                    .rounds = f.rounds_fired,
                    .last_cleaned = lc,
                    .notes = f.notes,
                };
            }
        },
        .soft_gear => {
            var repo = gear.SoftGearRepository{ .db = db };
            const gear_items = repo.getAll(allocator) catch &[_]gear.gear.SoftGear{};
            items = allocator.alloc(DisplayItem, gear_items.len) catch return &.{};
            for (gear_items, 0..) |g, i| {
                items[i] = .{
                    .id = g.id,
                    .name = g.name,
                    .col1 = g.category,
                    .col2 = g.brand,
                    .col3 = @tagName(g.status),
                };
            }
        },
        .nfa_items => {
            var repo = gear.NFAItemRepository{ .db = db };
            const nfa_items = repo.getAll(allocator) catch &[_]gear.gear.NFAItem{};
            items = allocator.alloc(DisplayItem, nfa_items.len) catch return &.{};
            for (nfa_items, 0..) |n, i| {
                items[i] = .{
                    .id = n.id,
                    .name = n.name,
                    .col1 = @tagName(n.nfa_type),
                    .col2 = n.serial_number,
                    .col3 = n.tax_stamp_id,
                };
            }
        },
        .attachments => {
            var repo = gear.AttachmentRepository{ .db = db };
            const attachments = repo.getAll(allocator) catch &[_]gear.gear.Attachment{};
            items = allocator.alloc(DisplayItem, attachments.len) catch return &.{};
            for (attachments, 0..) |a, i| {
                items[i] = .{
                    .id = a.id,
                    .name = a.name,
                    .col1 = a.category,
                    .col2 = a.brand,
                    .col3 = a.model,
                };
            }
        },
        .consumables => {
            var repo = gear.ConsumableRepository{ .db = db };
            const consumables = repo.getAll(allocator) catch &[_]gear.consumable.Consumable{};
            items = allocator.alloc(DisplayItem, consumables.len) catch return &.{};
            for (consumables, 0..) |c, i| {
                var qty_str: [32]u8 = undefined;
                const qty = std.fmt.bufPrintZ(&qty_str, "{d} {s}", .{ c.quantity, c.unit }) catch "";
                var status: []const u8 = "OK";
                if (c.quantity <= c.min_quantity) {
                    status = "LOW";
                }
                items[i] = .{
                    .id = c.id,
                    .name = c.name,
                    .col1 = @tagName(c.category),
                    .col2 = qty,
                    .col3 = status,
                    .notes = c.notes,
                };
            }
        },
        .reloading => {
            var repo = gear.ReloadBatchRepository{ .db = db };
            const batches = repo.getAll(allocator) catch &[_]gear.reloading.ReloadBatch{};
            items = allocator.alloc(DisplayItem, batches.len) catch return &.{};
            for (batches, 0..) |b, i| {
                items[i] = .{
                    .id = b.id,
                    .name = b.cartridge,
                    .col1 = b.bullet_maker,
                    .col2 = b.powder_name,
                    .col3 = @tagName(b.status),
                    .notes = b.notes,
                };
            }
        },
        .loadouts => {
            var repo = gear.LoadoutRepository{ .db = db };
            const loadouts = repo.getAll(allocator) catch &[_]gear.loadout.Loadout{};
            items = allocator.alloc(DisplayItem, loadouts.len) catch return &.{};
            for (loadouts, 0..) |l, i| {
                const item_count = repo.countItems(l.id) catch 0;
                const consumable_count = repo.countConsumables(l.id) catch 0;
                var item_buf: [16]u8 = undefined;
                var consumable_buf: [16]u8 = undefined;
                var date_buf: [32]u8 = undefined;
                const item_str = std.fmt.bufPrintZ(&item_buf, "{d}", .{item_count}) catch "0";
                const consumable_str = std.fmt.bufPrintZ(&consumable_buf, "{d}", .{consumable_count}) catch "0";
                const date_str = formatTimestamp(l.created_date, &date_buf);
                items[i] = .{
                    .id = l.id,
                    .name = l.name,
                    .col1 = l.description,
                    .col2 = item_str,
                    .col3 = consumable_str,
                    .notes = l.notes,
                    .created = date_str,
                };
            }
        },
        .checkouts => {
            var repo = gear.CheckoutRepository{ .db = db };
            const checkouts = repo.getActive(allocator) catch &[_]gear.checkout.Checkout{};
            items = allocator.alloc(DisplayItem, checkouts.len) catch return &.{};
            for (checkouts, 0..) |c, i| {
                var date_buf: [32]u8 = undefined;
                const date_str = formatTimestamp(c.checkout_date, &date_buf);
                items[i] = .{
                    .id = c.id,
                    .name = c.item_id,
                    .col1 = @tagName(c.item_type),
                    .col2 = c.borrower_id,
                    .col3 = date_str,
                    .notes = c.notes,
                };
            }
        },
        .borrowers => {
            var repo = gear.BorrowerRepository{ .db = db };
            const borrowers = repo.getAll(allocator) catch &[_]gear.checkout.Borrower{};
            items = allocator.alloc(DisplayItem, borrowers.len) catch return &.{};
            for (borrowers, 0..) |b, i| {
                items[i] = .{
                    .id = b.id,
                    .name = b.name,
                    .col1 = b.phone,
                    .col2 = b.email,
                    .col3 = b.notes,
                };
            }
        },
        .transfers => {
            var repo = gear.TransferRepository{ .db = db };
            const transfers = repo.getAll(allocator) catch &[_]gear.firearm.Transfer{};
            var fw_repo = gear.FirearmRepository{ .db = db };
            items = allocator.alloc(DisplayItem, transfers.len) catch return &.{};
            for (transfers, 0..) |t, i| {
                var date_buf: [32]u8 = undefined;
                const date_str = formatTimestamp(t.transfer_date, &date_buf);
                const firearm = fw_repo.getById(allocator, t.firearm_id) catch null;
                const fw_name = if (firearm) |f| f.name else t.firearm_id;
                const fw_serial = if (firearm) |f| f.serial_number else "";
                items[i] = .{
                    .id = t.id,
                    .name = fw_name,
                    .col1 = fw_serial,
                    .col2 = t.buyer_name,
                    .col3 = date_str,
                    .price = t.sale_price,
                };
            }
        },
        .import_export => {},
    }

    return items;
}

fn saveItem() !void {
    const name = std.mem.sliceTo(&form_name, 0);
    if (name.len == 0) return;

    const cat: Category = @enumFromInt(current_category);
    const timestamp = std.time.timestamp();

    switch (cat) {
        .firearms => {
            var repo = gear.FirearmRepository{ .db = db };
            const caliber = std.mem.sliceTo(&form_caliber, 0);
            const serial = std.mem.sliceTo(&form_serial, 0);
            const barrel = std.mem.sliceTo(&form_barrel, 0);
            const trust = std.mem.sliceTo(&form_trust, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            const status: gear.CheckoutStatus = switch (form_status) {
                0 => .available,
                1 => .checked_out,
                2 => .lost,
                3 => .retired,
                4 => .transferred,
                else => .available,
            };

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    const firearm = gear.firearm.Firearm{
                        .id = selected_id.?,
                        .name = name,
                        .caliber = if (caliber.len > 0) caliber else "Unknown",
                        .serial_number = serial,
                        .purchase_date = e.purchase_date,
                        .notes = notes,
                        .status = status,
                        .is_nfa = e.is_nfa,
                        .nfa_type = e.nfa_type,
                        .tax_stamp_id = e.tax_stamp_id,
                        .form_type = e.form_type,
                        .barrel_length = barrel,
                        .trust_name = trust,
                        .transfer_status = e.transfer_status,
                        .rounds_fired = e.rounds_fired,
                        .clean_interval_rounds = form_clean_interval,
                        .oil_interval_days = form_oil_interval,
                        .needs_maintenance = e.needs_maintenance,
                        .maintenance_conditions = e.maintenance_conditions,
                        .last_cleaned_at = e.last_cleaned_at,
                        .last_oiled_at = e.last_oiled_at,
                        .created_at = e.created_at,
                        .updated_at = timestamp,
                    };
                    try repo.update(firearm);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const firearm = gear.firearm.Firearm{
                    .id = id_str,
                    .name = name,
                    .caliber = if (caliber.len > 0) caliber else "Unknown",
                    .serial_number = serial,
                    .purchase_date = timestamp,
                    .notes = notes,
                    .status = status,
                    .is_nfa = false,
                    .nfa_type = null,
                    .tax_stamp_id = "",
                    .form_type = "",
                    .barrel_length = barrel,
                    .trust_name = trust,
                    .transfer_status = .owned,
                    .rounds_fired = 0,
                    .clean_interval_rounds = form_clean_interval,
                    .oil_interval_days = form_oil_interval,
                    .needs_maintenance = false,
                    .maintenance_conditions = "",
                    .last_cleaned_at = 0,
                    .last_oiled_at = 0,
                    .created_at = timestamp,
                    .updated_at = timestamp,
                };
                try repo.create(firearm);
            }
        },
        .soft_gear => {
            var repo = gear.SoftGearRepository{ .db = db };
            const category = std.mem.sliceTo(&form_caliber, 0);
            const brand = std.mem.sliceTo(&form_serial, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    defer repo.deinit(allocator, e);
                    const sg = gear.gear.SoftGear{
                        .id = selected_id.?,
                        .name = name,
                        .category = if (category.len > 0) category else "General",
                        .brand = brand,
                        .purchase_date = e.purchase_date,
                        .notes = notes,
                        .status = e.status,
                    };
                    try repo.update(sg);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const sg = gear.gear.SoftGear{
                    .id = id_str,
                    .name = name,
                    .category = if (category.len > 0) category else "General",
                    .brand = brand,
                    .purchase_date = timestamp,
                    .notes = notes,
                    .status = .available,
                };
                try repo.create(sg);
            }
        },
        .nfa_items => {
            var repo = gear.NFAItemRepository{ .db = db };
            const manufacturer = std.mem.sliceTo(&form_manufacturer, 0);
            const serial = std.mem.sliceTo(&form_serial, 0);
            const tax_stamp = std.mem.sliceTo(&form_tax_stamp, 0);
            const caliber_bore = std.mem.sliceTo(&form_caliber_bore, 0);
            const form_type = std.mem.sliceTo(&form_form_type, 0);
            const trust_name = std.mem.sliceTo(&form_trust, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            const nfa_type = gear.NFAItemType.fromString(NFAItemTypeOptions[@as(usize, @intCast(form_nfa_type))]);

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    const item = gear.gear.NFAItem{
                        .id = selected_id.?,
                        .name = name,
                        .nfa_type = nfa_type,
                        .manufacturer = manufacturer,
                        .serial_number = serial,
                        .tax_stamp_id = tax_stamp,
                        .caliber_bore = caliber_bore,
                        .purchase_date = e.purchase_date,
                        .form_type = form_type,
                        .trust_name = trust_name,
                        .notes = notes,
                        .status = e.status,
                        .rounds_fired = e.rounds_fired,
                        .clean_interval_rounds = form_clean_interval,
                        .oil_interval_days = form_oil_interval,
                        .needs_maintenance = e.needs_maintenance,
                        .maintenance_conditions = e.maintenance_conditions,
                    };
                    try repo.update(item);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const item = gear.gear.NFAItem{
                    .id = id_str,
                    .name = name,
                    .nfa_type = nfa_type,
                    .manufacturer = manufacturer,
                    .serial_number = serial,
                    .tax_stamp_id = tax_stamp,
                    .caliber_bore = caliber_bore,
                    .purchase_date = timestamp,
                    .form_type = form_type,
                    .trust_name = trust_name,
                    .notes = notes,
                    .status = .available,
                    .rounds_fired = 0,
                    .clean_interval_rounds = form_clean_interval,
                    .oil_interval_days = form_oil_interval,
                    .needs_maintenance = false,
                    .maintenance_conditions = "",
                };
                try repo.create(item);
            }
        },
        .attachments => {
            var repo = gear.AttachmentRepository{ .db = db };
            const category = std.mem.sliceTo(&form_caliber, 0);
            const brand = std.mem.sliceTo(&form_serial, 0);
            const model = std.mem.sliceTo(&form_model, 0);
            const serial = std.mem.sliceTo(&form_barrel, 0);
            const mount_position = std.mem.sliceTo(&form_mount_position, 0);
            const zero_notes = std.mem.sliceTo(&form_zero_notes, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            var mounted_on_id: ?[]const u8 = null;
            var fw_repo = gear.FirearmRepository{ .db = db };
            const firearms = fw_repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
            const fw_index = @as(usize, @intCast(form_mounted_firearm_index));
            if (fw_index < firearms.len) {
                mounted_on_id = firearms[fw_index].id;
            }

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    const att = gear.gear.Attachment{
                        .id = selected_id.?,
                        .name = name,
                        .category = if (category.len > 0) category else "General",
                        .brand = brand,
                        .model = model,
                        .purchase_date = e.purchase_date,
                        .serial_number = serial,
                        .mounted_on_firearm_id = mounted_on_id,
                        .mount_position = mount_position,
                        .zero_distance_yards = if (form_zero_distance > 0) form_zero_distance else null,
                        .zero_notes = zero_notes,
                        .notes = notes,
                    };
                    try repo.update(att);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const att = gear.gear.Attachment{
                    .id = id_str,
                    .name = name,
                    .category = if (category.len > 0) category else "General",
                    .brand = brand,
                    .model = model,
                    .purchase_date = timestamp,
                    .serial_number = serial,
                    .mounted_on_firearm_id = mounted_on_id,
                    .mount_position = mount_position,
                    .zero_distance_yards = if (form_zero_distance > 0) form_zero_distance else null,
                    .zero_notes = zero_notes,
                    .notes = notes,
                };
                try repo.create(att);
            }
        },
        .consumables => {
            var repo = gear.ConsumableRepository{ .db = db };
            const category_str = ConsumableCategoryOptions[@as(usize, @intCast(form_consumable_category))];
            const unit = ConsumableUnitOptions[@as(usize, @intCast(form_consumable_unit))];
            const notes = std.mem.sliceTo(&form_notes, 0);

            const category = gear.ConsumableCategory.fromString(category_str);

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing != null) {
                    const item = gear.consumable.Consumable{
                        .id = selected_id.?,
                        .name = name,
                        .category = category,
                        .unit = unit,
                        .quantity = form_quantity,
                        .min_quantity = form_min_quantity,
                        .notes = notes,
                    };
                    try repo.update(item);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const item = gear.consumable.Consumable{
                    .id = id_str,
                    .name = name,
                    .category = category,
                    .unit = unit,
                    .quantity = form_quantity,
                    .min_quantity = form_min_quantity,
                    .notes = notes,
                };
                try repo.create(item);
            }
        },
        .reloading => {
            var repo = gear.ReloadBatchRepository{ .db = db };
            const cartridge = std.mem.sliceTo(&form_cartridge, 0);
            const bullet_maker = std.mem.sliceTo(&form_bullet_maker, 0);
            const bullet_model = std.mem.sliceTo(&form_bullet_model, 0);
            const powder_name = std.mem.sliceTo(&form_powder_name, 0);
            const powder_lot = std.mem.sliceTo(&form_powder_lot, 0);
            const primer_maker = std.mem.sliceTo(&form_primer_maker, 0);
            const primer_type = std.mem.sliceTo(&form_primer_type, 0);
            const case_brand = std.mem.sliceTo(&form_case_brand, 0);
            const crimp_style = std.mem.sliceTo(&form_crimp_style, 0);
            const intended_use = std.mem.sliceTo(&form_intended_use, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            var firearm_id: ?[]const u8 = null;
            const fw_name = std.mem.sliceTo(&form_firearm_id, 0);
            if (fw_name.len > 0) {
                var fw_repo = gear.FirearmRepository{ .db = db };
                const firearms = fw_repo.getAll(allocator) catch &[_]gear.firearm.Firearm{};
                for (firearms) |fw| {
                    if (std.mem.eql(u8, fw.name, fw_name)) {
                        firearm_id = fw.id;
                        break;
                    }
                }
            }

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    const batch = gear.reloading.ReloadBatch{
                        .id = selected_id.?,
                        .cartridge = cartridge,
                        .firearm_id = firearm_id,
                        .date_created = e.date_created,
                        .bullet_maker = bullet_maker,
                        .bullet_model = bullet_model,
                        .bullet_weight_gr = if (form_bullet_weight > 0) form_bullet_weight else null,
                        .powder_name = powder_name,
                        .powder_charge_gr = if (form_powder_charge > 0) form_powder_charge else null,
                        .powder_lot = powder_lot,
                        .primer_maker = primer_maker,
                        .primer_type = primer_type,
                        .case_brand = case_brand,
                        .case_times_fired = if (form_case_times_fired > 0) form_case_times_fired else null,
                        .case_prep_notes = "",
                        .coal_in = if (form_coal > 0) form_coal else null,
                        .crimp_style = crimp_style,
                        .test_date = null,
                        .avg_velocity = null,
                        .es = null,
                        .sd = null,
                        .group_size_inches = null,
                        .group_distance_yards = null,
                        .intended_use = intended_use,
                        .status = existing.?.status,
                        .notes = notes,
                    };
                    try repo.update(batch);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const batch = gear.reloading.ReloadBatch{
                    .id = id_str,
                    .cartridge = cartridge,
                    .firearm_id = firearm_id,
                    .date_created = timestamp,
                    .bullet_maker = bullet_maker,
                    .bullet_model = bullet_model,
                    .bullet_weight_gr = if (form_bullet_weight > 0) form_bullet_weight else null,
                    .powder_name = powder_name,
                    .powder_charge_gr = if (form_powder_charge > 0) form_powder_charge else null,
                    .powder_lot = powder_lot,
                    .primer_maker = primer_maker,
                    .primer_type = primer_type,
                    .case_brand = case_brand,
                    .case_times_fired = if (form_case_times_fired > 0) form_case_times_fired else null,
                    .case_prep_notes = "",
                    .coal_in = if (form_coal > 0) form_coal else null,
                    .crimp_style = crimp_style,
                    .test_date = null,
                    .avg_velocity = null,
                    .es = null,
                    .sd = null,
                    .group_size_inches = null,
                    .group_distance_yards = null,
                    .intended_use = intended_use,
                    .status = .workup,
                    .notes = notes,
                };
                try repo.create(batch);
            }
        },
        .loadouts => {
            var repo = gear.LoadoutRepository{ .db = db };
            const description = std.mem.sliceTo(&form_caliber, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing) |e| {
                    const loadout = gear.loadout.Loadout{
                        .id = selected_id.?,
                        .name = name,
                        .description = description,
                        .notes = notes,
                        .created_date = e.created_date,
                    };
                    try repo.update(loadout);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const loadout = gear.loadout.Loadout{
                    .id = id_str,
                    .name = name,
                    .description = description,
                    .notes = notes,
                    .created_date = timestamp,
                };
                try repo.create(loadout);
            }
        },
        .checkouts => {},
        .borrowers => {
            var repo = gear.BorrowerRepository{ .db = db };
            const phone = std.mem.sliceTo(&form_caliber, 0);
            const email = std.mem.sliceTo(&form_serial, 0);
            const notes = std.mem.sliceTo(&form_notes, 0);

            if (modal_mode == .edit and selected_id != null) {
                const existing = repo.getById(allocator, selected_id.?) catch null;
                if (existing != null) {
                    const borrower = gear.checkout.Borrower{
                        .id = selected_id.?,
                        .name = name,
                        .phone = phone,
                        .email = email,
                        .notes = notes,
                    };
                    try repo.update(borrower);
                }
            } else {
                var id_buf: [32]u8 = undefined;
                const id_str = std.fmt.bufPrint(&id_buf, "{d}-{x}", .{ timestamp, @abs(std.crypto.random.int(u32)) }) catch return;
                const borrower = gear.checkout.Borrower{
                    .id = id_str,
                    .name = name,
                    .phone = phone,
                    .email = email,
                    .notes = notes,
                };
                try repo.create(borrower);
            }
        },
        .transfers => {},
        .import_export => {},
    }
}
